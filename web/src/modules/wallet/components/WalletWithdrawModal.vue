<template>
  <q-dialog v-model="isOpen" persistent transition-show="scale" transition-hide="scale">
    <q-card style="width: 480px; max-width: 95vw" class="rounded-borders">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="36px" class="bg-positive-soft text-positive bw-tabular text-weight-bold">
            <q-icon name="ph ph-bank" size="20px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold">Withdraw Cash</div>
            <div class="text-caption text-grey-7">
              Request bank payout for {{ entityName || entityType.toUpperCase() }}
            </div>
          </div>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <!-- Available Cash Hint Card -->
        <q-card flat bordered class="q-pa-sm q-mb-md bg-positive-soft border-positive">
          <div class="row items-center justify-between">
            <span class="text-caption text-weight-bold text-positive">
              Money You Have (Available Cash)
            </span>
            <span class="text-subtitle1 text-weight-bolder text-positive bw-tabular">
              ৳{{ formatCurrency(availableBalance) }}
            </span>
          </div>
        </q-card>

        <q-form class="q-gutter-y-md" @submit.prevent="handleWithdraw">
          <!-- Withdrawal Amount -->
          <div>
            <div class="row items-center justify-between q-mb-xs">
              <label class="text-caption text-weight-bold text-grey-8">
                Withdrawal Amount (BDT)
              </label>
              <q-btn
                flat
                dense
                no-caps
                size="xs"
                color="primary"
                label="Withdraw Max"
                class="text-weight-bold"
                @click="amount = availableBalance"
              />
            </div>
            <q-input
              v-model.number="amount"
              outlined
              dense
              type="number"
              step="0.01"
              min="1"
              :max="availableBalance"
              placeholder="1,000.00"
              :rules="[
                (val) => (val && val > 0) || 'Enter amount greater than zero',
                (val) => (val <= availableBalance) || `Max available cash is ৳${formatCurrency(availableBalance)}`
              ]"
            >
              <template #append>
                <span class="text-caption text-grey-6 bw-tabular">BDT</span>
              </template>
            </q-input>
          </div>

          <!-- Destination Channel -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Payout Method / Destination
            </label>
            <q-select
              v-model="destinationMethod"
              outlined
              dense
              emit-value
              map-options
              :options="destinationOptions"
              class="gentle-select"
            />
          </div>

          <!-- Account Details / Bank Info -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Account Details (Bank / Mobile Number)
            </label>
            <q-input
              v-model="accountDetails"
              outlined
              dense
              placeholder="e.g. Dutch-Bangla Bank (Acc: 124-100-XXXX) or bKash 01711XXXXXX"
              :rules="[(val) => (val && val.trim().length > 0) || 'Please provide account details']"
            />
          </div>

          <!-- Notes -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Payout Reference / Notes (Optional)
            </label>
            <q-input
              v-model="notes"
              outlined
              dense
              type="textarea"
              rows="2"
              placeholder="Withdrawal notes..."
            />
          </div>

          <!-- Submit Button -->
          <div class="row justify-end q-gutter-x-sm q-pt-sm">
            <q-btn v-close-popup flat label="Cancel" color="grey-8" no-caps />
            <q-btn
              unelevated
              color="positive"
              icon="ph ph-bank"
              label="Request Withdrawal"
              no-caps
              :loading="isSubmitting"
              type="submit"
              class="text-weight-bold q-px-md rounded-borders"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar } from 'quasar';
import type { UniversalWalletEntityType } from '../types';
import { walletRepository } from '../repositories/walletRepository';

const props = defineProps<{
  modelValue: boolean;
  entityType: UniversalWalletEntityType;
  entityId: number;
  entityName?: string;
  availableBalance?: number;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'withdrawn'): void;
}>();

const $q = useQuasar();
const isSubmitting = ref(false);
const amount = ref<number | null>(null);
const destinationMethod = ref<string>('bank_transfer');
const accountDetails = ref<string>('');
const notes = ref<string>('');

const availableBalance = computed(() => props.availableBalance ?? 0);

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const destinationOptions = [
  { label: 'Bank Account Payout (BEFTN / NPSB)', value: 'bank_transfer' },
  { label: 'bKash Personal / Merchant Payout', value: 'bkash' },
  { label: 'Nagad Payout', value: 'nagad' },
];

function formatCurrency(val: number): string {
  return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

async function handleWithdraw() {
  if (!amount.value || amount.value <= 0 || amount.value > availableBalance.value) return;
  isSubmitting.value = true;
  try {
    await walletRepository.recordTransaction({
      entity_type: props.entityType,
      entity_id: props.entityId,
      type: 'debit',
      amount: amount.value,
      target_bucket: 'available',
      source_type: 'payout',
      metadata: {
        note: notes.value || `Bank payout request to ${accountDetails.value}`,
        method: destinationMethod.value,
        account_details: accountDetails.value,
        description: `Cash withdrawal request (৳${amount.value.toLocaleString()})`,
      },
    });

    $q.notify({
      type: 'positive',
      message: `Withdrawal request for ৳${amount.value.toLocaleString()} submitted successfully!`,
      icon: 'ph ph-check-circle',
    });

    amount.value = null;
    accountDetails.value = '';
    notes.value = '';
    isOpen.value = false;
    emit('withdrawn');
  } catch (err: any) {
    console.error('[WalletWithdrawModal] Withdrawal failed:', err);
    $q.notify({
      type: 'negative',
      message: err.message || 'Failed to submit withdrawal request.',
      icon: 'ph ph-warning',
    });
  } finally {
    isSubmitting.value = false;
  }
}
</script>
