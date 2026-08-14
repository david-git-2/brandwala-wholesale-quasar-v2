<template>
  <q-dialog :model-value="modelValue" @update:model-value="(v) => emit('update:modelValue', v)">
    <q-card style="min-width: 440px; max-width: 520px" class="q-pa-md rounded-borders">
      <q-card-section class="row items-center justify-between q-pb-xs">
        <div class="row items-center q-gutter-xs">
          <q-icon name="ph ph-wallet" color="primary" size="24px" />
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            Payee Settlement & Credit
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-separator class="q-my-xs" />

      <q-card-section class="q-py-sm column q-gutter-y-sm">
        <!-- Payee Header Information -->
        <div class="q-pa-sm bg-grey-1 rounded-borders">
          <div class="row items-center justify-between">
            <span class="text-caption text-grey-6 uppercase text-weight-bold">Payee</span>
            <q-badge
              :color="entityType === 'vendor' ? 'blue-1' : 'teal-1'"
              :text-color="entityType === 'vendor' ? 'blue-9' : 'teal-9'"
              :label="entityType === 'vendor' ? 'Vendor' : 'Cargo Agent'"
            />
          </div>
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-xs">
            {{ entityName }}
          </div>

          <div class="row justify-between text-caption q-mt-xs pt-xs border-top-grey">
            <span class="text-grey-7">Live Wallet Balance:</span>
            <span
              class="text-weight-bold"
              :class="walletAvailableBalance > 0 ? 'text-positive' : 'text-grey-8'"
            >
              <q-spinner v-if="loadingBalance" size="12px" color="primary" class="q-mr-xs" />
              {{ purchaseCurrencySymbol }}{{ formatNumber(walletAvailableBalance) }}
              {{ walletAvailableBalance > 0 ? 'Available Credit' : '' }}
            </span>
          </div>
        </div>

        <!-- Payment Source Selector -->
        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Payment Source *</div>
          <q-btn-toggle
            v-model="paymentSource"
            spread
            no-caps
            dense
            unelevated
            toggle-color="primary"
            color="grey-2"
            text-color="grey-9"
            :options="sourceOptions"
            class="soft-toggle"
          />
        </div>

        <!-- Settlement Amount Input -->
        <div>
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-caption text-weight-bold text-grey-8">Settlement Amount *</span>
            <q-btn
              flat
              dense
              no-caps
              size="xs"
              color="primary"
              label="Use Agreed Total"
              @click="amount = agreedAmount"
            />
          </div>
          <q-input
            v-model.number="amount"
            type="number"
            step="0.01"
            min="0"
            outlined
            dense
            :prefix="purchaseCurrencySymbol"
            class="soft-input text-weight-bold"
            hint="Editable amount for this settlement transaction"
          />
        </div>

        <!-- Wallet Credit Application Alert -->
        <div
          v-if="paymentSource === 'wallet' && walletAvailableBalance > 0"
          class="q-pa-sm bg-purple-1 text-purple-10 rounded-borders text-caption"
        >
          <div class="row items-center q-gutter-xs">
            <q-icon name="ph ph-lightning" size="16px" />
            <span class="text-weight-bold">Applying Vendor Credit:</span>
          </div>
          <div style="font-size: 11px; line-height: 1.3" class="q-mt-xs">
            Using <strong>{{ purchaseCurrencySymbol }}{{ formatNumber(appliedWalletCredit) }}</strong>
            from accumulated wallet credit to fulfill this shipment cost.
          </div>
        </div>

        <!-- Overpayment / Credit Reservation Alert -->
        <div
          v-if="overpaymentCredit > 0 && paymentSource === 'cash'"
          class="q-pa-sm bg-amber-1 text-amber-10 rounded-borders text-caption"
        >
          <div class="row items-center q-gutter-xs">
            <q-icon name="ph ph-warning-circle" size="16px" />
            <span class="text-weight-bold">Vendor Credit Reservation:</span>
          </div>
          <div style="font-size: 11px; line-height: 1.3" class="q-mt-xs">
            Paying <strong>{{ purchaseCurrencySymbol }}{{ formatNumber(overpaymentCredit) }}</strong>
            more than received physical goods. This extra amount will be credited to the payee's
            wallet account for future shipments.
          </div>
        </div>

        <!-- Notes / Reference -->
        <div>
          <q-input
            v-model="notes"
            label="Notes / Reference (Optional)"
            dense
            outlined
            placeholder="e.g. Bank Ref #10492 / Overpayment credit"
            class="soft-input"
          />
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none">
        <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          no-caps
          icon="ph ph-check"
          label="Confirm & Settle"
          :loading="submitting"
          :disable="!amount || amount <= 0"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ShipmentCostPayeeType, ShipmentCostPaymentSource } from '../types/shipmentCostEntry';
import { supabase } from 'src/boot/supabase';
import { showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  entityType: ShipmentCostPayeeType;
  entityId: number | null;
  entityName: string;
  agreedAmount: number;
  receivedGoodsAmount?: number | undefined;
  purchaseCurrencySymbol: string;
  submitting?: boolean | undefined;
}>();

const emit = defineEmits<{
  'update:modelValue': [val: boolean];
  settle: [
    payload: {
      entityType: ShipmentCostPayeeType;
      entityId: number;
      amount: number;
      paymentSource: ShipmentCostPaymentSource;
      notes?: string;
    },
  ];
}>();

const paymentSource = ref<ShipmentCostPaymentSource>('cash');
const amount = ref<number>(0);
const notes = ref<string>('');
const walletAvailableBalance = ref<number>(0);
const loadingBalance = ref<boolean>(false);

const sourceOptions = computed(() => [
  { label: 'Cash / Bank', value: 'cash' as ShipmentCostPaymentSource },
  {
    label: `Vendor Credit (${props.purchaseCurrencySymbol}${formatNumber(walletAvailableBalance.value)})`,
    value: 'wallet' as ShipmentCostPaymentSource,
    disabled: walletAvailableBalance.value <= 0,
  },
  { label: 'Credit (On Account)', value: 'credit' as ShipmentCostPaymentSource },
]);

const appliedWalletCredit = computed(() =>
  Math.min(amount.value || 0, walletAvailableBalance.value || 0),
);

const overpaymentCredit = computed(() => {
  const rec = props.receivedGoodsAmount || 0;
  const current = amount.value || 0;
  if (rec > 0 && current > rec) {
    return Math.round((current - rec) * 100) / 100;
  }
  return 0;
});

const formatNumber = (num: number) =>
  (num || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const fetchWalletBalance = async () => {
  if (!props.entityId) {
    walletAvailableBalance.value = 0;
    return;
  }
  loadingBalance.value = true;
  try {
    const { data } = await supabase
      .from('wallet_accounts')
      .select('available_balance')
      .eq('entity_type', props.entityType)
      .eq('entity_id', props.entityId)
      .maybeSingle();

    walletAvailableBalance.value = Number(data?.available_balance) || 0;
  } catch {
    walletAvailableBalance.value = 0;
  } finally {
    loadingBalance.value = false;
  }
};

watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      amount.value = props.agreedAmount || 0;
      notes.value = '';
      paymentSource.value = 'cash';
      void fetchWalletBalance();
    }
  },
  { immediate: true },
);

const onConfirm = () => {
  if (!props.entityId) {
    showErrorNotification('Valid Payee ID required');
    return;
  }
  if (!amount.value || amount.value <= 0) {
    showErrorNotification('Settlement amount must be > 0');
    return;
  }
  emit('settle', {
    entityType: props.entityType,
    entityId: props.entityId,
    amount: amount.value,
    paymentSource: props.entityType === 'vendor' && paymentSource.value === 'wallet' ? 'wallet' : paymentSource.value,
    notes: notes.value,
  });
};
</script>

<style scoped>
.border-top-grey {
  border-top: 1px solid color-mix(in srgb, var(--bw-theme-border, #e0e0e0) 80%, transparent);
}
.soft-toggle {
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e0e0e0) 80%, transparent);
  border-radius: 8px;
}
</style>
