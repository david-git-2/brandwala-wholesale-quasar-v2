<template>
  <q-dialog v-model="isOpen" persistent transition-show="scale" transition-hide="scale">
    <q-card style="width: 520px; max-width: 95vw" class="rounded-borders shadow-2">
      <!-- Modal Header -->
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="38px" :class="actionConfig.avatarBgClass" :text-color="actionConfig.color" class="font-mono text-weight-bold">
            <q-icon :name="actionConfig.icon" size="20px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold leading-tight">
              {{ actionConfig.title }}
            </div>
            <div class="text-caption text-grey-7">
              {{ entityName || `Entity #${entityId}` }} ({{ entityTypeLabel }})
            </div>
          </div>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <!-- Form Body -->
      <q-card-section class="q-pt-md">
        <q-form class="q-gutter-y-md" @submit.prevent="handleSubmit">
          <!-- 0. Account & Transfer Routing Card -->
          <div class="q-pa-sm bg-grey-1 rounded-borders border-grey-3">
            <!-- Case A: PAY action -->
            <template v-if="actionType === 'pay'">
              <div v-if="entityType !== 'tenant'" class="row items-center justify-between text-caption">
                <div class="row items-center q-gutter-x-xs">
                  <span class="text-grey-6">From:</span>
                  <q-badge color="grey-3" text-color="grey-9" class="text-weight-bold">🏢 Company Cash</q-badge>
                </div>
                <q-icon name="ph ph-arrow-right" color="grey-6" size="14px" />
                <div class="row items-center q-gutter-x-xs">
                  <span class="text-grey-6">To Account:</span>
                  <q-badge color="primary-soft" text-color="primary" class="text-weight-bold">
                    {{ entityName || `${entityTypeLabel} #${entityId}` }}
                  </q-badge>
                </div>
              </div>
              <!-- If on Company Wallet: Pick the payee (To Account) -->
              <div v-else class="q-gutter-y-xs">
                <div class="row items-center justify-between text-caption q-mb-xs">
                  <span class="text-grey-7">From: <strong>🏢 Company Cash</strong></span>
                  <span class="text-primary text-weight-bold">➔ To Account (Select Payee): *</span>
                </div>
                <div class="row q-col-gutter-xs">
                  <div class="col-5">
                    <q-select
                      v-model="destinationType"
                      outlined
                      dense
                      emit-value
                      map-options
                      :options="destinationTypeOptions"
                      class="bg-white"
                      @update:model-value="loadDestinationEntities"
                    />
                  </div>
                  <div class="col-7">
                    <q-select
                      v-model="destinationEntityId"
                      outlined
                      dense
                      emit-value
                      map-options
                      use-input
                      fill-input
                      hide-selected
                      :options="filteredDestinationOptions"
                      :loading="isLoadingDestinations"
                      placeholder="Select Payee..."
                      class="bg-white"
                      :rules="[(val) => (val && val > 0) || 'Please select a payee wallet']"
                      @filter="filterDestinations"
                    />
                  </div>
                </div>
              </div>
            </template>

            <!-- Case B: CREDIT action (Record store credit) -->
            <template v-else-if="actionType === 'credit'">
              <div v-if="entityType !== 'tenant'" class="row items-center justify-between text-caption">
                <span class="text-grey-7">Type: <strong>Non-Cash Store Credit</strong></span>
                <div class="row items-center q-gutter-x-xs">
                  <span class="text-grey-6">To Account:</span>
                  <q-badge color="indigo-1" text-color="indigo-9" class="text-weight-bold">
                    {{ entityName || `${entityTypeLabel} #${entityId}` }}
                  </q-badge>
                </div>
              </div>
              <!-- If on Company Wallet: Pick recipient (To Account) -->
              <div v-else class="q-gutter-y-xs">
                <label class="text-caption text-weight-bold text-grey-8 block">
                  To Account (Select Credit Recipient): *
                </label>
                <div class="row q-col-gutter-xs">
                  <div class="col-5">
                    <q-select
                      v-model="destinationType"
                      outlined
                      dense
                      emit-value
                      map-options
                      :options="destinationTypeOptions"
                      class="bg-white"
                      @update:model-value="loadDestinationEntities"
                    />
                  </div>
                  <div class="col-7">
                    <q-select
                      v-model="destinationEntityId"
                      outlined
                      dense
                      emit-value
                      map-options
                      use-input
                      fill-input
                      hide-selected
                      :options="filteredDestinationOptions"
                      :loading="isLoadingDestinations"
                      placeholder="Select Account..."
                      class="bg-white"
                      :rules="[(val) => (val && val > 0) || 'Please select an account']"
                      @filter="filterDestinations"
                    />
                  </div>
                </div>
              </div>
            </template>

            <!-- Case C: DEPOSIT action -->
            <template v-else-if="actionType === 'deposit'">
              <div class="row items-center justify-between text-caption">
                <span class="text-grey-7">Source: <strong>External Bank / Cash Inflow</strong></span>
                <div class="row items-center q-gutter-x-xs">
                  <span class="text-grey-6">Deposit Into:</span>
                  <q-badge color="teal-1" text-color="teal-9" class="text-weight-bold">
                    {{ entityName || (entityType === 'tenant' ? '🏢 Our Company Wallet' : `${entityTypeLabel} #${entityId}`) }}
                  </q-badge>
                </div>
              </div>
            </template>

            <!-- Case D: WITHDRAW action -->
            <template v-else-if="actionType === 'withdraw'">
              <div class="row items-center justify-between text-caption">
                <div class="row items-center q-gutter-x-xs">
                  <span class="text-grey-6">Withdraw From:</span>
                  <q-badge color="positive-soft" text-color="positive" class="text-weight-bold">
                    {{ entityName || (entityType === 'tenant' ? '🏢 Our Company Wallet' : `${entityTypeLabel} #${entityId}`) }}
                  </q-badge>
                </div>
                <span class="text-grey-7">➔ Destination: <strong>External Bank / bKash</strong></span>
              </div>
            </template>
          </div>

          <!-- 1. Amount & Currency Row -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Transaction Amount &amp; Currency *
            </label>
            <div class="row q-col-gutter-xs">
              <div class="col-8">
                <q-input
                  v-model.number="amount"
                  outlined
                  dense
                  type="number"
                  step="0.01"
                  min="0.01"
                  placeholder="0.00"
                  :rules="[(val) => (val && val > 0) || 'Enter amount greater than zero']"
                  class="bg-white"
                />
              </div>
              <div class="col-4">
                <q-select
                  v-model="currency"
                  outlined
                  dense
                  emit-value
                  map-options
                  :options="currencyOptions"
                  class="bg-white"
                />
              </div>
            </div>
          </div>

          <!-- 2. Exchange Rate Row (Appears when foreign currency is selected) -->
          <div v-if="currency !== 'BDT'" class="q-pa-sm bg-grey-1 rounded-borders border-grey-3">
            <div class="row q-col-gutter-xs items-center">
              <div class="col-6">
                <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
                  Exchange Rate (1 {{ currency }} = ? BDT) *
                </label>
                <q-input
                  v-model.number="exchangeRate"
                  outlined
                  dense
                  type="number"
                  step="0.0001"
                  min="0.0001"
                  placeholder="124.50"
                  :rules="[(val) => (val && val > 0) || 'Rate required']"
                  class="bg-white"
                />
              </div>
              <div class="col-6 text-right">
                <div class="text-caption text-grey-6">Converted Base Value</div>
                <div class="text-subtitle1 text-weight-bolder text-primary font-mono">
                  ৳ {{ formatNumber(convertedBdt) }} BDT
                </div>
              </div>
            </div>
          </div>

          <!-- 3. Category / Reason -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Category / Reason *
            </label>
            <q-select
              v-model="category"
              outlined
              dense
              emit-value
              map-options
              :options="categoryOptions"
              class="bg-white"
            />
          </div>

          <!-- 4. Payment Method / Channel -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Payment Method / Channel *
            </label>
            <q-select
              v-model="paymentMethod"
              outlined
              dense
              emit-value
              map-options
              :options="methodOptions"
              class="bg-white"
            />
          </div>

          <!-- 5. Reference / TxID (Optional) -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Reference / TxID / Slip # (Optional)
            </label>
            <q-input
              v-model="referenceId"
              outlined
              dense
              placeholder="e.g. TRX-99283411 or Bank Slip #"
              class="bg-white"
            />
          </div>

          <!-- 6. Note (Optional) -->
          <div>
            <label class="text-caption text-weight-bold text-grey-8 block q-mb-xs">
              Notes &amp; Description (Optional)
            </label>
            <q-input
              v-model="note"
              outlined
              dense
              type="textarea"
              rows="2"
              placeholder="Brief explanation for this transaction..."
              class="bg-white"
            />
          </div>

          <!-- Action Buttons -->
          <div class="row justify-end q-gutter-x-sm q-pt-sm">
            <q-btn v-close-popup flat label="Cancel" color="grey-8" no-caps class="rounded-btn" />
            <q-btn
              unelevated
              :color="actionConfig.color"
              :icon="actionConfig.icon"
              :label="actionConfig.confirmLabel"
              no-caps
              :loading="submitting"
              type="submit"
              class="text-weight-bold q-px-md rounded-btn"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { UniversalWalletEntityType } from '../types';

export type WalletModalActionType = 'pay' | 'deposit' | 'credit' | 'withdraw';

export interface WalletActionPayload {
  actionType: WalletModalActionType;
  entityType: UniversalWalletEntityType;
  entityId: number;
  targetEntityType?: UniversalWalletEntityType;
  targetEntityId?: number;
  amount: number;
  currency: string;
  exchangeRate: number;
  baseAmount: number;
  category: string;
  paymentMethod: string;
  referenceId?: string;
  note?: string;
}

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    actionType: WalletModalActionType;
    entityType: UniversalWalletEntityType;
    entityId: number;
    entityName?: string;
    availableBalance?: number;
    submitting?: boolean;
  }>(),
  {
    entityName: '',
    availableBalance: 0,
    submitting: false,
  },
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'submit', payload: WalletActionPayload): void;
}>();

const authStore = useAuthStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const amount = ref<number | null>(null);
const currency = ref<string>('BDT');
const exchangeRate = ref<number>(1.0);
const category = ref<string>('');
const paymentMethod = ref<string>('bank_transfer');
const referenceId = ref<string>('');
const note = ref<string>('');

// Destination Payee state (when on Company wallet)
const destinationType = ref<UniversalWalletEntityType>('vendor');
const destinationEntityId = ref<number | null>(null);
const destinationOptions = ref<Array<{ label: string; value: number }>>([]);
const filteredDestinationOptions = ref<Array<{ label: string; value: number }>>([]);
const isLoadingDestinations = ref<boolean>(false);

const destinationTypeOptions = [
  { label: 'Supplier / Vendor', value: 'vendor' },
  { label: 'Cargo Agent', value: 'cargo_company' },
  { label: 'Courier Service', value: 'courier' },
  { label: 'Customer / Reseller', value: 'customer' },
];

async function loadDestinationEntities() {
  if (props.entityType !== 'tenant') return;
  isLoadingDestinations.value = true;
  destinationOptions.value = [];
  destinationEntityId.value = null;

  try {
    const tenantId = authStore.selectedTenant?.id || 1;
    const parentTenantId = authStore.selectedTenant?.parent_id ?? tenantId;

    if (destinationType.value === 'vendor') {
      const { data } = await supabase
        .from('vendors')
        .select('id, name')
        .eq('parent_tenant_id', parentTenantId)
        .order('name');
      destinationOptions.value = (data || []).map((v) => ({ label: v.name, value: v.id }));
    } else if (destinationType.value === 'cargo_company') {
      const { data } = await supabase
        .from('cargo_companies')
        .select('id, name')
        .eq('parent_tenant_id', parentTenantId)
        .order('name');
      destinationOptions.value = (data || []).map((c) => ({ label: c.name, value: c.id }));
    } else if (destinationType.value === 'courier') {
      const { data } = await supabase
        .from('courier_services')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
      destinationOptions.value = (data || []).map((c) => ({ label: c.name, value: c.id }));
    } else if (destinationType.value === 'customer') {
      const { data } = await supabase
        .from('billing_profiles')
        .select('id, name')
        .eq('tenant_id', parentTenantId)
        .order('name');
      destinationOptions.value = (data || []).map((c) => ({ label: c.name, value: c.id }));
    }
    filteredDestinationOptions.value = destinationOptions.value;
  } catch (err) {
    console.error('[WalletActionModal] Error loading destination entities:', err);
  } finally {
    isLoadingDestinations.value = false;
  }
}

function filterDestinations(val: string, update: (callbackFn: () => void) => void) {
  if (val === '') {
    update(() => {
      filteredDestinationOptions.value = destinationOptions.value;
    });
    return;
  }
  update(() => {
    const needle = val.toLowerCase();
    filteredDestinationOptions.value = destinationOptions.value.filter((v) =>
      v.label.toLowerCase().includes(needle),
    );
  });
}

onMounted(() => {
  if (props.entityType === 'tenant') {
    void loadDestinationEntities();
  }
});

watch(
  () => props.modelValue,
  (open) => {
    if (open && props.entityType === 'tenant' && destinationOptions.value.length === 0) {
      void loadDestinationEntities();
    }
  },
);

const convertedBdt = computed<number>(() => {
  const amt = amount.value || 0;
  if (currency.value === 'BDT') return amt;
  return amt * (exchangeRate.value || 1);
});

const currencyOptions = [
  { label: 'BDT (৳)', value: 'BDT' },
  { label: 'USD ($)', value: 'USD' },
  { label: 'CNY (¥)', value: 'CNY' },
  { label: 'EUR (€)', value: 'EUR' },
  { label: 'GBP (£)', value: 'GBP' },
];

const entityTypeLabel = computed<string>(() => {
  switch (props.entityType) {
    case 'tenant':        return 'Company';
    case 'customer':      return 'Customer';
    case 'vendor':        return 'Supplier';
    case 'cargo_company': return 'Cargo Agent';
    case 'courier':       return 'Courier';
    case 'investor':      return 'Investor';
    default:              return 'Entity';
  }
});

const actionConfig = computed(() => {
  switch (props.actionType) {
    case 'pay':
      return {
        title: 'Make Payment (Cash Out)',
        color: 'primary',
        avatarBgClass: 'bg-primary-soft',
        icon: 'ph ph-arrow-up-right',
        confirmLabel: 'Confirm Payment',
      };
    case 'deposit':
      return {
        title: 'Deposit Money (Cash In)',
        color: 'teal-8',
        avatarBgClass: 'bg-teal-1',
        icon: 'ph ph-plus-circle',
        confirmLabel: 'Confirm Deposit',
      };
    case 'credit':
      return {
        title: 'Record Store Credit (Non-Cash)',
        color: 'indigo-8',
        avatarBgClass: 'bg-indigo-1',
        icon: 'ph ph-tag',
        confirmLabel: 'Confirm Credit',
      };
    case 'withdraw':
      return {
        title: 'Withdraw Cash / Bank Payout',
        color: 'positive',
        avatarBgClass: 'bg-positive-soft',
        icon: 'ph ph-bank',
        confirmLabel: 'Confirm Payout',
      };
  }
});

const categoryOptions = computed(() => {
  switch (props.actionType) {
    case 'pay':
      return [
        { label: 'Vendor Purchase / Bill Payment', value: 'vendor_purchase' },
        { label: 'Cargo & Freight Fee', value: 'cargo_fee' },
        { label: 'Office & Operating Expense', value: 'expense' },
        { label: 'Invoice Settlement', value: 'invoice_settlement' },
        { label: 'Other Direct Payment', value: 'direct_payment' },
      ];
    case 'deposit':
      return [
        { label: 'Bank / Cash Top-Up', value: 'cash_topup' },
        { label: 'Customer Advance Payment', value: 'advance_payment' },
        { label: 'Owner / Investor Capital', value: 'capital_invested' },
        { label: 'Sales Revenue Deposit', value: 'sales_revenue' },
        { label: 'Other Deposit', value: 'deposit' },
      ];
    case 'credit':
      return [
        { label: 'Short Delivery Compensation', value: 'short_delivery' },
        { label: 'Damaged Goods Return', value: 'return_credit' },
        { label: 'Discount / Rebate Credit', value: 'discount_credit' },
        { label: 'General Store Credit', value: 'store_credit' },
      ];
    case 'withdraw':
      return [
        { label: 'Bank Account Transfer', value: 'bank_payout' },
        { label: 'Mobile Wallet (bKash/Nagad)', value: 'mobile_payout' },
        { label: 'Dropshipper / Reseller Profit', value: 'reseller_profit' },
        { label: 'Owner Drawing / Dividend', value: 'dividend_payout' },
        { label: 'Other Payout', value: 'payout' },
      ];
  }
});

const methodOptions = computed(() => {
  if (props.actionType === 'credit') {
    return [{ label: 'Store Credit / Internal Ledger (Non-Cash)', value: 'store_credit' }];
  }
  return [
    { label: 'Bank Transfer (EFT / RTGS)', value: 'bank_transfer' },
    { label: 'bKash Merchant / Personal', value: 'bkash' },
    { label: 'Nagad Online / Personal', value: 'nagad' },
    { label: 'Cash Drawer / Petty Cash', value: 'cash' },
  ];
});

watch(
  () => props.actionType,
  (newAction) => {
    if (newAction === 'credit') {
      paymentMethod.value = 'store_credit';
      category.value = 'store_credit';
    } else if (newAction === 'pay') {
      paymentMethod.value = 'bank_transfer';
      category.value = 'vendor_purchase';
    } else if (newAction === 'deposit') {
      paymentMethod.value = 'bank_transfer';
      category.value = 'cash_topup';
    } else if (newAction === 'withdraw') {
      paymentMethod.value = 'bank_transfer';
      category.value = 'bank_payout';
    }
  },
  { immediate: true },
);

function formatNumber(val: number): string {
  return (val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function handleSubmit() {
  if (!amount.value || amount.value <= 0) return;

  const payload: WalletActionPayload = {
    actionType: props.actionType,
    entityType: props.entityType,
    entityId: props.entityId,
    ...(props.entityType === 'tenant' && destinationType.value ? { targetEntityType: destinationType.value } : {}),
    ...(props.entityType === 'tenant' && destinationEntityId.value ? { targetEntityId: destinationEntityId.value } : {}),
    amount: amount.value,
    currency: currency.value,
    exchangeRate: currency.value === 'BDT' ? 1.0 : exchangeRate.value || 1.0,
    baseAmount: convertedBdt.value,
    category: category.value,
    paymentMethod: paymentMethod.value,
    ...(referenceId.value.trim() ? { referenceId: referenceId.value.trim() } : {}),
    ...(note.value.trim() ? { note: note.value.trim() } : {}),
  };

  emit('submit', payload);
}
</script>

<style scoped lang="scss">
.rounded-btn {
  border-radius: 8px;
}
.border-grey-3 {
  border: 1px solid #e2e8f0;
}
.bg-primary-soft {
  background: rgba(59, 130, 246, 0.1) !important;
}
.bg-positive-soft {
  background: rgba(16, 185, 129, 0.12) !important;
}
</style>
