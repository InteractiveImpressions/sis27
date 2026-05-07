#!/usr/bin/env node
/**
 * Tear down the local Supabase Docker Compose stack used by `pnpm dev`.
 * Mirrors `scripts/dev-down.sh` — shared so root dev, Contact dev, and Ctrl+C cleanup stay aligned.
 *
 * Resolution: `SIS27_ROOT` if it contains `infra/supabase/docker/docker-compose.yml`, else walk up from `process.cwd()`.
 */
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";

const COMPOSE_REL = join("infra", "supabase", "docker", "docker-compose.yml");

function composePath(root) {
  return join(root, COMPOSE_REL);
}

function findPlatformRoot() {
  const explicit = process.env.SIS27_ROOT?.trim();
  if (explicit && existsSync(composePath(resolve(explicit)))) {
    return resolve(explicit);
  }
  let dir = process.cwd();
  for (let i = 0; i < 40; i++) {
    if (existsSync(composePath(dir))) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

const root = findPlatformRoot();
if (!root) {
  console.error(
    "Could not find SIS27 platform checkout (expected infra/supabase/docker/docker-compose.yml).",
  );
  console.error("Set SIS27_ROOT to the sis27 repo root, or run from inside that checkout.");
  process.exit(1);
}

const projectName = process.env.SIS27_DEV_PROJECT_NAME?.trim() || "sis27-dev";
let envFile = process.env.SIS27_DEV_ENV_FILE?.trim();
if (!envFile) {
  envFile = join(root, "infra", "supabase", "docker", ".env");
}
if (!existsSync(envFile)) {
  envFile = join(root, "infra", "supabase", "docker", ".env.example");
}

console.log(`Stopping local SIS27 Docker stack (${projectName})...`);
const r = spawnSync(
  "docker",
  [
    "compose",
    "--env-file",
    envFile,
    "-f",
    COMPOSE_REL,
    "-p",
    projectName,
    "down",
  ],
  { cwd: root, stdio: "inherit" },
);

if (r.error) {
  console.error(r.error.message);
  process.exit(1);
}
process.exit(r.status === null ? 1 : r.status);
