# SIS27 — internal data platform (POC)

Monorepo for a minimal on-prem stack: **self-hosted Supabase** (Postgres + Auth + Kong + …), a **Nuxt** dashboard (auth + platform roles), a **Next.js** Contact app at `/contact`, SQL **migrations** with RLS, and **Docker Compose** + **GitHub Actions** deploy to a single VM.

## Project context

SIS27 is a demo / proof of concept for an internal data platform for a client company with roughly 300 employees. The long-term goal is to give employees a secure place to enter data, create workflows, and manage business processes on infrastructure owned by the client.

The central architectural idea is a self-hosted Supabase deployment running on-premise, with Postgres as the shared system of record and Row Level Security (RLS) as a core boundary. SIS27 should provide the central platform foundation, while client developers can build use-case-specific apps around it. Those apps may own their own Postgres tables and migrations.

SIS27 itself should stay small. The built-in app scope currently includes a central dashboard entrypoint that links to other apps, and possibly an admin app once that scope is clearer. Additional apps are expected to live outside this platform repo, either as separate repositories or, if that proves useful later, as submodules.

For this POC, prefer the simplest useful implementation. The repo exists to explore the architecture and validate the operating model before locking in a larger platform shape.

## What’s in the repo

| Area | Path |
|------|------|
| Dashboard app | [`apps/web`](apps/web) |
| Contact app (Next.js submodule) | [`InteractiveImpressions/sis27-contact`](https://github.com/InteractiveImpressions/sis27-contact) checked out at [`apps/contact`](apps/contact) |
| Shared npm contracts | [`packages/platform`](packages/platform) (`@sis27/platform`) |
| SQL migrations | [`supabase/migrations`](supabase/migrations) |
| Vendored Supabase Docker stack | [`infra/supabase/docker`](infra/supabase/docker) |
| Caddy + web overlay, scripts | [`infra/deploy`](infra/deploy) |

Supabase’s `docker/` tree is vendored from [supabase/supabase](https://github.com/supabase/supabase/tree/master/docker). Refresh with [`scripts/sync-supabase-docker.sh`](scripts/sync-supabase-docker.sh) when you want to track upstream.

## Prerequisites

- Node **20+**, **pnpm 9** (see root `packageManager`).
- On the VM: **Docker Engine** + **Compose v2** (see [`infra/deploy/scripts/bootstrap-vm.sh`](infra/deploy/scripts/bootstrap-vm.sh) for a starting point on Ubuntu-like images).

## Local development

```bash
git clone --recurse-submodules <your-github-repo-url>
cd sis27
pnpm install
pnpm dev
# Later, stop the local Docker stack:
pnpm dev:down
```

`pnpm dev` is the centralized local-dev entrypoint. It starts the self-hosted Supabase Docker stack, waits for Postgres and Kong, applies platform SQL from [`supabase/migrations`](supabase/migrations) then satellite app SQL from `apps/*/supabase/migrations` (including Contact), then runs **Nuxt on port 3000** and the **Contact Next app on port 3001** together (via [`concurrently`](https://www.npmjs.com/package/concurrently)). Open the dashboard at `http://localhost:3000` and Contact at `http://localhost:3001/contact`.

Other scripts: **`pnpm dev:web-stack`** — stack + Nuxt only (no Contact). **`pnpm dev:contact`** — stack + Contact only (or **`pnpm dev`** inside `apps/contact` using the sibling `sis27` checkout). **`pnpm dev:web`** — Nuxt only (when Supabase is already running elsewhere).

**Split dev ports (default):** the dashboard links to **`http://localhost:3001/contact`** in Nuxt development mode, and Contact links back to **`http://localhost:3000/`**, so cross-app navigation matches `pnpm dev:web` (port 3000) and Contact on 3001 while keeping auth cookies on the same browser host. Override with **`NUXT_PUBLIC_CONTACT_DEV_ORIGIN`** (dashboard → contact) or **`NEXT_PUBLIC_DASHBOARD_DEV_URL`** (contact → dashboard) if you use different ports. In production (single origin behind Caddy) both apps use **relative** `/` and `/contact` only.

**Prod-like local origin (optional):** with the stack and both dev servers running (`pnpm dev`), start Caddy on **`http://127.0.0.1:8888/`** using the same path routing as production ([`infra/deploy/Caddyfile`](infra/deploy/Caddyfile)): **`pnpm dev:caddy`** (requires [Caddy](https://caddyserver.com/docs/install) on your PATH). Then use **`http://127.0.0.1:8888/`** and **`http://127.0.0.1:8888/contact`** so behaviour matches the VM. For a Caddy container instead of a host binary, set `SIS27_PROXY_*` to `host.docker.internal:PORT` and add Docker’s `host-gateway` host mapping (see comments in [`infra/dev/Caddyfile`](infra/dev/Caddyfile)).

`pnpm dev:down` stops and removes the local SIS27 Docker Compose stack started for development.

By default it uses [`infra/supabase/docker/.env.example`](infra/supabase/docker/.env.example) and sets `ENABLE_EMAIL_AUTOCONFIRM=true` for a quick local POC. For persistent local secrets, create `infra/supabase/docker/.env`; the script will prefer that file automatically.

Useful overrides:

```bash
SIS27_DEV_PROJECT_NAME=sis27-dev pnpm dev
SIS27_DEV_ENV_FILE=/absolute/path/to/.env pnpm dev
# Optional: which dev servers after migrations (default is all = Nuxt + Contact)
SIS27_DEV_FRONTEND=all pnpm dev    # same as plain pnpm dev
SIS27_DEV_FRONTEND=web pnpm dev     # same as pnpm dev:web-stack
SIS27_DEV_FRONTEND=contact pnpm dev # same as pnpm dev:contact
```

## One-time Supabase env (self-hosted)

1. Copy the example env and generate secrets (JWT, keys, passwords) as documented upstream:

   ```bash
   cp infra/supabase/docker/.env.example infra/supabase/docker/.env
   cd infra/supabase/docker && ./utils/generate-keys.sh
   ```

2. Merge in SIS27-specific URL flags from [`infra/deploy/env.supabase.sis27.example`](infra/deploy/env.supabase.sis27.example):

   - **`SITE_URL`**, **`API_EXTERNAL_URL`**, **`SUPABASE_PUBLIC_URL`**, **`SIS27_PUBLIC_URL`** must all match the **browser-visible origin** (e.g. `http://YOUR_VM_IP` on port 80, or `https://your-domain` once TLS is configured).
   - For a quick POC without SMTP, set **`ENABLE_EMAIL_AUTOCONFIRM=true`** in `infra/supabase/docker/.env`.

3. **`SIS27_ROOT`** must be set to the **repository root** whenever you run Compose manually (scripts set it automatically):

   ```bash
   export SIS27_ROOT="$(pwd)"
   docker compose --env-file infra/supabase/docker/.env \
     -f infra/supabase/docker/docker-compose.yml \
     -f infra/deploy/docker-compose.sis27.yml \
     -p sis27 up -d
   ```

4. Apply SQL migrations:

   ```bash
   ./infra/deploy/scripts/migrate.sh
   ./scripts/migrate-apps.sh
   ```

   Or run [`infra/deploy/scripts/deploy.sh`](infra/deploy/scripts/deploy.sh), which applies platform and app migrations.

Traffic flow: **browser → Caddy (:80)** → Nuxt for `/`, Next **Contact** app for `/contact`, and **Kong** for `/auth/*`, `/rest/*`, `/realtime/*`, etc. The Nuxt app uses `NUXT_PUBLIC_SUPABASE_URL` / `NUXT_PUBLIC_SUPABASE_ANON_KEY` (set in Compose from `SIS27_PUBLIC_URL` and `ANON_KEY`). The Contact image receives the same public values as `NEXT_PUBLIC_*` build args.

## Platform roles and Contact app

- **Roles** are stored in Postgres (`public.roles`, `public.user_roles`). Users with **no roles** cannot use the dashboard beyond sign-in (they see an access-denied message). The Contact app requires `contact:user` or `contact:admin`.
- **Database ownership:** platform migrations own shared `public` objects (`profiles`, `roles`, `user_roles`, role helper functions, Auth signup triggers). The Contact satellite owns schema `app_contact`, role `contact_migrator`, and all Contact DDL under [`apps/contact/supabase/migrations`](apps/contact/supabase/migrations). The root repo only runs those files generically after platform migrations.
- **Supabase API schemas:** Contact uses `app_contact.entries` and `app_contact.users_public_profile(...)`, so `PGRST_DB_SCHEMAS` must include `app_contact` (for example `public,app_contact,storage,graphql_public`).
- **Manual role grant (POC)** — run as `postgres` or in Supabase Studio SQL, after you know the user’s UUID from `auth.users`:

  ```sql
  insert into public.user_roles (user_id, role_id)
  select '<USER_UUID>'::uuid, id from public.roles where name = 'contact:user'
  on conflict (user_id, role_id) do nothing;
  ```

  Replace `contact:user` with `contact:admin` when needed.

- **`@sis27/platform`**: shared TypeScript constants and helpers; publish to Google Artifact Registry using [`packages/platform/README.md`](packages/platform/README.md). **Contact** depends on **`^0.1.0`**; the repo root [`.npmrc`](.npmrc) sets **`link-workspace-packages`** and **`prefer-workspace-packages`** so `pnpm install` at the monorepo root always links [`packages/platform`](packages/platform). Standalone **sis27-contact** uses its own **`.npmrc`** so **`@sis27`** resolves from Artifact Registry.

**Supabase Studio** is not exposed on `/` anymore (Caddy sends `/` to Nuxt). Use `docker compose … port` or add a dedicated route later if you need the dashboard on the public host.

## Satellite app migration contract

Future satellite apps should follow the Contact pattern:

- Platform migrations create the app schema and a no-login app migrator role, for example `inventory` plus `inventory_migrator`.
- App migrations are stored under `apps/<app>/supabase/migrations` and must run successfully after `SET ROLE <app>_migrator`.
- App-owned tables, functions, triggers, policies, indexes, and grants live in the app schema. They may reference approved platform objects such as `auth.users`, `public.profiles`, and `public.has_role(...)`, but they should not alter or drop platform-owned objects.
- Any app schema used through Supabase clients must be listed in `PGRST_DB_SCHEMAS`, and client code should call it explicitly with `supabase.schema('<app>')`.

## VM deploy layout

Example layout on the instance:

```bash
sudo mkdir -p /opt/sis27 && sudo chown "$USER":"$USER" /opt/sis27
git clone --recurse-submodules <your-github-repo> /opt/sis27
cd /opt/sis27
# configure infra/supabase/docker/.env (see above)
./infra/deploy/scripts/deploy.sh
```

`deploy.sh` builds the **web** and **contact** images, starts the stack, waits for Postgres, and runs platform plus contact migrations. Docker BuildKit caches app image layers under `.docker-build-cache/` by default, so repeat `docker compose --build` deploys reuse dependency and build layers across runs. Set `SIS27_DOCKER_BUILD_CACHE_DIR=/path/to/cache` before running deploy scripts to move the cache, or remove that directory to force a cold rebuild.

The web image **must** receive `NUXT_PUBLIC_SUPABASE_URL` and `NUXT_PUBLIC_SUPABASE_ANON_KEY` as **Docker build args** (wired in [`infra/deploy/docker-compose.sis27.yml`](infra/deploy/docker-compose.sis27.yml)) so the browser bundle uses the same anon JWT as Kong. Without that, Kong returns **401 Unauthorized** for Auth/API calls. On **HTTP** (no TLS yet), the Nuxt app sets **non-secure** auth cookies so sessions work; switch to HTTPS in production and cookies become `Secure` automatically.

### First manual deploy (GCP example)

On a fresh Debian/Ubuntu VM: install Docker (see [`infra/deploy/scripts/bootstrap-vm.sh`](infra/deploy/scripts/bootstrap-vm.sh) or [Docker’s install script](https://get.docker.com/)), then either `git clone --recurse-submodules` this repo into `/opt/sis27` or copy a tarball excluding `node_modules` and `.git`.

```bash
sudo mkdir -p /opt/sis27 && sudo chown "$USER":"$USER" /opt/sis27
cd /opt/sis27   # repo root
cp infra/supabase/docker/.env.example infra/supabase/docker/.env
(cd infra/supabase/docker && sh ./utils/generate-keys.sh --update-env)
# Set browser-facing origin (VM public IP or domain) — all four must match:
#   SITE_URL, API_EXTERNAL_URL, SUPABASE_PUBLIC_URL, SIS27_PUBLIC_URL
# For a POC without mail: ENABLE_EMAIL_AUTOCONFIRM=true
# Set POOLER_TENANT_ID to a non-placeholder value (e.g. sis27-vm-tenant).
export SIS27_ROOT="$(pwd)"
./infra/deploy/scripts/deploy.sh
```

The SIS27 overlay lengthens the **analytics (Logflare)** healthcheck startup window; without it, first boot can fail while migrations run.

**`/contact` on the VM shows Nuxt’s 404:** port **80** must be served by **`sis27-caddy`** ([`infra/deploy/Caddyfile`](infra/deploy/Caddyfile)), which sends `/contact` to the **Contact** container and everything else (except API prefixes) to **Nuxt**. If Caddy’s config on disk includes `/contact` but the browser still hits Nuxt, **`sis27-caddy` is often serving a stale bind-mounted Caddyfile** (Linux keeps the old inode after `git pull` or `tar` replaces the file). **`./infra/deploy/scripts/deploy.sh`** now **force-recreates** `sis27-caddy` after every deploy so the mount refreshes; manually: `sudo SIS27_ROOT=/opt/sis27 docker compose … up -d --no-deps --force-recreate sis27-caddy` from the repo root (same compose files and `--env-file` as in [`deploy.sh`](infra/deploy/scripts/deploy.sh)).

### Matching your GCP VM

Your reference command:

`gcloud compute ssh --zone "europe-west3-c" "instance-20260507-035556" --project "sis27-495603"`

Use the same values as GitHub Actions secrets (see below).

## GitHub Actions

- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)): install, lint, typecheck, build on PRs and `main`.
- **Deploy** ([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)): on push to `main`, SSH via `gcloud` and run `git pull` + `deploy.sh`.

The **Contact** app is a private submodule ([`sis27-contact`](https://github.com/InteractiveImpressions/sis27-contact)). CI and deploy use a **read-only deploy key** on that repo and the matching private key in repository secret **`SIS27_CONTACT_DEPLOY_KEY`** (see workflow `webfactory/ssh-agent` + manual `git submodule update`). Pull requests from forks cannot use that secret; run CI from branches on this repo or make the submodule public.

### Repository secrets (CI + deploy)

| Secret | Example / notes |
|--------|------------------|
| `SIS27_CONTACT_DEPLOY_KEY` | PEM for a **read-only** deploy key on [`sis27-contact`](https://github.com/InteractiveImpressions/sis27-contact); required so CI/deploy can clone `apps/contact`. |
| `GCP_SA_KEY` | JSON for a service account that can use `gcloud compute ssh` (see [Google’s SSH guide](https://cloud.google.com/compute/docs/connect/standard-ssh)). |
| `GCP_PROJECT` | `sis27-495603` |
| `GCP_ZONE` | `europe-west3-c` |
| `GCP_INSTANCE` | `instance-20260507-035556` |
| `SIS27_DEPLOY_PATH` | e.g. `/opt/sis27` — path to the git clone on the VM |

Ensure the VM has **OS Login** or **SSH keys/metadata** configured so the SA (or the user the SA impersonates) can connect. If you use **IAP tunneling**, add the corresponding gcloud flags to the workflow command.

The deploy step runs **`git pull`** on the VM: configure a **deploy key**, **machine user**, or **cached credentials** if the repository is private.

## Domain & TLS

Not required for the first POC: use `http://<vm-ip>` and set all public URL env vars to that origin. For HTTPS, point DNS at the VM and replace the [`infra/deploy/Caddyfile`](infra/deploy/Caddyfile) `:80` block with a `your.domain { … }` site block and Let’s Encrypt (or terminate TLS on a load balancer).

## Next exploration

- Separate git repos per satellite app; keep each app on a dedicated schema plus app-specific migrator role.
- Optional admin app under `apps/admin` once scope is clear.
- Tighten auth (SMTP, MFA), rotate all example secrets, and restrict Studio / Kong exposure.

See also [`AGENTS.md`](AGENTS.md).
