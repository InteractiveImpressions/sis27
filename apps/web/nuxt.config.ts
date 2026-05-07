// https://nuxt.com/docs/api/configuration/nuxt-config
const supabaseUrl = process.env.NUXT_PUBLIC_SUPABASE_URL || "http://127.0.0.1:8000";

export default defineNuxtConfig({
  compatibilityDate: "2025-05-15",
  devtools: { enabled: true },
  modules: ["@nuxtjs/supabase", "@nuxt/eslint"],
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
