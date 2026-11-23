<template>
  <q-layout
    view="hHh lpR fFf"
    class="auth-layout"
    :class="[themeClass, { 'auth-layout--immersive': useImmersiveLayout }]"
    :style="
      useImmersiveLayout
        ? { '--auth-scene-bg': `url(${authSceneBg})` }
        : undefined
    "
  >
    <q-page-container>
      <q-page class="auth-page">
        <div class="auth-bg" aria-hidden="true">
          <div v-if="useImmersiveLayout" class="auth-bg__scene-cover" />
          <template v-else>
            <div class="auth-bg__blob auth-bg__blob--1" />
            <div class="auth-bg__blob auth-bg__blob--2" />
            <div class="auth-bg__blob auth-bg__blob--3" />
          </template>
        </div>

        <div
          class="auth-layout__inner"
          :class="{
            'auth-layout__inner--panel-only': isPanelOnlyRoute,
            'auth-layout__inner--immersive': useImmersiveLayout,
          }"
        >
          <div v-if="!isPanelOnlyRoute" class="auth-canvas">
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
              <span
                v-if="shopTypeGhostParts"
                class="auth-canvas__ghost-word auth-canvas__ghost-word--shop-type"
              >
                <span class="auth-canvas__ghost-stack">
                  <span class="auth-canvas__ghost-kind">{{ shopTypeGhostParts.kind }}</span>
                  <span class="auth-canvas__ghost-suffix">{{ shopTypeGhostParts.suffix }}</span>
                </span>
              </span>
              <span v-else class="auth-canvas__ghost-word">{{ ghostWord }}</span>
            </div>

            <div class="auth-canvas__footer">
              <p class="auth-canvas__tagline">{{ tagline }}</p>
              <p class="auth-canvas__credit">Powered by TradeFlow BD</p>
            </div>
          </div>

          <div class="auth-panel">
            <p
              v-if="authScope === 'shop' && shopTypeGhostParts"
              class="auth-panel__shop-eyebrow"
            >
              {{ shopTypeGhostParts.kind }}
              <span>{{ shopTypeGhostParts.suffix }}</span>
            </p>
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
import authSceneBg from 'src/assets/shop-login-bg.png';
import { SHOP_TYPE_AUTH_GHOST_LABEL } from 'src/modules/tenant/composables/useShopEntryShopType';
import { getShopTypePathFromRoute } from 'src/modules/tenant/utils/tenantRouteContext';

type AuthLayoutScope = 'platform' | 'app' | 'shop' | 'investor';

const route = useRoute();

const isPanelOnlyRoute = computed(
  () => route.name === 'auth-callback-page',
);

const useImmersiveLayout = computed(() => !isPanelOnlyRoute.value);

const panelTitle = ref('');
provide('authPanelTitle', panelTitle);

const authScope = computed(() => {
  const metaScope = (route.meta as { authScope?: AuthLayoutScope }).authScope;
  const queryScope = route.query.scope as AuthLayoutScope | undefined;
  return metaScope ?? queryScope ?? 'app';
});

const themeClass = computed(() => `theme-${authScope.value}`);

const shopTypePath = computed(() => getShopTypePathFromRoute(route));

const shopTypeGhostParts = computed(() => {
  if (authScope.value !== 'shop') return null;
  const seg = shopTypePath.value;
  if (!seg) return null;
  const label = SHOP_TYPE_AUTH_GHOST_LABEL[seg];
  return {
    kind: label.replace(/ shop$/i, ''),
    suffix: 'shop',
  };
});

const ghostWord = computed(() => {
  switch (authScope.value) {
    case 'platform':
      return 'Platform';
    case 'shop': {
      const seg = shopTypePath.value;
      return seg ? SHOP_TYPE_AUTH_GHOST_LABEL[seg] : 'Shop';
    }
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
.auth-layout {
  --auth-bg: var(--tf-theme-base);
  --auth-accent: var(--tf-theme-primary);
  --auth-accent-rgb: var(--tf-theme-primary-rgb);
  --auth-ink: var(--tf-theme-ink);
  --auth-muted: var(--tf-theme-muted);
  --auth-mid: color-mix(in srgb, var(--tf-theme-primary) 72%, var(--tf-theme-ink));
  --auth-glow: rgb(var(--tf-theme-primary-rgb) / 0.28);
  --auth-ghost: color-mix(in srgb, var(--tf-theme-ink) 10%, transparent);
  min-height: 100dvh;
  background: var(--auth-bg);
  position: relative;
  overflow-x: hidden;
}

.auth-page {
  min-height: 100dvh;
  padding: 0 !important;
  background: transparent !important;
  max-width: none !important;
  overflow-y: auto;
  overflow-x: hidden;
  -webkit-overflow-scrolling: touch;
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

.auth-bg__scene-cover {
  position: absolute;
  inset: 0;
  background-color: var(--auth-bg);
  background-image: var(--auth-scene-bg);
  background-size: cover;
  background-position: center center;
  background-repeat: no-repeat;
}

.auth-bg__scene-cover::after {
  content: '';
  position: absolute;
  inset: 0;
  background:
    radial-gradient(
      120% 90% at 18% 42%,
      color-mix(in srgb, var(--auth-bg) 52%, transparent) 0%,
      transparent 62%
    ),
    linear-gradient(
      100deg,
      color-mix(in srgb, var(--auth-bg) 48%, transparent) 0%,
      color-mix(in srgb, var(--auth-bg) 28%, transparent) 52%,
      color-mix(in srgb, var(--auth-bg) 22%, transparent) 100%
    );
}

.auth-layout__inner {
  position: relative;
  z-index: 1;
  min-height: 100dvh;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 420px);
}

.auth-layout--immersive .auth-layout__inner {
  grid-template-columns: minmax(0, 1.12fr) minmax(300px, 400px);
}

.auth-layout__inner--panel-only {
  grid-template-columns: minmax(0, 1fr);
  place-items: center;
  padding: clamp(1rem, 4vw, 2rem);
  padding-bottom: max(1rem, env(safe-area-inset-bottom));
}

.auth-canvas {
  position: relative;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: clamp(1.75rem, 3.5vw, 2.75rem);
  overflow: hidden;
  background-image:
    linear-gradient(color-mix(in srgb, var(--tf-theme-ink) 5%, transparent) 1px, transparent 1px),
    linear-gradient(
      90deg,
      color-mix(in srgb, var(--tf-theme-ink) 5%, transparent) 1px,
      transparent 1px
    );
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

.auth-layout--immersive .auth-canvas {
  background-image: none;
  background-color: transparent;
  border-right: none;
}

.auth-layout--immersive .auth-canvas::after {
  display: none;
}

.auth-layout--immersive .auth-panel {
  background: transparent;
  align-content: center;
  justify-items: start;
  padding: clamp(1.5rem, 4vw, 2.75rem) clamp(1.25rem, 4vw, 2.5rem);
  padding-bottom: max(clamp(1.5rem, 4vw, 2.75rem), env(safe-area-inset-bottom));
}

.auth-panel__shop-eyebrow {
  display: none;
  margin: 0;
  width: 100%;
  max-width: 21rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--auth-accent);
  line-height: 1.2;
}

.auth-panel__shop-eyebrow span {
  color: var(--auth-muted);
  font-weight: 600;
}

.auth-layout--immersive .auth-canvas__brand-name,
.auth-layout--immersive .auth-canvas__brand-sub,
.auth-layout--immersive .auth-canvas__tagline,
.auth-layout--immersive .auth-canvas__credit {
  text-shadow: 0 1px 22px color-mix(in srgb, var(--auth-bg) 92%, transparent);
}

.auth-layout--immersive .auth-canvas__ghost-wrap {
  justify-content: flex-start;
}

.auth-layout--immersive .auth-canvas__ghost-word--shop-type {
  display: block;
  text-align: left;
  letter-spacing: normal;
  text-wrap: wrap;
  color: var(--auth-ink);
  -webkit-text-stroke: 0;
  background: none;
  -webkit-background-clip: border-box;
  background-clip: border-box;
  text-shadow: 0 2px 28px color-mix(in srgb, var(--auth-bg) 88%, transparent);
}

.auth-layout--immersive .auth-canvas__ghost-stack {
  display: inline-flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.14em;
  max-width: 100%;
}

.auth-layout--immersive .auth-canvas__ghost-kind {
  display: block;
  font-size: 1em;
  font-weight: 800;
  letter-spacing: -0.05em;
  line-height: 0.92;
}

.auth-layout--immersive .auth-canvas__ghost-suffix {
  display: block;
  font-size: 0.38em;
  font-weight: 700;
  letter-spacing: 0.14em;
  padding-left: 0.14em;
  text-transform: uppercase;
  color: var(--auth-accent);
  line-height: 1.1;
  box-sizing: border-box;
}

.auth-layout--immersive .auth-canvas__tagline {
  font-size: clamp(1.05rem, 1.8vw, 1.35rem);
  font-weight: 700;
  letter-spacing: -0.03em;
}

.auth-layout--immersive .auth-canvas__credit {
  opacity: 0.85;
}

.auth-layout--immersive .auth-canvas__ghost-word:not(.auth-canvas__ghost-word--shop-type) {
  text-align: left;
  color: color-mix(in srgb, var(--auth-ink) 48%, var(--auth-accent));
  -webkit-text-stroke: 0;
  background: none;
  -webkit-background-clip: border-box;
  background-clip: border-box;
  text-shadow: 0 2px 28px color-mix(in srgb, var(--auth-bg) 88%, transparent);
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
  overflow: hidden;
  max-width: 100%;
}

.auth-canvas__ghost-word {
  font-size: clamp(7rem, 16vw, 16rem);
  font-weight: 900;
  line-height: 0.85;
  letter-spacing: -0.06em;
  color: transparent;
  -webkit-text-stroke: 1px rgb(var(--auth-accent-rgb) / 0.18);
  background: linear-gradient(
    160deg,
    var(--auth-ghost) 0%,
    color-mix(in srgb, var(--tf-theme-ink) 8%, transparent) 100%
  );
  -webkit-background-clip: text;
  background-clip: text;
}

.auth-canvas__ghost-word--shop-type {
  font-size: clamp(4rem, 10.5vw, 10rem);
  line-height: 0.92;
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
  justify-items: stretch;
  min-width: 0;
  width: 100%;
  box-sizing: border-box;
  background: var(--auth-bg);
  padding: clamp(1.25rem, 4vw, 3rem) clamp(1rem, 3.5vw, 2.5rem);
  padding-bottom: max(clamp(1.25rem, 4vw, 3rem), env(safe-area-inset-bottom));
}

.auth-panel > :deep(*) {
  width: 100%;
  max-width: 100%;
  min-width: 0;
  box-sizing: border-box;
}

.auth-layout__inner--panel-only .auth-panel {
  max-width: 28rem;
  padding: 0;
}

@media (max-width: 860px) {
  .auth-layout__inner {
    grid-template-columns: minmax(0, 1fr);
    grid-template-rows: auto minmax(0, 1fr);
  }

  .auth-layout__inner--panel-only {
    grid-template-rows: 1fr;
    min-height: 100dvh;
  }

  .auth-canvas {
    min-height: unset;
    border-right: none;
    border-bottom: 1px solid rgb(var(--auth-accent-rgb) / 0.12);
    padding: clamp(1.25rem, 3vw, 1.75rem);
  }

  .auth-layout--immersive .auth-bg__scene-cover::after {
    background: linear-gradient(
      180deg,
      color-mix(in srgb, var(--auth-bg) 58%, transparent) 0%,
      color-mix(in srgb, var(--auth-bg) 38%, transparent) 50%,
      color-mix(in srgb, var(--auth-bg) 42%, transparent) 100%
    );
  }

  .auth-layout--immersive .auth-layout__inner--immersive {
    display: flex;
    flex-direction: column;
    min-height: 100dvh;
    grid-template-rows: unset;
    grid-template-columns: unset;
  }

  .auth-layout--immersive .auth-canvas {
    flex: 0 0 auto;
    border-bottom: none;
    padding: max(1rem, env(safe-area-inset-top)) 1.25rem 0.5rem;
  }

  .auth-layout--immersive .auth-canvas__ghost-wrap,
  .auth-layout--immersive .auth-canvas__footer {
    display: none;
  }

  .auth-layout--immersive .auth-canvas__brand-mark-wrap {
    width: 40px;
    height: 40px;
  }

  .auth-layout--immersive .auth-panel {
    flex: 1 1 auto;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: center;
    align-content: unset;
    justify-items: unset;
    width: 100%;
    min-height: 0;
    padding: 0.75rem 1.25rem max(1.5rem, env(safe-area-inset-bottom));
  }

  .auth-layout--immersive .auth-panel__shop-eyebrow {
    display: block;
    margin-bottom: 0.65rem;
    align-self: flex-start;
    text-align: left;
  }

  .auth-layout--immersive .auth-panel > :deep(*) {
    align-self: flex-start;
    width: 100%;
    max-width: 22rem;
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

  .auth-canvas__ghost-word--shop-type {
    font-size: clamp(2.5rem, 12vw, 5rem);
  }

  .auth-panel {
    padding: clamp(1.5rem, 5vw, 2.25rem);
  }
}

@media (max-width: 480px) {
  .auth-canvas {
    padding: 1.25rem;
  }

  .auth-layout--immersive .auth-canvas {
    padding: max(0.85rem, env(safe-area-inset-top)) 1rem 0.35rem;
  }

  .auth-canvas__ghost-wrap {
    min-height: 4rem;
  }

  .auth-panel {
    padding: 1.25rem;
  }

  .auth-layout--immersive .auth-panel {
    padding: 0.5rem 1rem max(1.25rem, env(safe-area-inset-bottom));
  }
}
</style>
