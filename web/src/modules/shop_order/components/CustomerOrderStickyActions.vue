<template>
  <div class="sticky-footer-bar">
    <div class="row items-center justify-between no-wrap q-gutter-x-sm">
      <div class="column">
        <span class="text-caption text-grey-6">Estimated total</span>
        <span class="text-subtitle1 text-weight-bolder text-primary">
          {{ currencySymbol }}{{ totalAmount.toFixed(2) }}
        </span>
      </div>

      <div class="row items-center q-gutter-x-xs">
        <template v-if="isWaitingOnStaff">
          <span class="text-caption text-amber-9 text-weight-medium q-px-xs text-center wait-copy">
            {{ waitLabel }}
          </span>
        </template>

        <template v-else-if="status === 'priced' && isNegotiable">
          <q-btn
            unelevated
            color="amber-9"
            no-caps
            dense
            class="q-px-md text-caption text-weight-bold action-btn"
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
            dense
            class="q-px-md text-caption text-weight-bold action-btn"
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
            dense
            class="q-px-lg text-subtitle2 text-weight-bold action-btn"
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
            class="text-weight-bold text-caption"
          >
            {{ statusChipLabel }}
          </q-chip>
        </template>

        <template v-else-if="status === 'cancelled'">
          <q-badge color="red-7" class="q-pa-xs">Cancelled</q-badge>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  getCustomerCatalogStatusLabel,
  normalizeCatalogOrderStatus,
} from '../utils/catalogOrderStatus';

const props = defineProps<{
  status: string;
  isNegotiable: boolean;
  totalAmount: number;
  currencySymbol: string;
  canSubmitCounter?: boolean;
  isSubmittingCounter?: boolean;
  isConfirming?: boolean;
}>();

const emit = defineEmits<{
  (e: 'submit-counter'): void;
  (e: 'confirm-order'): void;
}>();

const normalizedStatus = computed(() => normalizeCatalogOrderStatus(props.status));

const isWaitingOnStaff = computed(() =>
  ['submitted', 'costing_pending', 'countered'].includes(normalizedStatus.value),
);

const waitLabel = computed(() => getCustomerCatalogStatusLabel(normalizedStatus.value));

const isConfirmedOrBeyond = computed(() =>
  ['confirmed', 'procuring', 'ordered', 'delivered'].includes(normalizedStatus.value),
);

const statusChipLabel = computed(() => getCustomerCatalogStatusLabel(normalizedStatus.value));
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderStickyActions',
};
</script>

<style scoped>
.sticky-footer-bar {
  position: sticky;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 100;
  background: #fff;
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.08);
  padding: 12px 16px;
}

.wait-copy {
  font-size: 11px;
  max-width: 180px;
  text-align: right;
}

.action-btn {
  border-radius: 8px;
}
</style>
