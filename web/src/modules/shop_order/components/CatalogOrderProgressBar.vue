<template>
  <q-card flat bordered class="catalog-progress-bar q-pa-sm" :class="cardClass">
    <!-- Mobile customer: compact current-step view -->
    <div v-if="isCompactCustomer" class="column q-gutter-y-xs">
      <div class="row items-center justify-between no-wrap q-gutter-x-sm">
        <div class="column col">
          <span class="text-subtitle2 text-weight-bold text-grey-9">{{ currentStepLabel }}</span>
          <span class="text-caption text-grey-6">Step {{ stepIndex.current }} of {{ stepIndex.total }}</span>
        </div>
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          class="text-caption"
          :label="stepsExpanded ? 'Hide steps' : 'All steps'"
          @click="stepsExpanded = !stepsExpanded"
        />
      </div>
      <q-linear-progress
        :value="stepIndex.current / stepIndex.total"
        rounded
        size="6px"
        color="primary"
        track-color="grey-3"
      />
      <div v-if="stepsExpanded" class="row items-center q-gutter-xs progress-row q-pt-xs">
        <template v-for="(stepKey, idx) in progressSteps" :key="stepKey">
          <div
            class="progress-step q-px-sm q-py-xs text-caption text-weight-bold"
            :class="progressStepClass(stepKey)"
          >
            {{ progressStepLabel(stepKey) }}
          </div>
          <q-icon
            v-if="idx < progressSteps.length - 1"
            name="ph ph-caret-right"
            color="grey-5"
            size="14px"
          />
        </template>
      </div>
    </div>

    <!-- Desktop / staff: full stepper -->
    <div v-else class="row items-center justify-between q-col-gutter-sm">
      <div class="col-grow">
        <div class="row items-center q-gutter-xs progress-row">
          <template v-for="(stepKey, idx) in progressSteps" :key="stepKey">
            <div
              class="progress-step q-px-sm q-py-xs text-caption text-weight-bold"
              :class="progressStepClass(stepKey)"
            >
              <q-icon
                v-if="isStepCurrent(stepKey)"
                name="ph ph-check-circle"
                size="14px"
                class="q-mr-xs"
              />
              {{ progressStepLabel(stepKey) }}
            </div>
            <q-icon
              v-if="idx < progressSteps.length - 1"
              name="ph ph-caret-right"
              color="grey-5"
              size="16px"
              class="progress-chevron"
            />
          </template>
        </div>
      </div>

      <div v-if="$slots.trailing" class="col-auto">
        <slot name="trailing" />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQuasar } from 'quasar';
import type { ShopOrder } from '../types';
import {
  getCatalogProgressCustomerLabel,
  getCatalogProgressStaffLabel,
  getCatalogProgressSteps,
  getCatalogProgressStepIndex,
  isCatalogProgressStepCurrent,
  mapStatusToProgressKey,
  type CatalogProgressKey,
} from '../utils/catalogOrderStatus';

const props = withDefaults(
  defineProps<{
    order: ShopOrder | null;
    variant?: 'staff' | 'customer';
  }>(),
  { variant: 'staff' },
);

const $q = useQuasar();
const stepsExpanded = ref(false);

const isNegotiable = computed(() => !!props.order?.is_negotiable_snapshot);
const progressSteps = computed(() => getCatalogProgressSteps(isNegotiable.value));
const currentProgressKey = computed(() =>
  mapStatusToProgressKey(props.order?.status, isNegotiable.value),
);

const stepIndex = computed(() =>
  getCatalogProgressStepIndex(currentProgressKey.value, isNegotiable.value),
);

const isCompactCustomer = computed(
  () => props.variant === 'customer' && $q.screen.lt.md,
);

const currentStepLabel = computed(() =>
  getCatalogProgressCustomerLabel(currentProgressKey.value),
);

const cardClass = computed(() =>
  props.variant === 'customer' ? 'catalog-progress-bar--customer bg-grey-1' : '',
);

function progressStepLabel(stepKey: CatalogProgressKey): string {
  return props.variant === 'customer'
    ? getCatalogProgressCustomerLabel(stepKey)
    : getCatalogProgressStaffLabel(stepKey);
}

function isStepCurrent(stepKey: CatalogProgressKey): boolean {
  return isCatalogProgressStepCurrent(stepKey, currentProgressKey.value);
}

function progressStepClass(stepKey: CatalogProgressKey): string {
  const steps = progressSteps.value;
  if (isStepCurrent(stepKey)) return 'progress-step--current';
  if (steps.indexOf(stepKey) < steps.indexOf(currentProgressKey.value)) {
    return 'progress-step--done';
  }
  return 'progress-step--upcoming';
}
</script>

<style scoped lang="scss">
.catalog-progress-bar {
  border-radius: 10px;
}

.progress-row {
  flex-wrap: wrap;
  row-gap: 8px;
}

.progress-step {
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #f5f5f5;
  color: rgba(0, 0, 0, 0.55);
}

.progress-step--current {
  background: var(--q-primary);
  color: #fff;
  border-color: var(--q-primary);
}

.progress-step--done {
  background: #eceff1;
  color: rgba(0, 0, 0, 0.75);
}

.progress-step--upcoming {
  background: #fafafa;
  color: rgba(0, 0, 0, 0.45);
}

@media (min-width: 600px) {
  .catalog-progress-bar {
    padding: 8px 10px !important;
  }

  .progress-step {
    padding: 4px 8px;
    font-size: 11px;
    line-height: 1.3;
  }

  .progress-chevron {
    font-size: 14px !important;
  }
}

@media (max-width: 599px) {
  .progress-chevron {
    display: none;
  }
}
</style>
