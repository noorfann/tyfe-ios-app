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
Supabase MCP server or `supabase db push` (the latter needs the linked database
password and a CLI matching the remote Postgres major version, currently 17).
