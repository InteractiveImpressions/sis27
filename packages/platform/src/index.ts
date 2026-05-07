/** Platform role names (must match Postgres seed in main repo migrations). */
export const ROLE_CONTACT_USER = "contact:user" as const;
export const ROLE_CONTACT_ADMIN = "contact:admin" as const;

export type ContactRole = typeof ROLE_CONTACT_USER | typeof ROLE_CONTACT_ADMIN;

/** Contact satellite app id and default deployed path (same-origin under Caddy). */
export const APP_CONTACT_ID = "contact" as const;
export const APP_CONTACT_BASE_PATH = "/contact" as const;

/** Default dev origins when dashboard and Contact run on separate ports (see root README). */
export const DEV_DASHBOARD_ORIGIN = "http://127.0.0.1:3000" as const;
export const DEV_CONTACT_ORIGIN = "http://127.0.0.1:3001" as const;

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
