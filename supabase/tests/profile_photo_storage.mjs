// Explicit operator-run integration coverage against disposable test accounts.
// Requires Node 20+. All object writes/deletes go through Storage API, never SQL.
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

const base = process.env.SUPABASE_URL?.replace(/\/$/, '');
const key = process.env.SUPABASE_PUBLISHABLE_KEY;
const owner = process.env.PHOTO_OWNER_JWT;
const peer = process.env.PHOTO_PEER_JWT;
const unrelated = process.env.PHOTO_UNRELATED_JWT;
const jpegFile = process.env.PHOTO_TEST_JPEG;
if (![base, key, owner, peer, unrelated, jpegFile].every(Boolean)) {
    throw new Error('Set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, PHOTO_OWNER_JWT, PHOTO_PEER_JWT, PHOTO_UNRELATED_JWT, PHOTO_TEST_JPEG. Use three disposable permanent accounts.');
}
const userId = token => JSON.parse(Buffer.from(token.split('.')[1], 'base64url')).sub;
const ownerId = userId(owner);
const peerId = userId(peer);
if (new Set([ownerId, peerId, userId(unrelated)]).size !== 3) throw new Error('Accounts must be distinct.');
const jpeg = await readFile(jpegFile);
if (jpeg.length > 1048576 || jpeg[0] !== 0xff || jpeg[1] !== 0xd8) throw new Error('Provide a real JPEG fixture no larger than 1 MiB.');
const path = `${ownerId}/${randomUUID()}.jpg`;
let circleId;
let previousPath;
let profileChanged = false;
let uploaded = false;
const headers = (token, extras = {}) => ({ apikey: key, ...(token ? { Authorization: `Bearer ${token}` } : {}), ...extras });
const request = (route, token, method = 'GET', body, extras = {}) => fetch(`${base}${route}`, {
    method, headers: headers(token, { ...(body === undefined ? {} : { 'Content-Type': 'application/json' }), ...extras }),
    body: body === undefined ? undefined : body instanceof Buffer ? body : JSON.stringify(body)
});
async function allowed(response, label) {
    if (!response.ok) throw new Error(`${label} rejected (${response.status}): ${await response.text()}`);
    return response;
}
async function denied(response, label) {
    if (response.ok) throw new Error(`${label} unexpectedly succeeded: ${await response.text()}`);
    if (response.status >= 500) throw new Error(`${label} hit server failure instead of authorization/validation rejection: ${await response.text()}`);
}
const objectRoute = `/storage/v1/object/profile-photos/${path}`;
const sign = token => request(`/storage/v1/object/sign/profile-photos/${path}`, token, 'POST', { expiresIn: 300 });
const authenticatedDownload = token => request(`/storage/v1/object/authenticated/profile-photos/${path}`, token);
async function setPath(avatarPath) {
    await allowed(await request(`/rest/v1/profiles?id=eq.${ownerId}`, owner, 'PATCH', { avatar_path: avatarPath }), 'profile photo reference');
}
try {
    const profiles = await (await allowed(await request(`/rest/v1/profiles?id=eq.${ownerId}&select=avatar_path`, owner), 'load owner profile')).json();
    if (profiles.length !== 1) throw new Error('Owner profile missing.');
    previousPath = profiles[0].avatar_path;
    const sharedMemberships = await (await allowed(await request(
        `/rest/v1/circle_memberships?user_id=in.(${peerId},${userId(unrelated)})&select=user_id`, owner
    ), 'check disposable account isolation')).json();
    if (sharedMemberships.length !== 0) throw new Error('Test accounts must not share any preexisting Circles.');
    const circles = await (await allowed(await request('/rest/v1/circles', owner, 'POST', {
        name: `Photo permission test ${randomUUID()}`, owner_id: ownerId
    }, { Prefer: 'return=representation' }), 'create Circle fixture')).json();
    circleId = circles[0].id;
    await allowed(await request('/rest/v1/circle_memberships', owner, 'POST', [
        { circle_id: circleId, user_id: ownerId, role: 'owner' },
        { circle_id: circleId, user_id: peerId, role: 'member' }
    ]), 'seed Circle memberships');

    await allowed(await request(objectRoute, owner, 'POST', jpeg, { 'Content-Type': 'image/jpeg', 'x-upsert': 'false' }), 'owner immutable upload');
    uploaded = true;
    await denied(await sign(peer), 'peer signing an uncommitted upload');
    await setPath(path);
    profileChanged = true;
    await allowed(await sign(owner), 'owner signed URL');
    await allowed(await sign(peer), 'current peer signed URL');
    await allowed(await authenticatedDownload(owner), 'owner authenticated download');
    await allowed(await authenticatedDownload(peer), 'peer authenticated download');
    await denied(await sign(unrelated), 'unrelated signed URL');
    await denied(await authenticatedDownload(unrelated), 'unrelated download');
    await denied(await sign(null), 'signed-out signed URL');
    await denied(await authenticatedDownload(null), 'signed-out download');
    await denied(await request(`/storage/v1/object/public/profile-photos/${path}`, null), 'public bucket download');
    await denied(await request(objectRoute, owner, 'POST', jpeg, { 'Content-Type': 'image/jpeg', 'x-upsert': 'true' }), 'immutable overwrite');
    await denied(await request(`/storage/v1/object/profile-photos/${peerId}/${randomUUID()}.jpg`, owner, 'POST', jpeg, { 'Content-Type': 'image/jpeg' }), 'foreign-folder upload');
    await denied(await request(`/storage/v1/object/profile-photos/${ownerId}/nested/${randomUUID()}.jpg`, owner, 'POST', jpeg, { 'Content-Type': 'image/jpeg' }), 'nested-path upload');
    await denied(await request(`/storage/v1/object/profile-photos/${ownerId}/${randomUUID()}.png`, owner, 'POST', jpeg, { 'Content-Type': 'image/jpeg' }), 'non-JPEG path');
    await denied(await request(`/storage/v1/object/profile-photos/${ownerId}/${randomUUID()}.jpg`, owner, 'POST', jpeg, { 'Content-Type': 'image/png' }), 'non-JPEG MIME');
    await denied(await request(`/storage/v1/object/profile-photos/${ownerId}/${randomUUID()}.jpg`, owner, 'POST', Buffer.alloc(1048577), { 'Content-Type': 'image/jpeg' }), 'oversized upload');

    // DELETE may return success with zero authorized rows. Assert the object survives.
    await request('/storage/v1/object/profile-photos', peer, 'DELETE', { prefixes: [path] });
    await allowed(await authenticatedDownload(owner), 'owner photo after denied peer deletion');
    await request('/storage/v1/object/profile-photos', unrelated, 'DELETE', { prefixes: [path] });
    await allowed(await authenticatedDownload(owner), 'owner photo after denied unrelated deletion');
    await request('/storage/v1/object/profile-photos', null, 'DELETE', { prefixes: [path] });
    await allowed(await authenticatedDownload(owner), 'owner photo after denied signed-out deletion');

    await allowed(await request(`/rest/v1/circle_memberships?circle_id=eq.${circleId}&user_id=eq.${peerId}`, owner, 'DELETE'), 'revoke Circle membership');
    await denied(await sign(peer), 'revoked peer issuing new URL');
    await denied(await authenticatedDownload(peer), 'revoked peer authenticated download');
    // Previously issued bearer URLs are intentionally not claimed to be revoked.
    await setPath(previousPath);
    profileChanged = false;
    await allowed(await request('/storage/v1/object/profile-photos', owner, 'DELETE', { prefixes: [path] }), 'owner deletion');
    uploaded = false;
    await denied(await authenticatedDownload(owner), 'download after owner deletion');
    console.log('Storage photo permissions passed: owner/peer/unrelated/signed-out/revoked; immutable, MIME, size, path, and owner deletion.');
} finally {
    // Restore reference before deleting the object; failures remain visible for operator retry.
    if (profileChanged) await setPath(previousPath);
    if (uploaded) await allowed(await request('/storage/v1/object/profile-photos', owner, 'DELETE', { prefixes: [path] }), 'cleanup uploaded photo');
    if (circleId) await allowed(await request(`/rest/v1/circles?id=eq.${circleId}`, owner, 'DELETE'), 'cleanup Circle fixture');
}
