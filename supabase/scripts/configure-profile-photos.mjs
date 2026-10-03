// Operator-run setup only. Requires a trusted server-side service-role key.
// Never bundle this script or its environment into the iOS application.
const url = process.env.SUPABASE_URL?.replace(/\/$/, '');
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) throw new Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY for the intended environment.');
const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
const endpoint = `${url}/storage/v1/bucket/profile-photos`;
const existing = await fetch(endpoint, { headers });
if (!existing.ok && existing.status !== 404 && existing.status !== 400) {
    throw new Error(`Bucket lookup failed (${existing.status}): ${await existing.text()}`);
}
if (!existing.ok) {
    const error = await existing.json();
    if (!['404', '400'].includes(String(error.statusCode)) || !/not found/i.test(error.message ?? '')) {
        throw new Error(`Bucket lookup failed: ${JSON.stringify(error)}`);
    }
}
const configuration = { public: false, file_size_limit: 1048576, allowed_mime_types: ['image/jpeg'] };
const result = await fetch(existing.ok ? endpoint : `${url}/storage/v1/bucket`, {
    method: existing.ok ? 'PUT' : 'POST', headers,
    body: JSON.stringify(existing.ok ? configuration : { id: 'profile-photos', name: 'profile-photos', ...configuration })
});
if (!result.ok) throw new Error(`Bucket configuration failed (${result.status}): ${await result.text()}`);
const verification = await fetch(endpoint, { headers });
if (!verification.ok) throw new Error(`Bucket verification failed (${verification.status}).`);
const bucket = await verification.json();
if (bucket.public !== false || Number(bucket.file_size_limit) !== 1048576 ||
    JSON.stringify(bucket.allowed_mime_types) !== JSON.stringify(['image/jpeg'])) {
    throw new Error('Bucket configuration did not match private, 1 MiB, JPEG-only requirements.');
}
console.log('profile-photos configured: private, JPEG only, maximum 1,048,576 bytes.');
