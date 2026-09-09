<template>
  <section class="dashboard-hero" :class="`dashboard-hero--${layout}`">
    <div
      class="dashboard-hero__bg"
      role="img"
      :aria-label="ariaLabel"
      :style="bgStyle"
    />
    <div class="dashboard-hero__vignette" />

    <div class="dashboard-hero__snapshot">
      <slot name="snapshot" />
    </div>

    <div class="dashboard-hero__queue">
      <slot name="queue" />
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    imageUrl: string;
    imagePosition?: string;
    layout?: 'tl-br' | 'tr-bl';
    ariaLabel?: string;
  }>(),
  {
    imagePosition: 'center',
    layout: 'tl-br',
    ariaLabel: 'Dashboard illustration',
  },
);

const bgStyle = computed(() => ({
  backgroundImage: `url(${props.imageUrl})`,
  backgroundPosition: props.imagePosition,
}));
</script>

<style scoped>
.dashboard-hero {
  position: relative;
  width: 100%;
  min-height: 300px;
  height: clamp(300px, 38vw, 460px);
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  background: var(--bw-theme-surface, #ffffff);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 1.25rem 1.45rem;
}

.dashboard-hero__bg {
  position: absolute;
  inset: 0;
  background-size: cover;
  background-repeat: no-repeat;
  z-index: 1;
}

.dashboard-hero__vignette {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 2;
}

.dashboard-hero--tl-br .dashboard-hero__vignette {
  background:
    radial-gradient(circle at 20% 20%, rgba(255, 255, 255, 0.35) 0%, transparent 50%),
    radial-gradient(circle at 85% 85%, rgba(255, 255, 255, 0.35) 0%, transparent 50%);
}

.dashboard-hero--tr-bl .dashboard-hero__vignette {
  background:
    radial-gradient(circle at 80% 20%, rgba(255, 255, 255, 0.35) 0%, transparent 50%),
    radial-gradient(circle at 20% 85%, rgba(255, 255, 255, 0.35) 0%, transparent 50%);
}

.dashboard-hero__snapshot,
.dashboard-hero__queue {
  position: relative;
  z-index: 3;
  width: fit-content;
}

.dashboard-hero--tl-br .dashboard-hero__snapshot,
.dashboard-hero--tr-bl .dashboard-hero__queue {
  align-self: flex-start;
}

.dashboard-hero--tl-br .dashboard-hero__queue,
.dashboard-hero--tr-bl .dashboard-hero__snapshot {
  align-self: flex-end;
}

:slotted(.glass-panel) {
  display: flex;
  align-items: center;
  gap: 1.15rem;
  background: rgba(255, 255, 255, 0.68);
  backdrop-filter: blur(18px) saturate(180%);
  -webkit-backdrop-filter: blur(18px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.75);
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.06);
  border-radius: 12px;
  padding: 0.75rem 1.15rem;
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

:slotted(.glass-panel--interactive) {
  cursor: pointer;
  user-select: none;
}

:slotted(.glass-panel--interactive:hover) {
  transform: translateY(-2px);
  background: rgba(255, 255, 255, 0.88);
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
}

:slotted(.glass-panel__action-icon) {
  font-size: 1.05rem;
  color: #94a3b8;
  transition: all 0.2s ease;
  margin-left: 0.15rem;
}

:slotted(.glass-panel--interactive:hover .glass-panel__action-icon) {
  color: var(--bw-theme-primary, #0284c7);
  transform: scale(1.15) translate(1px, -1px);
}

:slotted(.glass-panel--bottom) {
  gap: 0.75rem;
  padding: 0.55rem 0.85rem;
  background: rgba(255, 255, 255, 0.72);
}

:slotted(.stat-item) {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

:slotted(.stat-item__header) {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

:slotted(.pulse-dot) {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  display: inline-block;
}

:slotted(.pulse-dot--success) {
  background: #10b981;
  box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.25);
}

:slotted(.pulse-dot--primary) {
  background: #0284c7;
  box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.25);
}

:slotted(.pulse-dot--warn) {
  background: #d97706;
  box-shadow: 0 0 0 3px rgba(217, 119, 6, 0.25);
}

:slotted(.stat-item__label) {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #475569;
}

:slotted(.stat-item__value-row) {
  display: flex;
  align-items: baseline;
  gap: 0.35rem;
}

:slotted(.stat-item__number) {
  font-size: 1.45rem;
  font-weight: 800;
  color: #0f172a;
  letter-spacing: -0.02em;
  line-height: 1.15;
}

:slotted(.stat-item__unit) {
  font-size: 0.76rem;
  font-weight: 600;
  color: #64748b;
}

:slotted(.stat-item__badge) {
  font-size: 0.68rem;
  font-weight: 700;
  color: #0284c7;
  background: rgba(2, 132, 199, 0.12);
  padding: 0.1rem 0.35rem;
  border-radius: 4px;
}

:slotted(.glass-divider) {
  width: 1px;
  height: 32px;
  background: rgba(203, 213, 225, 0.8);
}

:slotted(.pill-stat) {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  padding: 0.35rem 0.65rem;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.65);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 1px solid rgba(255, 255, 255, 0.7);
}

:slotted(.pill-stat__icon) {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.95rem;
}

:slotted(.pill-stat--info .pill-stat__icon) {
  background: rgba(2, 132, 199, 0.15);
  color: #0284c7;
}

:slotted(.pill-stat--warn .pill-stat__icon) {
  background: rgba(245, 158, 11, 0.15);
  color: #d97706;
}

:slotted(.pill-stat--success .pill-stat__icon) {
  background: rgba(16, 185, 129, 0.15);
  color: #059669;
}

:slotted(.pill-stat--accent .pill-stat__icon) {
  background: rgba(124, 58, 237, 0.15);
  color: #7c3aed;
}

:slotted(.pill-stat__meta) {
  display: flex;
  flex-direction: column;
}

:slotted(.pill-stat__label) {
  font-size: 0.68rem;
  font-weight: 600;
  color: #64748b;
  line-height: 1.1;
}

:slotted(.pill-stat__value) {
  font-size: 0.84rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.2;
}

@media (max-width: 640px) {
  .dashboard-hero {
    gap: 1rem;
  }

  .dashboard-hero__queue {
    align-self: flex-start !important;
  }

  :slotted(.glass-panel--top) {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.65rem;
  }

  :slotted(.glass-divider) {
    display: none;
  }

  :slotted(.glass-panel--bottom) {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
