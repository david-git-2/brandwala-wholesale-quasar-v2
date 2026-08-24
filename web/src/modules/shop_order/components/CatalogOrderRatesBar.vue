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
      <div class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model.number="conversion_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="Conversion Rate (FX)"
          :readonly="isFirstOfferLocked"
          :class="{ 'bg-grey-2': isFirstOfferLocked }"
          @update:model-value="onRateChange"
        />
      </div>

      <div class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model.number="cargo_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="Cargo Rate (kg/GBP)"
          :readonly="isFirstOfferLocked"
          :class="{ 'bg-grey-2': isFirstOfferLocked }"
          @update:model-value="onRateChange"
        />
      </div>


      <div class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model.number="first_offer_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="1st Offer Profit Rate (%)"
          :readonly="isFirstOfferLocked"
          :class="{ 'bg-grey-2': isFirstOfferLocked }"
          @update:model-value="onRateChange"
        />
      </div>

      <div v-if="showFinalOfferRate" class="col-12 col-sm-6 col-md-2">
        <q-input
          v-model.number="final_offer_rate"
          dense
          outlined
          type="number"
          step="0.01"
          class="bg-white soft-input"
          label="Final Offer Profit Rate (%)"
          @update:model-value="onRateChange"
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
          :readonly="isFirstOfferLocked"
          :disable="isFirstOfferLocked"
          @update:model-value="onRateChange"
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
import { normalizeCatalogOrderStatus, isCatalogFirstOfferLocked } from '../utils/catalogOrderStatus';

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
      first_offer_rate: number | null;
      final_offer_rate: number | null;
      profit_basis: 'purchase' | 'total_cost';
    },
  ): void;
  (
    e: 'change-rates',
    payload: {
      conversion_rate: number | null;
      cargo_rate: number | null;
      profit_rate: number | null;
      first_offer_rate: number | null;
      final_offer_rate: number | null;
      profit_basis: 'purchase' | 'total_cost';
    },
  ): void;
}>();

const conversion_rate = ref<number | null>(null);
const cargo_rate = ref<number | null>(null);
const profit_rate = ref<number | null>(null);
const first_offer_rate = ref<number | null>(null);
const final_offer_rate = ref<number | null>(null);
const profit_basis = ref<'purchase' | 'total_cost'>('total_cost');

const showFinalOfferRate = computed(
  () => normalizeCatalogOrderStatus(props.order?.status) !== 'submitted',
);

const isFirstOfferLocked = computed(() => isCatalogFirstOfferLocked(props.order?.status));

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
      first_offer_rate.value = newOrder.first_offer_rate ?? null;
      final_offer_rate.value = newOrder.final_offer_rate ?? null;
      profit_basis.value = (newOrder.profit_basis as 'purchase' | 'total_cost') || 'total_cost';
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

function onRateChange() {
  if (isFirstOfferLocked.value) {
    emit('change-rates', {
      conversion_rate: props.order?.conversion_rate ?? conversion_rate.value,
      cargo_rate: props.order?.cargo_rate ?? cargo_rate.value,
      profit_rate: props.order?.profit_rate ?? profit_rate.value,
      first_offer_rate: props.order?.first_offer_rate ?? first_offer_rate.value,
      final_offer_rate: final_offer_rate.value,
      profit_basis: (props.order?.profit_basis as 'purchase' | 'total_cost') || profit_basis.value,
    });
    return;
  }

  emit('change-rates', {
    conversion_rate: conversion_rate.value,
    cargo_rate: cargo_rate.value,
    profit_rate: profit_rate.value,
    first_offer_rate: first_offer_rate.value,
    final_offer_rate: final_offer_rate.value,
    profit_basis: profit_basis.value,
  });
}

function onSave() {
  if (isFirstOfferLocked.value) {
    emit('save-rates', {
      conversion_rate: props.order?.conversion_rate ?? conversion_rate.value,
      cargo_rate: props.order?.cargo_rate ?? cargo_rate.value,
      profit_rate: props.order?.profit_rate ?? profit_rate.value,
      first_offer_rate: props.order?.first_offer_rate ?? first_offer_rate.value,
      final_offer_rate: final_offer_rate.value,
      profit_basis: (props.order?.profit_basis as 'purchase' | 'total_cost') || profit_basis.value,
    });
    return;
  }

  emit('save-rates', {
    conversion_rate: conversion_rate.value,
    cargo_rate: cargo_rate.value,
    profit_rate: profit_rate.value,
    first_offer_rate: first_offer_rate.value,
    final_offer_rate: final_offer_rate.value,
    profit_basis: profit_basis.value,
  });
}
</script>

<style scoped lang="scss">
.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
