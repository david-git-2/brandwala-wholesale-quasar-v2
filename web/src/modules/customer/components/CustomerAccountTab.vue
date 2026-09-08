<template>
  <div class="column q-gutter-y-md">
    <div v-if="isLoading" class="row justify-center q-py-lg">
      <q-spinner color="primary" size="2em" />
    </div>

    <div v-else-if="isError" class="text-center text-negative q-pa-md">
      {{ errorMessage }}
    </div>

    <template v-else-if="summary">
      <div v-if="!summary.billing_profile_id" class="text-caption text-grey-7 text-center q-pa-md">
        No billing profile linked — create or link one to enable account balances and wallet actions.
      </div>

      <template v-else>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-card flat bordered class="q-pa-md rounded-borders account-card account-card--due">
              <div class="text-caption text-uppercase text-grey-7">They owe us</div>
              <div class="text-h5 text-weight-bolder" :class="stillDueClass">
                {{ formatBdt(summary.still_due) }}
              </div>
              <div class="text-caption text-grey-6">Invoice balance due</div>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="q-pa-md rounded-borders account-card account-card--credit">
              <div class="text-caption text-uppercase text-grey-7">We owe them</div>
              <div class="text-h5 text-weight-bolder text-positive">
                {{ formatBdt(summary.store_credit_balance) }}
              </div>
              <div class="text-caption text-grey-6">Store credit / wallet</div>
            </q-card>
          </div>
        </div>

        <div class="row q-col-gutter-xs text-caption text-grey-7">
          <div class="col-auto">Billed: {{ formatBdt(summary.total_billed) }}</div>
          <div class="col-auto">·</div>
          <div class="col-auto">Cash collected: {{ formatBdt(summary.collected_cash) }}</div>
          <div class="col-auto">·</div>
          <div class="col-auto">Credit applied: {{ formatBdt(summary.wallet_applied) }}</div>
          <div class="col-auto">·</div>
          <div class="col-auto">Settlement: {{ formatBdt(summary.settlement) }}</div>
          <div v-if="summary.unallocated_payments > 0" class="col-auto">·</div>
          <div v-if="summary.unallocated_payments > 0" class="col-auto text-orange-9">
            Unallocated: {{ formatBdt(summary.unallocated_payments) }}
          </div>
        </div>

        <div class="row q-gutter-xs wrap">
          <q-btn
            unelevated
            color="primary"
            icon="ph ph-coins"
            label="Collect"
            no-caps
            size="sm"
            class="action-btn text-weight-bold"
            :disable="!summary.open_invoices.length"
            @click="openCollectForInvoice(summary.open_invoices[0])"
          />
          <q-btn
            unelevated
            color="teal-8"
            icon="ph ph-plus-circle"
            label="Deposit"
            no-caps
            size="sm"
            class="action-btn text-weight-bold"
            @click="openWalletAction('deposit')"
          />
          <q-btn
            unelevated
            color="indigo-8"
            icon="ph ph-tag"
            label="Credit"
            no-caps
            size="sm"
            class="action-btn text-weight-bold"
            @click="openWalletAction('credit')"
          />
          <q-btn
            unelevated
            color="positive"
            icon="ph ph-bank"
            label="Withdraw"
            no-caps
            size="sm"
            class="action-btn text-weight-bold"
            :disable="summary.store_credit_balance <= 0"
            @click="openWalletAction('withdraw')"
          />
          <q-btn
            flat
            color="primary"
            icon="ph ph-arrow-square-out"
            label="Full wallet"
            no-caps
            size="sm"
            class="text-weight-bold"
            @click="onOpenFullWallet"
          />
          <q-btn
            flat
            dense
            icon="ph ph-arrows-clockwise"
            label="Refresh"
            no-caps
            size="sm"
            class="text-caption"
            @click="emit('refresh')"
          />
        </div>

        <div v-if="summary.open_invoices.length">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Open invoices</div>
          <q-card flat bordered class="rounded-borders">
            <q-markup-table flat dense wrap-cells>
              <thead>
                <tr>
                  <th class="text-left">Invoice</th>
                  <th class="text-left">Type</th>
                  <th class="text-right">Due</th>
                  <th class="text-left">Desk</th>
                  <th class="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="inv in summary.open_invoices" :key="inv.id">
                  <td class="text-weight-medium">{{ inv.invoice_no }}</td>
                  <td class="text-caption text-grey-7">{{ inv.invoice_type }}</td>
                  <td class="text-right text-weight-bold text-negative">
                    {{ formatBdt(inv.due_amount) }}
                  </td>
                  <td class="text-caption">{{ inv.issued_by_tenant_name || '—' }}</td>
                  <td class="text-right">
                    <q-btn
                      flat
                      dense
                      no-caps
                      color="primary"
                      label="Collect"
                      size="sm"
                      @click="openCollectForInvoice(inv)"
                    />
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>

        <div v-if="activityRows.length">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Recent activity</div>
          <q-list separator bordered class="rounded-borders">
            <q-item v-for="row in activityRows" :key="row.key" class="q-py-sm">
              <q-item-section>
                <q-item-label class="text-weight-bold text-caption text-grey-9">
                  {{ row.label }}
                </q-item-label>
                <q-item-label caption class="text-grey-7">
                  {{ row.subtitle }}
                </q-item-label>
              </q-item-section>
              <q-item-section side class="text-right">
                <q-item-label
                  class="text-weight-bold text-caption"
                  :class="row.amountClass"
                >
                  {{ row.amountText }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div v-if="summary.shop_access.length">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Shop access</div>
          <q-card flat bordered class="rounded-borders">
            <q-markup-table flat dense wrap-cells>
              <thead>
                <tr>
                  <th class="text-left">Shop</th>
                  <th class="text-left">Tenant</th>
                  <th class="text-left">Type</th>
                  <th class="text-right">Credit limit</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="shop in summary.shop_access" :key="shop.shop_id">
                  <td>{{ shop.shop_name }}</td>
                  <td class="text-caption">{{ shop.shop_tenant_name }}</td>
                  <td class="text-caption text-grey-7">{{ shop.shop_type }}</td>
                  <td class="text-right text-caption">
                    {{ shop.credit_limit_amount != null ? formatBdt(shop.credit_limit_amount) : '—' }}
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>
      </template>
    </template>

    <WholesaleCollectPaymentDialog
      v-model="collectDialogOpen"
      :due-amount="collectDueAmount"
      :paid-amount="collectPaidAmount"
      :store-credit="collectStoreCredit"
      :saving="isCollecting"
      @submit="onCollectSubmit"
    />

    <WalletActionModal
      v-model="walletModalOpen"
      :action-type="walletActionType"
      entity-type="customer"
      :entity-id="effectiveBillingProfileId"
      :entity-name="groupName"
      :available-balance="summary?.store_credit_balance ?? 0"
      :submitting="isWalletSubmitting"
      @submit="onWalletSubmit"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import WholesaleCollectPaymentDialog from 'src/modules/sales_invoice/components/WholesaleCollectPaymentDialog.vue';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import WalletActionModal, {
  type WalletActionPayload,
  type WalletModalActionType,
} from 'src/modules/wallet/components/WalletActionModal.vue';
import { walletRepository } from 'src/modules/wallet/repositories/walletRepository';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';
import type {
  CustomerAccountOpenInvoice,
  CustomerAccountSummary,
} from '../types/customer';

const props = defineProps<{
  tenantId: number;
  customerGroupId: number;
  groupName: string;
  billingProfileId: number | null;
  summary: CustomerAccountSummary | null | undefined;
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
}>();

const emit = defineEmits<{
  (e: 'refresh'): void;
  (e: 'action-complete'): void;
}>();

const router = useRouter();
const route = useRoute();

const collectDialogOpen = ref(false);
const isCollecting = ref(false);
const selectedInvoice = ref<CustomerAccountOpenInvoice | null>(null);

const walletModalOpen = ref(false);
const walletActionType = ref<WalletModalActionType>('deposit');
const isWalletSubmitting = ref(false);

const effectiveBillingProfileId = computed(
  () => props.summary?.billing_profile_id ?? props.billingProfileId ?? 0,
);

const errorMessage = computed(() => props.error?.message || 'Failed to load account summary.');

const stillDueClass = computed(() =>
  Number(props.summary?.still_due ?? 0) > 0 ? 'text-negative' : 'text-grey-8',
);

const collectDueAmount = computed(() => Number(selectedInvoice.value?.due_amount ?? 0));
const collectPaidAmount = computed(() => Number(selectedInvoice.value?.paid_amount ?? 0));
const collectStoreCredit = computed(() => Number(props.summary?.store_credit_balance ?? 0));

type ActivityRow = {
  key: string;
  label: string;
  subtitle: string;
  amountText: string;
  amountClass: string;
};

const activityRows = computed<ActivityRow[]>(() => {
  const summary = props.summary;
  if (!summary) return [];

  const payments = (summary.recent_payments ?? []).map((p) => ({
    key: `pay-${p.payment_id}`,
    label: `Payment (${p.method})`,
    subtitle: `${p.payment_date}${p.invoice_id ? ` · Invoice #${p.invoice_id}` : ''}`,
    amountText: `+${formatBdt(p.amount)}`,
    amountClass: 'text-positive',
    sortAt: p.payment_date,
  }));

  const ledger = (summary.recent_ledger ?? []).map((l) => ({
    key: `led-${l.id}`,
    label: l.label || l.transaction_type || 'Wallet entry',
    subtitle: formatActivityDate(l.created_at),
    amountText: `${l.type === 'credit' ? '+' : '-'}${formatBdt(Number(l.amount))}`,
    amountClass: l.type === 'credit' ? 'text-positive' : 'text-negative',
    sortAt: l.created_at,
  }));

  return [...payments, ...ledger]
    .sort((a, b) => String(b.sortAt).localeCompare(String(a.sortAt)))
    .slice(0, 20)
    .map(({ key, label, subtitle, amountText, amountClass }) => ({
      key,
      label,
      subtitle,
      amountText,
      amountClass,
    }));
});

const formatBdt = (val?: number | null) => {
  const num = Number(val) || 0;
  return `${num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} BDT`;
};

const formatActivityDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

const openCollectForInvoice = (inv: CustomerAccountOpenInvoice | undefined) => {
  if (!inv) return;
  selectedInvoice.value = inv;
  collectDialogOpen.value = true;
};

const openWalletAction = (action: WalletModalActionType) => {
  walletActionType.value = action;
  walletModalOpen.value = true;
};

const onOpenFullWallet = () => {
  if (!effectiveBillingProfileId.value) return;
  void router.push({
    name: 'app-universal-wallet-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      walletType: 'customers',
      entityId: String(effectiveBillingProfileId.value),
    },
  });
};

const onCollectSubmit = async (payload: {
  cashAmount: number;
  cashMethod: string;
  walletAmount: number;
  settlementAmount: number;
}) => {
  if (!selectedInvoice.value) return;
  isCollecting.value = true;
  try {
    await invoiceRepository.collectWholesaleInvoicePayment({
      invoice_id: selectedInvoice.value.id,
      cash_amount: payload.cashAmount,
      cash_method: payload.cashMethod,
      wallet_amount: payload.walletAmount,
      settlement_amount: payload.settlementAmount,
    });
    showSuccessNotification('Payment recorded successfully.');
    collectDialogOpen.value = false;
    selectedInvoice.value = null;
    emit('action-complete');
  } catch (err: unknown) {
    showErrorNotification(parseSupabaseError(err, 'Failed to record payment.'));
  } finally {
    isCollecting.value = false;
  }
};

const onWalletSubmit = async (payload: WalletActionPayload) => {
  if (!effectiveBillingProfileId.value) return;
  isWalletSubmitting.value = true;
  try {
    const result = await walletRepository.recordManualTransaction({
      tenant_id: props.tenantId,
      action_type: payload.actionType,
      primary_entity_type: 'customer',
      primary_entity_id: effectiveBillingProfileId.value,
      amount: payload.amount,
      currency_code: payload.currency,
      exchange_rate: payload.exchangeRate,
      category: payload.category,
      payment_method: payload.paymentMethod,
      reference_id: payload.referenceId || null,
      note: payload.note || null,
      counterparty_entity_type: payload.targetEntityType || null,
      counterparty_entity_id: payload.targetEntityId || null,
      target_bucket: 'available',
    });

    if (result.success === false) {
      throw new Error(String(result.error || 'Transaction failed'));
    }

    showSuccessNotification('Wallet transaction recorded.');
    walletModalOpen.value = false;
    emit('action-complete');
  } catch (err: unknown) {
    showErrorNotification(parseSupabaseError(err, 'Failed to record wallet transaction.'));
  } finally {
    isWalletSubmitting.value = false;
  }
};
</script>

<style scoped>
.action-btn {
  border-radius: 8px !important;
}

.account-card {
  border-radius: 10px;
}

.account-card--due {
  border-left: 3px solid #ef4444;
}

.account-card--credit {
  border-left: 3px solid #22c55e;
}
</style>
