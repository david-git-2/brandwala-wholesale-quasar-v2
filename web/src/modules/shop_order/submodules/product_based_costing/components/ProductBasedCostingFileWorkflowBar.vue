<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="pbc-workflow-shell q-pa-sm">
      <q-skeleton type="rect" height="40px" />
    </q-card>

    <q-card v-else-if="file" flat bordered class="pbc-workflow-shell q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-x-sm no-wrap">
        <div class="col min-width-0">
          <ProductBasedCostingProgressBar :status="status" />
        </div>

        <div class="col-auto row items-center q-gutter-x-xs no-wrap workflow-trailing">
          <span v-if="!ratesExpanded" class="text-caption text-grey-7 rates-summary">
            {{ ratesSummary }}
          </span>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            :icon="ratesExpanded ? 'ph ph-caret-up' : 'ph ph-sliders-horizontal'"
            :aria-label="$t('product_based_costing.rates')"
            class="square-btn q-px-xs"
            @click="ratesExpanded = !ratesExpanded"
          >
            <q-tooltip>{{ $t('product_based_costing.rates') }}</q-tooltip>
          </q-btn>
          <ProductBasedCostingStaffOverflowMenu @override-status="emit('override-status')" />
        </div>
      </div>

      <div v-if="ratesExpanded" class="q-mt-sm">
        <div class="text-caption text-grey-7 q-mb-xs">
          {{ $t('product_based_costing.offer_bdt_help') }}
        </div>
        <div class="row items-end q-col-gutter-sm">
          <div class="col-12 col-sm-6 col-md-3">
            <q-input
              v-model.number="conversion_rate"
              dense
              outlined
              type="number"
              class="soft-input"
              :readonly="!isEditable"
              :label="$t('product_based_costing.conversion_rate_label')"
            />
          </div>
          <div class="col-12 col-sm-6 col-md-3">
            <q-input
              v-model.number="cargo_rate_kg_gbp"
              dense
              outlined
              type="number"
              class="soft-input"
              :readonly="!isEditable"
              :label="$t('product_based_costing.cargo_rate_label')"
            />
          </div>
          <div class="col-12 col-sm-6 col-md-3">
            <q-input
              v-model.number="profit_rate"
              dense
              outlined
              type="number"
              class="soft-input"
              :readonly="!isEditable"
              :label="$t('product_based_costing.profit_rate_label')"
            />
          </div>
          <div class="col-12 col-sm-6 col-md-3">
            <q-btn
              color="primary"
              unelevated
              no-caps
              dense
              class="full-width square-btn"
              :label="$t('product_based_costing.save_rates')"
              :disable="!isEditable"
              @click="onRateSave"
            />
          </div>
          <div v-if="cargoRateValue <= 0" class="col-12 text-caption text-warning">
            {{ $t('product_based_costing.cargo_zero_inline') }}
          </div>
        </div>
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ProductBasedCostingFile } from '../types';
import { normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';
import { isPbcRatesEditable } from '../utils/pbcFileStatus';
import ProductBasedCostingProgressBar from './ProductBasedCostingProgressBar.vue';
import ProductBasedCostingStaffOverflowMenu from './ProductBasedCostingStaffOverflowMenu.vue';

const props = defineProps<{
  file: ProductBasedCostingFile | null;
  isLoading: boolean;
  status: string;
}>();

const emit = defineEmits<{
  (e: 'override-status'): void;
  (
    e: 'save-rates',
    payload: {
      conversion_rate: number | null;
      cargo_rate_kg_gbp: number | null;
      profit_rate: number | null;
    },
  ): void;
}>();

const { t } = useI18n();

const ratesExpanded = ref(false);
const conversion_rate = ref<number | null>(null);
const cargo_rate_kg_gbp = ref<number | null>(null);
const profit_rate = ref<number | null>(null);

const normalizedStatus = computed(() => normalizePbcFileStatus(props.status));
const isEditable = computed(() => isPbcRatesEditable(normalizedStatus.value));

watch(
  () => props.file,
  (newFile) => {
    if (newFile) {
      cargo_rate_kg_gbp.value = newFile.cargo_rate_kg_gbp ?? 0;
      conversion_rate.value = newFile.conversion_rate ?? 140;
      profit_rate.value = newFile.profit_rate ?? 25;
    }
  },
  { immediate: true },
);

watch(
  () => normalizedStatus.value,
  (st) => {
    ratesExpanded.value = st === 'pending';
  },
  { immediate: true },
);

const conversionRateValue = computed(() => conversion_rate.value ?? 140);
const cargoRateValue = computed(() => cargo_rate_kg_gbp.value ?? 0);
const profitRateValue = computed(() => profit_rate.value ?? 25);

const ratesSummary = computed(() =>
  t('product_based_costing.rates_summary', {
    conversion: conversionRateValue.value,
    cargo: cargoRateValue.value,
    profit: profitRateValue.value,
  }),
);

function onRateSave() {
  emit('save-rates', {
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
  });
  if (normalizedStatus.value !== 'pending') {
    ratesExpanded.value = false;
  }
}
</script>

<style scoped lang="scss">
.pbc-workflow-shell {
  border-radius: 10px;
}

.workflow-trailing {
  flex-shrink: 0;
}

.rates-summary {
  white-space: nowrap;
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.min-width-0 {
  min-width: 0;
}

@media (max-width: 599px) {
  .rates-summary {
    display: none;
  }

  .workflow-trailing {
    flex-wrap: nowrap;
  }
}
</style>
