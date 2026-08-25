<template>
  <div class="pbc-progress-bar">
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
          size="14px"
          class="progress-chevron"
        />
      </template>
      <q-badge
        v-if="isCancelled"
        color="negative"
        text-color="white"
        class="q-ml-xs text-caption"
      >
        {{ $t('product_based_costing.status_cancelled') }}
      </q-badge>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';
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
.progress-row {
  flex-wrap: wrap;
  row-gap: 4px;
}

.progress-step {
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #f5f5f5;
  color: rgba(0, 0, 0, 0.55);
  padding: 2px 8px;
  font-size: 11px;
  line-height: 1.3;
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
