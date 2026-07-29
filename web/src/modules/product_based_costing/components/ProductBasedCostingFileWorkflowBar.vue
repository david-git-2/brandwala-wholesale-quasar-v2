<template>
  <div>
    <!-- Workflow Strip Skeleton -->
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-grow row items-center q-gutter-xs">
          <q-skeleton v-for="n in 6" :key="n" type="QBtn" width="90px" height="28px" />
        </div>
        <div class="col-auto">
          <q-skeleton type="QBtn" width="80px" height="28px" />
        </div>
      </div>
    </q-card>

    <!-- Loaded Workflow Bar -->
    <q-card v-else-if="file" flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-grow row items-center q-gutter-xs status-workflow-row">
          <template v-for="(st, idx) in workflowStatuses" :key="st">
            <q-btn
              :color="status === st ? getStatusColor(st) : isPassedStatus(status, st) ? 'grey-5' : 'grey-3'"
              :text-color="status === st ? 'white' : isPassedStatus(status, st) ? 'grey-9' : 'grey-7'"
              :outline="status !== st"
              :unelevated="status === st"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
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
              {{ formatStatusLabel(st) }}
            </q-btn>
            <q-icon
              v-if="idx < workflowStatuses.length - 1"
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
            class="q-px-md text-caption text-weight-bold"
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
            Cancelled
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
            :label="ratesExpanded ? 'Hide Rates' : 'Rates'"
            class="q-px-sm rounded-borders"
            @click="ratesExpanded = !ratesExpanded"
          />
        </div>
      </div>

      <div v-if="ratesExpanded" class="row items-end q-col-gutter-sm q-mt-sm">
        <div class="col-12 col-sm-6 col-md-3">
          <q-input
            v-model.number="conversion_rate"
            dense
            outlined
            type="number"
            class="soft-input"
            label="Conversion Rate"
          />
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-input
            v-model.number="cargo_rate_kg_gbp"
            dense
            outlined
            type="number"
            class="soft-input"
            label="Cargo Rate (kg/GBP)"
          />
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-input
            v-model.number="profit_rate"
            dense
            outlined
            type="number"
            class="soft-input"
            label="Profit Rate"
          />
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-btn
            color="primary"
            unelevated
            no-caps
            dense
            class="full-width"
            label="Save Rates"
            @click="onRateSave"
          />
        </div>
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ProductBasedCostingFile } from '../types';
import {
  workflowStatuses,
  formatStatusLabel,
  isPassedStatus,
  getStatusColor,
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

const ratesExpanded = ref(false);
const conversion_rate = ref<number | null>(null);
const cargo_rate_kg_gbp = ref<number | null>(null);
const profit_rate = ref<number | null>(null);

watch(
  () => props.file,
  (newFile) => {
    if (newFile) {
      cargo_rate_kg_gbp.value = newFile.cargo_rate_kg_gbp ?? null;
      conversion_rate.value = newFile.conversion_rate ?? null;
      profit_rate.value = newFile.profit_rate ?? null;
    }
  },
  { immediate: true },
);

const conversionRateValue = computed(() => conversion_rate.value ?? 140);
const cargoRateValue = computed(() => cargo_rate_kg_gbp.value ?? 0);
const profitRateValue = computed(() => profit_rate.value ?? 25);

const ratesSummary = computed(
  () =>
    `Conv ${conversionRateValue.value} · Cargo ${cargoRateValue.value} · Profit ${profitRateValue.value}%`,
);

function onRateSave() {
  emit('save-rates', {
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
  });
  ratesExpanded.value = false;
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
