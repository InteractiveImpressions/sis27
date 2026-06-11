# Database migrations (SIS27)

Migrations are managed with the **Supabase CLI** and tracked in the
`supabase_migrations.schema_migrations` table, so each migration runs **once**. They are
applied with `supabase db push` against the self-hosted Postgres (`db` service) — not via
`supabase start`; the runtime stack stays the vendored one in `infra/supabase/docker`.

## Scoping: per-app folders, one shared history

Each project authors and owns its own `supabase/migrations/` folder and Postgres schema:

| Project | Path | Schema |
| --- | --- | --- |
| Platform (shared infra) | `supabase/migrations/` | `public` |
| Contact app | `apps/contact/supabase/migrations/` | `app_contact` |
| Goals app | `apps/goals/supabase/migrations/` | `app_goals` |

The Supabase CLI allows **exactly one migration history per database** and refuses to apply
when that `supabase_migrations.schema_migrations` table contains a version not present in
the local migrations folder. So independent per-app pushes against the one shared database
are not possible. Instead, at apply time the platform + every app's migrations are combined
into a single staging folder (`.cache/supabase-combined`, gitignored) and pushed as **one
history** with a single `supabase db push`. See [`scripts/lib-db.sh`](../scripts/lib-db.sh)
(`assemble_migrations` / `push_all`).

- Each app still **authors** and owns its migrations independently (in its own submodule repo:
  `sis27-contact`, `sis27-goals`), scoped to its schema.
- Migrations apply in **global timestamp order**, so a migration that depends on another
  project's object must have a later timestamp than it (platform's `public` objects already
  predate the apps). `supabase migration new` always timestamps with the current time, so
  newly authored migrations naturally sort after existing ones.

## Conventions

- **RLS first**: every new table must have `ENABLE ROW LEVEL SECURITY` and explicit policies before shipping.
- **Ownership**: platform tables live here; satellite apps keep migrations in `apps/<app>/supabase/migrations`. No app-specific SQL in this folder.
- **Idempotency**: migrations now run once via the tracking table, but keeping `if not exists` / `on conflict` guards is still fine for POC iterations.
- **Transactions**: `db push` wraps each file in a transaction — avoid statements that can't run in one (`CREATE INDEX CONCURRENTLY`, `ALTER TYPE ... ADD VALUE`).

## Create a migration

```bash
pnpm db:new platform add_audit_log     # -> supabase/migrations/<ts>_add_audit_log.sql
pnpm db:new goals    add_goal_status   # -> apps/goals/supabase/migrations/<ts>_...
pnpm db:new contact  add_entry_field   # -> apps/contact/supabase/migrations/<ts>_...
```

## Apply migrations

The stack must be running with the db port published (`scripts/dev.sh` and the deploy do
this via `infra/supabase/docker/docker-compose.dbport.yml`, which exposes the db container
on `127.0.0.1:54322`).

```bash
pnpm db:push                          # platform + every app (one shared history)
./infra/deploy/scripts/migrate.sh     # same, used by the deploy
```

- **Local `pnpm dev`**: [`scripts/dev.sh`](../scripts/dev.sh) calls `push_all` after the stack is healthy.
- **VM deploy**: [`infra/deploy/scripts/deploy.sh`](../infra/deploy/scripts/deploy.sh) runs `migrate.sh`.

Connection details (db URL, percent-encoding, CLI resolution) live in
[`scripts/lib-db.sh`](../scripts/lib-db.sh); the CLI binary is resolved by
[`scripts/ensure-supabase-cli.sh`](../scripts/ensure-supabase-cli.sh) (pnpm-installed
locally, pinned download fallback on the VM).
