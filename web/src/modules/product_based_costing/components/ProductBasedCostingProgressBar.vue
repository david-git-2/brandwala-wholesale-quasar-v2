<template>
  <q-card flat bordered class="pbc-progress-bar q-pa-sm">
    <div class="row items-center justify-between q-col-gutter-sm">
      <div class="col-grow">
        <div class="row items-center q-gutter-xs phase-stepper q-mb-xs">
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
              {{ stepLabel(stepKey) }}
            </div>
            <q-icon
              v-if="idx < progressSteps.length - 1"
              name="ph ph-caret-right"
              color="grey-5"
              size="16px"
              class="progress-chevron"
            />
          </template>
          <q-badge
            v-if="isCancelled"
            color="negative"
            text-color="white"
            class="q-ml-sm text-caption"
          >
            {{ $t('product_based_costing.status_cancelled') }}
          </q-badge>
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
import { useI18n } from 'vue-i18n';
import { isFulfillmentStatus, normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';
import {
  getPbcProgressSteps,
  isPbcProgressStepCurrent,
  mapPbcStatusToProgressKey,
  type PbcProgressStepKey,
} from '../utils/pbcFileStatus';

const props = defineProps<{
  status: string;
}>();

const { t } = useI18n();

const normalizedStatus = computed(() => normalizePbcFileStatus(props.status));
const isCancelled = computed(() => normalizedStatus.value === 'cancelled');
const currentProgressKey = computed(() => mapPbcStatusToProgressKey(normalizedStatus.value));
const progressSteps = computed(() => getPbcProgressSteps());
const isQuotePhase = computed(() => !isFulfillmentStatus(normalizedStatus.value));
const isBuyPhase = computed(() => isFulfillmentStatus(normalizedStatus.value));

function stepLabel(stepKey: PbcProgressStepKey): string {
  return t(`product_based_costing.status_${stepKey}`);
}

function isStepCurrent(stepKey: PbcProgressStepKey): boolean {
  return isPbcProgressStepCurrent(stepKey, currentProgressKey.value);
}

function progressStepClass(stepKey: PbcProgressStepKey): string {
  const steps = progressSteps.value;
  if (isCancelled.value) {
    if (steps.indexOf(stepKey) <= steps.indexOf(currentProgressKey.value)) {
      return 'progress-step--done';
    }
    return 'progress-step--upcoming';
  }
  if (isStepCurrent(stepKey)) return 'progress-step--current';
  if (steps.indexOf(stepKey) < steps.indexOf(currentProgressKey.value)) {
    return 'progress-step--done';
  }
  return 'progress-step--upcoming';
}
</script>

<style scoped lang="scss">
.pbc-progress-bar {
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
