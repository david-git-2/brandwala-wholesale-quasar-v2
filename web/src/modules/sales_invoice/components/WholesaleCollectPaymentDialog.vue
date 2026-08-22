<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card class="q-pa-md" style="min-width: 380px; border-radius: 16px">
      <q-card-section class="text-h6 text-weight-bold">Record Payment</q-card-section>
      <q-card-section class="q-gutter-sm">
        <div class="row justify-between text-caption text-grey-7">
          <span>Due</span><span class="text-weight-bold text-grey-9">৳{{ dueAmount.toFixed(2) }}</span>
        </div>
        <div class="row justify-between text-caption text-grey-7">
          <span>Already paid</span><span>৳{{ paidAmount.toFixed(2) }}</span>
        </div>
        <div class="row justify-between text-caption text-grey-7">
          <span>Customer store credit</span><span>৳{{ storeCredit.toFixed(2) }}</span>
        </div>
        <q-separator />
        <q-input
          v-model.number="cashAmount"
          type="number"
          label="Cash / bank amount"
          outlined
          dense
          min="0"
          class="soft-input"
        />
        <q-select
          v-model="cashMethod"
          :options="methodOptions"
          label="Method"
          outlined
          dense
          class="soft-input"
        />
        <q-input
          v-model.number="walletAmount"
          type="number"
          label="From store credit"
          outlined
          dense
          min="0"
          :max="storeCredit"
          class="soft-input"
        />
        <q-input
          v-model.number="settlementAmount"
          type="number"
          label="Settlement (write-off)"
          outlined
          dense
          min="0"
          class="soft-input"
        />
        <div v-if="overDue" class="text-caption text-negative">Cash + credit + settlement cannot exceed due.</div>
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
        <q-btn
          color="primary"
          label="Save"
          class="pill-btn"
          :loading="saving"
          :disable="!canSubmit"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';

const props = defineProps<{
  modelValue: boolean;
  dueAmount: number;
  paidAmount: number;
  storeCredit: number;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [boolean];
  submit: [{ cashAmount: number; cashMethod: string; walletAmount: number; settlementAmount: number }];
}>();

const methodOptions = ['cash', 'bkash', 'bank_transfer', 'nagad'];
const cashAmount = ref(0);
const cashMethod = ref('cash');
const walletAmount = ref(0);
const settlementAmount = ref(0);

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      cashAmount.value = 0;
      cashMethod.value = 'cash';
      walletAmount.value = 0;
      settlementAmount.value = 0;
    }
  },
);

const cash = computed(() => Math.max(Number(cashAmount.value) || 0, 0));
const wallet = computed(() => Math.max(Number(walletAmount.value) || 0, 0));
const settle = computed(() => Math.max(Number(settlementAmount.value) || 0, 0));
const totalApply = computed(() => cash.value + wallet.value + settle.value);
const overDue = computed(() => totalApply.value > (Number(props.dueAmount) || 0) + 0.0001);
const canSubmit = computed(
  () => totalApply.value > 0 && !overDue.value && wallet.value <= (Number(props.storeCredit) || 0) + 0.0001,
);

const onSave = () => {
  if (!canSubmit.value) return;
  emit('submit', {
    cashAmount: cash.value,
    cashMethod: cashMethod.value,
    walletAmount: wallet.value,
    settlementAmount: settle.value,
  });
};
</script>
