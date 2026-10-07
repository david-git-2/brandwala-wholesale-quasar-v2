<template>
  <div
    class="tf-loading-screen"
    :class="[`theme-${scope}`, { 'tf-loading-screen--fullscreen': fullscreen }]"
    role="status"
    aria-live="polite"
    :aria-label="ariaLabel"
  >
    <div class="tf-loading-screen__backdrop" aria-hidden="true">
      <div class="tf-loading-screen__glow" />
    </div>

    <div class="tf-loading-screen__content">
      <img
        class="tf-loading-screen__logo"
        :src="logoSrc"
        alt="TradeFlow BD"
        decoding="async"
      />
      <p v-if="resolvedTenantName" class="tf-loading-screen__tenant">
        {{ resolvedTenantName }}
      </p>
      <p v-if="resolvedTagline" class="tf-loading-screen__tagline">
        {{ resolvedTagline }}
      </p>

      <div class="tf-loading-screen__loader" aria-hidden="true">
        <span class="tf-loading-screen__dot" />
        <span class="tf-loading-screen__dot" />
        <span class="tf-loading-screen__dot" />
      </div>

      <div v-if="$slots.default" class="tf-loading-screen__extra">
        <slot />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';

export type TradeFlowLoadingScope = 'platform' | 'app' | 'shop' | 'investor';

const SCOPE_TAGLINES: Record<TradeFlowLoadingScope, string> = {
  platform: 'Govern the platform',
  app: 'Run your business',
  shop: 'Your wholesale store',
  investor: 'See your portfolio',
};

const props = withDefaults(
  defineProps<{
    scope?: TradeFlowLoadingScope;
    tagline?: string;
    tenantName?: string | null;
    fullscreen?: boolean;
    ariaLabel?: string;
  }>(),
  {
    scope: 'app',
    fullscreen: false,
    ariaLabel: 'Loading',
  },
);

const $q = useQuasar();

const logoSrc = computed(() =>
  $q.dark.isActive ? '/brand/logo-dark.png' : '/brand/logo-light.png',
);

const resolvedTagline = computed(() => props.tagline ?? SCOPE_TAGLINES[props.scope]);

const resolvedTenantName = computed(() => {
  const name = props.tenantName?.trim();
  if (!name || name === 'TradeFlowBD' || name === 'TradeFlow BD') {
    return '';
  }
  return name;
});
</script>

<style scoped>
.tf-loading-screen {
  --splash-bg: var(--bw-theme-base, #f4f6f8);
  --splash-surface: var(--bw-theme-surface, #ffffff);
  --splash-accent: var(--bw-theme-primary, #0d6b5c);
  --splash-accent-rgb: var(--bw-theme-primary-rgb, 13 107 92);
  --splash-ink: var(--bw-theme-ink, #0f172a);
  --splash-muted: var(--bw-theme-muted, #64748b);
  --splash-glow: rgb(var(--splash-accent-rgb) / 0.14);
  --splash-gradient-end: color-mix(in srgb, var(--splash-bg) 88%, var(--splash-accent) 12%);

  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  width: 100%;
  min-height: min(70dvh, 28rem);
  box-sizing: border-box;
  background: linear-gradient(
    180deg,
    var(--splash-surface) 0%,
    var(--splash-bg) 42%,
    var(--splash-gradient-end) 100%
  );
  color: var(--splash-ink);
}

.tf-loading-screen--fullscreen {
  position: fixed;
  inset: 0;
  z-index: 99998;
  min-height: 100dvh;
}

.tf-loading-screen__backdrop {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.tf-loading-screen__glow {
  position: absolute;
  width: min(72vw, 520px);
  height: min(72vw, 520px);
  top: 50%;
  left: 50%;
  transform: translate(-50%, -54%);
  border-radius: 50%;
  background: radial-gradient(circle, var(--splash-glow) 0%, transparent 68%);
  opacity: 0.9;
}

.tf-loading-screen__content {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.85rem;
  width: min(100%, 360px);
  padding: 1.75rem 1.5rem 1.5rem;
  animation: tf-loading-rise 0.75s cubic-bezier(0.22, 1, 0.36, 1) both;
}

.tf-loading-screen__logo {
  width: auto;
  height: clamp(44px, 10vw, 58px);
  max-width: min(168px, 40vw);
  object-fit: contain;
  display: block;
  margin-top: 0.15rem;
}

.tf-loading-screen__tenant {
  margin: 0;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--splash-ink);
  text-align: center;
  line-height: 1.35;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tf-loading-screen__tagline {
  margin: -0.15rem 0 0;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--splash-muted);
  text-align: center;
  line-height: 1.4;
}

.tf-loading-screen__loader {
  display: flex;
  align-items: center;
  gap: 0.38rem;
  margin-top: 0.55rem;
}

.tf-loading-screen__dot {
  width: 0.34rem;
  height: 0.34rem;
  border-radius: 50%;
  background: var(--splash-accent);
  opacity: 0.35;
  animation: tf-loading-dot 1.1s ease-in-out infinite;
}

.tf-loading-screen__dot:nth-child(2) {
  animation-delay: 0.15s;
}

.tf-loading-screen__dot:nth-child(3) {
  animation-delay: 0.3s;
}

.tf-loading-screen__extra {
  width: 100%;
  margin-top: 0.5rem;
  text-align: center;
}

@keyframes tf-loading-rise {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes tf-loading-dot {
  0%,
  80%,
  100% {
    opacity: 0.28;
    transform: translateY(0);
  }
  40% {
    opacity: 1;
    transform: translateY(-3px);
  }
}

@media (prefers-reduced-motion: reduce) {
  .tf-loading-screen__content,
  .tf-loading-screen__dot {
    animation: none !important;
  }
}
</style>
