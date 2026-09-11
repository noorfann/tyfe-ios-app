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

## Edge Functions

Deploy functions with:

```sh
supabase functions deploy <name> --use-api --project-ref <ref>
```

`--use-api` bundles server-side and does not require Docker. Secret-bearing
values (for example an APNs key) are injected through Supabase secret storage
per environment and are never committed.
