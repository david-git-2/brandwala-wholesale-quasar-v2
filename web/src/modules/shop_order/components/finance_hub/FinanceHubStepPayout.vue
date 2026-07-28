<template>
  <q-card flat bordered class="q-pa-md">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center gap-xs">
      <q-icon name="ph ph-hand-coins" size="20px" />
      <span>Step 3: Dispense Middleman Payout</span>
    </div>

    <q-form @submit.prevent="handleConfirm" class="q-gutter-y-sm">
      <div class="row q-col-gutter-sm">
        <div class="col-12 col-md-6">
          <q-select
            v-model="form.billingProfileId"
            :options="merchantOptions"
            option-value="id"
            option-label="label"
            emit-value
            map-options
            label="Select Merchant / Middleman"
            outlined
            dense
            class="soft-input"
            :rules="[val => !!val || 'Merchant profile is required']"
          />
        </div>

        <div class="col-12 col-md-6">
          <q-input
            v-model.number="form.amount"
            type="number"
            label="Payout Amount (BDT)"
            outlined
            dense
            step="0.01"
            class="soft-input"
            :rules="[val => val > 0 || 'Must be > 0']"
          />
        </div>
      </div>

      <div class="row q-col-gutter-sm">
        <div class="col-12 col-md-6">
          <q-select
            v-model="form.payoutMethod"
            :options="payoutMethodOptions"
            label="Payout Method"
            outlined
            dense
            class="soft-input"
          />
        </div>

        <div class="col-12 col-md-6">
          <q-input
            v-model="form.referenceNotes"
            label="Reference Notes / Bank Trx Ref"
            outlined
            dense
            class="soft-input"
          />
        </div>
      </div>

      <div class="row justify-end q-mt-md">
        <q-btn
          type="submit"
          color="primary"
          unelevated
          no-caps
          :loading="loading"
          label="Dispense Payout & Debit Tenant & Middleman"
        />
      </div>
    </q-form>
  </q-card>
</template>

<script setup lang="ts">
import { reactive, computed, watch } from 'vue';
import type { FinanceHubMerchantItem } from '../../repositories/dropshipFinanceRepository';

const props = defineProps<{
  merchants: FinanceHubMerchantItem[];
  preselectedMerchantId?: number | null;
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'submit', payload: { billingProfileId: number; amount: number; payoutMethod?: string; referenceNotes?: string }): void;
}>();

const form = reactive({
  billingProfileId: null as number | null,
  amount: 0,
  payoutMethod: 'bank_transfer',
  referenceNotes: '',
});

const merchantOptions = computed(() =>
  props.merchants.map((m) => ({
    id: m.id,
    label: `${m.name} (Payable: ${m.payableBalance} BDT)`,
    balance: m.payableBalance,
  }))
);

const payoutMethodOptions = [
  { label: 'Bank Transfer', value: 'bank_transfer' },
  { label: 'bKash / Mobile Wallet', value: 'bkash' },
  { label: 'Cash', value: 'cash' },
];

watch(
  () => props.preselectedMerchantId,
  (id) => {
    if (id) {
      form.billingProfileId = id;
      const m = props.merchants.find((x) => x.id === id);
      if (m && m.payableBalance > 0) {
        form.amount = m.payableBalance;
      }
    }
  },
  { immediate: true }
);

watch(
  () => form.billingProfileId,
  (newId) => {
    if (newId) {
      const m = props.merchants.find((x) => x.id === newId);
      if (m && m.payableBalance > 0 && form.amount === 0) {
        form.amount = m.payableBalance;
      }
    }
  }
);

function handleConfirm() {
  if (!form.billingProfileId || form.amount <= 0) return;
  emit('submit', {
    billingProfileId: form.billingProfileId,
    amount: form.amount,
    payoutMethod: form.payoutMethod,
    referenceNotes: form.referenceNotes,
  });
}
</script>
