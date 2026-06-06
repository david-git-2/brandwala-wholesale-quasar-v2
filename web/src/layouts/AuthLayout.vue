<template>
  <q-layout view="hHh lpR fFf" class="auth-layout" :class="scopeClass">
    <q-page-container>
      <q-page class="auth-page">

        <!-- Animated background blobs -->
        <div class="auth-bg" aria-hidden="true">
          <div class="auth-bg__blob auth-bg__blob--1" />
          <div class="auth-bg__blob auth-bg__blob--2" />
          <div class="auth-bg__blob auth-bg__blob--3" />
        </div>

        <!-- Main stage -->
        <section class="auth-stage">
          <div class="auth-stage__shell">

            <!-- ── Left hero ──────────────────────────────────── -->
            <div class="auth-hero">
              <!-- Brand wordmark -->
              <div class="auth-hero__brand">
                <div class="auth-hero__brand-mark">
                  <svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                    <rect width="28" height="28" rx="7" fill="currentColor" fill-opacity="0.18"/>
                    <path d="M7 9.5C7 8.12 8.12 7 9.5 7H14V14H7V9.5Z" fill="currentColor"/>
                    <path d="M14 7H18.5C19.88 7 21 8.12 21 9.5V14H14V7Z" fill="currentColor" fill-opacity="0.7"/>
                    <path d="M7 14H14V21H9.5C8.12 21 7 19.88 7 18.5V14Z" fill="currentColor" fill-opacity="0.7"/>
                    <path d="M14 14H21V18.5C21 19.88 19.88 21 18.5 21H14V14Z" fill="currentColor" fill-opacity="0.45"/>
                  </svg>
                </div>
                <span class="auth-hero__brand-name">TradeFlowBD</span>
              </div>

              <!-- Headline -->
              <div class="auth-hero__content">
                <div class="auth-hero__scope-badge">{{ scopeLabel }}</div>
                <h1 class="auth-hero__headline">{{ heroHeadline }}</h1>
                <p class="auth-hero__sub">{{ heroSub }}</p>

                <!-- Feature highlights -->
                <ul class="auth-hero__features" aria-label="Key features">
                  <li v-for="feat in features" :key="feat.label" class="auth-hero__feature">
                    <span class="auth-hero__feature-icon" aria-hidden="true">{{ feat.icon }}</span>
                    <span>{{ feat.label }}</span>
                  </li>
                </ul>
              </div>

              <!-- Footer note -->
              <div class="auth-hero__footer">
                Powered by TradeFlowBD
              </div>
            </div>

            <!-- ── Right panel ─────────────────────────────────── -->
            <div class="auth-panel-wrap">
              <router-view />
            </div>

          </div>
        </section>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, provide, ref } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

// Child panels inject this and set it so the hero headline is dynamic
const panelTitle = ref('')
provide('authPanelTitle', panelTitle)

const authScope = computed(
  () => (route.meta as { authScope?: 'platform' | 'app' | 'shop' }).authScope ?? 'app',
)

const scopeClass = computed(() => `auth-scope--${authScope.value}`)

const scopeLabel = computed(() => {
  switch (authScope.value) {
    case 'platform': return 'Platform Console'
    case 'shop':     return 'Customer Storefront'
    default:         return 'Operations Hub'
  }
})

const heroHeadline = computed(() => {
  switch (authScope.value) {
    case 'platform': return 'Govern your entire platform.'
    // Use the injected panel title (e.g. tenant name or login button label)
    // falls back gracefully while loading
    case 'shop':     return panelTitle.value
      ? `Welcome to ${panelTitle.value}.`
      : 'Sign in to your store.'
    default:         return 'Run your business smarter.'
  }
})

const heroSub = computed(() => {
  switch (authScope.value) {
    case 'platform': return 'Super-admin access to tenants, roles, billing, and global configuration.'
    case 'shop':     return 'Browse products, place orders, and track your wholesale history in one place.'
    default:         return 'Inventory, orders, costing, analytics — everything your team needs, unified.'
  }
})

interface Feature { icon: string; label: string }

const features = computed((): Feature[] => {
  switch (authScope.value) {
    case 'platform':
      return [
        { icon: '🏢', label: 'Tenant & subscription management' },
        { icon: '🔐', label: 'Role-based access control' },
        { icon: '📊', label: 'Platform-level analytics' },
      ]
    case 'shop':
      return [
        { icon: '🛒', label: 'Browse & order products' },
        { icon: '📦', label: 'Track your order history' },
        { icon: '💬', label: 'View costing files & quotes' },
      ]
    default:
      return [
        { icon: '📋', label: 'Smart inventory management' },
        { icon: '💰', label: 'Costing & pricing engine' },
        { icon: '🚚', label: 'Shipment & order tracking' },
      ]
  }
})
</script>

<style scoped>
/* ── Scope-level colour tokens ───────────────────────── */
.auth-scope--platform {
  --auth-from:   #1a0a0a;
  --auth-mid:    #3b0d0d;
  --auth-accent: #dc2626;
  --auth-accent-rgb: 220 38 38;
  --auth-glow:   rgb(220 38 38 / 0.35);
  --auth-soft:   rgb(220 38 38 / 0.12);
  --auth-badge-bg: rgb(220 38 38 / 0.18);
  --auth-badge-color: #fca5a5;
}

.auth-scope--app {
  --auth-from:   #021a10;
  --auth-mid:    #064e2e;
  --auth-accent: #10b981;
  --auth-accent-rgb: 16 185 129;
  --auth-glow:   rgb(16 185 129 / 0.35);
  --auth-soft:   rgb(16 185 129 / 0.12);
  --auth-badge-bg: rgb(16 185 129 / 0.18);
  --auth-badge-color: #6ee7b7;
}

.auth-scope--shop {
  --auth-from:   #040d24;
  --auth-mid:    #0f2361;
  --auth-accent: #3b82f6;
  --auth-accent-rgb: 59 130 246;
  --auth-glow:   rgb(59 130 246 / 0.35);
  --auth-soft:   rgb(59 130 246 / 0.12);
  --auth-badge-bg: rgb(59 130 246 / 0.18);
  --auth-badge-color: #93c5fd;
}

/* ── Layout root ─────────────────────────────────────── */
.auth-layout {
  min-height: 100vh;
  background: var(--auth-from);
  position: relative;
  overflow: hidden;
}

.auth-page {
  min-height: 100vh;
  padding: 0;
  /* override the global .q-page white bg for auth pages */
  background: transparent !important;
  max-width: none !important;
}

/* ── Animated blobs ──────────────────────────────────── */
.auth-bg {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 0;
}

.auth-bg__blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.55;
  animation: blobFloat 14s ease-in-out infinite alternate;
}

.auth-bg__blob--1 {
  width: 520px;
  height: 520px;
  background: radial-gradient(circle, var(--auth-accent) 0%, transparent 70%);
  top: -160px;
  right: -120px;
  animation-delay: 0s;
  opacity: 0.3;
}

.auth-bg__blob--2 {
  width: 380px;
  height: 380px;
  background: radial-gradient(circle, var(--auth-mid) 0%, transparent 70%);
  bottom: -80px;
  left: -80px;
  animation-delay: -5s;
  opacity: 0.5;
}

.auth-bg__blob--3 {
  width: 260px;
  height: 260px;
  background: radial-gradient(circle, var(--auth-accent) 0%, transparent 70%);
  bottom: 30%;
  right: 38%;
  animation-delay: -9s;
  opacity: 0.18;
}

@keyframes blobFloat {
  0%   { transform: translate(0, 0) scale(1); }
  33%  { transform: translate(30px, -40px) scale(1.05); }
  66%  { transform: translate(-20px, 20px) scale(0.97); }
  100% { transform: translate(10px, -10px) scale(1.02); }
}

/* ── Stage wrapper ───────────────────────────────────── */
.auth-stage {
  position: relative;
  z-index: 1;
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: clamp(0.75rem, 2vw, 1.5rem);
}

/* ── Two-column shell ────────────────────────────────── */
.auth-stage__shell {
  width: min(100%, 76rem);
  min-height: min(90vh, 58rem);
  display: grid;
  grid-template-columns: 1fr minmax(22rem, 0.72fr);
  border-radius: 1.75rem;
  overflow: hidden;
  box-shadow:
    0 0 0 1px rgb(255 255 255 / 0.06),
    0 32px 80px rgb(0 0 0 / 0.55),
    0 4px 16px rgb(0 0 0 / 0.35);
}

/* ── Hero (left) ─────────────────────────────────────── */
.auth-hero {
  padding: clamp(2rem, 5vw, 3.5rem);
  background:
    linear-gradient(
      135deg,
      color-mix(in srgb, var(--auth-from) 80%, transparent) 0%,
      color-mix(in srgb, var(--auth-mid)  60%, transparent) 100%
    );
  display: flex;
  flex-direction: column;
  gap: 0;
  border-right: 1px solid rgb(255 255 255 / 0.06);
  position: relative;
  overflow: hidden;
}

/* subtle grid lines */
.auth-hero::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgb(255 255 255 / 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgb(255 255 255 / 0.03) 1px, transparent 1px);
  background-size: 40px 40px;
  pointer-events: none;
}

/* bottom glow streak */
.auth-hero::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: -10%;
  width: 120%;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--auth-glow), transparent);
}

.auth-hero__brand {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  color: rgb(255 255 255 / 0.9);
  margin-bottom: auto;
}

.auth-hero__brand-mark {
  color: var(--auth-accent);
  display: flex;
  align-items: center;
}

.auth-hero__brand-name {
  font-size: 0.9rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgb(255 255 255 / 0.8);
}

.auth-hero__content {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 1.25rem;
  padding: 2.5rem 0;
}

.auth-hero__scope-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.3rem 0.85rem;
  border-radius: 999px;
  background: var(--auth-badge-bg);
  color: var(--auth-badge-color);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  border: 1px solid rgb(255 255 255 / 0.08);
  backdrop-filter: blur(6px);
  width: fit-content;
}

.auth-hero__headline {
  margin: 0;
  font-size: clamp(1.9rem, 4vw, 3rem);
  font-weight: 800;
  line-height: 1.0;
  letter-spacing: -0.04em;
  color: #ffffff;
  max-width: 14ch;
}

.auth-hero__sub {
  margin: 0;
  font-size: clamp(0.88rem, 1.5vw, 1rem);
  line-height: 1.6;
  color: rgb(255 255 255 / 0.55);
  max-width: 36ch;
}

.auth-hero__features {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.auth-hero__feature {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  font-size: 0.88rem;
  color: rgb(255 255 255 / 0.65);
}

.auth-hero__feature-icon {
  font-size: 1.05rem;
  flex-shrink: 0;
  width: 1.5rem;
  text-align: center;
}

.auth-hero__footer {
  font-size: 0.7rem;
  color: rgb(255 255 255 / 0.25);
  letter-spacing: 0.04em;
  margin-top: auto;
  padding-top: 1.5rem;
}

/* ── Panel (right) ───────────────────────────────────── */
.auth-panel-wrap {
  background: #ffffff;
  display: grid;
  align-content: center;
  padding: clamp(1.5rem, 4vw, 2.5rem);
}

/* ── Responsive ──────────────────────────────────────── */
@media (max-width: 1023px) {
  .auth-stage__shell {
    width: min(100%, 44rem);
    grid-template-columns: 1fr;
    min-height: unset;
  }

  .auth-hero {
    padding: clamp(1.5rem, 4vw, 2.25rem);
    border-right: none;
    border-bottom: 1px solid rgb(255 255 255 / 0.06);
  }

  .auth-hero__content {
    padding: 1.5rem 0;
  }

  .auth-hero__headline {
    font-size: clamp(1.6rem, 5vw, 2.2rem);
  }
}

@media (max-width: 599px) {
  .auth-stage {
    padding: 0;
    align-items: flex-end;
  }

  .auth-stage__shell {
    width: 100%;
    border-radius: 1.4rem 1.4rem 0 0;
    min-height: 92vh;
  }

  .auth-hero,
  .auth-panel-wrap {
    padding: 1.25rem;
  }
}
</style>
