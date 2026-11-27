<template>
  <div class="shipment-stat-tile">
    <div class="shipment-stat-tile__label">{{ label }}</div>
    <div
      class="shipment-stat-tile__value tf-num"
      :class="valueClass"
    >
      {{ value }}
    </div>
    <div v-if="hint" class="shipment-stat-tile__hint tf-num">{{ hint }}</div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    label: string;
    value: string;
    hint?: string;
    emphasis?: 'default' | 'hero' | 'positive' | 'negative';
    tone?: 'positive' | 'negative';
  }>(),
  {
    emphasis: 'default',
  },
);

const valueClass = computed(() => {
  const classes: string[] = [];
  if (props.emphasis === 'hero') {
    classes.push('shipment-stat-tile__value--hero');
  }
  const tone =
    props.tone ??
    (props.emphasis === 'positive' || props.emphasis === 'negative' ? props.emphasis : undefined);
  if (tone === 'positive') classes.push('text-positive');
  if (tone === 'negative') classes.push('text-negative');
  return classes;
});
</script>

<style scoped>
.shipment-stat-tile {
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  min-height: 72px;
}

.shipment-stat-tile__label {
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  line-height: 1.3;
}

.shipment-stat-tile__value {
  font-size: 20px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
  line-height: 1.2;
  margin-top: 2px;
}

.shipment-stat-tile__value--hero {
  font-size: 28px;
  line-height: 1.15;
}

.shipment-stat-tile__hint {
  font-size: 12px;
  color: var(--tf-neutral-muted);
  margin-top: 4px;
}
</style>