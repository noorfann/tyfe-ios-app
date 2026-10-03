# Supabase

Supabase is the backend for social mode only. The local core loop stays on-device
(ADR-0004, ADR-0005).

- `migrations/` — versioned SQL migrations and RLS policies.
- `functions/` — TypeScript/Deno Edge Functions for secret-bearing or atomic operations.

## Environments

| Environment | Supabase project ref     | iOS scheme  | Purpose                  |
| ----------- | ------------------------ | ----------- | ------------------------ |
| Development | `rbarpjsuvzxaxajpbnkf`   | Development | Hosted development project |
| Production  | TBD                      | Production  | Separate project before beta |

The project ref is not a secret and may live in source. The app ships only the
project URL and publishable client key per environment.

## Secrets

Secret keys, database passwords, APNs auth keys, and the Apple provider secret
live in Supabase/CI secret storage and are never committed. `config.toml`
references them through `env(...)` variables; `supabase/.env*` files are
gitignored.

## Mock

Mock has no Supabase client, URL, or key. It uses deterministic local services
and must build and run without network access.

## Email signup release requirements

Account setup upgrades the current anonymous user without changing their ID. Users
enter their email, verify a six-digit email-change code, then set their password.
Core activities, rewards, and progress remain on-device; signup does not enable
cross-device progress backup.

The checked-in local configuration enables anonymous sign-in, manual linking,
email confirmation, a six-digit code, and a 60-second email resend interval. The
email-change template is `templates/email_change.html` and must include
`{{ .Token }}`. Hosted settings are separate: changing `config.toml` does not apply
these settings to Development or Production.

Before releasing, configure and verify these same auth settings in each hosted
environment, install the code-based email-change template, and configure an SMTP
sender authorized to deliver to real users. Production still requires its own
project and publishable client configuration. Missing live configuration makes
email signup and sign-in unavailable; it never falls back to mock account success.

Verify on Development that anonymous sign-in works, the email-change code arrives,
verification keeps the original user ID, setting the password produces a permanent
session, and a cold launch and later password sign-in restore that same account.
Verify expired-code/resend behavior, an email that already belongs to another
account, and interrupted verification and password writes. Keep guest data attached
to its original account; there is no automatic merge when signing into a different
existing account.

Recovery storage contains only the user ID, email, optional name, stage, and resend
timestamp. Passwords and codes are never persisted. The password-saved metadata is
only an interrupted-flow recovery hint, not an authorization or access-control
claim. Account setup stays pending until the local profile is durably saved;
streak, progress, and social refresh failures are logged separately and retried
when the app next restores the authenticated account.

The Mock-only `SIGNUP_FLOW` UI-test harness uses `123456` as its verification code.
`RESET_SIGNUP` clears only that harness's recovery state. The harness can restore
interrupted steps across launches; it does not emulate server credential storage.

## Applying migrations

Migrations are the source of truth. Apply them to Development through the
Supabase MCP server or the Management API (`POST /v1/projects/{ref}/database/query`
with a personal access token), then record the applied version so the history
stays consistent:

```sh
supabase migration repair --status applied <version> --project-ref <ref>
```

`supabase db push` also works but needs the linked database password and a CLI
matching the remote Postgres major version (currently 17). The MCP/Management
API path does not require Docker.

## Profile photos: separate deployment and setup

The iOS profile feature requires `20261002000000_profile_photos.sql` in each
environment. Applying source changes does not deploy this migration or configure
hosted Storage. Deploy and verify Development separately before Production.
The migration adds nullable `profiles.avatar_path`, preserves `avatar_token`,
extends the Circle progress view, and installs private Storage RLS helpers/policies.
It does not create objects, modify bucket metadata, or delete Storage metadata.

Create/configure `profile-photos` through the Storage API or Dashboard:

- Private (`public: false`), never public.
- Maximum object size **1,048,576 bytes (1 MiB)**.
- Allowed MIME types **`image/jpeg`** only.
- Object keys are exactly `<lowercase user UUID>/<fresh lowercase UUID>.jpg`.
- Upload with `upsert: false`; no UPDATE policy is granted.
- Owner can insert/read/delete own valid keys. Current Circle peers can read only
  the owner's currently referenced photo; unrelated and signed-out users cannot.
- Audit existing `storage.objects` policies before release: permissive policies
  combine with OR, so an unrelated broad policy must not grant access to this bucket.

The checked-in operator script configures the bucket through Storage API and
verifies its resulting settings. Run only in a trusted environment; never put the
service-role key in the iOS bundle, client config, logs, or source control:

```sh
SUPABASE_URL=https://<project-ref>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<server-only-key> \
node supabase/scripts/configure-profile-photos.mjs
```

Signed photo URLs are **five-minute bearer credentials**. The app keeps them only
in memory, renews Circle photos while the screen is visible, and clears state on
logout/account change. Circle entry/foreground identity and photo refresh remains
available when optional Cheers or progress refresh fails. Removing a Circle
membership or replacing the profile
reference prevents issuing new URLs immediately; it does **not** invalidate
previously issued URLs or erase already downloaded/cached images. Supabase uses
an internal Storage signing key, so logout and Auth signing-key rotation do not
revoke a signed URL. Keep the lifetime short; do not log, persist, or share URLs.
Do not promise instant revocation of already issued credentials.

Photo changes upload a fresh immutable object, then commit the profile name and
path together. If the profile write fails, remove the new object through Storage
API. After a successful replacement, remove the old object through Storage API;
for removal, clear the profile reference before removing its object. Account
deletion must list/remove **all** objects in the owner's folder through Storage
API before calling the existing account-deletion RPC. Cleanup failure is visible
and retryable; do not invoke the deletion RPC until cleanup succeeds. Administrative
orphan cleanup must likewise use Storage list/remove APIs, not SQL. Deleting a
`storage.objects` row deletes only metadata and can leave billed provider objects.

If a save response is lost, the app refetches the profile before rolling back an
upload. An uncertain response must not cause deletion of a potentially committed
photo. Failed rollback or obsolete-object removal is queued per account and
retried on a successful profile refresh. A committed remote profile remains
successful even if local caching or obsolete-object cleanup fails.

### Permission coverage (not run automatically)

Use an isolated migrated database/project. Run
`supabase/tests/profile_photo_permissions.sql` as postgres to check transaction-local
owner/peer/unrelated/signed-out/revoked membership predicates and token preservation.
It changes only Auth/public relational fixtures and rolls them back; it never
inserts or deletes Storage metadata.

The Storage API integration source exercises actual owner upload/delete and
owner/peer reads, denied unrelated/signed-out/revoked reads, forbidden overwrites,
foreign/nested/non-JPEG paths, MIME, and oversized uploads. Use three disposable
permanent test accounts with valid JWTs and a real JPEG fixture; do not use real
user accounts. This source creates a temporary Circle and temporarily changes
the test owner's photo reference, then restores/removes them through APIs:

```sh
SUPABASE_URL=https://<test-project-ref>.supabase.co \
SUPABASE_PUBLISHABLE_KEY=<test-client-key> \
PHOTO_OWNER_JWT=<owner-session> PHOTO_PEER_JWT=<peer-session> \
PHOTO_UNRELATED_JWT=<unrelated-session> PHOTO_TEST_JPEG=<jpeg-fixture-path> \
node supabase/tests/profile_photo_storage.mjs
```

If an authorization regression unexpectedly allows a malformed/foreign upload,
inspect the reported test paths and remove those fixtures using a trusted Storage
API client. Never remove their metadata with SQL.

Primary Supabase references:
[Storage access control](https://supabase.com/docs/guides/storage/security/access-control),
[schema design and API-only deletion](https://supabase.com/docs/guides/storage/schema/design),
[bucket restrictions](https://supabase.com/docs/guides/storage/buckets/creating-buckets),
and [private downloads / signed URL lifetime](https://supabase.com/docs/guides/storage/serving/downloads).


## Edge Functions

Deploy functions with:

```sh
supabase functions deploy <name> --use-api --project-ref <ref>
```

`--use-api` bundles server-side and does not require Docker. Secret-bearing
values (for example an APNs key) are injected through Supabase secret storage
per environment and are never committed.
