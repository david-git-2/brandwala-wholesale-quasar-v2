<template>
  <q-layout view="hHh lpR fFf" class="auth-layout" :class="scopeClass">
    <q-page-container>
      <q-page class="auth-page">

        <!-- Animated background blobs (left canvas only) -->
        <div class="auth-bg" aria-hidden="true">
          <div class="auth-bg__blob auth-bg__blob--1" />
          <div class="auth-bg__blob auth-bg__blob--2" />
          <div class="auth-bg__blob auth-bg__blob--3" />
        </div>

        <div class="auth-layout__inner">

          <!-- ── Left: full-bleed dark canvas ───────────────── -->
          <div class="auth-canvas">

            <!-- Brand wordmark — top left -->
            <div class="auth-canvas__brand">
              <div class="auth-canvas__brand-mark" aria-hidden="true">
                <svg width="24" height="24" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <rect width="28" height="28" rx="7" fill="currentColor" fill-opacity="0.2"/>
                  <path d="M7 9.5C7 8.12 8.12 7 9.5 7H14V14H7V9.5Z" fill="currentColor"/>
                  <path d="M14 7H18.5C19.88 7 21 8.12 21 9.5V14H14V7Z" fill="currentColor" fill-opacity="0.7"/>
                  <path d="M7 14H14V21H9.5C8.12 21 7 19.88 7 18.5V14Z" fill="currentColor" fill-opacity="0.7"/>
                  <path d="M14 14H21V18.5C21 19.88 19.88 21 18.5 21H14V14Z" fill="currentColor" fill-opacity="0.45"/>
                </svg>
              </div>
              <span class="auth-canvas__brand-name">TradeFlowBD</span>
            </div>

            <!-- Giant ghost word — centred vertically -->
            <div class="auth-canvas__ghost-wrap" aria-hidden="true">
              <span class="auth-canvas__ghost-word">{{ ghostWord }}</span>
            </div>

            <!-- Bottom tagline -->
            <div class="auth-canvas__footer">
              <p class="auth-canvas__tagline">{{ tagline }}</p>
              <p class="auth-canvas__credit">Powered by TradeFlowBD</p>
            </div>

          </div>

          <!-- ── Right: login card panel ─────────────────────── -->
          <div class="auth-panel">
            <router-view />
          </div>

        </div>

      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, provide, ref } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

// Injected by AuthLoginPanel so the headline can use the real store name
const panelTitle = ref('')
provide('authPanelTitle', panelTitle)

const authScope = computed(() => {
  const metaScope = (route.meta as { authScope?: 'platform' | 'app' | 'shop' }).authScope
  // The /auth/callback route carries ?scope=shop|app|platform in the URL;
  // fall back to it when meta doesn't define an authScope.
  const queryScope = route.query.scope as 'platform' | 'app' | 'shop' | undefined
  return metaScope ?? queryScope ?? 'app'
})

const scopeClass = computed(() => `auth-scope--${authScope.value}`)

// The giant ghost word stamped across the left canvas
const ghostWord = computed(() => {
  switch (authScope.value) {
    case 'platform': return 'Platform'
    case 'shop':     return 'Store'
    default:         return 'Operations'
  }
})

// Short, confident tagline below the ghost word
const tagline = computed(() => {
  switch (authScope.value) {
    case 'platform': return 'Govern the platform.'
    case 'shop':
      return panelTitle.value ? panelTitle.value : 'Your wholesale store.'
    default:         return 'Run your business.'
  }
})
</script>

<style scoped>
/* ── Per-scope colour palette ────────────────────────── */
.auth-scope--platform {
  --auth-bg:       #100707;
  --auth-mid:      #2d0a0a;
  --auth-accent:   #ef4444;
  --auth-accent-rgb: 239 68 68;
  --auth-glow:     rgb(239 68 68 / 0.4);
  --auth-ghost:    rgb(239 68 68 / 0.04);
  --auth-card-bar: #dc2626;
}

.auth-scope--app {
  --auth-bg:       #030f08;
  --auth-mid:      #052e1a;
  --auth-accent:   #10b981;
  --auth-accent-rgb: 16 185 129;
  --auth-glow:     rgb(16 185 129 / 0.38);
  --auth-ghost:    rgb(16 185 129 / 0.04);
  --auth-card-bar: #059669;
}

.auth-scope--shop {
  --auth-bg:       #030814;
  --auth-mid:      #09184a;
  --auth-accent:   #3b82f6;
  --auth-accent-rgb: 59 130 246;
  --auth-glow:     rgb(59 130 246 / 0.38);
  --auth-ghost:    rgb(59 130 246 / 0.04);
  --auth-card-bar: #2563eb;
}

/* ── Root layout ─────────────────────────────────────── */
.auth-layout {
  min-height: 100vh;
  background: var(--auth-bg);
  position: relative;
  overflow: hidden;
}

.auth-page {
  min-height: 100vh;
  padding: 0 !important;
  background: transparent !important;
  max-width: none !important;
}

/* ── Background blobs ────────────────────────────────── */
.auth-bg {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 0;
}

.auth-bg__blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  animation: blobFloat 16s ease-in-out infinite alternate;
}

.auth-bg__blob--1 {
  width: 600px;
  height: 600px;
  top: -200px;
  left: -100px;
  background: radial-gradient(circle, var(--auth-accent) 0%, transparent 68%);
  opacity: 0.18;
  animation-delay: 0s;
}

.auth-bg__blob--2 {
  width: 420px;
  height: 420px;
  bottom: -100px;
  left: 20%;
  background: radial-gradient(circle, var(--auth-mid) 0%, transparent 70%);
  opacity: 0.55;
  animation-delay: -6s;
}

.auth-bg__blob--3 {
  width: 300px;
  height: 300px;
  top: 40%;
  left: 30%;
  background: radial-gradient(circle, var(--auth-accent) 0%, transparent 70%);
  opacity: 0.1;
  animation-delay: -11s;
}

@keyframes blobFloat {
  0%   { transform: translate(0,     0)    scale(1); }
  40%  { transform: translate(40px, -50px) scale(1.06); }
  70%  { transform: translate(-25px, 30px) scale(0.96); }
  100% { transform: translate(15px,  -15px) scale(1.03); }
}

/* ── Two-column inner ────────────────────────────────── */
.auth-layout__inner {
  position: relative;
  z-index: 1;
  min-height: 100vh;
  display: grid;
  /* left canvas takes most space; card pinned to right */
  grid-template-columns: 1fr 420px;
}

/* ── Left canvas ─────────────────────────────────────── */
.auth-canvas {
  position: relative;
  display: flex;
  flex-direction: column;
  padding: clamp(1.75rem, 3.5vw, 2.75rem);
  overflow: hidden;

  /* subtle grid texture */
  background-image:
    linear-gradient(rgb(255 255 255 / 0.025) 1px, transparent 1px),
    linear-gradient(90deg, rgb(255 255 255 / 0.025) 1px, transparent 1px);
  background-size: 48px 48px;

  /* vertical accent glow line on the right edge */
  border-right: 1px solid rgb(255 255 255 / 0.05);
}

/* right-edge glow line */
.auth-canvas::after {
  content: '';
  position: absolute;
  top: 5%;
  right: -1px;
  width: 1px;
  height: 90%;
  background: linear-gradient(
    180deg,
    transparent 0%,
    var(--auth-glow) 40%,
    var(--auth-glow) 60%,
    transparent 100%
  );
}

/* ── Brand wordmark ──────────────────────────────────── */
.auth-canvas__brand {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  color: var(--auth-accent);
  flex-shrink: 0;
}

.auth-canvas__brand-mark {
  display: flex;
  align-items: center;
  color: var(--auth-accent);
}

.auth-canvas__brand-name {
  font-size: 0.82rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: rgb(255 255 255 / 0.65);
}

/* ── Giant ghost word ────────────────────────────────── */
.auth-canvas__ghost-wrap {
  flex: 1;
  display: flex;
  align-items: center;
  /* nudge slightly left so it bleeds off-canvas beautifully */
  margin-left: -0.05em;
  pointer-events: none;
  user-select: none;
}

.auth-canvas__ghost-word {
  font-size: clamp(7rem, 16vw, 16rem);
  font-weight: 900;
  line-height: 0.85;
  letter-spacing: -0.06em;
  color: transparent;
  /* two-layer approach: outline stroke + faint fill */
  -webkit-text-stroke: 1px rgb(255 255 255 / 0.07);
  background: linear-gradient(
    160deg,
    rgb(255 255 255 / 0.06) 0%,
    var(--auth-ghost) 100%
  );
  -webkit-background-clip: text;
  background-clip: text;
}

/* ── Footer tagline ──────────────────────────────────── */
.auth-canvas__footer {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.auth-canvas__tagline {
  margin: 0;
  font-size: clamp(0.95rem, 1.6vw, 1.15rem);
  font-weight: 600;
  letter-spacing: -0.02em;
  color: rgb(255 255 255 / 0.7);
}

.auth-canvas__credit {
  margin: 0;
  font-size: 0.68rem;
  color: rgb(255 255 255 / 0.2);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

/* ── Right panel (login card) ────────────────────────── */
.auth-panel {
  display: grid;
  align-content: center;
  background: #ffffff;
  padding: clamp(1.75rem, 4vw, 3rem) clamp(1.5rem, 3.5vw, 2.5rem);
  box-shadow: -24px 0 80px rgb(0 0 0 / 0.45);
}

/* ── Responsive: collapse to single column ───────────── */
@media (max-width: 860px) {
  .auth-layout__inner {
    grid-template-columns: 1fr;
    grid-template-rows: auto 1fr;
  }

  .auth-canvas {
    min-height: unset;
    border-right: none;
    border-bottom: 1px solid rgb(255 255 255 / 0.05);
    padding: clamp(1.25rem, 3vw, 1.75rem);
  }

  .auth-canvas::after {
    display: none;
  }

  .auth-canvas__ghost-wrap {
    /* On tablet the ghost is decorative padding only */
    min-height: 6rem;
    flex: unset;
  }

  .auth-canvas__ghost-word {
    font-size: clamp(4rem, 18vw, 7rem);
  }

  .auth-panel {
    padding: clamp(1.5rem, 5vw, 2.25rem);
    box-shadow: none;
  }
}

@media (max-width: 480px) {
  .auth-canvas {
    padding: 1.25rem;
  }

  .auth-canvas__ghost-wrap {
    min-height: 4rem;
  }

  .auth-panel {
    padding: 1.25rem;
  }
}
</style>
