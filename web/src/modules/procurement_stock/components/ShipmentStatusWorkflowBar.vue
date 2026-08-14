<template>
  <q-card flat bordered class="q-px-sm q-py-xs shipment-status-toolbar">
    <div class="row items-center justify-between q-gutter-xs wrap status-workflow-row">
      <!-- Solid lifecycle — never progress labels -->
      <div class="col-grow row items-center q-gutter-xs wrap">
        <template v-for="(st, idx) in workflowStatuses" :key="st">
          <q-btn
            :color="
              status === st ? statusColor(st) : isPassedStatus(status, st) ? 'grey-5' : 'grey-3'
            "
            :text-color="status === st ? 'white' : isPassedStatus(status, st) ? 'grey-9' : 'grey-7'"
            :outline="status !== st"
            :unelevated="status === st"
            dense
            no-caps
            size="sm"
            class="q-px-sm text-caption status-chip-btn"
            :loading="updating && targetStatus === st"
            :disable="isStatusDisabled(st)"
            @click="$emit('update-status', st)"
          >
            <q-icon
              v-if="st === 'received' && lockReceived && status !== st"
              name="ph ph-lock-key"
              size="11px"
              class="q-mr-xs"
            />
            {{ formatStatusLabel(st) }}
            <q-tooltip v-if="st === 'received' && lockReceived">
              Split every item first
            </q-tooltip>
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
          :color="status === 'cancelled' ? 'negative' : 'grey-3'"
          :text-color="status === 'cancelled' ? 'white' : 'grey-7'"
          :outline="status !== 'cancelled'"
          :unelevated="status === 'cancelled'"
          dense
          no-caps
          size="sm"
          class="q-px-sm text-caption status-chip-btn"
          :loading="updating && targetStatus === 'cancelled'"
          :disable="isStatusDisabled('cancelled')"
          @click="$emit('update-status', 'cancelled')"
        >
          Cancelled
        </q-btn>
      </div>

      <!-- Progress — compact select -->
      <div
        v-if="progressOptions.length"
        class="col-auto row items-center q-gutter-xs progress-select-wrap"
      >
        <span class="text-caption text-grey-7">Progress</span>
        <q-select
          :model-value="progressTagId"
          :options="progressSelectOptions"
          dense
          outlined
          emit-value
          map-options
          clearable
          options-dense
          hide-bottom-space
          class="progress-select soft-input"
          placeholder="Set progress"
          :loading="!!progressUpdating"
          :disable="!!progressUpdating"
          @update:model-value="onProgressSelect"
        />
      </div>
    </div>

    <!-- Next-step row (page owns chips + CTA via slot) -->
    <div v-if="showNext" class="next-step-row">
      <slot name="next" />
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShipmentProgressTag } from '../repositories/globalShipmentRepository';

/** Solid lifecycle — doc/procurement_stock/shipment/schema.md */
const workflowStatuses = ['draft', 'in_transit', 'received'] as const;

const props = withDefaults(
  defineProps<{
    status: string;
    updating?: boolean;
    targetStatus?: string | null;
    lockReceived?: boolean;
    progressOptions?: ShipmentProgressTag[];
    progressTagId?: number | null;
    progressUpdating?: boolean;
    progressTargetId?: number | null;
    showNext?: boolean;
  }>(),
  {
    progressOptions: () => [],
    progressTagId: null,
    progressUpdating: false,
    progressTargetId: null,
    showNext: false,
  },
);

const emit = defineEmits<{
  (e: 'update-status', status: string): void;
  (e: 'update-progress', tagId: number | null): void;
}>();

const progressSelectOptions = computed(() =>
  props.progressOptions.map((tag) => ({
    label: tag.name,
    value: tag.id,
  })),
);

function onProgressSelect(value: number | null | undefined) {
  emit('update-progress', value ?? null);
}

function formatStatusLabel(value: string): string {
  switch (value) {
    case 'draft':
      return 'Draft';
    case 'in_transit':
      return 'In transit';
    case 'received':
      return 'Received';
    case 'cancelled':
      return 'Cancelled';
    default:
      return value;
  }
}

function isPassedStatus(currentStatus: string, st: string): boolean {
  const currentIdx = workflowStatuses.indexOf(
    currentStatus as (typeof workflowStatuses)[number],
  );
  const targetIdx = workflowStatuses.indexOf(st as (typeof workflowStatuses)[number]);
  if (currentIdx < 0 || targetIdx < 0) return false;
  return targetIdx < currentIdx;
}

function statusColor(st: string): string {
  switch (st) {
    case 'draft':
      return 'grey-7';
    case 'in_transit':
      return 'orange-8';
    case 'received':
      return 'green-7';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
}

function isStatusDisabled(st: string): boolean {
  if (props.updating && props.targetStatus !== st) return true;
  if (props.status === 'received' && st !== 'received') return true;
  if (props.status === 'cancelled' && st !== 'cancelled') return true;
  if (st === 'received' && props.lockReceived) return true;
  return false;
}
</script>

<style scoped lang="scss">
.shipment-status-toolbar {
  border-radius: 8px;
}

.status-workflow-row {
  row-gap: 2px;
}

.status-chip-btn {
  min-height: 26px;
  padding-top: 0;
  padding-bottom: 0;
  border-radius: 6px;
  font-weight: 500;
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 16px;
}

.progress-select {
  min-width: 140px;
  max-width: 180px;
}

.progress-select :deep(.q-field__control) {
  min-height: 28px;
  height: 28px;
}

.progress-select :deep(.q-field__native),
.progress-select :deep(.q-field__prefix),
.progress-select :deep(.q-field__suffix),
.progress-select :deep(.q-field__input) {
  min-height: 28px;
  padding-top: 0;
  padding-bottom: 0;
}

.progress-select :deep(.q-field__marginal) {
  height: 28px;
}

.next-step-row {
  margin-top: 4px;
  padding-top: 4px;
  border-top: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }

  .progress-select-wrap {
    width: 100%;
  }

  .progress-select {
    flex: 1 1 auto;
    max-width: none;
  }
}
</style>
