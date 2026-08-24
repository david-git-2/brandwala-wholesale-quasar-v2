<template>
  <div class="order-action-bar">
    <q-card flat bordered class="order-action-bar__card">
      <q-card-section class="order-action-bar__inner q-pa-md">
        <div v-if="showItemProgress" class="order-action-bar__meta column q-gutter-y-xs">
          <div class="row items-center justify-between">
            <span class="text-subtitle2 text-weight-bold text-grey-9">Your response</span>
            <q-badge
              :color="allDecided ? 'green-7' : 'amber-9'"
              class="text-caption text-weight-bold q-px-sm"
            >
              {{ decidedCount }} / {{ totalItems }} decided
            </q-badge>
          </div>
          <q-linear-progress
            :value="decidedRatio"
            rounded
            size="8px"
            :color="allDecided ? 'positive' : 'amber-9'"
            track-color="grey-3"
          />
          <span v-if="!allDecided" class="text-caption text-grey-7 lt-sm">
            Accept or counter each item, then send your response.
          </span>
          <span v-else class="text-caption text-positive text-weight-medium lt-sm">
            All items decided — ready to send.
          </span>
        </div>

        <div v-else-if="showTotal" class="order-action-bar__meta row items-center justify-between">
          <div class="column">
            <span class="text-caption text-grey-6">Estimated total</span>
            <span class="text-subtitle1 text-weight-bolder text-primary">
              {{ currencySymbol }}{{ totalAmount.toFixed(2) }}
            </span>
          </div>
        </div>

        <div v-else-if="isWaitingOnStaff" class="order-action-bar__meta text-center">
          <span class="text-caption text-amber-9 text-weight-medium">{{ waitLabel }}</span>
        </div>

        <div class="order-action-bar__cta">
          <template v-if="status === 'priced' && isNegotiable">
            <q-btn
              unelevated
              color="amber-9"
              no-caps
              class="action-btn full-width text-weight-bold"
              label="Send my response"
              :disable="!canSubmitCounter"
              :loading="isSubmittingCounter"
              @click="emit('submit-counter')"
            >
              <q-tooltip v-if="!canSubmitCounter">
                Accept or counter all items before sending your response
              </q-tooltip>
            </q-btn>
          </template>

          <template v-else-if="status === 'priced' && !isNegotiable">
            <q-btn
              unelevated
              color="primary"
              no-caps
              class="action-btn full-width text-weight-bold"
              label="Confirm order"
              :loading="isConfirming"
              @click="emit('confirm-order')"
            />
          </template>

          <template v-else-if="status === 'final_offered'">
            <q-btn
              unelevated
              color="positive"
              no-caps
              class="action-btn full-width text-weight-bold"
              label="Confirm order"
              :loading="isConfirming"
              @click="emit('confirm-order')"
            />
          </template>

          <template v-else-if="isConfirmedOrBeyond">
            <q-chip
              dense
              color="green-1"
              text-color="green-9"
              icon="ph ph-check-circle"
              class="text-weight-bold text-caption full-width justify-center"
            >
              {{ statusChipLabel }}
            </q-chip>
          </template>

          <template v-else-if="status === 'cancelled'">
            <q-badge color="red-7" class="q-pa-sm full-width text-center">Cancelled</q-badge>
          </template>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  getCustomerCatalogStatusLabel,
  normalizeCatalogOrderStatus,
} from '../utils/catalogOrderStatus';

const props = withDefaults(
  defineProps<{
    status: string;
    isNegotiable: boolean;
    totalAmount: number;
    currencySymbol: string;
    decidedCount?: number;
    totalItems?: number;
    negotiateRound?: number | null;
    canSubmitCounter?: boolean;
    isSubmittingCounter?: boolean;
    isConfirming?: boolean;
  }>(),
  {
    decidedCount: 0,
    totalItems: 0,
    negotiateRound: null,
  },
);

const emit = defineEmits<{
  (e: 'submit-counter'): void;
  (e: 'confirm-order'): void;
}>();

const normalizedStatus = computed(() => normalizeCatalogOrderStatus(props.status));

const showItemProgress = computed(
  () => props.isNegotiable && props.status === 'priced' && props.totalItems > 0,
);

const allDecided = computed(
  () => props.totalItems > 0 && props.decidedCount >= props.totalItems,
);

const decidedRatio = computed(() =>
  props.totalItems > 0 ? props.decidedCount / props.totalItems : 0,
);

const showTotal = computed(() => {
  if (props.status === 'priced' && props.isNegotiable) return false;
  if (isWaitingOnStaff.value) return false;
  if (isConfirmedOrBeyond.value) return false;
  if (props.status === 'cancelled') return false;
  return props.totalAmount > 0;
});

const isWaitingOnStaff = computed(() =>
  ['submitted', 'costing_pending', 'countered'].includes(normalizedStatus.value),
);

const waitLabel = computed(() => getCustomerCatalogStatusLabel(normalizedStatus.value));

const isConfirmedOrBeyond = computed(() =>
  ['confirmed', 'procuring', 'ready_for_shipment', 'delivered'].includes(normalizedStatus.value),
);

const statusChipLabel = computed(() => getCustomerCatalogStatusLabel(normalizedStatus.value));
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderStickyActions',
};
</script>

<style scoped>
.order-action-bar {
  width: 100%;
}

.order-action-bar__card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #fff);
}

.order-action-bar__inner {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.order-action-bar__meta {
  width: 100%;
}

.order-action-bar__cta {
  width: 100%;
}

.action-btn {
  border-radius: 8px;
  min-height: 48px;
}

@media (min-width: 600px) {
  .order-action-bar__inner {
    flex-direction: row;
    align-items: center;
    gap: 16px;
    padding: 12px 16px !important;
  }

  .order-action-bar__meta {
    flex: 1 1 auto;
    min-width: 0;
  }

  .order-action-bar__cta {
    flex: 0 0 auto;
    width: auto;
  }

  .order-action-bar__meta :deep(.text-subtitle2) {
    font-size: 0.95rem;
  }

  .order-action-bar__meta :deep(.q-linear-progress) {
    max-width: 280px;
  }

  .action-btn {
    min-height: 40px;
    min-width: 180px;
    width: auto;
  }

  .action-btn.full-width {
    width: auto;
  }
}
</style>
