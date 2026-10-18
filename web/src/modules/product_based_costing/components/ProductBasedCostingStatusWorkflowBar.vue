<template>
  <div class="row items-center q-gutter-xs wrap pbc-status-workflow-row">
    <template v-for="(st, idx) in workflowStatuses" :key="st">
      <q-btn
        flat
        dense
        no-caps
        size="sm"
        :class="chipClass(st)"
        :loading="updating && targetStatus === st"
        :disable="isStatusDisabled(st)"
        @click="$emit('update-status', st)"
      >
        {{ statusLabel(st) }}
      </q-btn>
      <q-icon
        v-if="idx < workflowStatuses.length - 1"
        name="ph ph-caret-right"
        color="grey-5"
        size="12px"
        class="status-workflow-chevron"
      />
    </template>

    <q-separator vertical inset class="q-mx-xs status-workflow-sep" />

    <q-btn
      flat
      dense
      no-caps
      size="sm"
      :class="chipClass('cancelled')"
      :loading="updating && targetStatus === 'cancelled'"
      :disable="isStatusDisabled('cancelled')"
      @click="$emit('update-status', 'cancelled')"
    >
      {{ $t('product_based_costing.status_cancelled') }}
    </q-btn>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { normalizePbcFileStatus, workflowStatuses } from '../composables/useProductBasedCostingFileDetailsState';

const props = defineProps<{
  status: string;
  updating?: boolean;
  targetStatus?: string | null;
}>();

defineEmits<{
  (e: 'update-status', status: string): void;
}>();

const { t } = useI18n();

function statusLabel(st: string): string {
  const key = normalizePbcFileStatus(st);
  return t(`product_based_costing.status_${key}`);
}

function chipClass(st: string): string[] {
  const state = normalizePbcFileStatus(props.status) === st ? 'active' : isPassedStatus(props.status, st) ? 'passed' : 'todo';
  return ['q-px-sm', 'text-caption', 'status-chip-btn', `pbc-chip--${st}`, `status-chip-btn--${state}`];
}

function isPassedStatus(currentStatus: string, st: string): boolean {
  const current = normalizePbcFileStatus(currentStatus);
  const currentIdx = workflowStatuses.indexOf(current as (typeof workflowStatuses)[number]);
  const targetIdx = workflowStatuses.indexOf(st as (typeof workflowStatuses)[number]);
  if (currentIdx < 0 || targetIdx < 0) return false;
  return targetIdx < currentIdx;
}

function isStatusDisabled(st: string): boolean {
  if (props.updating && props.targetStatus !== st) return true;
  if (normalizePbcFileStatus(props.status) === 'cancelled' && st !== 'cancelled') return true;
  return false;
}
</script>

<style scoped lang="scss">
.pbc-status-workflow-row {
  row-gap: 2px;
  min-width: 0;
}

.status-chip-btn {
  min-height: 24px;
  padding-top: 0;
  padding-bottom: 0;
  border-radius: 6px;
  font-weight: 500;
}

.status-chip-btn {
  --pbc-c: var(--tf-neutral-muted);
  color: var(--tf-neutral-muted);
  border: 1px solid var(--tf-neutral-border);
}
.pbc-chip--pending { --pbc-c: var(--tf-pbc-pending); }
.pbc-chip--offered { --pbc-c: var(--tf-pbc-offered); }
.pbc-chip--confirmed { --pbc-c: var(--tf-pbc-confirmed); }
.pbc-chip--procuring { --pbc-c: var(--tf-pbc-procuring); }
.pbc-chip--packed { --pbc-c: var(--tf-pbc-packed); }
.pbc-chip--delivered { --pbc-c: var(--tf-pbc-delivered); }
.pbc-chip--cancelled { --pbc-c: var(--tf-pbc-cancelled); }
.status-chip-btn--passed {
  color: var(--pbc-c);
  background: color-mix(in srgb, var(--pbc-c) 14%, var(--tf-neutral-surface));
  border-color: color-mix(in srgb, var(--pbc-c) 40%, var(--tf-neutral-surface));
}
.status-chip-btn--active {
  color: var(--tf-neutral-surface);
  background: var(--pbc-c);
  border-color: var(--pbc-c);
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 14px;
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }
}
</style>
