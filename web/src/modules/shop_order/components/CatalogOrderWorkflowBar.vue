<template>
  <div>
    <!-- Skeleton -->
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
    <q-card v-else-if="order" flat bordered class="q-pa-sm">
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
              @click="$emit('change-status', st)"
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
            @click="$emit('change-status', 'cancelled')"
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
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder } from '../types';

const props = defineProps<{
  order: ShopOrder | null;
  isLoading?: boolean;
  updatingStatus?: boolean;
  targetUpdatingStatus?: string | null;
}>();

defineEmits<{
  (e: 'change-status', status: string): void;
}>();

const ratesExpanded = defineModel<boolean>('ratesExpanded', { default: false });

const workflowStatuses = [
  'submitted',
  'costing_pending',
  'priced',
  'countered',
  'final_offered',
  'confirmed',
  'ordered',
  'delivered',
];

const status = computed(() => props.order?.status || 'submitted');

function isPassedStatus(current: string, st: string): boolean {
  const currentIdx = workflowStatuses.indexOf(current);
  const targetIdx = workflowStatuses.indexOf(st);
  return currentIdx > targetIdx && currentIdx !== -1 && targetIdx !== -1;
}

function getStatusColor(st: string): string {
  switch (st) {
    case 'submitted':
      return 'info';
    case 'costing_pending':
      return 'warning';
    case 'priced':
      return 'secondary';
    case 'countered':
      return 'deep-orange';
    case 'final_offered':
      return 'purple';
    case 'confirmed':
      return 'primary';
    case 'procuring':
      return 'indigo';
    case 'ordered':
      return 'teal';
    case 'delivered':
      return 'positive';
    case 'cancelled':
      return 'negative';
    default:
      return 'grey';
  }
}

function formatStatusLabel(st: string): string {
  return st
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

const ratesSummary = computed(() => {
  const o = props.order;
  if (!o) return 'No rates';
  const conv = o.conversion_rate ?? 0;
  const cargo = o.cargo_rate ?? 0;
  const profit = o.profit_rate ?? 0;
  const basis = o.profit_basis === 'total_cost' ? 'Total Cost' : 'Purchase';
  return `Conv ${conv} · Cargo ${cargo} · Profit ${profit}% (${basis})`;
});
</script>

<style scoped lang="scss">
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
