<template>
  <q-card flat bordered class="q-pa-md bg-grey-1">
    <div class="row items-center justify-between q-mb-sm">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center gap-2">
        <q-icon name="ph ph-sliders-horizontal" size="18px" color="primary" />
        Order Calculation Rates
      </div>
      <q-badge outline color="primary" class="text-caption">
        Formula: {{ formulaExplanation }}
      </q-badge>
    </div>

    <div class="row items-end q-col-gutter-sm">
      <div class="col-12 col-sm-6 col-md-3">
        <q-input
          v-model.number="conversion_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="Conversion Rate (FX)"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-input
          v-model.number="cargo_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="Cargo Rate (kg/GBP)"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model.number="profit_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="Profit Rate (%)"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-select
          v-model="profit_basis"
          dense
          outlined
          emit-value
          map-options
          :options="basisOptions"
          class="bg-white soft-input"
          label="Profit Basis"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-btn
          color="primary"
          unelevated
          no-caps
          dense
          class="full-width q-py-xs"
          label="Apply Rates"
          :loading="saving"
          @click="onSave"
        />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { ShopOrder } from '../types';

const props = defineProps<{
  order: ShopOrder | null;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (
    e: 'save-rates',
    payload: {
      conversion_rate: number | null;
      cargo_rate: number | null;
      profit_rate: number | null;
      profit_basis: 'purchase' | 'total_cost';
    },
  ): void;
}>();

const conversion_rate = ref<number | null>(null);
const cargo_rate = ref<number | null>(null);
const profit_rate = ref<number | null>(null);
const profit_basis = ref<'purchase' | 'total_cost'>('total_cost');

const basisOptions = [
  { label: 'Total Cost', value: 'total_cost' },
  { label: 'Purchase Only', value: 'purchase' },
];

watch(
  () => props.order,
  (newOrder) => {
    if (newOrder) {
      conversion_rate.value = newOrder.conversion_rate ?? 140;
      cargo_rate.value = newOrder.cargo_rate ?? 0;
      profit_rate.value = newOrder.profit_rate ?? 25;
      profit_basis.value = newOrder.profit_basis || 'total_cost';
    }
  },
  { immediate: true },
);

const formulaExplanation = computed(() => {
  if (profit_basis.value === 'purchase') {
    return 'Round5(ceil((Cost × FX) × (1 + Profit%)))';
  }
  return 'Round5(ceil((Cost × FX + Weight × Cargo × FX) × (1 + Profit%)))';
});

function onSave() {
  emit('save-rates', {
    conversion_rate: conversion_rate.value,
    cargo_rate: cargo_rate.value,
    profit_rate: profit_rate.value,
    profit_basis: profit_basis.value,
  });
}
</script>

<style scoped lang="scss">
.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
