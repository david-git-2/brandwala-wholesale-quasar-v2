<template>
  <q-card flat bordered class="catalog-progress-bar q-pa-sm" :class="cardClass">
    <div class="row items-center justify-between q-col-gutter-sm">
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
import { computed } from 'vue';
import type { ShopOrder } from '../types';
import {
  getCatalogProgressCustomerLabel,
  getCatalogProgressStaffLabel,
  getCatalogProgressSteps,
  isCatalogProgressStepComplete,
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

const isNegotiable = computed(() => !!props.order?.is_negotiable_snapshot);
const progressSteps = computed(() => getCatalogProgressSteps(isNegotiable.value));
const currentProgressKey = computed(() =>
  mapStatusToProgressKey(props.order?.status, isNegotiable.value),
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

@media (max-width: 599px) {
  .progress-chevron {
    display: none;
  }
}
</style>
