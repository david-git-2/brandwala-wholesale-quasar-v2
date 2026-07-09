<template>
  <div class="row q-col-gutter-md">
    <div v-for="card in items" :key="card.label" :class="card.class || 'col-12 col-sm-6 col-md-3'">
      <q-card flat bordered class="q-pa-md h-full bg-white text-black">
        <div class="text-caption text-grey-7 text-uppercase tracking-wider">
          {{ card.label }}
        </div>
        <div class="text-h5 text-weight-bolder q-mt-xs text-primary" :class="card.valueClass">
          {{ formatCardValue(card.value, card.format) }}
        </div>
        <div v-if="card.caption" class="text-caption text-grey-5 q-mt-xs">
          {{ card.caption }}
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatAmountBdt } from 'src/utils/currency';

export interface StatCardItem {
  label: string;
  value: number | string;
  caption?: string;
  class?: string;
  valueClass?: string;
  format?: 'currency' | 'percent' | 'number' | 'text';
}

defineProps<{
  items: StatCardItem[];
}>();

const formatCardValue = (
  val: number | string,
  format?: 'currency' | 'percent' | 'number' | 'text',
) => {
  if (format === 'percent') {
    const num = Number(val);
    return `${Number.isFinite(num) ? num.toFixed(2) : val}%`;
  }
  if (format === 'number') {
    const num = Number(val);
    return Number.isFinite(num) ? num.toLocaleString() : String(val);
  }
  if (format === 'text') {
    return String(val);
  }
  // Default: currency
  return formatAmountBdt(val);
};
</script>
