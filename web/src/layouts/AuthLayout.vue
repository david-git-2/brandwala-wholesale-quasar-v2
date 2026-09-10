<template>
  <q-layout view="hHh lpR fFf" class="auth-layout" :class="[scopeClass, themeClass]">
    <q-page-container>
      <q-page class="auth-page">
        <div class="auth-bg" aria-hidden="true">
          <div class="auth-bg__blob auth-bg__blob--1" />
          <div class="auth-bg__blob auth-bg__blob--2" />
          <div class="auth-bg__blob auth-bg__blob--3" />
        </div>

        <div class="auth-layout__inner">
          <div class="auth-canvas">
            <div
              class="auth-canvas__brand"
              aria-label="TradeFlow BD — B2B commerce platform"
            >
              <div class="auth-canvas__brand-mark-wrap" aria-hidden="true">
                <AppLogoMark :scope="authScope" class="auth-canvas__brand-mark" />
              </div>
              <div class="auth-canvas__brand-text">
                <p class="auth-canvas__brand-name">
                  TradeFlow<span class="auth-canvas__brand-name-accent">BD</span>
                </p>
                <p class="auth-canvas__brand-sub">B2B commerce platform</p>
              </div>
            </div>

            <div class="auth-canvas__ghost-wrap" aria-hidden="true">
              <span class="auth-canvas__ghost-word">{{ ghostWord }}</span>
            </div>

            <div class="auth-canvas__footer">
              <p class="auth-canvas__tagline">{{ tagline }}</p>
              <p class="auth-canvas__credit">Powered by TradeFlow BD</p>
            </div>
          </div>

          <div class="auth-panel">
            <router-view />
          </div>
        </div>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, provide, ref } from 'vue';
import { useRoute } from 'vue-router';
import AppLogoMark from 'src/components/brand/AppLogoMark.vue';

type AuthLayoutScope = 'platform' | 'app' | 'shop' | 'investor';

const route = useRoute();

const panelTitle = ref('');
provide('authPanelTitle', panelTitle);

const authScope = computed(() => {
  const metaScope = (route.meta as { authScope?: AuthLayoutScope }).authScope;
  const queryScope = route.query.scope as AuthLayoutScope | undefined;
  return metaScope ?? queryScope ?? 'app';
});

const scopeClass = computed(() => `auth-scope--${authScope.value}`);
const themeClass = computed(() => `theme-${authScope.value}`);

const ghostWord = computed(() => {
  switch (authScope.value) {
    case 'platform':
      return 'Platform';
    case 'shop':
      return 'Store';
    case 'investor':
      return 'Investor';
    default:
      return 'Operations';
  }
});

const tagline = computed(() => {
  switch (authScope.value) {
    case 'platform':
      return 'Govern the platform.';
    case 'shop':
      return panelTitle.value ? panelTitle.value : 'Your wholesale store.';
    case 'investor':
      return 'See your portfolio.';
    default:
      return 'Run your business.';
  }
});
</script>

<style scoped>
.auth-scope--platform {
  --auth-bg: #f6f1f2;
  --auth-mid: #6b2d3c;
  --auth-accent: #6b2d3c;
  --auth-accent-rgb: 107 45 60;
  --auth-ink: #1c1416;
  --auth-ink-rgb: 28 20 22;
  --auth-muted: #6b5a5e;
  --auth-glow: rgb(107 45 60 / 0.28);
  --auth-ghost: rgb(28 20 22 / 0.1);
}

.auth-scope--app {
  --auth-bg: #f3f4f5;
  --auth-mid: #334e58;
  --auth-accent: #03b5aa;
  --auth-accent-rgb: 3 181 170;
  --auth-ink: #33261d;
  --auth-ink-rgb: 51 38 29;
  --auth-muted: #6b6d76;
  --auth-glow: rgb(3 181 170 / 0.28);
  --auth-ghost: rgb(51 38 29 / 0.1);
}

.auth-scope--shop {
  --auth-bg: #faf8f6;
  --auth-mid: #5e4955;
  --auth-accent: #996888;
  --auth-accent-rgb: 153 104 136;
  --auth-ink: #2a2b2a;
  --auth-ink-rgb: 42 43 42;
  --auth-muted: #5e4955;
  --auth-glow: rgb(153 104 136 / 0.28);
  --auth-ghost: rgb(42 43 42 / 0.1);
}

.auth-scope--investor {
  --auth-bg: #f2f6f6;
  --auth-mid: #0f5c5a;
  --auth-accent: #0f5c5a;
  --auth-accent-rgb: 15 92 90;
  --auth-ink: #1a2222;
  --auth-ink-rgb: 26 34 34;
  --auth-muted: #5a6b6b;
  --auth-glow: rgb(15 92 90 / 0.28);
  --auth-ghost: rgb(26 34 34 / 0.1);
}

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
}

.auth-bg__blob--1 {
  width: 600px;
  height: 600px;
  top: -200px;
  left: -100px;
  background: radial-gradient(circle, var(--auth-accent) 0%, transparent 68%);
  opacity: 0.14;
}

.auth-bg__blob--2 {
  width: 420px;
  height: 420px;
  bottom: -100px;
  left: 20%;
  background: radial-gradient(circle, var(--auth-mid) 0%, transparent 70%);
  opacity: 0.2;
}

.auth-bg__blob--3 {
  width: 300px;
  height: 300px;
  top: 40%;
  left: 30%;
  background: radial-gradient(circle, var(--auth-accent) 0%, transparent 70%);
  opacity: 0.1;
}

.auth-layout__inner {
  position: relative;
  z-index: 1;
  min-height: 100vh;
  display: grid;
  grid-template-columns: 1fr 420px;
}

.auth-canvas {
  position: relative;
  display: flex;
  flex-direction: column;
  padding: clamp(1.75rem, 3.5vw, 2.75rem);
  overflow: hidden;
  background-image:
    linear-gradient(rgb(var(--auth-ink-rgb, 28 20 22) / 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgb(var(--auth-ink-rgb, 28 20 22) / 0.05) 1px, transparent 1px);
  background-size: 48px 48px;
  border-right: 1px solid rgb(var(--auth-accent-rgb) / 0.12);
}

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

.auth-canvas__brand {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  flex-shrink: 0;
}

.auth-canvas__brand-mark-wrap {
  width: 52px;
  height: 52px;
  flex-shrink: 0;
}

.auth-canvas__brand-mark {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.auth-canvas__brand-text {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  min-width: 0;
}

.auth-canvas__brand-name {
  margin: 0;
  font-size: 1.2rem;
  font-weight: 800;
  letter-spacing: -0.045em;
  line-height: 1.05;
  color: var(--auth-ink);
}

.auth-canvas__brand-name-accent {
  color: var(--auth-accent);
}

.auth-canvas__brand-sub {
  margin: 0;
  font-size: 0.68rem;
  font-weight: 500;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--auth-muted);
  line-height: 1.2;
}

.auth-canvas__ghost-wrap {
  flex: 1;
  display: flex;
  align-items: center;
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
  -webkit-text-stroke: 1px rgb(var(--auth-accent-rgb) / 0.18);
  background: linear-gradient(160deg, var(--auth-ghost) 0%, rgb(var(--auth-ink-rgb) / 0.08) 100%);
  -webkit-background-clip: text;
  background-clip: text;
}

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
  color: var(--auth-ink);
}

.auth-canvas__credit {
  margin: 0;
  font-size: 0.68rem;
  color: var(--auth-muted);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.auth-panel {
  display: grid;
  align-content: center;
  background: var(--auth-bg);
  padding: clamp(1.75rem, 4vw, 3rem) clamp(1.5rem, 3.5vw, 2.5rem);
}

@media (max-width: 860px) {
  .auth-layout__inner {
    grid-template-columns: 1fr;
    grid-template-rows: auto 1fr;
  }

  .auth-canvas {
    min-height: unset;
    border-right: none;
    border-bottom: 1px solid rgb(var(--auth-accent-rgb) / 0.12);
    padding: clamp(1.25rem, 3vw, 1.75rem);
  }

  .auth-canvas::after {
    display: none;
  }

  .auth-canvas__ghost-wrap {
    min-height: 6rem;
    flex: unset;
  }

  .auth-canvas__ghost-word {
    font-size: clamp(4rem, 18vw, 7rem);
  }

  .auth-panel {
    padding: clamp(1.5rem, 5vw, 2.25rem);
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
