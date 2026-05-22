# Database migrations (SIS27)

SQL in `migrations/` is applied in filename order by `infra/deploy/scripts/migrate.sh` against the self-hosted Postgres (`db` service).

## Conventions

- **RLS first**: every new table must have `ENABLE ROW LEVEL SECURITY` and explicit policies before shipping.
- **Ownership**: built-in platform tables live here. Satellite apps keep migrations in `apps/<app>/supabase/migrations` in their own repo or submodule; the platform applies them via [`scripts/migrate-apps.sh`](../scripts/migrate-apps.sh) without app-specific SQL in this folder.
- **Idempotency**: prefer `if not exists` / guarded drops for POC iterations; tighten for production.

## Local / VM apply

With the stack running:

```bash
./infra/deploy/scripts/migrate.sh
./scripts/migrate-apps.sh
```

## Satellite app migrations

Each app under `apps/<name>/supabase/migrations/` owns its schema bootstrap and DDL (for example Contact creates `contact_migrator`, schema `app_contact`, tables, and policies). The root project does not duplicate that logic in `supabase/migrations`.

- **Local `pnpm dev`**: [`scripts/dev.sh`](../scripts/dev.sh) applies platform migrations, then every `apps/*/supabase/migrations/*.sql`.
- **VM deploy**: [`infra/deploy/scripts/deploy.sh`](../infra/deploy/scripts/deploy.sh) runs [`scripts/migrate-apps.sh`](../scripts/migrate-apps.sh) after `migrate.sh`.
