<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 440px; border-radius: 12px">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold row items-center">
          <q-icon name="ph ph-hand-coins" size="24px" class="q-mr-xs text-primary" />
          Settle Wallet Payout
        </div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-card-section class="q-gutter-y-md">
        <div v-if="profile" class="q-pa-sm bg-blue-1 text-primary rounded-borders border-all-1">
          <div class="text-caption">Billing Profile</div>
          <div class="text-subtitle2 text-weight-bold">{{ profile.profile_name }}</div>
          <div class="text-caption">Available Net Credit: {{ formatBdt(profile.net_balance) }}</div>
        </div>

        <q-input
          v-model.number="amount"
          type="number"
          label="Payout Amount (BDT) *"
          outlined
          dense
          :rules="[
            (val) => !!val || 'Amount is required',
            (val) => val > 0 || 'Amount must be greater than 0',
            (val) => !profile || val <= profile.net_balance || 'Amount cannot exceed available credit',
          ]"
        />

        <q-input
          v-model="notes"
          label="Reference Notes / Transaction Details"
          outlined
          dense
          type="textarea"
          rows="2"
          placeholder="e.g. Bank transfer ref #12345 or MFS cash out"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat label="Cancel" no-caps v-close-popup />
        <q-btn
          color="primary"
          label="Confirm & Issue Payout"
          no-caps
          unelevated
          :loading="saving"
          :disable="!isValid"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { BillingProfileWalletSummary } from '../repositories/billingWalletRepository';

const props = defineProps<{
  modelValue: boolean;
  profile: BillingProfileWalletSummary | null;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'submit', payload: { amount: number; notes: string }): void;
}>();

const amount = ref<number>(0);
const notes = ref<string>('');

watch(
  () => props.profile,
  (newProfile) => {
    if (newProfile && newProfile.net_balance > 0) {
      amount.value = newProfile.net_balance;
    } else {
      amount.value = 0;
    }
    notes.value = '';
  },
  { immediate: true },
);

const isValid = computed(() => {
  if (!props.profile) return false;
  return amount.value > 0 && amount.value <= props.profile.net_balance;
});

const formatBdt = (val: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT' }).format(val);

const onConfirm = () => {
  if (!isValid.value) return;
  emit('submit', { amount: amount.value, notes: notes.value });
};
</script>
