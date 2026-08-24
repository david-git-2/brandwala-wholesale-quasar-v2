<template>
  <q-card flat bordered class="decision-summary-card">
    <q-card-section class="q-pa-md column q-gutter-y-md">
      <div v-if="showItemProgress" class="column q-gutter-y-xs">
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
        <span v-if="!allDecided" class="text-caption text-grey-7">
          Accept or counter each item, then send your response.
        </span>
        <span v-else class="text-caption text-positive text-weight-medium">
          All items decided — ready to send.
        </span>
      </div>

      <div v-else-if="statusLabel" class="column q-gutter-y-xs">
        <span class="text-subtitle2 text-weight-bold text-grey-9">Order status</span>
        <span class="text-body2 text-grey-8">{{ statusLabel }}</span>
      </div>

      <q-separator v-if="showPrimaryAction" />

      <q-btn
        v-if="showPrimaryAction"
        unelevated
        no-caps
        :color="primaryColor"
        class="full-width action-btn text-weight-bold"
        :label="primaryLabel"
        :disable="primaryDisabled"
        :loading="primaryLoading"
        @click="emit('primary-action')"
      />
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { getCustomerCatalogStatusLabel } from '../utils/catalogOrderStatus';

const props = defineProps<{
  status: string;
  isNegotiable: boolean;
  decidedCount: number;
  totalItems: number;
  canSubmitCounter?: boolean;
  isSubmittingCounter?: boolean;
  isConfirming?: boolean;
}>();

const emit = defineEmits<{
  (e: 'primary-action'): void;
}>();

const showItemProgress = computed(
  () => props.isNegotiable && props.status === 'priced' && props.totalItems > 0,
);

const allDecided = computed(
  () => props.totalItems > 0 && props.decidedCount >= props.totalItems,
);

const decidedRatio = computed(() =>
  props.totalItems > 0 ? props.decidedCount / props.totalItems : 0,
);

const statusLabel = computed(() => getCustomerCatalogStatusLabel(props.status));

const showPrimaryAction = computed(() => {
  if (props.status === 'priced' && props.isNegotiable) return true;
  if (props.status === 'priced' && !props.isNegotiable) return true;
  if (props.status === 'final_offered') return true;
  return false;
});

const primaryLabel = computed(() => {
  if (props.status === 'priced' && props.isNegotiable) return 'Send my response';
  if (props.status === 'final_offered') return 'Confirm order';
  return 'Confirm order';
});

const primaryColor = computed(() => {
  if (props.status === 'priced' && props.isNegotiable) return 'amber-9';
  return 'positive';
});

const primaryDisabled = computed(() => {
  if (props.status === 'priced' && props.isNegotiable) {
    return !props.canSubmitCounter;
  }
  return false;
});

const primaryLoading = computed(() => {
  if (props.status === 'priced' && props.isNegotiable) return !!props.isSubmittingCounter;
  return !!props.isConfirming;
});
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderDecisionSummary',
};
</script>

<style scoped>
.decision-summary-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #fff);
}

.action-btn {
  min-height: 44px;
  border-radius: 8px;
}
</style>
