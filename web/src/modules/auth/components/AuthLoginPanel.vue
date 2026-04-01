<template>
  <section class="auth-panel" :class="`auth-panel--${tone}`">
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
        @click="handleGoogleLogin"
      />

      <div class="auth-panel__security">
        <q-icon name="verified_user" size="18px" />
        <span>{{ supportText }}</span>
      </div>
    </div>

    <div class="auth-panel__notes">
      <div
        v-for="item in notes"
        :key="item"
        class="auth-panel__note"
      >
        <q-icon name="done" size="16px" />
        <span>{{ item }}</span>
      </div>
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
  supportText: string
  notes: string[]
  tone: 'platform' | 'app' | 'shop'
}>()

const route = useRoute()
const { handleGoogleLogin, isLoading } = useOAuthLogin(props.scope)

const loginErrorMessage = computed(() => {
  const error = route.query.login_error

  if (error === 'no_membership') {
    return 'This Google account does not have permission for this entry point yet.'
  }

  return ''
})
</script>

<style scoped>
.auth-panel {
  padding: clamp(1.25rem, 4vw, 2rem);
  border-radius: 1.75rem;
  border: 1px solid rgba(95, 70, 43, 0.12);
  background: rgba(255, 250, 242, 0.8);
  box-shadow:
    0 1rem 2.2rem rgba(68, 51, 31, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.75);
}

.auth-panel--platform {
  background: linear-gradient(180deg, rgba(255, 251, 245, 0.9), rgba(246, 237, 224, 0.86));
}

.auth-panel--app {
  background: linear-gradient(180deg, rgba(247, 252, 248, 0.9), rgba(233, 245, 237, 0.86));
}

.auth-panel--shop {
  background: linear-gradient(180deg, rgba(255, 249, 244, 0.92), rgba(250, 235, 224, 0.88));
}

.auth-panel__eyebrow {
  font-size: 0.75rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #7b6550;
}

.auth-panel__title {
  margin: 0.5rem 0 0;
  font-size: clamp(1.8rem, 4vw, 2.5rem);
  line-height: 1;
  font-weight: 700;
  color: #2b2118;
}

.auth-panel__description {
  margin: 0.9rem 0 0;
  max-width: 38ch;
  color: #6e5b49;
  line-height: 1.65;
}

.auth-panel__error {
  margin-top: 1rem;
  background: rgba(176, 52, 30, 0.12);
  color: #7c2417;
  border: 1px solid rgba(176, 52, 30, 0.2);
}

.auth-panel__actions {
  display: grid;
  gap: 0.9rem;
  margin-top: 1.4rem;
}

.auth-panel__cta {
  justify-content: center;
  min-height: 3.4rem;
  border-radius: 1rem;
  background: #2f2419;
  color: #fff8f0;
}

.auth-panel__security {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  color: #6e5b49;
}

.auth-panel__notes {
  display: grid;
  gap: 0.8rem;
  margin-top: 1.5rem;
}

.auth-panel__note {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  color: #463628;
}
</style>
