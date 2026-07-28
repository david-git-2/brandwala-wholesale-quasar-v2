<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 440px; max-width: 90vw;" class="q-pa-sm">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6 text-weight-bold text-grey-9">
          Dispense Payout
        </div>
        <q-btn flat round dense icon="ph ph-x" @click="closeDialog" />
      </q-card-section>

      <q-separator />

      <q-card-section v-if="merchant" class="q-gutter-y-md">
        <!-- Merchant Info -->
        <div class="row items-center q-gutter-x-sm bg-grey-1 q-pa-sm rounded-borders">
          <q-avatar size="36px" :color="getAvatarColor(merchant.name)" text-color="white" class="text-weight-bold">
            {{ getInitials(merchant.name) }}
          </q-avatar>
          <div>
            <div class="text-weight-bold text-grey-9">{{ merchant.name }}</div>
            <div class="text-caption text-grey-7">
              Available Balance: <span class="text-weight-bold text-positive">৳{{ (merchant.available_balance || 0).toLocaleString() }}</span>
            </div>
          </div>
        </div>

        <!-- Amount Input -->
        <q-input
          v-model.number="form.amount"
          type="number"
          label="Payout Amount (৳) *"
          dense
          outlined
          :rules="[
            (val) => (val !== null && val !== undefined && val > 0) || 'Amount must be greater than zero',
            (val) => (merchant ? val <= merchant.available_balance : true) || 'Amount exceeds available balance',
          ]"
        />

        <!-- Payment Method Selection -->
        <q-select
          v-model="form.method"
          :options="methodOptions"
          label="Payment Channel *"
          dense
          outlined
          emit-value
          map-options
        />

        <!-- Transaction ID / Reference -->
        <q-input
          v-model="form.trxId"
          label="Transaction ID / Ref (Optional)"
          dense
          outlined
          placeholder="e.g. BKASH-TRX-998231"
        />
      </q-card-section>

      <q-separator />

      <q-card-actions align="right" class="q-pa-md q-gutter-x-sm">
        <q-btn flat label="Cancel" no-caps class="rounded-btn" @click="closeDialog" />
        <q-btn
          color="primary"
          label="Confirm &amp; Dispense"
          no-caps
          unelevated
          class="rounded-btn"
          :loading="loading"
          :disable="!isValid"
          @click="submitPayout"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { MerchantPayoutSummary } from '../types';
import { getInitials, getAvatarColor } from 'src/shared/utils/avatarUtils';

const props = defineProps<{
  modelValue: boolean;
  merchant: MerchantPayoutSummary | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'confirm', payload: { billingProfileId: number; amount: number; method: string; trxId?: string }): void;
}>();

const methodOptions = [
  { label: 'bKash (MFS)', value: 'bkash' },
  { label: 'Nagad (MFS)', value: 'nagad' },
  { label: 'Bank Transfer', value: 'bank_transfer' },
  { label: 'Wallet Credit', value: 'wallet_credit' },
];

const form = ref({
  amount: 0,
  method: 'bkash',
  trxId: '',
});

watch(
  () => props.merchant,
  (newVal) => {
    if (newVal) {
      form.value.amount = newVal.available_balance > 0 ? newVal.available_balance : 0;
      form.value.method = 'bkash';
      form.value.trxId = '';
    }
  },
  { immediate: true },
);

const isValid = computed(() => {
  if (!props.merchant) return false;
  return (
    form.value.amount > 0 &&
    form.value.amount <= props.merchant.available_balance &&
    !!form.value.method
  );
});

function closeDialog() {
  emit('update:modelValue', false);
}

function submitPayout() {
  if (!props.merchant || !isValid.value) return;
  const payload: { billingProfileId: number; amount: number; method: string; trxId?: string } = {
    billingProfileId: props.merchant.billing_profile_id,
    amount: form.value.amount,
    method: form.value.method,
  };
  if (form.value.trxId) {
    payload.trxId = form.value.trxId;
  }
  emit('confirm', payload);
}
</script>

<style scoped>
.rounded-btn {
  border-radius: 8px;
}
.rounded-borders {
  border-radius: 8px;
}
</style>
