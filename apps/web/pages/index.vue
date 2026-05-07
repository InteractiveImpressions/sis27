<script setup lang="ts">
const supabase = useSupabaseClient();
const user = useSupabaseUser();

const mode = ref<"signin" | "signup">("signin");
const email = ref("");
const password = ref("");
const displayName = ref("");
const loading = ref(false);
const errorMessage = ref<string | null>(null);

const displayUsername = computed(() => {
  const u = user.value;
  if (!u) return "";
  const meta = u.user_metadata as Record<string, unknown> | undefined;
  const fromMeta = meta?.display_name;
  if (typeof fromMeta === "string" && fromMeta.trim()) return fromMeta.trim();
  if (u.email) return u.email.split("@")[0] ?? u.email;
  return "there";
});

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
      <p class="subtitle">Proof of concept — sign in to continue.</p>
    </header>

    <section v-if="user" class="welcome">
      <p class="welcome__text">Welcome, <strong>{{ displayUsername }}</strong>!</p>
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
