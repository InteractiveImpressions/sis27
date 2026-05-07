<script setup lang="ts">
import { APP_CONTACT_BASE_PATH, hasContactAccess } from "@sis27/platform";

const supabase = useSupabaseClient();
const user = useSupabaseUser();

const mode = ref<"signin" | "signup">("signin");
const email = ref("");
const password = ref("");
const displayName = ref("");
const loading = ref(false);
const errorMessage = ref<string | null>(null);

const roles = ref<string[]>([]);
const rolesState = ref<"idle" | "loading" | "ready">("idle");

const displayUsername = computed(() => {
  const u = user.value;
  if (!u) return "";
  const meta = u.user_metadata as Record<string, unknown> | undefined;
  const fromMeta = meta?.display_name;
  if (typeof fromMeta === "string" && fromMeta.trim()) return fromMeta.trim();
  if (u.email) return u.email.split("@")[0] ?? u.email;
  return "there";
});

const showContactLink = computed(() => hasContactAccess(roles.value));

async function loadRoles() {
  if (!user.value) {
    roles.value = [];
    rolesState.value = "idle";
    return;
  }
  rolesState.value = "loading";
  errorMessage.value = null;
  const { data, error } = await supabase.rpc("current_user_roles");
  if (error) {
    errorMessage.value = error.message;
    roles.value = [];
    rolesState.value = "ready";
    return;
  }
  const list = Array.isArray(data) ? (data as string[]) : [];
  roles.value = list;
  rolesState.value = "ready";
}

watch(
  user,
  (u) => {
    if (u) void loadRoles();
    else {
      roles.value = [];
      rolesState.value = "idle";
    }
  },
  { immediate: true },
);

async function onSubmit() {
  errorMessage.value = null;
  loading.value = true;
  try {
    if (mode.value === "signup") {
      const { error } = await supabase.auth.signUp({
        email: email.value.trim(),
        password: password.value,
        options: {
          data: {
            display_name: displayName.value.trim() || undefined,
          },
        },
      });
      if (error) throw error;
    } else {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.value.trim(),
        password: password.value,
      });
      if (error) throw error;
    }
  } catch (e: unknown) {
    errorMessage.value = e instanceof Error ? e.message : "Something went wrong.";
  } finally {
    loading.value = false;
  }
}

async function signOut() {
  errorMessage.value = null;
  await supabase.auth.signOut();
}
</script>

<template>
  <main class="card">
    <header class="card__header">
      <p class="eyebrow">SIS27</p>
      <h1 class="title">Data platform</h1>
      <p class="subtitle">Proof of concept</p>
    </header>

    <section v-if="user && rolesState === 'loading'" class="welcome">
      <p class="welcome__text">Checking your access…</p>
    </section>

    <section v-else-if="user && rolesState === 'ready' && roles.length === 0" class="welcome">
      <p class="welcome__text">Welcome, <strong>{{ displayUsername }}</strong>.</p>
      <p class="denied">
        Your account is signed in but has no platform roles yet. You cannot use SIS27 until an administrator assigns
        at least one role.
      </p>
      <button type="button" class="btn btn--ghost" :disabled="loading" @click="signOut">
        Sign out
      </button>
    </section>

    <section v-else-if="user && rolesState === 'ready' && roles.length > 0" class="welcome">
      <p class="welcome__text">Welcome, <strong>{{ displayUsername }}</strong>!</p>
      <p class="roles">Roles: <code>{{ roles.join(", ") }}</code></p>

      <div v-if="showContactLink" class="apps">
        <p class="apps__title">Apps</p>
        <a class="app-card" :href="APP_CONTACT_BASE_PATH">
          <span class="app-card__name">Contact</span>
          <span class="app-card__hint">Open directory and manage your contact details</span>
        </a>
      </div>

      <button type="button" class="btn btn--ghost" :disabled="loading" @click="signOut">
        Sign out
      </button>
    </section>

    <form v-else class="form" @submit.prevent="onSubmit">
      <div class="tabs">
        <button
          type="button"
          class="tab"
          :class="{ 'tab--active': mode === 'signin' }"
          @click="mode = 'signin'"
        >
          Sign in
        </button>
        <button
          type="button"
          class="tab"
          :class="{ 'tab--active': mode === 'signup' }"
          @click="mode = 'signup'"
        >
          Sign up
        </button>
      </div>

      <label class="field">
        <span>Email</span>
        <input v-model="email" type="email" autocomplete="email" required >
      </label>

      <label v-if="mode === 'signup'" class="field">
        <span>Display name <small>(optional)</small></span>
        <input v-model="displayName" type="text" autocomplete="nickname" >
      </label>

      <label class="field">
        <span>Password</span>
        <input v-model="password" type="password" autocomplete="current-password" required >
      </label>

      <p v-if="errorMessage" class="error" role="alert">
        {{ errorMessage }}
      </p>

      <button type="submit" class="btn btn--primary" :disabled="loading">
        {{ loading ? "Please wait…" : mode === "signup" ? "Create account" : "Sign in" }}
      </button>
    </form>
  </main>
</template>

<style scoped>
.card {
  width: 100%;
  max-width: 420px;
  background: #fff;
  border-radius: 16px;
  padding: 2rem;
  box-shadow: 0 24px 48px -24px rgb(15 23 42 / 0.25), 0 0 0 1px rgb(15 23 42 / 0.06);
}

.card__header {
  margin-bottom: 1.75rem;
}

.eyebrow {
  margin: 0 0 0.35rem;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #6366f1;
}

.title {
  margin: 0;
  font-size: 1.75rem;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.subtitle {
  margin: 0.5rem 0 0;
  color: #64748b;
  font-size: 0.95rem;
}

.welcome {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  align-items: flex-start;
}

.welcome__text {
  margin: 0;
  font-size: 1.25rem;
}

.denied {
  margin: 0;
  font-size: 0.9rem;
  line-height: 1.5;
  color: #64748b;
}

.roles {
  margin: 0;
  font-size: 0.85rem;
  color: #64748b;
}

.roles code {
  font-size: 0.8rem;
  color: #334155;
}

.apps {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.apps__title {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #94a3b8;
}

.app-card {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.85rem 1rem;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
  text-decoration: none;
  color: inherit;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.app-card:hover {
  border-color: #c7d2fe;
  box-shadow: 0 2px 8px rgb(99 102 241 / 0.12);
}

.app-card__name {
  font-weight: 600;
  color: #0f172a;
}

.app-card__hint {
  font-size: 0.8rem;
  color: #64748b;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.tabs {
  display: flex;
  gap: 0.25rem;
  padding: 0.25rem;
  background: #f1f5f9;
  border-radius: 10px;
  margin-bottom: 0.25rem;
}

.tab {
  flex: 1;
  border: none;
  background: transparent;
  padding: 0.5rem 0.75rem;
  border-radius: 8px;
  font: inherit;
  font-weight: 500;
  color: #64748b;
  cursor: pointer;
}

.tab--active {
  background: #fff;
  color: #0f172a;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.08);
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #334155;
}

.field small {
  font-weight: 400;
  color: #94a3b8;
}

.field input {
  font: inherit;
  padding: 0.65rem 0.75rem;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
  background: #fff;
}

.field input:focus {
  outline: 2px solid #818cf8;
  outline-offset: 0;
  border-color: transparent;
}

.error {
  margin: 0;
  font-size: 0.875rem;
  color: #b91c1c;
}

.btn {
  font: inherit;
  font-weight: 600;
  padding: 0.7rem 1rem;
  border-radius: 10px;
  border: none;
  cursor: pointer;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn--primary {
  margin-top: 0.25rem;
  background: linear-gradient(135deg, #4f46e5, #6366f1);
  color: #fff;
}

.btn--ghost {
  background: #f1f5f9;
  color: #334155;
}
</style>
