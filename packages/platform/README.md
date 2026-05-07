# `@sis27/platform`

Shared public contracts for SIS27 satellite apps and the dashboard: role names, app routes, small helpers, and env parsing for **public** Supabase client settings only.

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

### Consumers

In `.npmrc`:

```ini
@sis27:registry=https://europe-west3-npm.pkg.dev/sis27-495603/sis27-npm/
```

Then:

```bash
pnpm add @sis27/platform@0.1.0
```

When developing **inside** this monorepo, use `"@sis27/platform": "workspace:*"` instead.
