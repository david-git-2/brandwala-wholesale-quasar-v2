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
            v-if="canIssueDeliveryCloseDraft || canIssueApDraft"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-check-circle"
            label="Issue"
            :loading="issueDeliveryCloseMutation.isPending.value || issueApDraftMutation.isPending.value"
            @click="onIssueDraftBill"
          />
          <q-btn
            v-if="!isApBill && canOpenBillAdjustmentComposer && !isWholesaleKernelBill"
            outline
            no-caps
            color="primary"
            icon="ph ph-file-minus"
            label="Add credit/debit note"
            @click="openAdjustmentInNewTab()"
          />
          <q-btn
            v-if="canWriteOffArBill"
            outline
            no-caps
            color="primary"
            icon="ph ph-eraser"
            label="Write off"
            @click="openAdjustmentInNewTab('write_off')"
          />
          <q-btn
            v-if="canOpenApCreditNote"
            outline
            no-caps
            color="primary"
            icon="ph ph-file-minus"
            label="Credit note"
            @click="openAdjustmentInNewTab('credit_note')"
          />
          <q-btn
            v-if="canWriteOffApBill"
            outline
            no-caps
            color="primary"
            icon="ph ph-eraser"
            label="Write off"
            @click="openAdjustmentInNewTab('write_off')"
          />
          <q-btn
            v-if="canApplyCreditToBill"
            outline
            no-caps
            color="primary"
            icon="ph ph-arrows-left-right"
            label="Apply credit to another bill"
            @click="applyCreditDialogOpen = true"
          />
          <q-btn
            v-if="canRecordPayment"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-wallet"
            label="Add payment"
            @click="goToBillPay()"
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
            v-if="canVoid"
            outline
            no-caps
            color="negative"
            icon="ph ph-prohibit"
            label="Cancel bill"
            :loading="voidMutation.isPending.value"
            @click="openCancelBillDialog"
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
              <div v-if="!isStandardBill && adjustmentReason" class="text-body2 q-mt-xs">
                {{ adjustmentReason }}
              </div>
              <div class="text-caption text-grey-7 q-mt-xs">
                {{ channelLabel }}
                <span v-if="billSettlementCurrencyLabel"> · {{ billSettlementCurrencyLabel }}</span>
              </div>
              <div class="text-caption text-grey-7 q-mt-xs">
                <button
                  v-if="canEditBillDates"
                  type="button"
                  class="bill-date-link"
                  @click="openBillDateEditor('invoice')"
                >
                  {{ bill.invoice_date }}
                </button>
                <span v-else>{{ bill.invoice_date }}</span>
                <template v-if="bill.due_date || canEditBillDates">
                  <span> · Due </span>
                  <button
                    v-if="canEditBillDates"
                    type="button"
                    class="bill-date-link"
                    @click="openBillDateEditor('due')"
                  >
                    {{ bill.due_date ?? 'Set date' }}
                  </button>
                  <span v-else-if="bill.due_date">{{ bill.due_date }}</span>
                </template>
              </div>

              <q-dialog v-model="billDateEditorOpen" class="no-print">
                <q-card flat bordered class="bill-date-editor-card">
                  <q-card-section class="text-subtitle2 text-weight-medium">
                    {{ billDateEditorTitle }}
                  </q-card-section>
                  <q-card-section class="q-pt-none">
                    <q-date v-model="billDateEditorDraft" mask="YYYY-MM-DD" minimal />
                  </q-card-section>
                  <q-card-actions align="right" class="q-gutter-sm">
                    <q-btn flat no-caps label="Cancel" @click="closeBillDateEditor" />
                    <q-btn
                      unelevated
                      no-caps
                      color="primary"
                      label="Change date"
                      :loading="patchBillDatesMutation.isPending.value"
                      :disable="!billDateEditorDraft"
                      @click="confirmBillDateEditor"
                    />
                  </q-card-actions>
                </q-card>
              </q-dialog>
            </div>
            <BillKernelSourceChips
              v-if="isApBill"
              :source-type="bill.source_type"
              :source-id="bill.source_id"
              :source-key="bill.source_key ?? bill.ap_kind"
              :ap-kind="bill.ap_kind"
              :shipment-id="billShipmentId"
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
          <ArBillPartiesBlock v-else :bill="bill" />
        </div>
        <BillKernelSourceChips
          v-if="showArKernelSource && bill"
          class="q-mb-sm"
          :source-type="bill.source_type"
          :source-id="bill.source_id != null ? String(bill.source_id) : null"
          :source-key="bill.source_key"
          :shop-order-id="deliveryPaperShopOrderId"
        />

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
            :desk-bill-lines="bundleQuery.data.value?.billLines"
          />
          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <BillNetSettlementPanel
                :balances="netBalances"
                :is-ap="true"
                :loading="bundleQuery.isFetching.value"
                :channel-meta="(bill.channel_meta as Record<string, unknown> | null) ?? null"
                :settlement-currency-code="apBillSettlementCurrency ?? bill.currency_code ?? null"
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
            Open customer credit on this note. Refund the customer or apply to another invoice.
          </q-banner>
          <template v-if="!isStandardBill">
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
                  <span>Refunded</span>
                  <span>{{ formatAmountBdt(bill.paid_amount) }}</span>
                </div>
                <div class="bill-total-row text-weight-bold">
                  <span>Credit still owed</span>
                  <span>{{ formatAmountBdt(bill.due_amount) }}</span>
                </div>
              </div>
            </div>
          </template>
          <q-markup-table v-else flat dense class="bill-lines-table">
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
                  <BillLineItemDisplay
                    :name="line.name_snapshot"
                    :global-stock-id="line.global_stock_id > 0 ? line.global_stock_id : null"
                    :shipment-item-id="line.shipment_item_id ?? null"
                    :shipment-id="line.shipment_id ?? null"
                  />
                </td>
                <td class="text-right">{{ line.quantity }}</td>
                <td class="text-right">{{ formatDeskAmount(line.sell_price_amount) }}</td>
                <td class="text-right">{{ formatDeskAmount(line.line_discount_amount) }}</td>
                <td class="text-right text-weight-medium">{{ formatDeskAmount(line.line_total_amount) }}</td>
              </tr>
            </tbody>
          </q-markup-table>

          <div class="row justify-end q-mt-md">
            <div class="bill-totals-panel">
              <div v-if="billLinesQuantityTotal > 0" class="bill-total-row">
                <span>Total qty</span>
                <span class="font-mono">{{ formatBillQuantityTotal(billLinesQuantityTotal) }}</span>
              </div>
              <div v-if="bill.discount_amount" class="bill-total-row">
                <span>Discount</span>
                <span>{{ formatDeskAmount(bill.discount_amount) }}</span>
              </div>
              <div v-if="bill.shipping_charge" class="bill-total-row">
                <span>Shipping</span>
                <span>{{ formatDeskAmount(bill.shipping_charge) }}</span>
              </div>
              <div v-if="bill.wrapping_charge" class="bill-total-row">
                <span>Wrapping</span>
                <span>{{ formatDeskAmount(bill.wrapping_charge) }}</span>
              </div>
              <div v-if="bill.print_charge" class="bill-total-row">
                <span>Print</span>
                <span>{{ formatDeskAmount(bill.print_charge) }}</span>
              </div>
              <BillNetSettlementPanel
                v-if="isStandardBill"
                :balances="netBalances"
                :is-ap="false"
                :loading="bundleQuery.isFetching.value"
                :open-credit-note-nos="openArCreditNoteNos"
              />
            </div>
          </div>
        </template>

        <div v-if="shipmentCostBillSectionLabel" class="q-mt-md">
          <div class="text-overline text-grey-7">Shipment section</div>
          <div class="text-body2 text-grey-9">{{ shipmentCostBillSectionLabel }}</div>
        </div>

        <div v-if="hasBillComment" class="q-mt-md bill-detail-note">
          <div class="text-overline text-grey-7">Note</div>
          <div class="rich-text-body text-body2 text-grey-9" v-html="billCommentHtml" />
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
            No payments or write-offs on this bill yet.
          </div>
          <q-list v-else bordered separator class="rounded-borders bill-payment-history-list">
            <q-item
              v-for="entry in paymentHistoryEntries"
              :key="`${entry.entry_type}-${entry.entry_id}`"
              dense
              :clickable="Boolean(entry.payment_id)"
              class="bill-pay-history-row"
              @click="entry.payment_id ? openPayDetail(entry) : undefined"
            >
              <q-item-section class="bill-pay-history-row__main">
                <div class="bill-pay-history-row__meta">
                  <span>{{ entry.payment_date }}</span>
                  <span
                    v-if="entry.entry_type !== 'write_off' && entry.method"
                    class="bill-pay-history-row__sep"
                  >·</span>
                  <span
                    v-if="entry.entry_type !== 'write_off' && entry.method"
                    class="bill-pay-history-row__method"
                  >
                    {{ paymentHistoryMethodLabel(entry) }}
                  </span>
                  <span v-if="entry.entry_type === 'write_off'" class="bill-pay-history-row__method">
                    Write-off
                  </span>
                  <span v-if="entry.voided_at" class="bill-pay-history-row__voided">Voided</span>
                </div>
                <div v-if="paymentHistoryListSubtitleForEntry(entry)" class="bill-pay-history-row__note">
                  {{ paymentHistoryListSubtitleForEntry(entry) }}
                </div>
              </q-item-section>

              <q-item-section side class="bill-pay-history-row__amounts text-right">
                <div class="bill-pay-history-row__amount tf-num">
                  {{ paymentHistoryPrimaryAmount(entry) }}
                </div>
                <div
                  v-if="paymentHistoryAmountSubline(entry)"
                  class="bill-pay-history-row__amount-sub tf-num"
                >
                  {{ paymentHistoryAmountSubline(entry) }}
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </div>
      </div>
    </div>

    <ApplyCreditToBillDialog
      v-if="bill && billProfileId && applyCreditTenantId"
      v-model="applyCreditDialogOpen"
      :tenant-id="applyCreditTenantId"
      :books-tenant-id="operatingTenantId"
      :profile-id="billProfileId"
      :is-ap="isApBill"
      :exclude-bill-id="bill.id"
      :open-credit-notes="openCreditNotesForApply"
      @applied="onCreditAppliedToBill"
    />
    <ProfilePayDetailDialog
      v-model="payDetailDialogOpen"
      :operating-tenant-id="operatingTenantId"
      :row="payDetailRow"
      :viewed-profile-id="billProfileId"
      :viewed-profile-display-name="profileName"
    />
    <BillCancelConfirmDialog
      v-if="bill"
      v-model="cancelBillDialogOpen"
      :bill="cancelBillSnapshot"
      :payments="cancelDialogPayments"
      :settlement-currency-code="apBillSettlementCurrency ?? bill.currency_code ?? null"
      :is-ap="isApBill"
      :open-credit-note-count="openLinkedCreditNoteCount"
      :confirm-loading="voidMutation.isPending.value"
      @confirm="onConfirmCancelBill"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import {
  billDraftComposeRoute,
  billOpensOnDetailNotComposeDesk,
  isDeliveryPaperOutcomeBillSource,
} from '../utils/billRoutes';
import { billsRepository } from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import {
  formatAmountBdt,
  formatBdtTaka,
  formatSettlementCurrencyAmount,
  settlementCurrencyDisplayLabel,
} from 'src/utils/currency';
import { showErrorNotification, showSuccessNotification, requestConfirmation } from 'src/utils/appFeedback';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow, GlobalInvoiceRow } from 'src/modules/bills_pays/types/invoice';
import {
  invoiceChannelLabel,
  invoiceChannelTone,
  invoiceListStatusLabel,
} from 'src/modules/bills_pays/utils/invoiceListDisplay';
import { useBillDetailBundleQuery } from '../composables/useBillDetailBundleQuery';
import { useBillDetailQuery } from '../composables/useBillDetailQuery';
import { useVoidBillMutation } from '../composables/useVoidBillMutation';
import type { InvoicePaymentHistoryEntry } from 'src/modules/bills_pays/types/invoice';
import {
  aggregateVendorRefundReceipts,
  formatPaymentHistoryBooksCaption,
  formatPaymentHistoryPrimary,
  paymentHistoryEntryToPayListRow,
  paymentHistoryListSubtitle,
} from '../utils/paymentHistoryDisplay';
import ProfilePayDetailDialog from '../components/ProfilePayDetailDialog.vue';
import type { PayListRow } from '../repositories/paysRepository';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import ApBillPartiesBlock from '../components/ApBillPartiesBlock.vue';
import ArBillPartiesBlock from '../components/ArBillPartiesBlock.vue';
import BillKernelSourceChips from '../components/BillKernelSourceChips.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { useBillPayCashbookLegsStore } from '../stores/billPayCashbookLegsStore';
import {
  billAdjustmentRoute,
  billPayRoute,
  billVendorRefundRoute,
  type BillDetailAdjustmentKind,
} from '../utils/billRoutes';
import BillAdjustmentLinesTable from '../components/BillAdjustmentLinesTable.vue';
import BillNetSettlementPanel from '../components/BillNetSettlementPanel.vue';
import ApplyCreditToBillDialog from '../components/ApplyCreditToBillDialog.vue';
import BillCancelConfirmDialog from '../components/BillCancelConfirmDialog.vue';
import type { BillCancelConfirmSnapshot } from '../components/BillCancelConfirmDialog.vue';
import { usePaymentsVoidAccess } from '../composables/usePaymentsVoidAccess';
import type { BillLineDisplayRow } from '../repositories/billLinesRepository';
import { usePatchBillDatesMutation } from '../composables/usePatchBillDatesMutation';
import { syncShipmentApBills } from 'src/modules/procurement_stock/repositories/shipmentMoneyKernelRepository';
import { apBillDueStoresForeignFace } from '../utils/apBillBooks';
import {
  apBillCurrencyBalances,
  apBillPaperCurrencyCode,
  isLegacyApPaperSnapshot,
  parseApBillPaper,
} from '../utils/parseApBillPaper';
import type { BillNetBalances } from '../types/billBalances';
import type { BillAdjustmentRow } from '../types/billAdjustments';
import { shipmentIdFromBill } from '../utils/shipmentApBillSource';
import { isDropshipCourierApBill, isDropshipManagerBill } from '../utils/dropshipManagedBill';
import { kernelBillLinesToStockRows } from '../utils/kernelBillLinesToStockRows';
import {
  billNoteHasVisibleContent,
  billNoteHtml,
} from '../utils/billNoteDisplay';
import { formatBillQuantityTotal, sumBillLineQuantities } from '../utils/billLineQuantityTotal';
import { isInvWsWholesaleBill as isInvWsWholesaleBillCheck } from '../utils/wholesaleKernelBill';

const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();
const authStore = useAuthStore();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

const billId = computed(() => {
  const raw = route.params.billId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const staffOperatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const operatingTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t?.id) return 0;
  return t.parent_id ?? t.id;
});

const booksTenantId = operatingTenantId;

const bundleQuery = useBillDetailBundleQuery(billId, operatingTenantId);
const billFromBundle = computed(() => bundleQuery.data.value?.bill);

const payCashbookLegsStore = useBillPayCashbookLegsStore();

watch(
  () => bundleQuery.data.value?.payCashbookLegs,
  (legs) => {
    payCashbookLegsStore.syncFromBundleQuery(billId.value, legs);
  },
  { immediate: true },
);

watch(billId, (id) => {
  if (id == null) payCashbookLegsStore.clear();
});

const { itemsQuery, billLinesQuery } = useBillDetailQuery(
  billId,
  billFromBundle,
  computed(() => bundleQuery.data.value),
);
const voidMutation = useVoidBillMutation(
  () => billId.value,
  () => ({
    tenantId: operatingTenantId.value,
  }),
);
const patchBillDatesMutation = usePatchBillDatesMutation(() => billId.value);
const paymentHistoryEntries = computed(
  () => (bundleQuery.data.value?.paymentHistory ?? []) as InvoicePaymentHistoryEntry[],
);

const applyCreditDialogOpen = ref(false);
const cancelBillDialogOpen = ref(false);
const paymentsVoidAccess = usePaymentsVoidAccess();
const bill = computed(() => billFromBundle.value as GlobalInvoiceDetail | undefined);

const billCommentHtml = computed(() => billNoteHtml(bill.value?.note));
const hasBillComment = computed(() => billNoteHasVisibleContent(bill.value?.note));

const shipmentCostBillSectionLabel = computed(() => {
  const meta = bill.value?.channel_meta as Record<string, unknown> | null | undefined;
  if (!meta) return null;
  const title =
    typeof meta.section_title === 'string' && meta.section_title.trim() !== ''
      ? meta.section_title.trim()
      : null;
  if (title) return title;
  const sid = meta.section_id;
  if (sid != null && String(sid).trim() !== '') return `Section #${sid}`;
  return null;
});

type BillDateEditorTarget = 'invoice' | 'due';

const billDateEditorOpen = ref(false);
const billDateEditorTarget = ref<BillDateEditorTarget>('invoice');
const billDateEditorDraft = ref('');

const canEditBillDates = computed(() => {
  const b = bill.value;
  if (!b || b.invoice_status === 'voided') return false;
  return operatingTenantId.value > 0;
});

const billDateEditorTitle = computed(() =>
  billDateEditorTarget.value === 'invoice' ? 'Change invoice date' : 'Change due date',
);

const openBillDateEditor = (target: BillDateEditorTarget) => {
  const b = bill.value;
  if (!b) return;
  billDateEditorTarget.value = target;
  if (target === 'invoice') {
    billDateEditorDraft.value = b.invoice_date?.slice(0, 10) ?? '';
  } else {
    billDateEditorDraft.value =
      b.due_date?.slice(0, 10) ?? b.invoice_date?.slice(0, 10) ?? '';
  }
  billDateEditorOpen.value = true;
};

const closeBillDateEditor = () => {
  billDateEditorOpen.value = false;
};

const confirmBillDateEditor = async () => {
  const id = billId.value;
  const tenantId = operatingTenantId.value;
  const b = bill.value;
  if (!id || !tenantId || !b || !billDateEditorDraft.value.trim()) return;

  const invoiceDate = b.invoice_date?.slice(0, 10) ?? '';
  if (billDateEditorTarget.value === 'invoice') {
    if (billDateEditorDraft.value === invoiceDate) {
      closeBillDateEditor();
      return;
    }
    await patchBillDatesMutation.mutateAsync({
      tenantId,
      billId: id,
      invoiceDate: billDateEditorDraft.value,
      touchDueDate: false,
    });
  } else {
    const dueNorm = b.due_date?.slice(0, 10) ?? null;
    if (billDateEditorDraft.value === dueNorm) {
      closeBillDateEditor();
      return;
    }
    await patchBillDatesMutation.mutateAsync({
      tenantId,
      billId: id,
      invoiceDate,
      dueDate: billDateEditorDraft.value,
      touchDueDate: true,
    });
  }
  closeBillDateEditor();
};

const isApBill = computed(() => bill.value?.invoice_type === 'ap');
const billShipmentId = computed(() => shipmentIdFromBill(bill.value) ?? null);

const vendorRefundReceiptBuckets = computed(() =>
  aggregateVendorRefundReceipts(paymentHistoryEntries.value, { isAp: isApBill.value }),
);

const parentDueAmount = computed(() => Number(bill.value?.due_amount ?? 0));

const billDocumentKind = computed(() => {
  const b = bill.value as { document_kind?: string } | undefined;
  return b?.document_kind ?? 'standard';
});
const isStandardBill = computed(() => billDocumentKind.value === 'standard');

const isArStockInvoiceType = (invoiceType: string | null | undefined) =>
  invoiceType === 'wholesale' || invoiceType === 'retail' || invoiceType === 'dropship';

const lines = computed((): GlobalInvoiceItemRow[] => {
  const bundle = bundleQuery.data.value;
  const stockItems = bundle?.stockItems;
  if (stockItems?.length) {
    return stockItems;
  }
  const fromQuery = itemsQuery.data.value;
  if (fromQuery?.length) {
    return fromQuery;
  }
  const b = bill.value;
  const id = billId.value ?? b?.id;
  if (
    bundle?.billLines?.length &&
    id != null &&
    isStandardBill.value &&
    !isApBill.value &&
    isArStockInvoiceType(b?.invoice_type)
  ) {
    return kernelBillLinesToStockRows(bundle.billLines, id);
  }
  return stockItems ?? fromQuery ?? [];
});

const billLinesQuantityTotal = computed(() => sumBillLineQuantities(lines.value));

const parentInvoiceNoFromMeta = computed(() => {
  const meta = bill.value?.channel_meta as Record<string, unknown> | null;
  const adj = meta?.adjustment as Record<string, unknown> | undefined;
  const fromMeta = adj?.parent_invoice_no;
  return typeof fromMeta === 'string' && fromMeta.trim() ? fromMeta.trim() : null;
});

const adjustmentReason = computed(() => {
  const meta = bill.value?.channel_meta as Record<string, unknown> | null;
  const adj = meta?.adjustment as Record<string, unknown> | undefined;
  const fromMeta = adj?.reason;
  if (typeof fromMeta === 'string' && fromMeta.trim()) return fromMeta.trim();
  return bill.value?.note?.trim() || null;
});

const adjustmentLineRows = computed((): BillLineDisplayRow[] => {
  if (!isStandardBill.value) {
    const fromBundle = bundleQuery.data.value?.billLines;
    const fromQuery = billLinesQuery.data.value;
    if (fromBundle?.length || fromQuery?.length) {
      return fromBundle ?? fromQuery ?? [];
    }
    if (isApBill.value) {
      return [];
    }
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

const openArCreditNoteNos = openApCreditNoteNos;

const openCreditNotesForApply = computed(() =>
  adjustmentRows.value
    .filter((r) => r.document_kind === 'credit_note' && Number(r.due_amount ?? 0) > 0)
    .map((r) => ({
      id: r.id,
      invoice_no: r.invoice_no,
      due_amount: Number(r.due_amount ?? 0),
    })),
);

const applyCreditTenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const billProfileId = computed(() => {
  const b = bill.value;
  if (!b) return null;
  return b.profile_id ?? (b as { profile_id?: number }).profile_id ?? null;
});

const paymentDueAmount = computed(() => {
  const nb = netBalances.value;
  if (isApBill.value && apBillSettlementCurrency.value) {
    if (nb?.open_txn != null) return Math.max(0, Number(nb.open_txn));
  }
  if (nb?.due_amount != null) return Math.max(0, Number(nb.due_amount));
  return Math.max(0, Number(bill.value?.due_amount ?? 0));
});

const canApplyCreditToBill = computed(() => {
  if (isApBill.value) return false;
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  if (isDropshipCourierApBill(b)) return false;
  if (!billProfileId.value) return false;
  return Number(netBalances.value?.credit_open ?? 0) > 0 && openCreditNotesForApply.value.length > 0;
});

const onCreditAppliedToBill = () => {
  void bundleQuery.refetch();
};

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
  const fromPaper = apBillPaperCurrencyCode(bill.value.channel_meta as Record<string, unknown> | null);
  if (fromPaper !== 'BDT') return fromPaper;
  const header = String(bill.value.currency_code ?? '').trim().toUpperCase();
  if (header && header !== 'BDT') return header;
  const deskCcy = bundleQuery.data.value?.billLines?.[0]?.currency_code?.trim().toUpperCase();
  if (deskCcy && deskCcy !== 'BDT') return deskCcy;
  return null;
});

const billSettlementCurrencyLabel = computed(() => {
  const code = apBillSettlementCurrency.value ?? bill.value?.currency_code;
  if (!code) return null;
  return settlementCurrencyDisplayLabel(code);
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
const statusLabel = computed(() => {
  if (!bill.value) return '';
  const base = invoiceListStatusLabel(bill.value as GlobalInvoiceRow);
  const writtenOff =
    Number(netBalances.value?.written_off_amount ?? 0)
    || Number((bill.value as { written_off_amount?: number }).written_off_amount ?? 0);
  if (writtenOff > 0.001 && base === 'Paid') return 'Paid · write-off';
  return base;
});

const livePaymentHistoryEntries = computed(() =>
  paymentHistoryEntries.value.filter(
    (e) =>
      !e.voided_at &&
      e.payment_id != null &&
      e.entry_type !== 'write_off',
  ),
);

const openLinkedCreditNoteCount = computed(
  () =>
    adjustmentRows.value.filter(
      (r) => r.document_kind === 'credit_note' && r.invoice_status !== 'voided',
    ).length,
);

const cancelDialogPayments = computed(() => livePaymentHistoryEntries.value);

const cancelBillSnapshot = computed((): BillCancelConfirmSnapshot | null => {
  const b = bill.value;
  if (!b) return null;
  const code =
    (apBillSettlementCurrency.value ?? b.currency_code ?? 'BDT').trim().toUpperCase();
  return {
    invoiceNo: b.invoice_no,
    totalAmount: Number(b.total_amount ?? 0),
    paidAmount: Number(b.paid_amount ?? 0),
    dueAmount: Number(b.due_amount ?? 0),
    writtenOffAmount: Number(
      (b as { written_off_amount?: number }).written_off_amount ?? netBalances.value?.written_off_amount ?? 0,
    ),
    currencyCode: code,
  };
});

const canVoid = computed(() => {
  const b = bill.value;
  if (!b || b.invoice_status === 'voided') return false;
  if (!isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  if (livePaymentHistoryEntries.value.length > 0 && !paymentsVoidAccess.value) {
    return false;
  }
  return true;
});

const canAddAdjustment = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  return b.invoice_status === 'issued';
});

const canOpenBillAdjustmentComposer = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value || b.invoice_status !== 'issued') return false;
  if (canAddAdjustment.value) return true;
  return Number(b.due_amount ?? 0) > 0;
});

const canOpenApCreditNote = computed(
  () => isApBill.value && isStandardBill.value && canOpenBillAdjustmentComposer.value,
);

const canWriteOffApBill = computed(() => {
  const b = bill.value;
  if (!b || !isApBill.value || !isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  return Number(b.due_amount ?? 0) > 0;
});

const isWholesaleKernelBill = computed(() => isInvWsWholesaleBillCheck(bill.value ?? null));

const canWriteOffArBill = computed(() => {
  const b = bill.value;
  if (!b || isApBill.value || !isStandardBill.value) return false;
  if (!isWholesaleKernelBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  return Number(b.due_amount ?? 0) > 0;
});

const isDeliveryCloseBill = computed(() =>
  isDeliveryPaperOutcomeBillSource(bill.value?.source_type, bill.value?.source_key ?? null),
);

const showArKernelSource = computed(() => {
  if (isApBill.value || !bill.value) return false;
  return isDeliveryPaperOutcomeBillSource(bill.value.source_type, bill.value.source_key ?? null);
});

const deliveryPaperShopOrderId = computed(() => {
  const b = bill.value;
  if (!b) return null;
  const meta = b.channel_meta as Record<string, unknown> | null;
  const fromMeta = meta?.shop_order_id;
  if (fromMeta != null && Number(fromMeta) > 0) return Number(fromMeta);
  if (b.source_type === 'shop_order' && b.source_id != null) {
    const id = Number(b.source_id);
    return Number.isFinite(id) && id > 0 ? id : null;
  }
  return null;
});

const billCurrencyCode = computed(() =>
  String(bill.value?.currency_code ?? 'BDT').trim().toUpperCase(),
);

function formatDeskAmount(value: number | string | null | undefined): string {
  if (isApBill.value) return formatAmountBdt(value);
  return formatSettlementCurrencyAmount(value, billCurrencyCode.value);
}

const canIssueDeliveryCloseDraft = computed(() => {
  const b = bill.value;
  if (!b || !isDeliveryCloseBill.value || isApBill.value) return false;
  if (b.invoice_status !== 'draft' && b.invoice_status !== 'proforma_generated') return false;
  return lines.value.some((l) => Number(l.quantity) > 0);
});

const apDraftBooksTotal = (b: GlobalInvoiceDetail): number => {
  const books = Number(b.total_amount ?? 0);
  if (books > 0) return books;
  const paper = parseApBillPaper(b.channel_meta as Record<string, unknown> | null, null);
  const fromPaper = Number(paper?.bdt_amount ?? 0);
  return fromPaper > 0 ? fromPaper : books;
};

const canIssueApDraft = computed(() => {
  const b = bill.value;
  if (!b || !isApBill.value || !isStandardBill.value) return false;
  if (isDropshipCourierApBill(b)) return false;
  if (b.invoice_status !== 'draft' && b.invoice_status !== 'proforma_generated') return false;
  return apDraftBooksTotal(b) > 0;
});

const issueDeliveryCloseMutation = useMutation({
  mutationFn: async () => {
    const id = billId.value;
    const b = bill.value;
    if (id == null || !b) throw new Error('Bill not loaded');
    const stockItems = lines.value
      .filter((l) => l.global_stock_id != null && Number(l.quantity) > 0)
      .map((l) => ({
        id: l.id,
        global_stock_id: l.global_stock_id!,
        quantity: Number(l.quantity),
        sell_price_amount: Number(l.sell_price_amount),
      }));
    await billsRepository.issueBill(id, {
      invoiceType: (b.invoice_type ?? 'wholesale') as 'wholesale' | 'retail' | 'ap',
      tenantId: operatingTenantId.value,
      stockItems,
    });
  },
  onSuccess: async () => {
    showSuccessNotification('Bill issued.');
    const id = billId.value;
    if (id != null) {
      await queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
      await queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
      await queryClient.invalidateQueries({ queryKey: billsQueryKeys.items(id) });
    }
    await bundleQuery.refetch();
  },
  onError: (err: unknown) => {
    showErrorNotification(err instanceof Error ? err.message : 'Could not issue bill.');
  },
});

const issueApDraftMutation = useMutation({
  mutationFn: async () => {
    const id = billId.value;
    if (id == null) throw new Error('Bill not loaded');
    await billsRepository.issueApBillFromDesk(id, {
      tenantId: operatingTenantId.value,
    });
  },
  onSuccess: async () => {
    showSuccessNotification('Bill issued.');
    const id = billId.value;
    if (id != null) {
      await queryClient.invalidateQueries({ queryKey: billsQueryKeys.detailBundle(id) });
      await queryClient.invalidateQueries({ queryKey: billsQueryKeys.detail(id) });
    }
    await bundleQuery.refetch();
  },
  onError: (err: unknown) => {
    showErrorNotification(err instanceof Error ? err.message : 'Could not issue bill.');
  },
});

const onIssueApDraft = async () => {
  const ok = await requestConfirmation(
    'No sales on this paper. Pay out later on Payments.',
    'Issue this payable bill?',
    'Issue',
  );
  if (!ok) return;
  await issueApDraftMutation.mutateAsync();
};

const onIssueDraftBill = async () => {
  if (canIssueDeliveryCloseDraft.value) {
    await onIssueDeliveryCloseDraft();
    return;
  }
  if (canIssueApDraft.value) {
    await onIssueApDraft();
  }
};

const onIssueDeliveryCloseDraft = async () => {
  const b = bill.value;
  const settle = (b as { settlement_kind?: string } | undefined)?.settlement_kind;
  const isCondition = settle === 'condition';
  const ok = await requestConfirmation(
    isCondition
      ? 'Stock moves to held. Sales count when this bill is paid. Collect on Payments.'
      : 'Sellable stock will leave inventory when you issue. You can collect payment later on Payments.',
    isCondition ? 'Issue this condition bill?' : 'Issue this bill?',
    'Issue',
  );
  if (!ok) return;
  await issueDeliveryCloseMutation.mutateAsync();
};

const paymentDueCurrencyCode = computed(() => {
  const b = bill.value;
  if (!b) return 'BDT';
  if (apBillSettlementCurrency.value) return apBillSettlementCurrency.value;
  const due = paymentDueAmount.value;
  const meta = (b.channel_meta as Record<string, unknown> | null) ?? null;
  if (isApBill.value && apBillDueStoresForeignFace(meta, due)) {
    return apBillPaperCurrencyCode(meta);
  }
  const header = String(b.currency_code ?? '').trim();
  if (header) return header.toUpperCase();
  return 'BDT';
});

function goToBillPay() {
  const id = billId.value;
  if (id == null) return;
  const slug =
    typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  void router.push(billPayRoute(id, slug));
}

const canRecordPayment = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  if (isDropshipManagerBill(b)) return false;
  if (b.invoice_status !== 'issued') return false;
  if (!billProfileId.value) return false;
  return paymentDueAmount.value > 0;
});

const canRecordVendorRefund = computed(() => {
  if (!isApBill.value) return false;
  const b = bill.value;
  if (!b || b.invoice_status !== 'issued') return false;
  if (isDropshipCourierApBill(b)) return false;
  if (billDocumentKind.value === 'credit_note') {
    return Number(b.due_amount ?? 0) > 0;
  }
  if (!isStandardBill.value) return false;
  return Number(netBalances.value?.credit_open ?? 0) > 0;
});

function openVendorRefund(noteId?: number) {
  const id = billId.value;
  if (id == null) return;
  const slug =
    typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  let creditNoteId: number | undefined;
  if (noteId) {
    creditNoteId = noteId;
  } else if (billDocumentKind.value !== 'credit_note') {
    const firstOpen = adjustmentRows.value.find(
      (r) => r.document_kind === 'credit_note' && Number(r.due_amount ?? 0) > 0,
    );
    if (firstOpen?.id) creditNoteId = firstOpen.id;
  }
  void router.push(
    billVendorRefundRoute(
      id,
      slug,
      creditNoteId ? { creditNoteId: String(creditNoteId) } : undefined,
    ),
  );
}

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

watch(
  () => bill.value,
  (b) => {
    if (!b || bundleQuery.isPending.value) return;
    if (b.invoice_status !== 'draft' && b.invoice_status !== 'proforma_generated') return;
    const id = billId.value;
    if (id == null || id <= 0) return;
    if (billOpensOnDetailNotComposeDesk(b)) return;
    void router.replace(billDraftComposeRoute(id, authStore.tenantSlug));
  },
);

onBeforeUnmount(() => {
  payCashbookLegsStore.clear();
  clearCustomBreadcrumbs();
});

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

const openCancelBillDialog = () => {
  if (!canVoid.value) return;
  cancelBillDialogOpen.value = true;
};

const onConfirmCancelBill = async (reason: string | null) => {
  if (!canVoid.value) return;
  try {
    await voidMutation.mutateAsync({ reason });
    cancelBillDialogOpen.value = false;
  } catch {
    /* toast from mutation */
  }
};

const paymentHistoryMethodLabel = (entry: InvoicePaymentHistoryEntry) =>
  (entry.method ?? 'Payment').replace(/_/g, ' ');

const paymentHistoryListSubtitleForEntry = (entry: InvoicePaymentHistoryEntry): string | null =>
  paymentHistoryListSubtitle(entry, { isAp: isApBill.value });

const payDetailDialogOpen = ref(false);
const payDetailRow = ref<PayListRow | null>(null);

const openPayDetail = (entry: InvoicePaymentHistoryEntry) => {
  if (entry.payment_id == null) return;
  const row = paymentHistoryEntryToPayListRow(entry, billProfileId.value);
  if (!row) return;
  payDetailRow.value = row;
  payDetailDialogOpen.value = true;
};

const paymentHistoryPrimaryAmount = (entry: InvoicePaymentHistoryEntry) =>
  formatPaymentHistoryPrimary(entry, apBillSettlementCurrency.value);

/** One subline under amount: FX books on bill, or BDT receipt when it differs from alloc. */
const paymentHistoryAmountSubline = (entry: InvoicePaymentHistoryEntry): string | null => {
  const fxBooks = formatPaymentHistoryBooksCaption(entry, apBillSettlementCurrency.value);
  if (fxBooks) return fxBooks;
  const receipt = Number(entry.receipt_amount) || 0;
  const alloc = Number(entry.amount) || 0;
  if (receipt > 0 && Math.abs(receipt - alloc) > 0.01) {
    return `Receipt ${formatBdtTaka(receipt)}`;
  }
  return null;
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

function openAdjustmentInNewTab(adjustmentKind?: BillDetailAdjustmentKind) {
  const id = billId.value;
  if (id == null) return;
  const tenantSlug =
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
    authStore.tenantSlug ||
    undefined;
  const loc = router.resolve(
    billAdjustmentRoute(id, tenantSlug, adjustmentKind ? { adjustmentKind } : undefined),
  );
  window.open(loc.href, '_blank', 'noopener,noreferrer');
}
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

.bill-payment-history-list {
  :deep(.q-item) {
    padding: 6px 10px;
  }
}

.bill-pay-history-row__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  font-size: 13px;
  line-height: 1.35;
  color: var(--tf-neutral-ink);
}

.bill-pay-history-row__sep,
.bill-pay-history-row__method {
  color: var(--tf-neutral-muted);
}

.bill-pay-history-row__voided {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--tf-status-bad, #c62828);
}

.bill-pay-history-row__note {
  margin-top: 2px;
  font-size: 12px;
  line-height: 1.3;
  color: var(--tf-neutral-muted);
}

.bill-pay-history-row__amount {
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
  white-space: nowrap;
}

.bill-pay-history-row__amount-sub {
  margin-top: 1px;
  font-size: 11px;
  font-weight: 500;
  color: var(--tf-neutral-muted);
  white-space: nowrap;
}

.bill-pay-history-row__amounts {
  padding-left: 8px;
  min-width: 88px;
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

.bill-date-link {
  appearance: none;
  border: none;
  padding: 0;
  margin: 0;
  font: inherit;
  color: var(--tf-theme-primary);
  text-decoration: underline;
  text-decoration-color: transparent;
  cursor: pointer;
  background: transparent;

  &:hover,
  &:focus-visible {
    text-decoration-color: currentColor;
  }
}

.bill-date-editor-card {
  min-width: 280px;
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

  .bill-date-link {
    color: inherit;
    text-decoration: none;
    cursor: default;
  }
}

.bill-detail-note .rich-text-body :deep(p) {
  margin-top: 0;
  margin-bottom: 8px;
  line-height: 1.5;
}

.bill-detail-note .rich-text-body :deep(ul),
.bill-detail-note .rich-text-body :deep(ol) {
  padding-left: 20px;
  margin-top: 0;
  margin-bottom: 8px;
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
