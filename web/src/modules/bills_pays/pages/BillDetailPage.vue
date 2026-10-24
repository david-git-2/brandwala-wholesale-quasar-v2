<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden bill-detail-page">
    <div v-if="bundleQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="bundleQuery.isError.value" class="col flex flex-center text-negative">
      {{ detailErrorMessage }}
    </div>

    <div v-else-if="bill" class="col overflow-auto bill-print-root">
      <div class="bill-detail-card q-pa-md">
        <div class="bill-page-actions row items-center justify-end q-gutter-sm no-print q-mb-md">
          <q-btn
            v-if="canAddAdjustment && !adjustmentComposerOpen"
            outline
            no-caps
            color="primary"
            icon="ph ph-file-minus"
            label="Add credit/debit note"
            @click="adjustmentComposerOpen = true"
          />
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
            v-if="canRecordVendorRefund"
            outline
            no-caps
            color="primary"
            icon="ph ph-arrow-down-left"
            label="Record vendor refund"
            @click="openVendorRefund()"
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
          <div class="column q-gutter-y-xs">
            <div>
              <div v-if="!isStandardBill" class="text-subtitle2 text-weight-bold q-mb-xs">
                {{ adjustmentKindLabel(billDocumentKind) }}
              </div>
              <div class="text-h6 text-weight-bold">{{ bill.invoice_no }}</div>
              <div v-if="parentInvoiceNoFromMeta" class="text-caption text-grey-8">
                Against {{ parentInvoiceNoFromMeta }}
              </div>
              <div class="text-caption text-grey-7 q-mt-xs">
                {{ channelLabel }} · {{ bill.invoice_date }}
                <span v-if="bill.due_date"> · Due {{ bill.due_date }}</span>
                <span v-if="bill.currency_code"> · {{ bill.currency_code }}</span>
              </div>
            </div>
            <BillKernelSourceChips
              v-if="isApBill"
              :source-type="bill.source_type"
              :source-id="bill.source_id"
              :source-key="bill.source_key ?? bill.ap_kind"
            />
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

        <template v-if="isApBill && !isStandardBill">
          <q-banner
            v-if="billDocumentKind === 'credit_note' && Number(bill.due_amount ?? 0) > 0"
            dense
            rounded
            class="bg-blue-1 text-blue-10 q-mb-md no-print"
          >
            Open vendor credit. Use Record vendor refund when they return cash.
          </q-banner>
          <BillAdjustmentLinesTable
            :lines="adjustmentLineRows"
            :header-total-bdt="bill.total_amount"
          />
          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <div class="bill-total-row text-weight-bold">
                <span>Note amount</span>
                <span>{{ formatAmountBdt(bill.total_amount) }}</span>
              </div>
              <div class="bill-total-row">
                <span>Refund received</span>
                <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
              </div>
              <div class="bill-total-row text-weight-bold">
                <span>Vendor still owes you</span>
                <span>{{ formatAmountBdt(bill.due_amount) }}</span>
              </div>
            </div>
          </div>
        </template>

        <template v-else-if="isApBill && isStandardBill">
          <ApBillPaper
            :channel-meta="bill.channel_meta"
            :ap-kind="bill.source_key ?? bill.ap_kind"
            :total-amount="bill.total_amount"
            :note-edit-mode="adjustmentComposerOpen"
            :draft-rows="draftRows"
            @add-extra-line="(code) => addExtraRow(code)"
            @note-amount="onNoteAmountInput"
          />
          <BillAdjustmentNoteBar
            v-if="adjustmentComposerOpen"
            v-model:kind="kind"
            v-model:reason="reason"
            :note-total-labels="noteTotalLabels"
            :balance-effect="balanceEffect"
            :submit-disabled-reason="submitDisabledReason"
            :loading="createAdjustmentMutation.isPending.value"
            @cancel="adjustmentComposerOpen = false"
            @submit="submitAdjustment"
          />
          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <BillNetSettlementPanel
                :balances="netBalances"
                :is-ap="true"
                :loading="bundleQuery.isFetching.value"
                :channel-meta="(bill.channel_meta as Record<string, unknown> | null) ?? null"
                :open-credit-note-nos="openApCreditNoteNos"
                :vendor-refund-receipts="vendorRefundReceiptBuckets"
              />
            </div>
          </div>
        </template>

        <template v-else>
          <q-banner
            v-if="!isStandardBill && billDocumentKind === 'credit_note' && Number(bill.due_amount ?? 0) > 0"
            dense
            rounded
            class="bg-blue-1 text-blue-10 q-mb-md no-print"
          >
            Open customer credit on this note. Refund or apply later.
          </q-banner>
          <q-markup-table flat dense class="bill-lines-table">
            <thead>
              <tr>
                <th class="text-left">Item</th>
                <th class="text-right">Qty</th>
                <th class="text-right">Sell</th>
                <th class="text-right">Disc.</th>
                <th class="text-right">Line total</th>
                <th v-if="adjustmentComposerOpen" class="text-right">Revised (BDT)</th>
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
                <td v-if="adjustmentComposerOpen" class="text-right">
                  <q-input
                    v-if="draftByKey(`stock-${line.id}`)"
                    :model-value="draftByKey(`stock-${line.id}`)!.revisedAmount"
                    dense
                    outlined
                    type="number"
                    step="0.01"
                    min="0"
                    class="note-amount-input"
                    :placeholder="formatAmountBdt(line.line_total_amount)"
                    @update:model-value="
                      (v) =>
                        onNoteAmountInput(draftByKey(`stock-${line.id}`)!, v as number | null)
                    "
                  />
                </td>
              </tr>
              <tr
                v-for="chargeRow in arChargeDraftRows"
                :key="chargeRow.key"
              >
                <td>{{ chargeRow.name }}</td>
                <td />
                <td />
                <td />
                <td class="text-right font-mono">
                  {{ formatAmountBdt(chargeRow.maxAmount ?? 0) }}
                </td>
                <td v-if="adjustmentComposerOpen" class="text-right">
                  <q-input
                    :model-value="chargeRow.revisedAmount"
                    dense
                    outlined
                    type="number"
                    step="0.01"
                    min="0"
                    class="note-amount-input"
                    :placeholder="formatAmountBdt(chargeRow.maxAmount ?? 0)"
                    @update:model-value="
                      (v) => onNoteAmountInput(chargeRow, v as number | null)
                    "
                  />
                </td>
              </tr>
              <tr
                v-for="extra in extraDraftRows"
                :key="extra.key"
              >
                <td>
                  <q-input v-model="extra.name" dense outlined placeholder="Description" />
                </td>
                <td colspan="3" />
                <td />
                <td v-if="adjustmentComposerOpen" class="text-right">
                  <q-input
                    :model-value="extra.amount"
                    dense
                    outlined
                    type="number"
                    step="0.01"
                    min="0"
                    class="note-amount-input"
                    placeholder="0"
                    @update:model-value="
                      (v) => onNoteAmountInput(extra, v as number | null)
                    "
                  />
                </td>
              </tr>
            </tbody>
          </q-markup-table>
          <div v-if="adjustmentComposerOpen" class="q-mt-xs no-print">
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              icon="ph ph-plus"
              label="Add line"
              @click="addExtraRow('BDT')"
            />
          </div>
          <BillAdjustmentNoteBar
            v-if="adjustmentComposerOpen"
            v-model:kind="kind"
            v-model:reason="reason"
            :note-total-labels="noteTotalLabels"
            :balance-effect="balanceEffect"
            :submit-disabled-reason="submitDisabledReason"
            :loading="createAdjustmentMutation.isPending.value"
            @cancel="adjustmentComposerOpen = false"
            @submit="submitAdjustment"
          />

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
              <BillNetSettlementPanel
                v-if="isStandardBill"
                :balances="netBalances"
                :is-ap="false"
                :loading="bundleQuery.isFetching.value"
              />
            </div>
          </div>
        </template>

        <div v-if="bill.note" class="q-mt-md">
          <div class="text-overline text-grey-7">Note</div>
          <div class="text-body2">{{ bill.note }}</div>
        </div>

        <div v-if="isStandardBill" class="q-mt-lg no-print">
          <div class="text-overline text-grey-7 q-mb-sm">Credit / debit notes</div>
          <div v-if="bundleQuery.isPending.value" class="text-caption text-grey-6">
            Loading…
          </div>
          <div
            v-else-if="!adjustmentRows.length"
            class="text-caption text-grey-6 q-pa-sm rounded-borders bg-grey-1"
          >
            No credit or debit notes on this bill.
          </div>
          <q-list v-else bordered separator class="rounded-borders">
            <q-item
              v-for="row in adjustmentRows"
              :key="row.id"
              clickable
              @click="goToBill(row.id)"
            >
              <q-item-section>
                <q-item-label>
                  {{ row.invoice_no }}
                  · {{ adjustmentKindLabel(row.document_kind) }}
                </q-item-label>
                <q-item-label caption>
                  {{ row.invoice_date }}
                  · {{ invoiceListStatusLabel(row as GlobalInvoiceRow) }}
                </q-item-label>
                <q-item-label v-if="row.note" caption>{{ row.note }}</q-item-label>
                <q-item-label
                  v-if="row.document_kind === 'credit_note' && Number(row.due_amount ?? 0) > 0"
                  caption
                  class="text-primary"
                >
                  Open — {{ isApBill ? 'vendor credit' : 'customer credit' }}
                  · {{ formatAmountBdt(row.due_amount) }} remaining
                </q-item-label>
              </q-item-section>
              <q-item-section side class="text-right">
                <q-item-label class="text-weight-medium font-mono">
                  {{ formatAmountBdt(row.total_amount) }}
                </q-item-label>
                <q-item-label
                  v-if="Number(row.due_amount ?? 0) > 0"
                  caption
                  class="font-mono text-grey-7"
                >
                  Remaining {{ formatAmountBdt(row.due_amount) }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div class="q-mt-lg no-print bill-payment-history">
          <div class="text-overline text-grey-7 q-mb-sm">Payment history</div>
          <div v-if="bundleQuery.isPending.value" class="text-caption text-grey-6">
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
                  v-if="paymentHistoryFxLine(entry)"
                  caption
                  class="text-grey-7"
                >
                  {{ paymentHistoryFxLine(entry) }}
                </q-item-label>
              </q-item-section>
              <q-item-section side class="text-right">
                <q-item-label class="text-weight-medium font-mono">
                  {{ paymentHistoryPrimaryAmount(entry) }}
                </q-item-label>
                <q-item-label
                  v-if="paymentHistoryBdtSideCaption(entry)"
                  caption
                  class="font-mono text-grey-7"
                >
                  {{ paymentHistoryBdtSideCaption(entry) }}
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
      :due-amount="paymentDueAmount"
      :due-currency-code="paymentDueCurrencyCode"
      :profile-id="billProfileId"
      :tenant-id="operatingTenantId"
      :books-tenant-id="operatingTenantId"
      :is-ap="isApBill"
      :channel-meta="(bill.channel_meta as Record<string, unknown> | null) ?? null"
      :loading="recordPaymentMutation.isPending.value"
      @submit="onRecordPayment"
    />
    <RecordVendorCreditRefundDialog
      v-if="vendorRefundTargetId"
      v-model="vendorRefundDialogOpen"
      :credit-note-id="vendorRefundTargetId"
      :parent-bill-id="vendorRefundParentId"
      :open-credit="vendorRefundOpenAmount"
      :books-tenant-id="operatingTenantId"
      :from-profile-name="profileName"
      :tenant-label="authStore.selectedTenant?.name ?? 'Our books'"
      :channel-meta="(bill?.channel_meta as Record<string, unknown> | null) ?? null"
      :loading="vendorRefundMutation.isPending.value"
      @submit="onVendorRefund"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { formatAmountBdt, formatBdtTaka } from 'src/utils/currency';
import { requestConfirmation } from 'src/utils/appFeedback';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow, GlobalInvoiceRow } from 'src/modules/sales_invoice/types';
import {
  invoiceChannelLabel,
  invoiceChannelTone,
  invoiceListStatusLabel,
} from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import { useBillDetailBundleQuery } from '../composables/useBillDetailBundleQuery';
import { useBillDetailQuery } from '../composables/useBillDetailQuery';
import { useIssueApBillMutation } from '../composables/useIssueApBillMutation';
import { useRecordBillPaymentMutation } from '../composables/useRecordBillPaymentMutation';
import { useVoidBillMutation } from '../composables/useVoidBillMutation';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';
import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import {
  aggregateVendorRefundReceipts,
  formatPaymentHistoryBooksCaption,
  formatPaymentHistoryPrimary,
  paymentHistoryEntryCaption,
  paymentHistoryFxCaption,
} from '../utils/paymentHistoryDisplay';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import ApBillPartiesBlock from '../components/ApBillPartiesBlock.vue';
import BillKernelSourceChips from '../components/BillKernelSourceChips.vue';
import RecordBillPaymentDialog from '../components/RecordBillPaymentDialog.vue';
import RecordVendorCreditRefundDialog from '../components/RecordVendorCreditRefundDialog.vue';
import { usePostVendorCreditRefundMutation } from '../composables/usePostVendorCreditRefundMutation';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';
import BillAdjustmentNoteBar from '../components/BillAdjustmentNoteBar.vue';
import BillAdjustmentLinesTable from '../components/BillAdjustmentLinesTable.vue';
import BillNetSettlementPanel from '../components/BillNetSettlementPanel.vue';
import type { BillLineDisplayRow } from '../repositories/billLinesRepository';
import { useBillAdjustmentDraft } from '../composables/useBillAdjustmentDraft';
import { useCreateBillAdjustmentMutation } from '../composables/useCreateBillAdjustmentMutation';
import { syncShipmentApBills } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';
import { apBillDueStoresForeignFace } from '../utils/apBillBooks';
import {
  apBillCurrencyBalances,
  apBillPaperCurrencyCode,
  isLegacyApPaperSnapshot,
} from '../utils/parseApBillPaper';
import type { BillNetBalances } from '../composables/useBillNetBalancesQuery';
import type { BillAdjustmentRow } from '../composables/useBillAdjustmentsQuery';
import {
  isShipmentCostApBill,
  shipmentApKindFromBill,
  shipmentIdFromBill,
} from '../utils/shipmentApBillSource';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const operatingTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});

const bundleQuery = useBillDetailBundleQuery(billId, operatingTenantId);
const billFromBundle = computed(() => bundleQuery.data.value?.bill);
const { itemsQuery, billLinesQuery } = useBillDetailQuery(billId, billFromBundle);
const voidMutation = useVoidBillMutation(() => billId.value);
const issueApMutation = useIssueApBillMutation(() => billId.value);
const recordPaymentMutation = useRecordBillPaymentMutation(() => billId.value);
const vendorRefundMutation = usePostVendorCreditRefundMutation(() => billId.value);
const createAdjustmentMutation = useCreateBillAdjustmentMutation(() => billId.value);

const paymentHistoryEntries = computed(
  () => (bundleQuery.data.value?.paymentHistory ?? []) as InvoicePaymentHistoryEntry[],
);

const paymentDialogOpen = ref(false);
const vendorRefundDialogOpen = ref(false);
const vendorRefundNoteId = ref<number | null>(null);
const adjustmentComposerOpen = ref(false);

const bill = computed(() => billFromBundle.value as GlobalInvoiceDetail | undefined);
const isApBill = computed(() => bill.value?.invoice_type === 'ap');

const vendorRefundReceiptBuckets = computed(() =>
  aggregateVendorRefundReceipts(paymentHistoryEntries.value, { isAp: isApBill.value }),
);

const lines = computed(() => (itemsQuery.data.value ?? []) as GlobalInvoiceItemRow[]);

const parentDueAmount = computed(() => Number(bill.value?.due_amount ?? 0));

const billDocumentKind = computed(() => {
  const b = bill.value as { document_kind?: string } | undefined;
  return b?.document_kind ?? 'standard';
});
const isStandardBill = computed(() => billDocumentKind.value === 'standard');

const parentInvoiceNoFromMeta = computed(() => {
  const meta = bill.value?.channel_meta as Record<string, unknown> | null;
  const adj = meta?.adjustment as Record<string, unknown> | undefined;
  const fromMeta = adj?.parent_invoice_no;
  return typeof fromMeta === 'string' && fromMeta.trim() ? fromMeta.trim() : null;
});

const adjustmentLineRows = computed((): BillLineDisplayRow[] => {
  if (!isStandardBill.value && isApBill.value) {
    return billLinesQuery.data.value ?? [];
  }
  if (!isStandardBill.value && !isApBill.value) {
    return lines.value.map((line) => ({
      id: line.id,
      name_snapshot: line.name_snapshot ?? 'Line',
      currency_code: 'BDT',
      line_total_amount: Number(line.line_total_amount ?? 0),
      books_amount: Number(line.line_total_amount ?? 0),
      quantity: Number(line.quantity ?? 1),
    }));
  }
  return [];
});

const netBalances = computed(
  () => bundleQuery.data.value?.netBalances as BillNetBalances | undefined,
);

const adjustmentRows = computed(
  () => (bundleQuery.data.value?.adjustments ?? []) as BillAdjustmentRow[],
);

const openApCreditNoteNos = computed(() =>
  adjustmentRows.value
    .filter((r) => r.document_kind === 'credit_note' && Number(r.due_amount ?? 0) > 0)
    .map((r) => r.invoice_no),
);

const {
  kind,
  reason,
  draftRows,
  draftByKey,
  onNoteAmountInput,
  addExtraRow,
  extraDraftRows,
  arChargeDraftRows,
  noteTotalLabels,
  balanceEffect,
  submitDisabledReason,
  buildSubmitPayload,
} = useBillAdjustmentDraft({
  bill,
  stockLines: lines,
  isAp: isApBill,
  parentDueAmount,
  siblingNotes: adjustmentRows,
  active: adjustmentComposerOpen,
});

const apCurrencyBalances = computed(() => {
  if (!isApBill.value || !bill.value) return null;
  return apBillCurrencyBalances(
    bill.value.channel_meta as Record<string, unknown> | null,
    bill.value.paid_amount,
    bill.value.due_amount,
  );
});

const apBillSettlementCurrency = computed(() => {
  if (apCurrencyBalances.value?.[0]?.currency_code) {
    return apCurrencyBalances.value[0].currency_code;
  }
  if (!isApBill.value || !bill.value) return null;
  const code = apBillPaperCurrencyCode(bill.value.channel_meta as Record<string, unknown> | null);
  return code !== 'BDT' ? code : null;
});

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

const canAddAdjustment = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  return b.invoice_status === 'issued';
});

const billProfileId = computed(() => {
  const b = bill.value;
  if (!b) return null;
  return b.profile_id ?? (b as { profile_id?: number }).profile_id ?? null;
});

const paymentDueAmount = computed(() => {
  const nb = netBalances.value;
  if (nb?.due_amount != null) return Math.max(0, Number(nb.due_amount));
  return Math.max(0, Number(bill.value?.due_amount ?? 0));
});

const paymentDueCurrencyCode = computed(() => {
  const b = bill.value;
  if (!b) return null;
  const due = paymentDueAmount.value;
  const meta = (b.channel_meta as Record<string, unknown> | null) ?? null;
  if (isApBill.value && apBillDueStoresForeignFace(meta, due)) {
    return apBillPaperCurrencyCode(meta);
  }
  const header = String(b.currency_code ?? '').trim();
  if (header) return header.toUpperCase();
  return 'BDT';
});

const vendorRefundTargetId = computed(() => {
  if (vendorRefundNoteId.value) return vendorRefundNoteId.value;
  if (isApBill.value && billDocumentKind.value === 'credit_note') return billId.value;
  return null;
});

const vendorRefundParentId = computed(() => {
  const b = bill.value;
  if (billDocumentKind.value === 'credit_note') {
    return (b as { parent_bill_id?: number | null } | undefined)?.parent_bill_id ?? null;
  }
  return billId.value;
});

const vendorRefundOpenAmount = computed(() => {
  const id = vendorRefundTargetId.value;
  if (!id) return 0;
  if (isApBill.value && billDocumentKind.value === 'credit_note' && id === billId.value) {
    return Math.max(0, Number(bill.value?.due_amount ?? 0));
  }
  const row = adjustmentRows.value.find((r) => r.id === id);
  return Math.max(0, Number(row?.due_amount ?? 0));
});

const canRecordVendorRefund = computed(() => {
  if (!isApBill.value) return false;
  const b = bill.value;
  if (!b || b.invoice_status !== 'issued') return false;
  if (billDocumentKind.value === 'credit_note') {
    return Number(b.due_amount ?? 0) > 0;
  }
  if (!isStandardBill.value) return false;
  return Number(netBalances.value?.credit_open ?? 0) > 0;
});

function openVendorRefund(noteId?: number) {
  if (noteId) {
    vendorRefundNoteId.value = noteId;
  } else if (billDocumentKind.value === 'credit_note') {
    vendorRefundNoteId.value = billId.value;
  } else {
    const firstOpen = adjustmentRows.value.find(
      (r) => r.document_kind === 'credit_note' && Number(r.due_amount ?? 0) > 0,
    );
    vendorRefundNoteId.value = firstOpen?.id ?? null;
  }
  vendorRefundDialogOpen.value = true;
}

const canRecordPayment = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  if (!billProfileId.value) return false;
  return paymentDueAmount.value > 0;
});

const canIssueAp = computed(() => {
  const b = bill.value;
  if (!b || b.invoice_type !== 'ap') return false;
  if (b.invoice_status !== 'draft') return false;
  if (!isShipmentCostApBill(b)) return false;
  if (!shipmentIdFromBill(b) || !shipmentApKindFromBill(b)) return false;
  return Number(b.total_amount ?? 0) > 0;
});

const onIssueAp = async () => {
  const b = bill.value;
  const shipmentId = shipmentIdFromBill(b);
  const apKind = shipmentApKindFromBill(b);
  if (!canIssueAp.value || shipmentId == null || !apKind) return;
  await issueApMutation.mutateAsync({
    shipmentId,
    apKind,
  });
};

const detailErrorMessage = computed(() => {
  const err = bundleQuery.error.value;
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
        await bundleQuery.refetch();
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

const paymentEntryCaption = (entry: InvoicePaymentHistoryEntry) =>
  paymentHistoryEntryCaption(entry, { isAp: isApBill.value });

const paymentHistoryPrimaryAmount = (entry: InvoicePaymentHistoryEntry) =>
  formatPaymentHistoryPrimary(entry, apBillSettlementCurrency.value);

const paymentHistoryFxLine = (entry: InvoicePaymentHistoryEntry) =>
  paymentHistoryFxCaption(entry, apBillSettlementCurrency.value);

const paymentHistoryBdtSideCaption = (entry: InvoicePaymentHistoryEntry): string | null =>
  formatPaymentHistoryBooksCaption(entry, apBillSettlementCurrency.value);

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

const goToBill = (id: number) => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(id),
    },
  });
};

const adjustmentKindLabel = (kind: string) => {
  if (kind === 'credit_note') return 'Credit note';
  if (kind === 'debit_note') return 'Debit note';
  return kind;
};

const onRecordPayment = async (payload: RecordBillPaymentInput) => {
  paymentDialogOpen.value = false;
  await recordPaymentMutation.mutateAsync(payload);
};

const onVendorRefund = async (payload: PostVendorCreditRefundInput) => {
  await vendorRefundMutation.mutateAsync(payload);
  vendorRefundDialogOpen.value = false;
  vendorRefundNoteId.value = null;
};

const submitAdjustment = async () => {
  const payload = buildSubmitPayload();
  if (!payload) return;
  await createAdjustmentMutation.mutateAsync(payload);
  adjustmentComposerOpen.value = false;
};
</script>

<style scoped lang="scss">
.page-fixed-layout {
  height: calc(100vh - 55px);
}

.bill-detail-card {
  max-width: 960px;
  margin: 0 auto;
  background: var(--tf-neutral-surface, #fff);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: var(--tf-radius-sm, 8px);
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
  border-top: 1px solid var(--tf-neutral-border, #e2e8f0);
}

.bill-lines-table th {
  font-size: 11px;
  color: var(--tf-neutral-chrome, #64748b);
  font-weight: 600;
}

.bill-line-item-cell {
  vertical-align: top;
  max-width: 320px;
}

.note-amount-input {
  max-width: 120px;
  margin-left: auto;
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
