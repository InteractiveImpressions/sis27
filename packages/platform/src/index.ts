/** Platform role names (must match Postgres seed in app migrations). */
export const ROLE_CONTACT_USER = "contact:user" as const;
export const ROLE_CONTACT_ADMIN = "contact:admin" as const;
export const ROLE_GOALS_USER = "goals:user" as const;
export const ROLE_GOALS_ADMIN = "goals:admin" as const;

export type ContactRole = typeof ROLE_CONTACT_USER | typeof ROLE_CONTACT_ADMIN;
export type GoalsRole = typeof ROLE_GOALS_USER | typeof ROLE_GOALS_ADMIN;

/** Contact satellite app id and default deployed path (same-origin under Caddy). */
export const APP_CONTACT_ID = "contact" as const;
export const APP_CONTACT_BASE_PATH = "/contact" as const;

/** Postgres schema for the Contact satellite (PostgREST + supabase.schema()). */
export const APP_CONTACT_DB_SCHEMA = "app_contact" as const;

/** Goals satellite app id and default deployed path (same-origin under Caddy). */
export const APP_GOALS_ID = "goals" as const;
export const APP_GOALS_BASE_PATH = "/goals" as const;

/** Postgres schema for the Goals satellite (PostgREST + supabase.schema()). */
export const APP_GOALS_DB_SCHEMA = "app_goals" as const;

/** Default dev origins when dashboard and satellites run on separate ports (see root README). */
export const DEV_DASHBOARD_ORIGIN = "http://localhost:3000" as const;
export const DEV_CONTACT_ORIGIN = "http://localhost:3001" as const;
export const DEV_GOALS_ORIGIN = "http://localhost:3002" as const;

/** Join origin (no trailing slash) and path (leading slash). */
export function absoluteAppUrl(origin: string, path: string): string {
  const o = origin.replace(/\/$/, "");
  const p = path.startsWith("/") ? path : `/${path}`;
  return `${o}${p}`;
}

/**
 * Link target for the Contact app from the dashboard.
 * Production: same-origin relative path only. Local split dev: full URL when `contactDevOrigin` is set.
 */
export function contactAppHref(options?: { contactDevOrigin?: string; basePath?: string }): string {
  const basePath = options?.basePath ?? APP_CONTACT_BASE_PATH;
  const dev = options?.contactDevOrigin?.trim();
  if (dev) return absoluteAppUrl(dev, basePath);
  return basePath;
}

/**
 * Link target for the Nuxt dashboard from the Contact app.
 * Production: `/`. Local split dev: full dashboard origin when `dashboardDevOrigin` is set.
 */
export function dashboardAppHref(dashboardDevOrigin?: string): string {
  const dev = dashboardDevOrigin?.trim();
  if (dev) return `${dev.replace(/\/$/, "")}/`;
  return "/";
}

export function hasContactUserRole(roles: readonly string[] | null | undefined): boolean {
  return roles?.includes(ROLE_CONTACT_USER) ?? false;
}

export function hasContactAdminRole(roles: readonly string[] | null | undefined): boolean {
  return roles?.includes(ROLE_CONTACT_ADMIN) ?? false;
}

export function hasContactAccess(roles: readonly string[] | null | undefined): boolean {
  return hasContactUserRole(roles) || hasContactAdminRole(roles);
}

/**
 * Link target for the Goals app from the dashboard.
 * Production: same-origin relative path only. Local split dev: full URL when `goalsDevOrigin` is set.
 */
export function goalsAppHref(options?: { goalsDevOrigin?: string; basePath?: string }): string {
  const basePath = options?.basePath ?? APP_GOALS_BASE_PATH;
  const dev = options?.goalsDevOrigin?.trim();
  if (dev) return absoluteAppUrl(dev, basePath);
  return basePath;
}

export function hasGoalsUserRole(roles: readonly string[] | null | undefined): boolean {
  return roles?.includes(ROLE_GOALS_USER) ?? false;
}

export function hasGoalsAdminRole(roles: readonly string[] | null | undefined): boolean {
  return roles?.includes(ROLE_GOALS_ADMIN) ?? false;
}

export function hasGoalsAccess(roles: readonly string[] | null | undefined): boolean {
  return hasGoalsUserRole(roles) || hasGoalsAdminRole(roles);
}

export type PublicSupabaseEnv = {
  supabaseUrl: string;
  supabaseAnonKey: string;
};

/**
 * Read public Supabase client settings from process.env (Node) or import.meta.env (Vite).
 * Throws if required values are missing or blank.
 */
function defaultEnvRecord(): Record<string, string | undefined> {
  if (typeof process !== "undefined" && process.env) {
    return process.env as Record<string, string | undefined>;
  }
  return {};
}

export function parsePublicSupabaseEnv(
  env: Record<string, string | undefined> = defaultEnvRecord(),
): PublicSupabaseEnv {
  const supabaseUrl =
    env.NEXT_PUBLIC_SUPABASE_URL ??
    env.NUXT_PUBLIC_SUPABASE_URL ??
    env.VITE_SUPABASE_URL ??
    "";
  const supabaseAnonKey =
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    env.NUXT_PUBLIC_SUPABASE_ANON_KEY ??
    env.VITE_SUPABASE_ANON_KEY ??
    "";
  if (!supabaseUrl.trim()) {
    throw new Error(
      "Missing public Supabase URL: set NEXT_PUBLIC_SUPABASE_URL, NUXT_PUBLIC_SUPABASE_URL, or VITE_SUPABASE_URL",
    );
  }
  if (!supabaseAnonKey.trim()) {
    throw new Error(
      "Missing public Supabase anon key: set NEXT_PUBLIC_SUPABASE_ANON_KEY, NUXT_PUBLIC_SUPABASE_ANON_KEY, or VITE_SUPABASE_ANON_KEY",
    );
  }
  return { supabaseUrl: supabaseUrl.trim(), supabaseAnonKey: supabaseAnonKey.trim() };
}
