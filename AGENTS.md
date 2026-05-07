# AGENTS.md — SIS27

Internal data platform POC. Central Postgres + Supabase (self-hosted) with RLS; satellite apps in this or other repos.

## Repo layout

| Path | Purpose |
|------|---------|
| `apps/web` | Built-in Nuxt dashboard shell (auth + welcome). |
| `supabase/migrations` | SQL migrations applied after DB is up (platform + app-owned tables). |
| `infra/supabase/docker` | Vendored official [Supabase Docker](https://github.com/supabase/supabase/tree/master/docker) stack. |
| `infra/deploy` | Compose overlay, Caddy, VM deploy/migrate scripts. |

## Conventions

- **RLS**: New app tables live in `public` or a dedicated schema; always `ENABLE ROW LEVEL SECURITY` and explicit policies.
- **Migrations**: One logical change per file, timestamp prefix. Apps that own tables should keep migrations in their repo and apply in CI/CD (this POC applies `supabase/migrations` from the platform repo).
- **Secrets**: Never commit `infra/supabase/docker/.env`. Copy from `.env.example` and run `utils/generate-keys.sh` inside that folder.

## Commands (local)

```bash
pnpm install
pnpm dev
pnpm dev:down
```

`pnpm dev` is the only local-dev entrypoint: it starts the Supabase Docker stack, applies `supabase/migrations/*.sql`, then runs the Nuxt dev server. Use `pnpm dev:web` only when the backend is already managed separately.

`pnpm dev:down` tears down the local SIS27 Docker Compose stack.

## Deploy (VM)

See [README.md](./README.md). Compose merges the vendored Supabase stack with `infra/deploy/docker-compose.sis27.yml`.

**`SIS27_ROOT`**: must be exported to the **repository root** when invoking `docker compose` manually (see [`infra/deploy/scripts/compose.sh`](infra/deploy/scripts/compose.sh)). Compose resolves bind mounts and build context from the *first* compose file’s directory; this variable avoids broken paths for the web image and Caddyfile.

## CI/CD secrets

GitHub Actions deploy expects `GCP_SA_KEY`, `GCP_PROJECT`, `GCP_ZONE`, `GCP_INSTANCE`, `SIS27_DEPLOY_PATH` — see README.

## Updating vendored Supabase Docker

```bash
./scripts/sync-supabase-docker.sh
```

Review diffs before committing; image tags change upstream frequently.
