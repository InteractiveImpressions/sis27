# `@sis27/platform`

Shared public contracts for SIS27 satellite apps and the dashboard: role names, app routes, small helpers, and env parsing for **public** Supabase client settings only.

## Local Docker stack

The package ships a small CLI used by monorepo and Contact dev scripts so **Ctrl+C** and **`pnpm dev:down`** tear down the same Compose project:

- **`sis27-stack-down`** — runs `docker compose … down` for `infra/supabase/docker/docker-compose.yml`. Honors **`SIS27_ROOT`** (platform repo root), **`SIS27_DEV_PROJECT_NAME`** (default `sis27-dev`), and **`SIS27_DEV_ENV_FILE`** (falls back to `.env` then `.env.example` under `infra/supabase/docker/`).

## Publish to Google Artifact Registry (project `sis27-495603`)

Prerequisites: `gcloud` authenticated, Artifact Registry API enabled, npm 9+.

### One-time: create npm repository and public read (POC)

```bash
gcloud artifacts repositories create sis27-npm \
  --project=sis27-495603 \
  --repository-format=npm \
  --location=europe-west3 \
  --description="SIS27 npm packages"

gcloud artifacts repositories add-iam-policy-binding sis27-npm \
  --project=sis27-495603 \
  --location=europe-west3 \
  --member=allUsers \
  --role=roles/artifactregistry.reader
```

Verify:

```bash
gcloud artifacts repositories describe sis27-npm \
  --project=sis27-495603 \
  --location=europe-west3
```

### Publish a version

From the repository root, after `pnpm install`:

```bash
pnpm --filter @sis27/platform build
cd packages/platform
# npm needs an OAuth token against the Artifact Registry host:
npm_config_registry=https://europe-west3-npm.pkg.dev/sis27-495603/sis27-npm/ \
  npm publish --access public
```

Authenticate `npm` to Artifact Registry using your Google identity, for example:

```bash
npx google-artifactregistry-auth \
  --repo-config=.npmrc \
  --credential-config=.npmrc-gcloud
```

Or set `_authToken` to `$(gcloud auth print-access-token)` for the `//europe-west3-npm.pkg.dev/...` registry URL (short-lived; prefer `google-artifactregistry-auth` for local publishes).

Grant the publishing principal `roles/artifactregistry.writer` on repository `sis27-npm`.

### Consumers (optional — published package only)

After **`allUsers`** has **`roles/artifactregistry.reader`** on `sis27-npm` (see above), installs can use the registry **without** `_authToken`. In `.npmrc`:

```ini
@sis27:registry=https://europe-west3-npm.pkg.dev/sis27-495603/sis27-npm/
```

The **Contact** app repo instead links the local platform package via **`pnpm-workspace.yaml`** and `workspace:*` (sibling `sis27` checkout); see [`apps/contact/README.md`](../../apps/contact/README.md) in this monorepo.

When developing **inside** this monorepo, use `"@sis27/platform": "workspace:*"` (root `pnpm.overrides` already enforces it).
