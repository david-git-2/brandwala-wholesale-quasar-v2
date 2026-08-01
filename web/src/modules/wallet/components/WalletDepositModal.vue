<template>
  <q-dialog v-model="isOpen" persistent transition-show="scale" transition-hide="scale">
    <q-card style="width: 480px; max-width: 95vw" class="rounded-borders">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="36px" class="bg-primary-soft text-primary font-mono text-weight-bold">
            <q-icon name="ph ph-plus-circle" size="20px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold">Deposit / Add Money</div>
            <div class="text-caption text-grey-7">
              Top up {{ entityName || entityType.toUpperCase() }} wallet balance
            </div>
          </div>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <q-form class="q-gutter-y-md" @submit.prevent="handleDeposit">
          <!-- Payment Method / Channel Selector -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Deposit Method
            </label>
            <q-select
              v-model="paymentMethod"
              outlined
              dense
              emit-value
              map-options
              :options="methodOptions"
              class="gentle-select"
            />
          </div>

          <!-- Deposit Amount -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Deposit Amount (BDT)
            </label>
            <q-input
              v-model.number="amount"
              outlined
              dense
              type="number"
              step="0.01"
              min="1"
              placeholder="1,000.00"
              :rules="[(val) => (val && val > 0) || 'Enter amount greater than zero']"
            >
              <template #append>
                <span class="text-caption text-grey-6 font-mono">BDT</span>
              </template>
            </q-input>
          </div>

          <!-- Transaction Reference / TxID -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Transaction Reference / TxID (Optional)
            </label>
            <q-input
              v-model="referenceId"
              outlined
              dense
              placeholder="e.g. TRX99283411 or Bank Slip #"
            />
          </div>

          <!-- Notes -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Notes (Optional)
            </label>
            <q-input
              v-model="notes"
              outlined
              dense
              type="textarea"
              rows="2"
              placeholder="Reason for deposit..."
            />
          </div>

          <!-- Submit Button -->
          <div class="row justify-end q-gutter-x-sm q-pt-sm">
            <q-btn v-close-popup flat label="Cancel" color="grey-8" no-caps />
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-plus-circle"
              label="Confirm Deposit"
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
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'deposited'): void;
}>();

const $q = useQuasar();
const isSubmitting = ref(false);
const amount = ref<number | null>(null);
const paymentMethod = ref<string>('bank_transfer');
const referenceId = ref<string>('');
const notes = ref<string>('');

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const methodOptions = [
  { label: 'Bank Transfer (EFT / RTGS)', value: 'bank_transfer' },
  { label: 'bKash Merchant Payment', value: 'bkash' },
  { label: 'Nagad Online Deposit', value: 'nagad' },
  { label: 'Cash / Manual Top Up', value: 'cash' },
];

async function handleDeposit() {
  if (!amount.value || amount.value <= 0) return;
  isSubmitting.value = true;
  try {
    await walletRepository.recordTransaction({
      entity_type: props.entityType,
      entity_id: props.entityId,
      type: 'credit',
      amount: amount.value,
      target_bucket: 'available',
      source_type: 'adjustment',
      metadata: {
        note: notes.value || `Deposit via ${paymentMethod.value}`,
        method: paymentMethod.value,
        reference_id: referenceId.value || undefined,
        description: `Direct wallet top-up (৳${amount.value.toLocaleString()})`,
      },
    });

    $q.notify({
      type: 'positive',
      message: `Successfully deposited ৳${amount.value.toLocaleString()} to wallet!`,
      icon: 'ph ph-check-circle',
    });

    amount.value = null;
    referenceId.value = '';
    notes.value = '';
    isOpen.value = false;
    emit('deposited');
  } catch (err: any) {
    console.error('[WalletDepositModal] Deposit failed:', err);
    $q.notify({
      type: 'negative',
      message: err.message || 'Failed to deposit money to wallet.',
      icon: 'ph ph-warning',
    });
  } finally {
    isSubmitting.value = false;
  }
}
</script>
