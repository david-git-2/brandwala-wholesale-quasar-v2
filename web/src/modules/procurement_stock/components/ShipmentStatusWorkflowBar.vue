<template>
  <div class="row items-center q-gutter-xs status-workflow-row wrap">
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
        class="q-px-sm text-caption text-weight-medium"
        :loading="updating && targetStatus === st"
        :disable="isStatusDisabled(st)"
        @click="$emit('update-status', st)"
      >
        <q-icon v-if="status === st" name="ph ph-check-circle" size="12px" class="q-mr-xs" />
        <q-icon
          v-else-if="st === 'received' && lockReceived"
          name="ph ph-lock-key"
          size="12px"
          class="q-mr-xs"
        />
        {{ formatStatusLabel(st) }}
        <q-tooltip v-if="st === 'received' && lockReceived">
          Configure splits for all items while In transit first
        </q-tooltip>
      </q-btn>
      <q-icon
        v-if="idx < workflowStatuses.length - 1"
        name="ph ph-caret-right"
        color="grey-5"
        size="14px"
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
      class="q-px-sm text-caption text-weight-medium"
      :loading="updating && targetStatus === 'cancelled'"
      :disable="isStatusDisabled('cancelled')"
      @click="$emit('update-status', 'cancelled')"
    >
      <q-icon
        v-if="status === 'cancelled'"
        name="ph ph-x-circle"
        size="12px"
        class="q-mr-xs"
      />
      Cancelled
    </q-btn>
  </div>
</template>

<script setup lang="ts">
/** Solid lifecycle — doc/procurement_stock/shipment/schema.md */
const workflowStatuses = ['draft', 'in_transit', 'received'] as const;

const props = defineProps<{
  status: string;
  updating?: boolean;
  targetStatus?: string | null;
  lockReceived?: boolean;
}>();

defineEmits<{
  (e: 'update-status', status: string): void;
}>();

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
.status-workflow-row {
  row-gap: 4px;
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 20px;
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }
}
</style>
