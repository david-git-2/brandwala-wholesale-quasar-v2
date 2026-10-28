<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: min(400px, 96vw)">
      <q-card-section class="text-h6">Apply custody to this bill</q-card-section>
      <q-card-section class="q-pt-none">
        <div class="text-body2 q-mb-md">
          Profile custody available: {{ formatAmountBdt(custodyAvailable) }}
        </div>
        <div class="text-caption text-grey-7 q-mb-sm">
          Open on bill: {{ formatAmountBdt(openBooks) }}
        </div>
        <q-input
          v-model.number="amount"
          type="number"
          outlined
          dense
          label="Amount (BDT)"
          :max="maxAmount"
          min="0"
        />
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Apply custody"
          :loading="submitting"
          :disable="!canSubmit"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import { useApplySettlementMutation } from '../composables/useApplySettlementMutation';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  billId: number;
  openBooks: number;
  custodyAvailable: number;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  applied: [];
}>();

const applyMutation = useApplySettlementMutation({ successMessage: 'Custody applied to bill.' });
const amount = ref(0);

const maxAmount = computed(() =>
  Math.min(Math.max(0, props.openBooks), Math.max(0, props.custodyAvailable)),
);

watch(
  () => props.modelValue,
  (open) => {
    if (open) amount.value = maxAmount.value;
  },
);

const canSubmit = computed(
  () => amount.value > 0 && amount.value <= maxAmount.value && !applyMutation.isPending.value,
);

const submitting = computed(() => applyMutation.isPending.value);

const onSubmit = async () => {
  if (!canSubmit.value) return;
  await applyMutation.mutateAsync({
    tenantId: props.tenantId,
    lines: [
      {
        bill_id: props.billId,
        amount: Number(amount.value),
        allocator_kind: 'custody_entry',
      },
    ],
  });
  emit('applied');
  emit('update:modelValue', false);
};
</script>
