<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-grow row items-center q-gutter-xs">
          <q-skeleton v-for="n in 2" :key="n" type="QBtn" width="90px" height="28px" />
        </div>
        <div class="col-auto">
          <q-skeleton type="QBtn" width="80px" height="28px" />
        </div>
      </div>
    </q-card>

    <q-card v-else-if="file" flat bordered class="q-pa-xs q-px-sm pbc-workflow-bar">
      <div class="row items-center q-gutter-xs q-mb-xs phase-stepper">
        <div
          class="text-caption"
          :class="isQuotePhase ? 'text-weight-bold text-primary' : 'text-grey-6'"
        >
          {{ $t('product_based_costing.phase_quote') }}
        </div>
        <q-icon name="ph ph-caret-right" color="grey-5" size="16px" />
        <div>
          <div
            class="text-caption"
            :class="isBuyPhase ? 'text-weight-bold text-primary' : 'text-grey-6'"
          >
            {{ $t('product_based_costing.phase_buy_ship') }}
          </div>
          <div v-if="isQuotePhase" class="text-caption text-grey-6">
            {{ $t('product_based_costing.phase_buy_next') }}
          </div>
        </div>
      </div>

      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-grow row items-center q-gutter-xs status-workflow-row">
          <template v-for="(st, idx) in visibleWorkflowStatuses" :key="st">
            <q-btn
              :color="status === st ? getStatusColor(st) : isPassedStatus(status, st) ? 'grey-5' : 'grey-3'"
              :text-color="status === st ? 'white' : isPassedStatus(status, st) ? 'grey-9' : 'grey-7'"
              :outline="status !== st"
              :unelevated="status === st"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold square-btn"
              :loading="updatingStatus && targetUpdatingStatus === st"
              :disable="updatingStatus && targetUpdatingStatus !== st"
              @click="$emit('update-status', st)"
            >
              <q-icon
                v-if="status === st"
                name="ph ph-check-circle"
                size="14px"
                class="q-mr-xs"
              />
              {{ statusLabel(st) }}
              <q-tooltip
                v-if="statusHint(st).when"
                class="pbc-status-tooltip"
                max-width="280px"
                anchor="top middle"
                self="bottom middle"
                :offset="[0, 8]"
              >
                <div class="pbc-status-tooltip__k">{{ $t('product_based_costing.tooltip_use_when') }}</div>
                <div class="pbc-status-tooltip__v">{{ statusHint(st)?.when }}</div>
                <div class="pbc-status-tooltip__k pbc-status-tooltip__k--next">
                  {{ $t('product_based_costing.tooltip_this_will') }}
                </div>
                <div class="pbc-status-tooltip__v">{{ statusHint(st)?.does }}</div>
              </q-tooltip>
            </q-btn>
            <q-icon
              v-if="idx < visibleWorkflowStatuses.length - 1"
              name="ph ph-caret-right"
              color="grey-5"
              size="18px"
              class="status-workflow-chevron"
            />
          </template>
          <q-separator vertical class="q-mx-sm status-workflow-sep" />
          <q-btn
            :color="status === 'cancelled' ? 'negative' : 'grey-3'"
            :text-color="status === 'cancelled' ? 'white' : 'grey-7'"
            :outline="status !== 'cancelled'"
            :unelevated="status === 'cancelled'"
            dense
            no-caps
            class="q-px-md text-caption text-weight-bold square-btn"
            :loading="updatingStatus && targetUpdatingStatus === 'cancelled'"
            :disable="updatingStatus && targetUpdatingStatus !== 'cancelled'"
            @click="$emit('update-status', 'cancelled')"
          >
            <q-icon
              v-if="status === 'cancelled'"
              name="ph ph-x-circle"
              size="14px"
              class="q-mr-xs"
            />
            {{ $t('product_based_costing.status_cancelled') }}
            <q-tooltip
              class="pbc-status-tooltip"
              max-width="280px"
              anchor="top middle"
              self="bottom middle"
              :offset="[0, 8]"
            >
              <div class="pbc-status-tooltip__k">{{ $t('product_based_costing.tooltip_use_when') }}</div>
              <div class="pbc-status-tooltip__v">{{ statusHint('cancelled')?.when }}</div>
              <div class="pbc-status-tooltip__k pbc-status-tooltip__k--next">
                {{ $t('product_based_costing.tooltip_this_will') }}
              </div>
              <div class="pbc-status-tooltip__v">{{ statusHint('cancelled')?.does }}</div>
            </q-tooltip>
          </q-btn>
          <q-btn
            v-if="status === 'offered'"
            unelevated
            dense
            no-caps
            color="primary"
            class="q-px-md text-caption text-weight-bold square-btn"
            :loading="updatingStatus && targetUpdatingStatus === 'confirmed'"
            :disable="updatingStatus"
            :label="$t('product_based_costing.confirm_order')"
            @click="$emit('update-status', 'confirmed')"
          >
            <q-tooltip
              class="pbc-status-tooltip"
              max-width="280px"
              anchor="top middle"
              self="bottom middle"
              :offset="[0, 8]"
            >
              <div class="pbc-status-tooltip__k">{{ $t('product_based_costing.tooltip_use_when') }}</div>
              <div class="pbc-status-tooltip__v">{{ statusHint('confirmed')?.when }}</div>
              <div class="pbc-status-tooltip__k pbc-status-tooltip__k--next">
                {{ $t('product_based_costing.tooltip_this_will') }}
              </div>
              <div class="pbc-status-tooltip__v">{{ statusHint('confirmed')?.does }}</div>
            </q-tooltip>
          </q-btn>
        </div>

        <div class="col-auto row items-center q-gutter-sm">
          <div v-if="!ratesExpanded" class="text-caption text-grey-7 rates-summary">
            {{ ratesSummary }}
          </div>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            :icon="ratesExpanded ? 'ph ph-caret-up' : 'ph ph-sliders-horizontal'"
            :label="
              ratesExpanded
                ? $t('product_based_costing.hide_rates')
                : $t('product_based_costing.rates')
            "
            class="q-px-sm square-btn"
            @click="ratesExpanded = !ratesExpanded"
          />
        </div>
      </div>

      <div class="text-caption text-grey-7 q-mt-xs">
        {{ $t('product_based_costing.offer_bdt_help') }}
      </div>

      <div v-if="ratesExpanded" class="row items-end q-col-gutter-sm q-mt-xs">
        <div class="col-12 col-sm-6 col-md-3">
          <q-input
            v-model.number="conversion_rate"
            dense
            outlined
            type="number"
            class="soft-input"
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
            @click="onRateSave"
          />
        </div>
        <div v-if="cargoRateValue <= 0" class="col-12 text-caption text-warning">
          {{ $t('product_based_costing.cargo_zero_inline') }}
        </div>
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ProductBasedCostingFile } from '../types';
import {
  quoteStatuses,
  workflowStatuses,
  isPassedStatus,
  getStatusColor,
  isFulfillmentStatus,
} from '../composables/useProductBasedCostingFileDetailsState';

const props = defineProps<{
  file: ProductBasedCostingFile | null;
  isLoading: boolean;
  status: string;
  updatingStatus: boolean;
  targetUpdatingStatus: string | null;
}>();

const emit = defineEmits<{
  (e: 'update-status', status: string): void;
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
  () => props.status,
  (st) => {
    if (st === 'pending') ratesExpanded.value = true;
  },
  { immediate: true },
);

const conversionRateValue = computed(() => conversion_rate.value ?? 140);
const cargoRateValue = computed(() => cargo_rate_kg_gbp.value ?? 0);
const profitRateValue = computed(() => profit_rate.value ?? 25);

const ratesSummary = computed(
  () =>
    t('product_based_costing.rates_summary', {
      conversion: conversionRateValue.value,
      cargo: cargoRateValue.value,
      profit: profitRateValue.value,
    }),
);

const isBuyPhase = computed(() => isFulfillmentStatus(props.status));
const isQuotePhase = computed(() => !isBuyPhase.value);

const visibleWorkflowStatuses = computed(() =>
  isBuyPhase.value ? [...workflowStatuses] : [...quoteStatuses],
);

const statusLabel = (status: string) => {
  const key = `product_based_costing.status_${status}`;
  return t(key);
};

const statusHint = (status: string) => {
  const base = `product_based_costing.status_hint_${status}`;
  return {
    when: t(`${base}_when`),
    does: t(`${base}_does`),
  };
};

function onRateSave() {
  emit('save-rates', {
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
  });
  if (props.status !== 'pending') {
    ratesExpanded.value = false;
  }
}
</script>

<style scoped lang="scss">
.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.status-workflow-row {
  flex-wrap: wrap;
  row-gap: 8px;
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 24px;
}

.rates-summary {
  white-space: nowrap;
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }

  .rates-summary {
    white-space: normal;
  }
}
</style>

<style>
.pbc-status-tooltip.q-tooltip {
  background: #fff !important;
  color: #334155 !important;
  font-size: 13px;
  line-height: 1.4;
  white-space: normal;
  max-width: 280px;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.14);
}

.pbc-status-tooltip__k {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #64748b;
}

.pbc-status-tooltip__k--next {
  margin-top: 8px;
}

.pbc-status-tooltip__v {
  white-space: normal;
  overflow-wrap: anywhere;
}
</style>
