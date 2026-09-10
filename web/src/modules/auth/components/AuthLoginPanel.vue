<template>
  <section class="auth-card" :class="`auth-card--${tone}`">
    <div class="auth-card__accent-bar" aria-hidden="true" />

    <div class="auth-card__header">
      <h2 class="auth-card__title">{{ title }}</h2>
      <p class="auth-card__subtitle">Sign in to continue</p>
    </div>

    <div v-if="loginErrorMessage" class="auth-card__error" role="alert">
      <q-icon name="ph ph-warning-circle" size="1.1rem" class="auth-card__error-icon" />
      <span>{{ loginErrorMessage }}</span>
    </div>

    <div class="auth-card__divider" aria-hidden="true">
      <span>Continue with</span>
    </div>

    <button
      class="auth-card__cta"
      :class="{ 'auth-card__cta--loading': isLoading }"
      :disabled="isLoading || disabled"
      @click="handleGoogleLogin"
      type="button"
      :aria-label="isLoading ? 'Connecting…' : ctaLabel"
    >
      <span class="auth-card__cta-inner">
        <span v-if="!isLoading" class="auth-card__google-disc">
          <svg
            class="auth-card__google-icon"
            viewBox="0 0 24 24"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden="true"
            focusable="false"
          >
            <path
              d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              fill="#4285F4"
            />
            <path
              d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              fill="#34A853"
            />
            <path
              d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"
              fill="#FBBC05"
            />
            <path
              d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
              fill="#EA4335"
            />
          </svg>
        </span>

        <svg
          v-else
          class="auth-card__spinner"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
        >
          <circle
            class="auth-card__spinner-track"
            cx="12"
            cy="12"
            r="9"
            fill="none"
            stroke-width="2.5"
          />
          <path
            class="auth-card__spinner-arc"
            d="M12 3a9 9 0 0 1 9 9"
            fill="none"
            stroke-width="2.5"
            stroke-linecap="round"
          />
        </svg>

        <span class="auth-card__cta-label">
          {{ isLoading ? 'Connecting…' : ctaLabel }}
        </span>
      </span>
    </button>

    <p class="auth-card__secure-note">
      <q-icon name="ph ph-lock-key" size="0.85rem" style="vertical-align: -2px" />
      Secured with OAuth 2.0 — we never store your password
    </p>
  </section>
</template>

<script setup lang="ts">
import { computed, inject, watchEffect } from 'vue';
import { useRoute } from 'vue-router';
import type { Ref } from 'vue';
import { useOAuthLogin, type AuthScope } from '../composables/useOAuthLogin';

const props = defineProps<{
  scope: AuthScope;
  title: string;
  ctaLabel: string;
  disabled?: boolean;
  tenantSlug?: string | null;
  tone: 'platform' | 'app' | 'shop' | 'investor';
}>();

const route = useRoute();
const { handleGoogleLogin, isLoading } = useOAuthLogin(props.scope, {
  tenantSlug: props.tenantSlug ?? null,
});

const panelTitle = inject<Ref<string>>('authPanelTitle');
watchEffect(() => {
  if (panelTitle) panelTitle.value = props.title;
});

const loginErrorMessage = computed(() => {
  const error = route.query.login_error;
  if (error === 'session_expired') return 'Your session expired. Please sign in again.';
  if (error === 'no_membership')
    return 'This Google account does not have permission for this entry point yet.';
  if (error === 'wrong_tenant')
    return props.scope === 'app'
      ? 'This Google account is not allowed for the requested tenant workspace.'
      : 'This Google account is not allowed for this tenant shop link.';
  if (error === 'invalid_tenant')
    return props.scope === 'app'
      ? 'The requested tenant workspace could not be found for this account.'
      : 'This shop link is not connected to an active tenant.';
  return '';
});
</script>

<style scoped>
.auth-card {
  --card-ink: var(--auth-ink, #1c1416);
  --card-muted: var(--auth-muted, #6b6560);
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid color-mix(in srgb, var(--card-muted) 22%, #ffffff);
  box-shadow:
    0 2px 4px rgb(0 0 0 / 0.04),
    0 8px 24px rgb(0 0 0 / 0.06);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
  padding: 0 0 1.75rem;
}

.auth-card--platform {
  --card-accent: #6b2d3c;
  --card-accent-rgb: 107 45 60;
  --card-soft: rgb(107 45 60 / 0.12);
  --card-ink: #1c1416;
  --card-muted: #6b5a5e;
}

.auth-card--app {
  --card-accent: #03b5aa;
  --card-accent-rgb: 3 181 170;
  --card-soft: rgb(3 181 170 / 0.14);
  --card-ink: #33261d;
  --card-muted: #6b6d76;
}

.auth-card--shop {
  --card-accent: #996888;
  --card-accent-rgb: 153 104 136;
  --card-soft: rgb(153 104 136 / 0.14);
  --card-ink: #2a2b2a;
  --card-muted: #5e4955;
}

.auth-card--investor {
  --card-accent: #0f5c5a;
  --card-accent-rgb: 15 92 90;
  --card-soft: rgb(15 92 90 / 0.12);
  --card-ink: #1a2222;
  --card-muted: #5a6b6b;
}

.auth-card__accent-bar {
  height: 4px;
  background: var(--card-accent);
}

.auth-card__header {
  padding: 1.5rem 1.75rem 0;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.auth-card__title {
  margin: 0;
  font-size: clamp(1.45rem, 3vw, 1.85rem);
  font-weight: 800;
  letter-spacing: -0.035em;
  line-height: 1.05;
  color: var(--card-ink);
}

.auth-card__subtitle {
  margin: 0;
  font-size: 0.875rem;
  color: var(--card-muted);
  letter-spacing: 0.005em;
}

.auth-card__error {
  margin: 0 1.75rem;
  padding: 0.75rem 1rem;
  border-radius: 8px;
  background: rgb(220 38 38 / 0.06);
  border: 1px solid rgb(220 38 38 / 0.18);
  color: #991b1b;
  font-size: 0.83rem;
  line-height: 1.4;
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
}

.auth-card__error-icon {
  flex-shrink: 0;
  margin-top: 1px;
  color: #dc2626;
}

.auth-card__divider {
  margin: 0 1.75rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: var(--card-muted);
  font-size: 0.75rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.auth-card__divider::before,
.auth-card__divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: color-mix(in srgb, var(--card-muted) 22%, #ffffff);
}

.auth-card__cta {
  appearance: none;
  cursor: pointer;
  border: none;
  background: var(--card-accent);
  border-radius: 8px;
  margin: 0 1.75rem;
  padding: 0.7rem 1rem;
  transition:
    background 0.18s ease,
    box-shadow 0.18s ease,
    transform 0.12s ease;
  outline: none;
}

.auth-card__cta:hover:not(:disabled) {
  background: color-mix(in srgb, var(--card-accent) 82%, var(--card-ink));
  box-shadow: 0 6px 18px rgb(var(--card-accent-rgb) / 0.28);
  transform: translateY(-1px);
}

.auth-card__cta:active:not(:disabled) {
  transform: translateY(0);
  box-shadow: none;
}

.auth-card__cta:focus-visible {
  box-shadow: 0 0 0 3px var(--card-soft);
}

.auth-card__cta:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.auth-card__cta--loading {
  pointer-events: none;
}

.auth-card__cta-inner {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
}

.auth-card__google-disc {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #ffffff;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}

.auth-card__google-icon {
  width: 1.05rem;
  height: 1.05rem;
}

.auth-card__cta-label {
  font-size: 0.93rem;
  font-weight: 600;
  color: #ffffff;
  letter-spacing: 0.01em;
}

.auth-card__spinner {
  width: 1.2rem;
  height: 1.2rem;
  animation: spin 0.85s linear infinite;
  flex-shrink: 0;
}

.auth-card__spinner-track {
  stroke: rgb(255 255 255 / 0.35);
}

.auth-card__spinner-arc {
  stroke: #ffffff;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.auth-card__secure-note {
  margin: 0 1.75rem;
  font-size: 0.72rem;
  color: var(--card-muted);
  line-height: 1.45;
  text-align: center;
}
</style>
