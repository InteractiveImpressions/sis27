// https://nuxt.com/docs/api/configuration/nuxt-config
import { DEV_CONTACT_ORIGIN } from "@sis27/platform";

const supabaseUrl = process.env.NUXT_PUBLIC_SUPABASE_URL || "http://127.0.0.1:8000";

const contactDevOrigin =
  process.env.NUXT_PUBLIC_CONTACT_DEV_ORIGIN?.trim() ||
  (process.env.NODE_ENV === "development" ? DEV_CONTACT_ORIGIN : "");

export default defineNuxtConfig({
  compatibilityDate: "2025-05-15",
  devtools: { enabled: true },
  modules: ["@nuxtjs/supabase", "@nuxt/eslint"],
  runtimeConfig: {
    public: {
      /** Full URL to Contact dev server (e.g. http://localhost:3001); empty in production for same-origin `/contact`. */
      contactDevOrigin: contactDevOrigin,
    },
  },
  supabase: {
    url: supabaseUrl,
    key:
      process.env.NUXT_PUBLIC_SUPABASE_ANON_KEY ||
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE",
    redirect: false,
    // Module default is secure: true — breaks auth cookies on plain HTTP (POC VM without TLS).
    cookieOptions: {
      secure: supabaseUrl.startsWith("https://"),
    },
  },
});
