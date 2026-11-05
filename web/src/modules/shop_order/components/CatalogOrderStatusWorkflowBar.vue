<template>
  <div class="row items-center q-gutter-xs wrap catalog-status-workflow-row">
    <template v-for="(st, idx) in workflowStatuses" :key="st">
      <q-btn
        v-if="isStatusClickable(st)"
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
        <q-tooltip v-if="statusTooltip(st)">{{ statusTooltip(st) }}</q-tooltip>
      </q-btn>
      <span v-else :class="chipClass(st)" class="status-chip-label">
        {{ statusLabel(st) }}
        <q-tooltip v-if="statusTooltip(st)">{{ statusTooltip(st) }}</q-tooltip>
      </span>
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
      {{ statusLabel('cancelled') }}
    </q-btn>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  getCatalogStaffWorkflowStatuses,
  getStaffCatalogStatusLabel,
  getStaffCatalogStatusShortLabel,
  isCatalogStaffWorkflowStatusChipClickable,
  normalizeCatalogOrderStatus,
} from '../utils/catalogOrderStatus';

const props = defineProps<{
  status: string;
  isNegotiable: boolean;
  updating?: boolean;
  targetStatus?: string | null;
}>();

defineEmits<{
  (e: 'update-status', status: string): void;
}>();

const workflowStatuses = computed(() => getCatalogStaffWorkflowStatuses(props.isNegotiable));

const normalizedCurrent = computed(() => normalizeCatalogOrderStatus(props.status));

function statusLabel(st: string): string {
  return getStaffCatalogStatusShortLabel(st);
}

function statusTooltip(st: string): string | undefined {
  const short = getStaffCatalogStatusShortLabel(st);
  const long = getStaffCatalogStatusLabel(st);
  return short !== long ? long : undefined;
}

function chipClass(st: string): string[] {
  const key = st === 'cancelled' ? 'cancelled' : normalizeCatalogOrderStatus(st);
  const current = normalizedCurrent.value;
  const state =
    current === key ? 'active' : isPassedStatus(current, key) ? 'passed' : 'todo';
  return ['q-px-sm', 'text-caption', 'status-chip-btn', `catalog-chip--${key}`, `status-chip-btn--${state}`];
}

function isPassedStatus(current: string, st: string): boolean {
  const steps = workflowStatuses.value;
  const currentIdx = steps.indexOf(current);
  const targetIdx = steps.indexOf(st);
  if (currentIdx < 0 || targetIdx < 0) return false;
  return targetIdx < currentIdx;
}

function isStatusClickable(st: string): boolean {
  return isCatalogStaffWorkflowStatusChipClickable(st);
}

function isStatusDisabled(st: string): boolean {
  if (props.updating && props.targetStatus !== st) return true;
  if (normalizedCurrent.value === 'cancelled' && st !== 'cancelled') return true;
  return false;
}
</script>

<style scoped lang="scss">
.catalog-status-workflow-row {
  row-gap: 2px;
  min-width: 0;
}

.status-chip-label {
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  cursor: default;
  user-select: none;
}

.status-chip-btn {
  min-height: 24px;
  padding-top: 0;
  padding-bottom: 0;
  border-radius: 6px;
  font-weight: 500;
  --catalog-c: var(--tf-neutral-muted);
  color: var(--tf-neutral-muted);
  border: 1px solid var(--tf-neutral-border);
}

.catalog-chip--submitted { --catalog-c: var(--tf-pbc-pending); }
.catalog-chip--priced { --catalog-c: var(--tf-pbc-offered); }
.catalog-chip--countered { --catalog-c: var(--tf-pbc-offered); }
.catalog-chip--final_offered { --catalog-c: var(--tf-pbc-offered); }
.catalog-chip--confirmed { --catalog-c: var(--tf-pbc-confirmed); }
.catalog-chip--procuring { --catalog-c: var(--tf-pbc-procuring); }
.catalog-chip--dispatch { --catalog-c: var(--tf-pbc-packed); }
.catalog-chip--delivered { --catalog-c: var(--tf-pbc-delivered); }
.catalog-chip--closed { --catalog-c: var(--tf-grey-7, #616161); }
.catalog-chip--cancelled { --catalog-c: var(--tf-pbc-cancelled); }

.status-chip-btn--passed {
  color: var(--catalog-c);
  background: color-mix(in srgb, var(--catalog-c) 14%, var(--tf-neutral-surface));
  border-color: color-mix(in srgb, var(--catalog-c) 40%, var(--tf-neutral-surface));
}

.status-chip-btn--active {
  color: var(--tf-neutral-surface);
  background: var(--catalog-c);
  border-color: var(--catalog-c);
}

.status-workflow-chevron {
  flex-shrink: 0;
}

.status-workflow-sep {
  height: 20px;
  align-self: center;
}
</style>
