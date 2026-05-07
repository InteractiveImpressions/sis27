/** Platform role names (must match Postgres seed in main repo migrations). */
export const ROLE_CONTACT_USER = "contact:user" as const;
export const ROLE_CONTACT_ADMIN = "contact:admin" as const;

export type ContactRole = typeof ROLE_CONTACT_USER | typeof ROLE_CONTACT_ADMIN;

/** Contact satellite app id and default deployed path (same-origin under Caddy). */
export const APP_CONTACT_ID = "contact" as const;
export const APP_CONTACT_BASE_PATH = "/contact" as const;

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
