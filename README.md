# SIS27 — internal data platform (POC)

Monorepo for a minimal on-prem stack: **self-hosted Supabase** (Postgres + Auth + Kong + …), a **Nuxt** shell app (sign in / sign up → welcome), SQL **migrations** with RLS, and **Docker Compose** + **GitHub Actions** deploy to a single VM.

## Project context

SIS27 is a demo / proof of concept for an internal data platform for a client company with roughly 300 employees. The long-term goal is to give employees a secure place to enter data, create workflows, and manage business processes on infrastructure owned by the client.

The central architectural idea is a self-hosted Supabase deployment running on-premise, with Postgres as the shared system of record and Row Level Security (RLS) as a core boundary. SIS27 should provide the central platform foundation, while client developers can build use-case-specific apps around it. Those apps may own their own Postgres tables and migrations.

SIS27 itself should stay small. The built-in app scope currently includes a central dashboard entrypoint that links to other apps, and possibly an admin app once that scope is clearer. Additional apps are expected to live outside this platform repo, either as separate repositories or, if that proves useful later, as submodules.

For this POC, prefer the simplest useful implementation. The repo exists to explore the architecture and validate the operating model before locking in a larger platform shape.

## What’s in the repo

| Area | Path |
|------|------|
| Dashboard app | [`apps/web`](apps/web) |
| SQL migrations | [`supabase/migrations`](supabase/migrations) |
| Vendored Supabase Docker stack | [`infra/supabase/docker`](infra/supabase/docker) |
| Caddy + web overlay, scripts | [`infra/deploy`](infra/deploy) |

Supabase’s `docker/` tree is vendored from [supabase/supabase](https://github.com/supabase/supabase/tree/master/docker). Refresh with [`scripts/sync-supabase-docker.sh`](scripts/sync-supabase-docker.sh) when you want to track upstream.

## Prerequisites

- Node **20+**, **pnpm 9** (see root `packageManager`).
- On the VM: **Docker Engine** + **Compose v2** (see [`infra/deploy/scripts/bootstrap-vm.sh`](infra/deploy/scripts/bootstrap-vm.sh) for a starting point on Ubuntu-like images).

## Local development

```bash
pnpm install
pnpm dev
# Later, stop the local Docker stack:
pnpm dev:down
```

`pnpm dev` is the centralized local-dev entrypoint. It starts the self-hosted Supabase Docker stack, waits for Postgres and Kong, applies SQL migrations from [`supabase/migrations`](supabase/migrations), then starts the Nuxt app.

`pnpm dev:down` stops and removes the local SIS27 Docker Compose stack started for development.

By default it uses [`infra/supabase/docker/.env.example`](infra/supabase/docker/.env.example) and sets `ENABLE_EMAIL_AUTOCONFIRM=true` for a quick local POC. For persistent local secrets, create `infra/supabase/docker/.env`; the script will prefer that file automatically.

Useful overrides:

```bash
SIS27_DEV_PROJECT_NAME=sis27-dev pnpm dev
SIS27_DEV_ENV_FILE=/absolute/path/to/.env pnpm dev
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
   ```

Traffic flow: **browser → Caddy (:80)** → Nuxt for `/` and **Kong** for `/auth/*`, `/rest/*`, `/realtime/*`, etc. The Nuxt app uses `NUXT_PUBLIC_SUPABASE_URL` / `NUXT_PUBLIC_SUPABASE_ANON_KEY` (set in Compose from `SIS27_PUBLIC_URL` and `ANON_KEY`).

**Supabase Studio** is not exposed on `/` anymore (Caddy sends `/` to Nuxt). Use `docker compose … port` or add a dedicated route later if you need the dashboard on the public host.

## VM deploy layout

Example layout on the instance:

```bash
sudo mkdir -p /opt/sis27 && sudo chown "$USER":"$USER" /opt/sis27
git clone <your-github-repo> /opt/sis27
cd /opt/sis27
# configure infra/supabase/docker/.env (see above)
./infra/deploy/scripts/deploy.sh
```

`deploy.sh` builds the web image, starts the stack, waits for Postgres, and runs migrations.

The web image **must** receive `NUXT_PUBLIC_SUPABASE_URL` and `NUXT_PUBLIC_SUPABASE_ANON_KEY` as **Docker build args** (wired in [`infra/deploy/docker-compose.sis27.yml`](infra/deploy/docker-compose.sis27.yml)) so the browser bundle uses the same anon JWT as Kong. Without that, Kong returns **401 Unauthorized** for Auth/API calls. On **HTTP** (no TLS yet), the Nuxt app sets **non-secure** auth cookies so sessions work; switch to HTTPS in production and cookies become `Secure` automatically.

### First manual deploy (GCP example)

On a fresh Debian/Ubuntu VM: install Docker (see [`infra/deploy/scripts/bootstrap-vm.sh`](infra/deploy/scripts/bootstrap-vm.sh) or [Docker’s install script](https://get.docker.com/)), then either `git clone` this repo into `/opt/sis27` or copy a tarball excluding `node_modules` and `.git`.

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

### Matching your GCP VM

Your reference command:

`gcloud compute ssh --zone "europe-west3-c" "instance-20260507-035556" --project "sis27-495603"`

Use the same values as GitHub Actions secrets (see below).

## GitHub Actions

- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)): install, lint, typecheck, build on PRs and `main`.
- **Deploy** ([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)): on push to `main`, SSH via `gcloud` and run `git pull` + `deploy.sh`.

### Required repository secrets (deploy)

| Secret | Example / notes |
|--------|------------------|
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

- Separate git repos per satellite app; agree on migration ownership and schema namespaces.
- Optional admin app under `apps/admin` once scope is clear.
- Tighten auth (SMTP, MFA), rotate all example secrets, and restrict Studio / Kong exposure.

See also [`AGENTS.md`](AGENTS.md).
