# Database migrations (SIS27)

SQL in `migrations/` is applied in filename order by `infra/deploy/scripts/migrate.sh` against the self-hosted Postgres (`db` service).

## Conventions

- **RLS first**: every new table must have `ENABLE ROW LEVEL SECURITY` and explicit policies before shipping.
- **Ownership**: built-in platform tables live here. Future satellite apps should keep migrations in their own repo and run them in their pipeline, or contribute folders under `supabase/migrations/apps/<app-name>/` once that process is agreed.
- **Idempotency**: prefer `if not exists` / guarded drops for POC iterations; tighten for production.

## Local / VM apply

With the stack running:

```bash
./infra/deploy/scripts/migrate.sh
```
