<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden bill-detail-page">
    <div v-if="detailQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="detailQuery.isError.value" class="col flex flex-center text-negative">
      {{ detailErrorMessage }}
    </div>

    <div v-else-if="bill" class="col overflow-auto bill-print-root">
      <div class="bill-detail-card q-pa-md">
        <div class="bill-page-actions row items-center justify-end q-gutter-sm no-print q-mb-md">
          <q-btn
            v-if="canRecordPayment"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-wallet"
            label="Add payment"
            @click="paymentDialogOpen = true"
          />
          <q-btn
            v-if="canIssueAp"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-file-arrow-up"
            label="Issue invoice"
            :loading="issueApMutation.isPending.value"
            @click="onIssueAp"
          />
          <q-btn
            v-if="canVoid"
            outline
            no-caps
            color="negative"
            icon="ph ph-prohibit"
            label="Void"
            :loading="voidMutation.isPending.value"
            @click="onVoid"
          />
          <q-btn
            unelevated
            no-caps
            color="primary"
            icon="ph ph-printer"
            label="Print"
            @click="onPrint"
          />
        </div>

        <div class="row items-start justify-between q-mb-md">
          <div>
            <div class="text-h6 text-weight-bold">{{ bill.invoice_no }}</div>
            <div class="text-caption text-grey-7 q-mt-xs">
              {{ channelLabel }} · {{ bill.invoice_date }}
              <span v-if="bill.due_date"> · Due {{ bill.due_date }}</span>
            </div>
          </div>
          <q-badge
            dense
            :color="channelTone.color"
            :text-color="channelTone.textColor"
            :label="statusLabel"
          />
        </div>

        <div class="q-mb-md">
          <ApBillPartiesBlock v-if="isApBill" :bill="bill" />
          <div v-else class="row q-col-gutter-md">
            <div class="col-12 col-sm-6">
              <div class="text-overline text-grey-7">To</div>
              <div class="text-subtitle2 text-weight-medium">{{ profileName }}</div>
              <div v-if="bill.profiles?.email" class="text-caption text-grey-7">
                {{ bill.profiles.email }}
              </div>
              <div v-if="bill.profiles?.address" class="text-caption text-grey-7">
                {{ bill.profiles.address }}
              </div>
            </div>
          </div>
        </div>

        <template v-if="isApBill">
          <ApBillPaper
            :channel-meta="bill.channel_meta"
            :ap-kind="bill.ap_kind"
            :total-amount="bill.total_amount"
          />
          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <template v-if="apCurrencyBalances">
                <div
                  v-for="(group, gIdx) in apCurrencyBalances"
                  :key="group.currency_code"
                  class="ap-bill-balance-group"
                  :class="{ 'ap-bill-balance-group--spaced': gIdx > 0 }"
                >
                  <div
                    v-if="apCurrencyBalances.length > 1"
                    class="text-caption text-weight-bold text-grey-8 q-mb-xs text-uppercase"
                    style="letter-spacing: 0.04em"
                  >
                    {{ group.currency_code }}
                  </div>
                  <div class="bill-total-row">
                    <span>Total</span>
                    <span class="font-mono">{{ group.totalLabel }}</span>
                  </div>
                  <div class="bill-total-row">
                    <span>Paid</span>
                    <span class="font-mono">{{ group.paidLabel }}</span>
                  </div>
                  <div class="bill-total-row text-weight-bold">
                    <span>Due</span>
                    <span class="font-mono">{{ group.dueLabel }}</span>
                  </div>
                </div>
              </template>
              <template v-else>
                <div class="bill-total-row text-weight-bold">
                  <span>Total</span>
                  <span>{{ formatAmountBdt(bill.total_amount) }}</span>
                </div>
                <div class="bill-total-row">
                  <span>Paid</span>
                  <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
                </div>
                <div class="bill-total-row text-weight-bold">
                  <span>Due</span>
                  <span>{{ formatAmountBdt(bill.due_amount) }}</span>
                </div>
              </template>
            </div>
          </div>
        </template>

        <template v-else>
          <q-markup-table flat dense class="bill-lines-table">
            <thead>
              <tr>
                <th class="text-left">Item</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Sell</th>
                <th class="text-right">Disc.</th>
                <th class="text-right">Line total</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="line in lines" :key="line.id">
                <td class="bill-line-item-cell">
                  <BillLineItemDisplay :name="line.name_snapshot" :image-url="line.image_url" />
                </td>
                <td class="text-right">{{ line.quantity }}</td>
                <td class="text-right">{{ formatAmountBdt(line.sell_price_amount) }}</td>
                <td class="text-right">{{ formatAmountBdt(line.line_discount_amount) }}</td>
                <td class="text-right text-weight-medium">{{ formatAmountBdt(line.line_total_amount) }}</td>
              </tr>
            </tbody>
          </q-markup-table>

          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <div v-if="bill.discount_amount" class="bill-total-row">
                <span>Discount</span>
                <span>{{ formatAmountBdt(bill.discount_amount) }}</span>
              </div>
              <div v-if="bill.shipping_charge" class="bill-total-row">
                <span>Shipping</span>
                <span>{{ formatAmountBdt(bill.shipping_charge) }}</span>
              </div>
              <div v-if="bill.wrapping_charge" class="bill-total-row">
                <span>Wrapping</span>
                <span>{{ formatAmountBdt(bill.wrapping_charge) }}</span>
              </div>
              <div v-if="bill.print_charge" class="bill-total-row">
                <span>Print</span>
                <span>{{ formatAmountBdt(bill.print_charge) }}</span>
              </div>
              <div class="bill-total-row text-weight-bold">
                <span>Total</span>
                <span>{{ formatAmountBdt(bill.total_amount) }}</span>
              </div>
              <div class="bill-total-row">
                <span>Paid</span>
                <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
              </div>
              <div class="bill-total-row text-weight-bold">
                <span>Due</span>
                <span>{{ formatAmountBdt(bill.due_amount) }}</span>
              </div>
            </div>
          </div>
        </template>

        <div v-if="bill.note" class="q-mt-md">
          <div class="text-overline text-grey-7">Note</div>
          <div class="text-body2">{{ bill.note }}</div>
        </div>

        <div class="q-mt-lg no-print bill-payment-history">
          <div class="text-overline text-grey-7 q-mb-sm">Payment history</div>
          <div v-if="paymentHistoryQuery.isPending.value" class="text-caption text-grey-6">
            Loading…
          </div>
          <div
            v-else-if="!paymentHistoryEntries.length"
            class="text-caption text-grey-6 q-pa-sm rounded-borders bg-grey-1"
          >
            No payments recorded on this bill yet.
          </div>
          <q-list v-else bordered separator class="rounded-borders">
            <q-item
              v-for="entry in paymentHistoryEntries"
              :key="`${entry.entry_type}-${entry.entry_id}`"
              :clickable="!!entry.payment_id && !entry.voided_at"
              @click="entry.payment_id && !entry.voided_at ? goToPayment(entry.payment_id) : undefined"
            >
              <q-item-section>
                <q-item-label>
                  {{ entry.payment_date }}
                  <span v-if="entry.voided_at" class="text-negative"> · Voided</span>
                </q-item-label>
                <q-item-label caption>
                  {{ paymentEntryCaption(entry) }}
                </q-item-label>
                <q-item-label
                  v-if="paymentEntryFxCaption(entry)"
                  caption
                  class="text-grey-7"
                >
                  {{ paymentEntryFxCaption(entry) }}
                </q-item-label>
              </q-item-section>
              <q-item-section side class="text-right">
                <q-item-label class="text-weight-medium font-mono">
                  {{ paymentHistoryPrimaryAmount(entry) }}
                </q-item-label>
                <q-item-label
                  v-if="paymentHistoryBdtOnBillLabel(entry)"
                  caption
                  class="font-mono text-grey-7"
                >
                  On this bill {{ paymentHistoryBdtOnBillLabel(entry) }}
                </q-item-label>
                <q-item-label
                  v-else-if="entry.receipt_amount && entry.receipt_amount !== entry.amount"
                  caption
                  class="font-mono text-grey-7"
                >
                  Payment {{ formatBdtTaka(entry.receipt_amount) }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </div>
      </div>
    </div>

    <RecordBillPaymentDialog
      v-if="bill && billProfileId"
      v-model="paymentDialogOpen"
      :bill-id="bill.id"
      :due-amount="Number(bill.due_amount ?? 0)"
      :profile-id="billProfileId"
      :tenant-id="operatingTenantId"
      :is-ap="isApBill"
      :channel-meta="(bill.channel_meta as Record<string, unknown> | null) ?? null"
      :loading="recordPaymentMutation.isPending.value"
      @submit="onRecordPayment"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { formatAmountBdt, formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';
import { requestConfirmation } from 'src/utils/appFeedback';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow, GlobalInvoiceRow } from 'src/modules/sales_invoice/types';
import {
  invoiceChannelLabel,
  invoiceChannelTone,
  invoiceListStatusLabel,
} from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import { useBillDetailQuery } from '../composables/useBillDetailQuery';
import { useBillPaymentHistoryQuery } from '../composables/useBillPaymentHistoryQuery';
import { useIssueApBillMutation } from '../composables/useIssueApBillMutation';
import { useRecordBillPaymentMutation } from '../composables/useRecordBillPaymentMutation';
import { useVoidBillMutation } from '../composables/useVoidBillMutation';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';
import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import type { ShipmentApKind } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import ApBillPartiesBlock from '../components/ApBillPartiesBlock.vue';
import RecordBillPaymentDialog from '../components/RecordBillPaymentDialog.vue';
import { syncShipmentApBills } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';
import { apBillCurrencyBalances, isLegacyApPaperSnapshot } from '../utils/parseApBillPaper';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const { detailQuery, itemsQuery } = useBillDetailQuery(billId);
const voidMutation = useVoidBillMutation(() => billId.value);
const issueApMutation = useIssueApBillMutation(() => billId.value);
const recordPaymentMutation = useRecordBillPaymentMutation(() => billId.value);

const operatingTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});

const paymentHistoryQuery = useBillPaymentHistoryQuery(billId, operatingTenantId);
const paymentHistoryEntries = computed(
  () => (paymentHistoryQuery.data.value ?? []) as InvoicePaymentHistoryEntry[],
);

const paymentDialogOpen = ref(false);

const bill = computed(() => detailQuery.data.value as GlobalInvoiceDetail | undefined);
const isApBill = computed(() => bill.value?.invoice_type === 'ap');

const apCurrencyBalances = computed(() => {
  if (!isApBill.value || !bill.value) return null;
  return apBillCurrencyBalances(
    bill.value.channel_meta as Record<string, unknown> | null,
    bill.value.paid_amount,
    bill.value.due_amount,
  );
});
const lines = computed(() => (itemsQuery.data.value ?? []) as GlobalInvoiceItemRow[]);

const profileName = computed(
  () => bill.value?.profiles?.name || bill.value?.recipient_name || '—',
);

const channelLabel = computed(() =>
  bill.value ? invoiceChannelLabel(bill.value as GlobalInvoiceRow) : '',
);
const channelTone = computed(() =>
  bill.value ? invoiceChannelTone(bill.value as GlobalInvoiceRow) : { color: 'grey-3', textColor: 'grey-9' },
);
const statusLabel = computed(() =>
  bill.value ? invoiceListStatusLabel(bill.value as GlobalInvoiceRow) : '',
);

const canVoid = computed(
  () =>
    bill.value?.invoice_status === 'issued' &&
    Number(bill.value.paid_amount ?? 0) === 0,
);

const billProfileId = computed(() => {
  const b = bill.value;
  if (!b) return null;
  return b.profile_id ?? (b as { profile_id?: number }).profile_id ?? null;
});

const canRecordPayment = computed(() => {
  const b = bill.value;
  if (!b || b.invoice_status !== 'issued') return false;
  if (b.invoice_status === 'voided') return false;
  if (!billProfileId.value) return false;
  return Number(b.due_amount ?? 0) > 0;
});

const canIssueAp = computed(() => {
  const b = bill.value;
  if (!b || b.invoice_type !== 'ap') return false;
  if (b.invoice_status !== 'draft') return false;
  if (!b.ap_shipment_id || !b.ap_kind) return false;
  return Number(b.total_amount ?? 0) > 0;
});

const onIssueAp = async () => {
  const b = bill.value;
  if (!canIssueAp.value || !b?.ap_shipment_id || !b.ap_kind) return;
  await issueApMutation.mutateAsync({
    shipmentId: b.ap_shipment_id,
    apKind: b.ap_kind as ShipmentApKind,
  });
};

const detailErrorMessage = computed(() => {
  const err = detailQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load bill.';
});

const billLeafLabel = computed(() => {
  const no = bill.value?.invoice_no?.trim();
  if (no) return no;
  return billId.value ? `Bill #${billId.value}` : 'Bill';
});

const breadcrumbItems = computed(() => {
  const tenantSlug =
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
    authStore.tenantSlug ||
    undefined;
  return [
    {
      label: authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    {
      label: 'Bills',
      to: {
        name: 'app-bills-page',
        ...(tenantSlug ? { params: { tenantSlug } } : {}),
      },
    },
    { label: billLeafLabel.value },
  ];
});

watch(breadcrumbItems, (items) => setCustomBreadcrumbs(items), { immediate: true });
onBeforeUnmount(() => clearCustomBreadcrumbs());

const apPaperRefreshKey = ref<string | null>(null);

watch(
  bill,
  (b) => {
    if (!b || b.invoice_type !== 'ap' || !b.ap_shipment_id) return;
    if (Number(b.paid_amount ?? 0) > 0) return;
    if (!isLegacyApPaperSnapshot(b.channel_meta as Record<string, unknown> | null)) return;

    const key = `${b.id}:${b.ap_shipment_id}`;
    if (apPaperRefreshKey.value === key) return;
    apPaperRefreshKey.value = key;

    void (async () => {
      try {
        await syncShipmentApBills(b.ap_shipment_id!);
        await detailQuery.refetch();
      } catch {
        apPaperRefreshKey.value = null;
      }
    })();
  },
  { immediate: true },
);

const onPrint = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  const id = billId.value;
  if (!id) return;
  router.push({
    name: 'app-bill-preview-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(id),
    },
  });
};

const onVoid = async () => {
  if (!canVoid.value) return;
  const ok = await requestConfirmation(
    'Stock on this bill will be restored. This cannot be undone.',
    'Void this bill?',
  );
  if (!ok) return;
  await voidMutation.mutateAsync();
};

const paymentEntryCaption = (entry: InvoicePaymentHistoryEntry) => {
  if (entry.entry_type === 'write_off') {
    return entry.write_off_reason ? `Write-off · ${entry.write_off_reason}` : 'Write-off';
  }
  const method = entry.method?.replace(/_/g, ' ') ?? 'Payment';
  return method;
};

const paymentSettlementCode = (entry: InvoicePaymentHistoryEntry) =>
  (entry.settlement_currency_code ?? 'BDT').toUpperCase();

const isForeignSettlementPayment = (entry: InvoicePaymentHistoryEntry) => {
  const foreign = Number(entry.foreign_amount ?? 0);
  return paymentSettlementCode(entry) !== 'BDT' && foreign > 0;
};

const proratedForeignForBillAllocation = (entry: InvoicePaymentHistoryEntry): number => {
  const foreign = Number(entry.foreign_amount) || 0;
  const receiptBdt = Number(entry.receipt_amount) || 0;
  const allocBdt = Number(entry.amount) || 0;
  if (receiptBdt > 0 && allocBdt > 0 && Math.abs(allocBdt - receiptBdt) > 0.005) {
    return Math.round((foreign * allocBdt) / receiptBdt * 100) / 100;
  }
  return foreign;
};

const paymentHistoryPrimaryAmount = (entry: InvoicePaymentHistoryEntry) => {
  if (!isForeignSettlementPayment(entry)) {
    return formatBdtTaka(entry.amount);
  }
  return formatSettlementCurrencyAmount(
    proratedForeignForBillAllocation(entry),
    paymentSettlementCode(entry),
  );
};

const paymentHistoryBdtOnBillLabel = (entry: InvoicePaymentHistoryEntry): string | null => {
  if (!isForeignSettlementPayment(entry)) return null;
  return formatBdtTaka(entry.amount);
};

const paymentEntryFxCaption = (entry: InvoicePaymentHistoryEntry): string | null => {
  if (!isForeignSettlementPayment(entry)) return null;
  const rate = entry.exchange_rate ?? 1;
  const receiptBdt = Number(entry.receipt_amount) || 0;
  const parts = [`Rate ${rate} BDT per 1 ${paymentSettlementCode(entry)}`];
  if (receiptBdt > 0) {
    parts.push(`Payment total ${formatBdtTaka(receiptBdt)}`);
  }
  return parts.join(' · ');
};

const goToPayment = (paymentId: number) => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-pay-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      payId: String(paymentId),
    },
  });
};

const onRecordPayment = async (payload: RecordBillPaymentInput) => {
  await recordPaymentMutation.mutateAsync(payload);
  paymentDialogOpen.value = false;
};
</script>

<style scoped lang="scss">
.page-fixed-layout {
  height: calc(100vh - 55px);
}

.bill-detail-card {
  max-width: 960px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: var(--bw-radius-sm, 8px);
}

.bill-totals-panel {
  min-width: 220px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
}

.bill-total-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}

.ap-bill-balance-group--spaced {
  margin-top: 0.65rem;
  padding-top: 0.65rem;
  border-top: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.bill-lines-table th {
  font-size: 11px;
  color: var(--bw-neutral-chrome, #64748b);
  font-weight: 600;
}

.bill-line-item-cell {
  vertical-align: top;
  max-width: 320px;
}

.bill-page-actions :deep(.q-btn) {
  min-height: 36px;
  padding: 0 14px;
}

@media print {
  .no-print {
    display: none !important;
  }

  .bill-detail-page {
    height: auto !important;
    overflow: visible !important;
  }

  .bill-print-root {
    overflow: visible !important;
  }

  .bill-detail-card {
    border: none;
    box-shadow: none;
  }
}
</style>

<style lang="scss">
@media print {
  .q-header,
  .q-drawer,
  .q-footer,
  .workspace-shell-toolbar {
    display: none !important;
  }

  .q-page-container {
    padding-top: 0 !important;
  }
}
</style>
