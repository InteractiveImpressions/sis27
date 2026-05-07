# AGENTS.md — SIS27

Internal data platform POC. Central Postgres + Supabase (self-hosted) with RLS; satellite apps in this or other repos.

## Background

SIS27 is a demo / proof of concept for an internal data platform for a client company with roughly 300 employees. The platform should let employees enter data, create workflows, and manage business processes on the client's own on-premise infrastructure.

The core architecture is a centralized, secure, self-hosted Supabase / Postgres deployment. Treat Postgres as the shared system of record and RLS as a core platform invariant. Client developers should be able to build apps for specific use cases; those apps may own their own tables and migrations.

SIS27 itself should contain only a few built-in apps: the dashboard entrypoint in `apps/web` (auth, role gate, links to satellites), the **Contact** app in `apps/contact` (Next.js, same-origin `/contact`), and potentially an admin app later once scope is clearer. Other apps should generally live in separate git repositories; you can attach them as **git submodules** under `apps/<name>` when you want this repo to build and deploy them. The Contact app lives in [`github.com/InteractiveImpressions/sis27-contact`](https://github.com/InteractiveImpressions/sis27-contact) and is linked from this repo as a **git submodule** at `apps/contact`. Clone with `git clone --recurse-submodules` (or run `git submodule update --init --recursive` after clone).

This POC should stay as simple as possible while exploring the platform idea.

## Repo layout

| Path | Purpose |
|------|---------|
| `apps/web` | Built-in Nuxt dashboard shell (auth, platform roles, links to apps). |
| `apps/contact` | Contact satellite app (Next.js); owns `contact_entries` migrations under `apps/contact/supabase/migrations`. |
| `packages/platform` | Published npm package `@sis27/platform` — shared role names, routes, env helpers (see `packages/platform/README.md`). |
| `supabase/migrations` | SQL migrations applied after DB is up (platform tables, roles, helpers). |
| `infra/supabase/docker` | Vendored official [Supabase Docker](https://github.com/supabase/supabase/tree/master/docker) stack. |
| `infra/deploy` | Compose overlay, Caddy, VM deploy/migrate scripts. |

## Conventions

- **RLS**: New app tables live in `public` or a dedicated schema; always `ENABLE ROW LEVEL SECURITY` and explicit policies.
- **Migrations**: One logical change per file, timestamp prefix. Platform tables live under `supabase/migrations`. Satellite-owned tables may live under `apps/<app>/supabase/migrations` (see Contact); `pnpm dev` and `deploy.sh` apply those after platform migrations.
- **Secrets**: Never commit `infra/supabase/docker/.env`. Copy from `.env.example` and run `utils/generate-keys.sh` inside that folder.

## Commands (local)

```bash
pnpm install
pnpm dev
pnpm dev:down
```

`pnpm dev` is the only full-stack local entrypoint: it starts the Supabase Docker stack, applies `supabase/migrations/*.sql` and contact migrations from `apps/contact/supabase/migrations`, then runs **both** the Nuxt dev server (port **3000**) and the Contact Next dev server (port **3001**). Use **`pnpm dev:web-stack`** for stack + Nuxt only, **`pnpm dev:contact`** (or **`pnpm dev`** inside `apps/contact`) for stack + Contact only, and **`pnpm dev:web`** when the backend is already up and you only need Nuxt. A standalone [`sis27-contact`](https://github.com/InteractiveImpressions/sis27-contact) clone uses `scripts/dev.sh` there to find a sibling `sis27` checkout or `SIS27_ROOT`.

`pnpm dev:down` tears down the local SIS27 Docker Compose stack.

## Deploy (VM)

See [README.md](./README.md). Compose merges the vendored Supabase stack with `infra/deploy/docker-compose.sis27.yml`.

**`SIS27_ROOT`**: must be exported to the **repository root** when invoking `docker compose` manually (see [`infra/deploy/scripts/compose.sh`](infra/deploy/scripts/compose.sh)). Compose resolves bind mounts and build context from the *first* compose file’s directory; this variable avoids broken paths for the web image and Caddyfile.

## CI/CD secrets

GitHub Actions expect `SIS27_CONTACT_DEPLOY_KEY` (private half of a read-only deploy key on the `sis27-contact` repo for the `apps/contact` submodule), plus deploy secrets `GCP_SA_KEY`, `GCP_PROJECT`, `GCP_ZONE`, `GCP_INSTANCE`, `SIS27_DEPLOY_PATH` — see README.

## Updating vendored Supabase Docker

```bash
./scripts/sync-supabase-docker.sh
```

Review diffs before committing; image tags change upstream frequently.
