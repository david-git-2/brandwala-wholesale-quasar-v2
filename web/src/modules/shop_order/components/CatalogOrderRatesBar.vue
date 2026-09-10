<template>
  <q-card v-if="variant === 'card'" flat bordered class="q-pa-md bg-grey-1">
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
          :readonly="isStaffReadOnly"
          :class="{ 'bg-grey-2': isStaffReadOnly }"
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
          :disable="isStaffReadOnly"
          @click="onSave"
        >
          <q-tooltip v-if="isStaffReadOnly">Rates are locked while the customer reviews the offer</q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>

  <div v-else class="catalog-rates-compact q-pt-xs">
    <div class="row items-center justify-center">
      <div class="rates-pill row items-center q-gutter-x-xs q-px-sm q-py-2xs bg-grey-2 rounded-borders text-caption text-grey-8 font-mono">
        <span><strong>FX:</strong> {{ conversion_rate ?? '—' }}</span>
        <span class="text-grey-4">|</span>
        <span><strong>Cargo:</strong> {{ buyCurrency }}{{ cargo_rate ?? '—' }}/kg</span>
        <span class="text-grey-4">|</span>
        <span><strong>1st Offer:</strong> {{ first_offer_rate ?? profit_rate ?? '—' }}%</span>
        <span class="text-grey-4">|</span>
        <span><strong>Basis:</strong> {{ profitBasisLabel }}</span>
        <q-btn
          flat
          round
          dense
          size="xs"
          icon="ph ph-sliders-horizontal"
          color="primary"
          class="q-ml-2xs"
          @click="ratesExpanded = !ratesExpanded"
        >
          <q-tooltip>Edit rates (FX, Cargo, Profit)</q-tooltip>
        </q-btn>
      </div>
    </div>

    <div v-if="ratesExpanded" class="q-pt-sm q-pb-xs border-top q-mt-xs">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-md-2">
          <q-input
            v-model.number="conversion_rate"
            dense
            outlined
            type="number"
            step="0.01"
            prefix="৳"
            label="FX Rate"
            hide-bottom-space
            :readonly="isFirstOfferLocked"
            @update:model-value="onRateChange"
          />
        </div>
        <div class="col-12 col-md-2">
          <q-input
            v-model.number="cargo_rate"
            dense
            outlined
            type="number"
            step="0.01"
            :prefix="buyCurrency"
            suffix="/kg"
            label="Cargo Rate"
            hide-bottom-space
            :readonly="isFirstOfferLocked"
            @update:model-value="onRateChange"
          />
        </div>
        <div class="col-12 col-md-2">
          <q-input
            v-model.number="first_offer_rate"
            dense
            outlined
            type="number"
            step="0.01"
            suffix="%"
            label="1st Offer Profit %"
            hide-bottom-space
            :readonly="isFirstOfferLocked"
            @update:model-value="onRateChange"
          />
        </div>
        <div v-if="showFinalOfferRate" class="col-12 col-md-2">
          <q-input
            v-model.number="final_offer_rate"
            dense
            outlined
            type="number"
            step="0.01"
            suffix="%"
            label="Final Offer Profit %"
            hide-bottom-space
            :readonly="isStaffReadOnly"
            @update:model-value="onRateChange"
          />
        </div>
        <div class="col-12 col-md-2">
          <q-select
            v-model="profit_basis"
            dense
            outlined
            emit-value
            map-options
            :options="basisOptions"
            label="Profit Basis"
            hide-bottom-space
            :readonly="isFirstOfferLocked"
            :disable="isFirstOfferLocked"
            @update:model-value="onRateChange"
          />
        </div>
        <div class="col-12 col-md-2 row justify-end q-gutter-xs">
          <q-btn flat dense no-caps label="Cancel" class="rounded-sq-btn" @click="cancelCompactEdit" />
          <q-btn
            unelevated
            dense
            no-caps
            color="primary"
            label="Save Rates"
            class="rounded-sq-btn q-px-sm"
            :loading="saving"
            :disable="isStaffReadOnly"
            @click="onSave"
          />
        </div>
      </div>
      <div class="text-caption text-grey-6 q-mt-xs">Formula: {{ formulaExplanation }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { ShopOrder } from '../types';
import {
  normalizeCatalogOrderStatus,
  isCatalogFirstOfferLocked,
  isCatalogStaffReadOnly,
} from '../utils/catalogOrderStatus';

const props = withDefaults(
  defineProps<{
    order: ShopOrder | null;
    saving?: boolean;
    variant?: 'card' | 'compact';
  }>(),
  { variant: 'card' },
);

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
const ratesExpanded = ref(false);

const buyCurrency = computed(() => props.order?.shop_buy_currency_symbol || '£');

const showFinalOfferRate = computed(
  () => normalizeCatalogOrderStatus(props.order?.status) !== 'submitted',
);

const isFirstOfferLocked = computed(() => isCatalogFirstOfferLocked(props.order?.status));
const isStaffReadOnly = computed(() => isCatalogStaffReadOnly(props.order?.status));

const basisOptions = [
  { label: 'Total Cost', value: 'total_cost' },
  { label: 'Purchase Only', value: 'purchase' },
];

const profitBasisLabel = computed(() =>
  profit_basis.value === 'purchase' ? 'Purchase' : 'Total Cost',
);

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
  if (isStaffReadOnly.value) {
    return;
  }

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
  if (isStaffReadOnly.value) {
    return;
  }

  if (isFirstOfferLocked.value) {
    emit('save-rates', {
      conversion_rate: props.order?.conversion_rate ?? conversion_rate.value,
      cargo_rate: props.order?.cargo_rate ?? cargo_rate.value,
      profit_rate: props.order?.profit_rate ?? profit_rate.value,
      first_offer_rate: props.order?.first_offer_rate ?? first_offer_rate.value,
      final_offer_rate: final_offer_rate.value,
      profit_basis: (props.order?.profit_basis as 'purchase' | 'total_cost') || profit_basis.value,
    });
  } else {
    emit('save-rates', {
      conversion_rate: conversion_rate.value,
      cargo_rate: cargo_rate.value,
      profit_rate: profit_rate.value,
      first_offer_rate: first_offer_rate.value,
      final_offer_rate: final_offer_rate.value,
      profit_basis: profit_basis.value,
    });
  }

  ratesExpanded.value = false;
}

function cancelCompactEdit() {
  if (props.order) {
    conversion_rate.value = props.order.conversion_rate ?? 140;
    cargo_rate.value = props.order.cargo_rate ?? 0;
    profit_rate.value = props.order.profit_rate ?? 25;
    first_offer_rate.value = props.order.first_offer_rate ?? null;
    final_offer_rate.value = props.order.final_offer_rate ?? null;
    profit_basis.value = (props.order.profit_basis as 'purchase' | 'total_cost') || 'total_cost';
  }
  ratesExpanded.value = false;
}
</script>

<style scoped lang="scss">
.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.rounded-sq-btn {
  border-radius: 8px !important;
}
</style>
