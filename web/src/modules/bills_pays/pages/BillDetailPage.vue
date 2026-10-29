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
            v-if="canApplyCreditToBill"
            outline
            no-caps
            color="primary"
            icon="ph ph-arrows-left-right"
            label="Apply credit to another bill"
            @click="applyCreditDialogOpen = true"
          />
          <q-btn
            v-if="canApplyCustodyToBill"
            outline
            no-caps
            color="primary"
            icon="ph ph-vault"
            label="Apply custody to bill"
            @click="applyCustodyDialogOpen = true"
          />
          <q-btn
            v-if="canRecordPayment"
            unelevated
            no-caps
            color="primary"
            icon="ph ph-wallet"
            label="Add payment"
            @click="openAddPayment"
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
              <div v-if="!isStandardBill && adjustmentReason" class="text-body2 q-mt-xs">
                {{ adjustmentReason }}
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
          <q-banner
            v-if="adjustmentComposerOpen && commercialCreditHintBdt != null"
            dense
            rounded
            class="bg-grey-2 q-mt-sm no-print"
          >
            Suggested commercial credit (missing/damaged qty hint):
            {{ formatAmountBdt(commercialCreditHintBdt) }} — enter lines manually above.
          </q-banner>
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
            Open customer credit on this note. Refund the customer or apply to another invoice.
          </q-banner>
          <template v-if="!isStandardBill && !adjustmentComposerOpen">
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
                <th v-if="adjustmentComposerOpen" class="text-right">Revised (BDT)</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="line in lines" :key="line.id">
                <td class="bill-line-item-cell">
                  <BillLineItemDisplay :name="line.name_snapshot" />
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
            ref="arAdjustmentNoteBarRef"
            v-model:kind="kind"
            v-model:reason="reason"
            v-model:refund-cash-now="refundCashNow"
            v-model:refund-amount="refundAmount"
            :note-total-labels="noteTotalLabels"
            :balance-effect="balanceEffect"
            :submit-disabled-reason="submitDisabledReason"
            :loading="createAdjustmentMutation.isPending.value"
            :parent-tenant-id="parentTenantId"
            :ar-refund-eligible="arRefundEligible"
            :excess-credit-bdt="excessCreditBdt"
            @cancel="adjustmentComposerOpen = false"
            @submit="submitAdjustment"
          />
          <q-banner
            v-if="adjustmentComposerOpen && commercialCreditHintBdt != null"
            dense
            rounded
            class="bg-grey-2 q-mt-sm no-print"
          >
            Suggested commercial credit (missing/damaged qty hint):
            {{ formatAmountBdt(commercialCreditHintBdt) }} — enter lines manually above.
          </q-banner>

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
                :open-credit-note-nos="openArCreditNoteNos"
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
          <q-list v-else bordered separator class="rounded-borders bill-payment-history-list">
            <q-item
              v-for="entry in paymentHistoryEntries"
              :key="`${entry.entry_type}-${entry.entry_id}`"
              dense
              class="bill-pay-history-row"
            >
              <q-item-section class="bill-pay-history-row__main">
                <div class="bill-pay-history-row__meta">
                  <span>{{ entry.payment_date }}</span>
                  <span v-if="entry.method" class="bill-pay-history-row__sep">·</span>
                  <span v-if="entry.method" class="bill-pay-history-row__method">
                    {{ paymentHistoryMethodLabel(entry) }}
                  </span>
                  <span v-if="entry.payment_id" class="bill-pay-history-row__sep">·</span>
                  <span v-if="entry.payment_id" class="bill-pay-history-row__pay-id">
                    Pay #{{ entry.payment_id }}
                  </span>
                  <span v-if="entry.voided_at" class="bill-pay-history-row__voided">Voided</span>
                </div>
                <div v-if="paymentHistoryExtraCaption(entry)" class="bill-pay-history-row__note">
                  {{ paymentHistoryExtraCaption(entry) }}
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

              <q-item-section v-if="entry.payment_id" side class="bill-pay-history-row__actions">
                <TfBtn
                  variant="link"
                  size="sm"
                  label="Open"
                  @click.stop="goToPayment(entry.payment_id)"
                />
                <TfBtn
                  v-if="canCorrectHistoryEntry(entry)"
                  variant="secondary"
                  color="warning"
                  size="sm"
                  label="Correct"
                  :disable="!canUseCorrectPayment"
                  @click.stop="onCorrectPayment(entry)"
                />
              </q-item-section>
            </q-item>
          </q-list>
        </div>
      </div>
    </div>

    <RecordBillPaymentDialog
      v-if="bill && billProfileId && paymentDialogOpen"
      v-model="paymentDialogOpen"
      :bill-id="bill.id"
      :due-amount="paymentDueAmount"
      :due-currency-code="paymentDueCurrencyCode"
      :profile-id="billProfileId"
      :tenant-id="operatingTenantId"
      :books-tenant-id="operatingTenantId"
      :is-ap="isApBill"
      :channel-meta="(bill.channel_meta as Record<string, unknown> | null) ?? null"
      :shipment-id="billShipmentId"
      :loading="recordPaymentMutation.isPending.value"
      :replacing-pay-id="replacingPayId"
      :prefill-snapshot="paymentPrefillSnapshot"
      @submit="onRecordPayment"
    />
    <CorrectBillPaymentDialog
      v-if="bill && billProfileId"
      v-model="correctBillPaymentOpen"
      :history-entry="correctPaymentHistoryEntry"
      :bill-id="bill.id"
      :due-amount="paymentDueAmount"
      :due-currency-code="paymentDueCurrencyCode"
      :profile-id="billProfileId"
      :tenant-id="operatingTenantId"
      :books-tenant-id="operatingTenantId"
      :is-ap="isApBill"
      :channel-meta="(bill.channel_meta as Record<string, unknown> | null) ?? null"
      :shipment-id="billShipmentId"
      :record-loading="recordPaymentMutation.isPending.value"
      @voided="onCorrectPaymentVoided"
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
    <ApplyCustodyToBillDialog
      v-if="applyCustodyDialogOpen && bill && billProfileId && applyCreditTenantId"
      v-model="applyCustodyDialogOpen"
      :tenant-id="applyCreditTenantId"
      :bill-id="bill.id"
      :open-books="billOpenBooks"
      :custody-available="profileCustodyAvailable"
      @applied="onCreditAppliedToBill"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { formatAmountBdt, formatBdtTaka } from 'src/utils/currency';
import { showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';
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
} from '../utils/paymentHistoryDisplay';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import ApBillPaper from '../components/ApBillPaper.vue';
import ApBillPartiesBlock from '../components/ApBillPartiesBlock.vue';
import BillKernelSourceChips from '../components/BillKernelSourceChips.vue';
import RecordBillPaymentDialog from '../components/RecordBillPaymentDialog.vue';
import CorrectBillPaymentDialog from '../components/CorrectBillPaymentDialog.vue';
import { usePaymentsVoidAccess } from '../composables/usePaymentsVoidAccess';
import { isPayVoidable } from '../utils/payVoidability';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';
import RecordVendorCreditRefundDialog from '../components/RecordVendorCreditRefundDialog.vue';
import { usePostVendorCreditRefundMutation } from '../composables/usePostVendorCreditRefundMutation';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';
import BillAdjustmentNoteBar from '../components/BillAdjustmentNoteBar.vue';
import BillAdjustmentLinesTable from '../components/BillAdjustmentLinesTable.vue';
import BillNetSettlementPanel from '../components/BillNetSettlementPanel.vue';
import ApplyCreditToBillDialog from '../components/ApplyCreditToBillDialog.vue';
import ApplyCustodyToBillDialog from '../components/ApplyCustodyToBillDialog.vue';
import { useCashbookPartyQuery } from '../composables/useCashbookPartyQuery';
import type { BillLineDisplayRow } from '../repositories/billLinesRepository';
import { useBillAdjustmentDraft } from '../composables/useBillAdjustmentDraft';
import { useCreateBillAdjustmentMutation } from '../composables/useCreateBillAdjustmentMutation';
import { syncShipmentApBills } from 'src/modules/procurement_stock/repositories/shipmentMoneyKernelRepository';
import { apBillDueStoresForeignFace } from '../utils/apBillBooks';
import {
  apBillCurrencyBalances,
  apBillPaperCurrencyCode,
  isLegacyApPaperSnapshot,
} from '../utils/parseApBillPaper';
import type { BillNetBalances } from '../types/billBalances';
import type { BillAdjustmentRow } from '../types/billAdjustments';
import {
  isShipmentCostApBill,
  shipmentApKindFromBill,
  shipmentIdFromBill,
} from '../utils/shipmentApBillSource';
import { isDropshipCourierApBill, isDropshipManagerBill } from '../utils/dropshipManagedBill';

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
const { itemsQuery, billLinesQuery } = useBillDetailQuery(
  billId,
  billFromBundle,
  computed(() => bundleQuery.data.value),
);
const voidMutation = useVoidBillMutation(() => billId.value);
const issueApMutation = useIssueApBillMutation(() => billId.value);
const recordPaymentMutation = useRecordBillPaymentMutation(() => billId.value);
const vendorRefundMutation = usePostVendorCreditRefundMutation(() => billId.value);
const createAdjustmentMutation = useCreateBillAdjustmentMutation(() => billId.value);

const correctPaymentHistoryEntry = ref<InvoicePaymentHistoryEntry | null>(null);
const correctBillPaymentOpen = ref(false);

const paymentsVoidAccess = usePaymentsVoidAccess();

const paymentDialogOpen = ref(false);
const replacingPayId = ref<number | null>(null);
const paymentPrefillSnapshot = ref<PayCorrectionSnapshot | null>(null);

const paymentHistoryEntries = computed(
  () => (bundleQuery.data.value?.paymentHistory ?? []) as InvoicePaymentHistoryEntry[],
);

const applyCreditDialogOpen = ref(false);
const applyCustodyDialogOpen = ref(false);
const vendorRefundDialogOpen = ref(false);
const vendorRefundNoteId = ref<number | null>(null);
const adjustmentComposerOpen = ref(false);
const arAdjustmentNoteBarRef = ref<InstanceType<typeof BillAdjustmentNoteBar> | null>(null);

const parentTenantId = computed(() => Number(bill.value?.parent_tenant_id ?? 0) || null);

const bill = computed(() => billFromBundle.value as GlobalInvoiceDetail | undefined);
const isApBill = computed(() => bill.value?.invoice_type === 'ap');
const billShipmentId = computed(() => shipmentIdFromBill(bill.value) ?? null);

const vendorRefundReceiptBuckets = computed(() =>
  aggregateVendorRefundReceipts(paymentHistoryEntries.value, { isAp: isApBill.value }),
);

const lines = computed(
  () =>
    (bundleQuery.data.value?.stockItems ??
      itemsQuery.data.value ??
      []) as GlobalInvoiceItemRow[],
);

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
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  if (isDropshipCourierApBill(b)) return false;
  if (!billProfileId.value) return false;
  return Number(netBalances.value?.credit_open ?? 0) > 0 && openCreditNotesForApply.value.length > 0;
});

const billOpenBooks = computed(() => {
  const nb = netBalances.value;
  if (nb?.open_books != null) return Math.max(0, Number(nb.open_books));
  return paymentDueAmount.value;
});

const custodyPartyParams = computed(() => ({
  tenantId: applyCreditTenantId.value,
  entityType: 'customer',
  entityId: billProfileId.value ?? 0,
}));

const needsProfileCustodyFetch = computed(() => {
  const b = bill.value;
  if (!b || isApBill.value) return false;
  if (!isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  if (isDropshipCourierApBill(b)) return false;
  if (!billProfileId.value) return false;
  return billOpenBooks.value > 0;
});

const { detailQuery: profileCustodyQuery } = useCashbookPartyQuery(custodyPartyParams, {
  fetchLedger: false,
  enabled: needsProfileCustodyFetch,
});

const profileCustodyAvailable = computed(() =>
  Number(profileCustodyQuery.data.value?.available_balance ?? 0),
);

const canApplyCustodyToBill = computed(() => {
  const b = bill.value;
  if (!b || !isStandardBill.value) return false;
  if (b.invoice_status !== 'issued') return false;
  if (isDropshipCourierApBill(b)) return false;
  if (!billProfileId.value) return false;
  return billOpenBooks.value > 0 && profileCustodyAvailable.value > 0;
});

const onCreditAppliedToBill = () => {
  void bundleQuery.refetch();
};

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
  arRefundEligible,
  excessCreditBdt,
  refundCashNow,
  refundAmount,
} = useBillAdjustmentDraft({
  bill,
  stockLines: lines,
  isAp: isApBill,
  parentDueAmount,
  siblingNotes: adjustmentRows,
  active: adjustmentComposerOpen,
});

const commercialCreditHintBdt = computed(() => {
  const raw = route.query.suggestedAmount;
  const n = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(n) && n > 0 ? n : null;
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

watch(
  () =>
    [
      billId.value,
      route.query.startAdjustment,
      bundleQuery.isSuccess.value,
      canAddAdjustment.value,
    ] as const,
  () => {
    if (route.query.startAdjustment !== '1') return;
    if (!canAddAdjustment.value) return;
    const r = route.query.reason;
    if (typeof r === 'string' && r.trim()) {
      reason.value = r.trim();
    }
    adjustmentComposerOpen.value = true;
  },
  { immediate: true },
);

const paymentDueCurrencyCode = computed(() => {
  const b = bill.value;
  if (!b) return null;
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
  if (isDropshipCourierApBill(b)) return false;
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
  if (isDropshipManagerBill(b)) return false;
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
onMounted(() => {
  const state = history.state as { payCorrectionPrefill?: PayCorrectionSnapshot } | null;
  const prefill = state?.payCorrectionPrefill;
  if (prefill?.paymentId) {
    replacingPayId.value = prefill.paymentId;
    paymentPrefillSnapshot.value = prefill;
    paymentDialogOpen.value = true;
  }
});

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

const paymentHistoryMethodLabel = (entry: InvoicePaymentHistoryEntry) =>
  (entry.method ?? 'Payment').replace(/_/g, ' ');

const paymentHistoryExtraCaption = (entry: InvoicePaymentHistoryEntry): string | null => {
  const cap = paymentEntryCaption(entry);
  const method = paymentHistoryMethodLabel(entry).toLowerCase();
  if (entry.entry_type === 'write_off') return cap;
  if (cap.toLowerCase() === method) return null;
  if (cap.toLowerCase() === 'payment') return null;
  return cap;
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

const canCorrectHistoryEntry = (entry: InvoicePaymentHistoryEntry) => {
  if (!entry.payment_id || entry.voided_at) return false;
  if (entry.entry_type === 'write_off') return false;
  if (entry.method === 'wallet_credit' || entry.payment_source === 'store_credit') return false;
  if (entry.payment_source) {
    return isPayVoidable({
      source: entry.payment_source,
      method: entry.method,
      voidedAt: entry.voided_at,
    });
  }
  // list_invoice_payment_history may omit pays.source; button still shown — dialog validates.
  return true;
};

const canUseCorrectPayment = computed(() => paymentsVoidAccess.value);

const onCorrectPayment = (entry: InvoicePaymentHistoryEntry) => {
  if (!canUseCorrectPayment.value) {
    showErrorNotification('You need payments void permission to correct a payment.');
    return;
  }
  if (!canCorrectHistoryEntry(entry)) {
    showErrorNotification('This payment cannot be corrected here.');
    return;
  }
  correctPaymentHistoryEntry.value = entry;
  correctBillPaymentOpen.value = true;
};

const onCorrectPaymentVoided = async () => {
  await bundleQuery.refetch();
};

const clearPaymentCorrectionPrefill = () => {
  replacingPayId.value = null;
  paymentPrefillSnapshot.value = null;
};

const openAddPayment = () => {
  clearPaymentCorrectionPrefill();
  paymentDialogOpen.value = true;
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
  correctBillPaymentOpen.value = false;
  correctPaymentHistoryEntry.value = null;
  await recordPaymentMutation.mutateAsync(payload);
  clearPaymentCorrectionPrefill();
};

const onVendorRefund = async (payload: PostVendorCreditRefundInput) => {
  await vendorRefundMutation.mutateAsync(payload);
  vendorRefundDialogOpen.value = false;
  vendorRefundNoteId.value = null;
};

const submitAdjustment = async () => {
  const pointRef = arAdjustmentNoteBarRef.value?.cashbookPointId;
  const pointId =
    pointRef != null && typeof pointRef === 'object' && 'value' in pointRef
      ? (pointRef as { value: number | null }).value
      : (pointRef as number | null | undefined) ?? null;
  const payload = buildSubmitPayload(pointId);
  if (!payload) return;
  if (refundCashNow.value && !payload.cashbookPointId) {
    showErrorNotification('Choose a till or safe to pay the refund from.');
    return;
  }
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
.bill-pay-history-row__method,
.bill-pay-history-row__pay-id {
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

.bill-pay-history-row__actions {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
  padding-left: 8px;
  min-width: 0;

  :deep(.q-btn) {
    min-height: 28px;
    padding: 0 6px;
  }
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
