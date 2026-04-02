<template>
  <section class="auth-panel" :class="[`auth-panel--${tone}`, `theme-${tone}`]">
    <div class="auth-panel__icon">{{ panelBadge }}</div>
    <div class="auth-panel__eyebrow">{{ eyebrow }}</div>
    <h1 class="auth-panel__title">{{ title }}</h1>
    <p class="auth-panel__description">{{ description }}</p>

    <q-banner
      v-if="loginErrorMessage"
      rounded
      class="auth-panel__error"
    >
      {{ loginErrorMessage }}
    </q-banner>

    <div class="auth-panel__actions">
      <q-btn
        unelevated
        no-caps
        icon="login"
        class="auth-panel__cta"
        :label="isLoading ? 'Connecting to Google...' : ctaLabel"
        :loading="isLoading"
        :disable="disabled"
        @click="handleGoogleLogin"
      />

      <p v-if="supportText" class="auth-panel__support">{{ supportText }}</p>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import { useOAuthLogin, type AuthScope } from '../composables/useOAuthLogin'

const props = defineProps<{
  scope: AuthScope
  eyebrow: string
  title: string
  description: string
  ctaLabel: string
  disabled?: boolean
  supportText?: string
  tenantSlug?: string | null
  tone: 'platform' | 'app' | 'shop'
}>()

const route = useRoute()
const { handleGoogleLogin, isLoading } = useOAuthLogin(props.scope, {
  tenantSlug: props.tenantSlug ?? null,
})

const panelBadge = computed(() => {
  switch (props.tone) {
    case 'platform':
      return 'BW'
    case 'app':
      return 'APP'
    case 'shop':
      return 'SHOP'
    default:
      return 'BW'
  }
})

const loginErrorMessage = computed(() => {
  const error = route.query.login_error

  if (error === 'no_membership') {
    return 'This Google account does not have permission for this entry point yet.'
  }

  if (error === 'wrong_tenant') {
    return 'This Google account is not allowed for this tenant shop link.'
  }

  if (error === 'invalid_tenant') {
    return 'This shop link is not connected to an active tenant.'
  }

  return ''
})
</script>

<style scoped>
.auth-panel {
  --auth-panel-accent: var(--bw-theme-primary, var(--q-primary));
  --auth-panel-soft: rgb(var(--bw-theme-primary-rgb, 141 95 47) / 0.08);
  --auth-panel-bg: color-mix(in srgb, var(--bw-theme-surface, white) 92%, white 8%);
  --auth-panel-border: var(--bw-theme-border, rgb(0 0 0 / 0.07));
  --auth-panel-copy: var(--bw-theme-muted, #4b5563);
  --auth-panel-title: var(--bw-theme-ink, #1f2937);
  padding: clamp(1.25rem, 4vw, 2rem);
  border-radius: 1.4rem;
  border: 1px solid var(--auth-panel-border);
  background: var(--auth-panel-bg);
  box-shadow: 0 1rem 2rem rgb(15 23 42 / 0.06);
}

.auth-panel__icon {
  width: 3.25rem;
  height: 3.25rem;
  margin: 0 auto 0.9rem;
  display: grid;
  place-items: center;
  border-radius: 1rem;
  background: linear-gradient(
    145deg,
    var(--auth-panel-accent),
    color-mix(in srgb, var(--auth-panel-accent) 62%, white 38%)
  );
  color: #fffaf5;
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  box-shadow: 0 16px 28px rgb(var(--bw-theme-primary-rgb, 141 95 47) / 0.16);
}

.auth-panel__eyebrow {
  font-size: 0.75rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--auth-panel-accent);
  text-align: center;
}

.auth-panel__title {
  margin: 0.5rem 0 0;
  font-size: clamp(1.8rem, 4vw, 2.2rem);
  line-height: 1.05;
  font-weight: 700;
  color: var(--auth-panel-title);
  text-align: center;
}

.auth-panel__description {
  margin: 0.9rem 0 0;
  max-width: 34ch;
  margin-left: auto;
  margin-right: auto;
  color: var(--auth-panel-copy);
  line-height: 1.6;
  text-align: center;
}

.auth-panel__error {
  margin-top: 1rem;
  background: rgb(193 0 21 / 0.1);
  color: #7c2417;
  border: 1px solid rgb(193 0 21 / 0.16);
}

.auth-panel__actions {
  display: grid;
  gap: 0.75rem;
  margin-top: 1.25rem;
}

.auth-panel__cta {
  justify-content: center;
  min-height: 3.4rem;
  border-radius: 0.95rem;
  background: var(--auth-panel-accent);
  color: #fffaf5;
}

.auth-panel__support {
  margin: 0;
  color: var(--auth-panel-copy);
  line-height: 1.5;
  text-align: center;
}
</style>
