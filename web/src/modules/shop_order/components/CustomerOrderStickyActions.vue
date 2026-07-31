<template>
  <div class="sticky-footer-bar bg-white border-top q-pa-sm">
    <div class="row items-center justify-between no-wrap q-gutter-x-sm">
      <!-- Total Summary snippet -->
      <div class="column">
        <span class="text-caption text-grey-6">Estimated Total</span>
        <span class="text-subtitle1 text-weight-bolder text-primary">
          {{ currencySymbol }}{{ totalAmount.toFixed(2) }}
        </span>
      </div>

      <!-- Action Buttons Gated by Status -->
      <div class="row items-center q-gutter-x-xs">
        <!-- Status: submitted / costing_pending -->
        <template v-if="status === 'submitted' || status === 'costing_pending'">
          <span class="text-caption text-amber-9 text-weight-medium q-px-xs text-center" style="font-size: 11px;">
            Awaiting Staff Costing
          </span>
        </template>

        <!-- Status: priced (Path A: Negotiable) -->
        <template v-else-if="status === 'priced' && isNegotiable">
          <q-btn
            unelevated
            color="amber-9"
            no-caps
            dense
            class="q-px-md text-caption text-weight-bold"
            label="Submit Counter"
            :disable="!canSubmitCounter"
            :loading="isSubmittingCounter"
            @click="emit('submit-counter')"
          >
            <q-tooltip v-if="!canSubmitCounter">
              Accept or counter all items to submit counter offer
            </q-tooltip>
          </q-btn>
        </template>

        <!-- Status: priced (Path B: Non-negotiable) -->
        <template v-else-if="status === 'priced' && !isNegotiable">
          <span class="text-caption text-grey-7 q-mr-xs">Offer Priced</span>
          <q-btn
            unelevated
            color="primary"
            no-caps
            dense
            class="q-px-md text-caption text-weight-bold"
            label="Confirm Order"
            :loading="isConfirming"
            @click="emit('confirm-order')"
          />
        </template>

        <!-- Status: countered -->
        <template v-else-if="status === 'countered'">
          <span class="text-caption text-amber-9 text-weight-medium q-px-xs text-center" style="font-size: 11px;">
            Counter Submitted • Awaiting Staff Final Offer
          </span>
        </template>

        <!-- Status: final_offered -->
        <template v-else-if="status === 'final_offered'">
          <q-btn
            unelevated
            color="positive"
            no-caps
            class="full-width q-px-lg text-subtitle2 text-weight-bold"
            label="Confirm Final Order"
            :loading="isConfirming"
            @click="emit('confirm-order')"
          />
        </template>

        <!-- Status: confirmed and beyond -->
        <template v-else-if="isConfirmedOrBeyond">
          <q-chip
            dense
            color="green-1"
            text-color="green-9"
            icon="ph ph-check-circle"
            class="text-weight-bold text-caption"
          >
            Order {{ status.toUpperCase() }}
          </q-chip>
        </template>

        <!-- Status: cancelled -->
        <template v-else-if="status === 'cancelled'">
          <q-badge color="red-7" class="q-pa-xs">ORDER CANCELLED</q-badge>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

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

const isConfirmedOrBeyond = computed(() => {
  return ['confirmed', 'procuring', 'ordered', 'delivered'].includes(props.status);
});
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
  box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
