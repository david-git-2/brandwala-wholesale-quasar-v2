<template>
  <q-page class="global-invoice-details-page">
    <div class="global-invoice-details-page__inner">
      <div v-if="loading" class="global-invoice-details-page__paper-wrap">
        <q-card flat class="invoice-paper-skeleton q-pa-lg">
          <q-skeleton type="text" width="40%" class="q-mb-md" />
          <q-skeleton type="rect" height="120px" class="q-mb-md" />
          <q-skeleton type="rect" height="240px" />
        </q-card>
      </div>

      <div v-else-if="error" class="text-center q-pa-xl text-negative">{{ error }}</div>

      <template v-else-if="invoice">
        <header class="global-invoice-details-page__toolbar row items-center justify-between q-mb-md">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="goBack" />
            <div class="text-subtitle1 text-weight-bold">Invoice details</div>
          </div>
          <div class="row items-center q-gutter-x-xs">
            <q-btn
              v-if="showPreview"
              flat
              dense
              color="secondary"
              icon="ph ph-eye"
              @click="openPreview"
            >
              <q-tooltip>Preview</q-tooltip>
            </q-btn>
            <q-btn
              v-if="
                canMutateInvoice &&
                (invoice.invoice_status === 'draft' ||
                  invoice.invoice_status === 'voided' ||
                  (invoice.invoice_status === 'issued' && canUnpostOrVoid))
              "
              flat
              dense
              icon="ph ph-dots-three-vertical"
              aria-label="Actions"
            >
              <q-menu auto-close>
                <q-list style="min-width: 150px">
                  <q-item
                    v-if="invoice.invoice_status === 'draft' || invoice.invoice_status === 'voided'"
                    clickable
                    class="text-negative"
                    :disable="deletingInvoice"
                    @click="onDeleteInvoice"
                  >
                    <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                      <q-icon name="ph ph-trash" />
                    </q-item-section>
                    <q-item-section>{{ invoice.invoice_status === 'voided' ? 'Delete Voided Invoice' : 'Delete Draft' }}</q-item-section>
                  </q-item>

                  <q-item
                    v-if="invoice.invoice_status === 'draft' && invoice.invoice_type === 'wholesale'"
                    clickable
                    class="text-primary"
                    :disable="convertingInvoice"
                    @click="onConvertWholesaleToRetail"
                  >
                    <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                      <q-icon name="ph ph-arrows-left-right" />
                    </q-item-section>
                    <q-item-section>Convert to Retail</q-item-section>
                  </q-item>

                  <q-item
                    v-if="invoice.invoice_status === 'issued' && canUnpostOrVoid"
                    clickable
                    class="text-negative"
                    :disable="voidingInvoice"
                    @click="changeInvoiceStatus('voided')"
                  >
                    <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                      <q-icon name="ph ph-x-circle" />
                    </q-item-section>
                    <q-item-section>Void Invoice</q-item-section>
                  </q-item>

                  <q-item
                    v-if="invoice.invoice_status === 'issued' && canUnpostOrVoid"
                    clickable
                    class="text-warning"
                    :disable="unpostingInvoice"
                    @click="changeInvoiceStatus('draft')"
                  >
                    <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                      <q-icon name="ph ph-arrow-u-up-left" />
                    </q-item-section>
                    <q-item-section>Undo Post (Draft)</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </div>
        </header>

        <div class="global-invoice-details-page__paper-wrap">
          <GlobalInvoiceDetailPaper
            :invoice="invoice"
            :items="items"
            :form="form"
            :tenant-slug="String(route.params.tenantSlug ?? '')"
            :can-edit-draft="canEditDraft"
            :can-mutate-invoice="canMutateInvoice"
            :is-parent-tenant="isParentTenant"
            :is-dropship="isDropship"
            :is-wholesale="isWholesale"
            :show-charges="showCharges"
            :show-returns="showReturns"
            :linked-order-remittance="linkedOrderRemittance"
            :collection-history="collectionHistoryDisplay"
            :return-history="returnHistory"
            :total-return-quantity="totalReturnQuantity"
            :original-gross-subtotal="originalGrossSubtotal"
            :total-return-deduction="totalReturnDeduction"
            :total-cost="totalCost"
            :total-quantity="totalQuantity"
            :estimated-profit="estimatedProfit"
            :average-profit-rate="averageProfitRate"
            :format-item-unit-cost="formatItemUnitCost"
            :line-margin-for-row="lineMarginForRow"
            :get-item-name-for-return="getItemNameForReturn"
            :format-return-date="formatReturnDate"
            :posting-invoice="postingInvoice"
            :voiding-invoice="voidingInvoice"
            :unposting-invoice="unpostingInvoice"
            :is-transition-disabled="isTransitionDisabled"
            :target-total="targetTotal"
            :target-preview="targetPreview"
            :target-error="targetError"
            :target-previewing="targetPreviewing"
            :applying-target="applyingTarget"
            :editing-recipient="editingRecipient"
            @header-blur="onHeaderUpdate"
            @date-change="onDateChange"
            @status-change="changeInvoiceStatus"
            @update-item="onUpdateItemField"
            @remove-item="onRemoveItem"
            @open-bulk-paste="openBulkPaste"
            @open-stock-dialog="stockDialog = true"
            @toggle-edit-recipient="onToggleEditRecipient"
            @open-edit-note="openEditNoteDialog"
            @view-note="viewNoteDialog = true"
            @process-return="onProcessReturnFromPaper"
            @update:target-total="onTargetTotalModelUpdate"
            @target-total-input="onTargetTotalInput"
            @apply-target-total="onApplyTargetTotal"
          />
        </div>

        <footer v-if="canMutateInvoice" class="global-invoice-details-page__actions">
          <template v-if="invoice.invoice_status === 'draft'">
            <q-btn
              color="primary"
              unelevated
              no-caps
              class="full-width text-weight-bold global-invoice-details-page__action-btn"
              icon="ph ph-paper-plane-right"
              label="Post invoice"
              :loading="postingInvoice"
              data-test="post-invoice-btn"
              @click="changeInvoiceStatus('issued')"
            />
          </template>

          <template v-else-if="invoice.invoice_status === 'issued'">
            <template v-if="invoice.due_amount > 0">
              <q-btn
                color="primary"
                unelevated
                no-caps
                class="full-width text-weight-bold global-invoice-details-page__action-btn q-mb-sm"
                icon="ph ph-credit-card"
                :label="isDropship ? 'Record COD' : 'Record payment'"
                @click="isDropship ? openCodDialog() : openPaymentDialog()"
              />
              <div v-if="showPayments && !isDropship" class="row q-col-gutter-sm">
                <div class="col">
                  <q-btn
                    color="orange"
                    outline
                    no-caps
                    class="full-width global-invoice-details-page__action-btn"
                    label="Settle / write-off"
                    @click="openSettleDialog"
                  />
                </div>
              </div>
              <q-btn
                v-if="isDropship"
                color="secondary"
                outline
                no-caps
                class="full-width global-invoice-details-page__action-btn q-mt-sm"
                label="Pay middle man"
                @click="payoutDialog = true"
              />
            </template>
            <q-btn
              v-else
              color="positive"
              unelevated
              disable
              no-caps
              class="full-width text-weight-bold global-invoice-details-page__action-btn"
              icon="ph ph-check-circle"
              label="Invoice settled"
            />
          </template>

          <q-btn
            v-else-if="invoice.invoice_status === 'voided'"
            color="grey-6"
            unelevated
            disable
            no-caps
            class="full-width text-weight-bold global-invoice-details-page__action-btn"
            icon="ph ph-x-circle"
            label="Invoice voided"
          />
        </footer>
      </template>
    </div>

    <!-- Add From Stock Dialog -->
    <q-dialog v-model="stockDialog" persistent>
      <q-card
        style="
          width: 1100px;
          max-width: 95vw;
          border-radius: 16px;
          background: var(--bw-theme-surface);
          border: 1px solid var(--bw-theme-border);
        "
        class="q-pa-sm shadow-2"
      >
        <q-card-section class="text-h6 text-weight-bold row items-center justify-between q-pb-none">
          <span>Add From Stock</span>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="row q-col-gutter-md">
            <!-- Search Panel -->
            <div class="col-12 col-md-6 column">
              <div class="text-subtitle2 text-weight-bold q-mb-sm">Search Stock</div>
              <NetworkStockSearchPanel
                v-if="invoice && stockDialog"
                mode="invoice"
                :context-tenant-id="invoice.issued_by_tenant_id || invoice.parent_tenant_id"
                selectable
                :show-search-controls="true"
                @select="onSelectStockRow"
              />
            </div>

            <!-- Cart Panel -->
            <div class="col-12 col-md-6 column">
              <div class="text-subtitle2 text-weight-bold q-mb-sm row items-center justify-between">
                <span>Selected Items (Cart)</span>
                <div class="row items-center q-gutter-x-sm">
                  <q-btn
                    v-if="stockCart.length"
                    flat
                    dense
                    no-caps
                    color="negative"
                    label="Clear Cart"
                    size="sm"
                    @click="stockCart = []"
                    class="pill-btn"
                  />
                  <q-badge color="primary" class="q-px-sm q-py-xs" style="border-radius: 8px">
                    {{ stockCart.length }} item(s)
                  </q-badge>
                </div>
              </div>

              <div
                class="border rounded-borders q-pa-sm scroll"
                style="
                  height: 450px;
                  background: var(--bw-theme-surface);
                  border: 1px solid var(--bw-theme-border);
                  border-radius: 12px;
                "
              >
                <div
                  v-if="stockCart.length === 0"
                  class="column items-center justify-center text-grey-5 q-py-xl"
                  style="height: 100%"
                >
                  <q-icon name="ph ph-shopping-cart" size="48px" class="q-mb-sm" />
                  <div class="text-subtitle2">Cart is empty</div>
                  <div class="text-caption text-center">
                    Click items in the search results to add them here
                  </div>
                </div>

                <q-list v-else separator>
                  <q-item
                    v-for="(item, idx) in stockCart"
                    :key="item.global_stock_id"
                    class="q-py-md q-px-sm"
                  >
                    <q-item-section avatar>
                      <q-avatar rounded size="48px" class="bg-grey-2 shadow-1">
                        <img
                          :src="item.image_url || 'https://placehold.co/48x48?text=No+Image'"
                          alt="product image"
                          style="object-fit: contain"
                        />
                      </q-avatar>
                    </q-item-section>

                    <q-item-section>
                      <q-item-label class="text-weight-bold text-subtitle2">{{
                        item.name
                      }}</q-item-label>
                      <q-item-label caption class="text-grey-7 row q-gutter-x-md flex-wrap">
                        <span v-if="item.product_code">Code: {{ item.product_code }}</span>
                        <span v-if="item.is_own_tenant" class="text-green-9 text-weight-bold"
                          >Own Stock</span
                        >
                        <span v-else-if="item.holding_tenant_name" class="text-grey-8">{{
                          item.holding_tenant_name
                        }}</span>
                        <span v-if="item.shipment_name" class="text-primary text-weight-bold">
                          Shipment: {{ item.shipment_name }}
                        </span>
                      </q-item-label>

                      <!-- Editable fields for each item -->
                      <div class="row q-col-gutter-sm q-mt-xs">
                        <div class="col-4">
                          <q-input
                            v-model.number="item.quantity"
                            type="number"
                            label="Quantity"
                            dense
                            outlined
                            min="1"
                            class="soft-input"
                          />
                        </div>
                        <div class="col-6">
                          <q-input
                            v-model.number="item.sell_price_amount"
                            type="number"
                            label="Sell Price"
                            dense
                            outlined
                            min="0"
                            class="soft-input"
                          />
                        </div>
                      </div>
                    </q-item-section>

                    <q-item-section side>
                      <q-btn
                        flat
                        round
                        dense
                        color="negative"
                        icon="ph ph-trash"
                        size="sm"
                        @click="stockCart.splice(idx, 1)"
                      >
                        <q-tooltip>Remove</q-tooltip>
                      </q-btn>
                    </q-item-section>
                  </q-item>
                </q-list>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            :label="
              stockCart.length
                ? `Add ${stockCart.length} Item${stockCart.length === 1 ? '' : 's'}`
                : 'Add'
            "
            :loading="addingItem"
            :disable="stockCart.length === 0"
            @click="onAddCartItems"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <WholesaleCollectPaymentDialog
      v-model="paymentDialog"
      :due-amount="invoice?.due_amount ?? 0"
      :paid-amount="invoice?.paid_amount ?? 0"
      :store-credit="storeCreditBalance"
      :saving="paymentSaving"
      @submit="onCollectPayment"
    />

    <!-- Record COD Dialog -->
    <q-dialog v-model="codDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Record COD Collection</q-card-section>
        <q-card-section class="q-gutter-md">
          <q-input
            v-model.number="codAmount"
            type="number"
            label="Amount collected"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model="codDate"
            label="Collection Date"
            outlined
            dense
            readonly
            class="soft-input"
          >
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="codDate" mask="YYYY-MM-DD" />
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <q-select
            v-model="codMethod"
            :options="paymentMethodOptions"
            label="Method"
            outlined
            dense
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="paymentSaving"
            @click="onRecordCod"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Settlement / Write-off Dialog -->
    <q-dialog v-model="settleDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Settle / Write-off</q-card-section>
        <q-card-section>
          <div class="text-caption text-grey-7 q-mb-sm">
            Records a settlement discount that closes the remaining due. Outstanding:
            {{ formatAmount(invoice?.due_amount ?? 0) }}
          </div>
          <q-input
            v-model.number="settleAmount"
            type="number"
            label="Discount amount"
            outlined
            dense
            min="0"
            :max="invoice?.due_amount ?? 0"
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="orange"
            label="Apply"
            :loading="paymentSaving"
            @click="onApplySettlement"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Pay Middle Man Dialog -->
    <q-dialog v-model="payoutDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Pay Middle Man</q-card-section>
        <q-card-section>
          <q-input
            v-model.number="payoutAmount"
            type="number"
            label="Payout amount"
            outlined
            dense
            min="0"
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="paymentSaving"
            @click="onRecordPayout"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add Return Dialog -->
    <q-dialog v-model="returnDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 400px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Add Return</q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-select
            v-model="returnItemId"
            :options="returnItemOptions"
            label="Invoice item"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
          />
          <q-input
            v-model.number="returnQty"
            type="number"
            label="Quantity"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-select
            v-model="returnGradeTagId"
            :options="returnGradeOptions"
            label="Condition grade"
            outlined
            dense
            emit-value
            map-options
            option-label="name"
            option-value="id"
            class="soft-input"
          />
          <q-select
            v-model="returnAvailability"
            :options="returnAvailabilityOptions"
            label="Availability"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
          />
          <q-input
            v-model.number="returnFaceAmount"
            type="number"
            label="Customer Refund Amount (Face)"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model.number="returnAccountingAmount"
            type="number"
            label="Seller Deduction Amount (Accounting)"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model.number="returnCharge"
            type="number"
            label="Return charge (optional)"
            outlined
            dense
            min="0"
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="returnSaving"
            :disable="!returnItemId || !returnGradeTagId || returnQty <= 0"
            @click="onAddReturn"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- View Note Dialog -->
    <q-dialog v-model="viewNoteDialog">
      <q-card
        class="q-pa-md"
        style="min-width: 500px; width: 90vw; max-width: 800px; border-radius: 16px"
      >
        <q-card-section class="text-h6 text-weight-bold">Invoice Note</q-card-section>
        <q-card-section class="invoice-note-preview invoice-note-preview--full scroll">
          <div v-html="invoice?.note || '—'"></div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Close" v-close-popup class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Edit Note Dialog -->
    <q-dialog v-model="editNoteDialog" persistent>
      <q-card
        class="q-pa-md"
        style="min-width: 500px; width: 90vw; max-width: 800px; border-radius: 16px"
      >
        <q-card-section class="text-h6 text-weight-bold">Edit Invoice Note</q-card-section>
        <q-card-section>
          <RichTextEditor v-model="noteEditValue" min-height="12rem" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" :disable="savingNote" />
          <q-btn
            color="primary"
            label="Save"
            :loading="savingNote"
            @click="saveNote"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useQueryClient } from '@tanstack/vue-query';

import RichTextEditor from 'src/components/ui/RichTextEditor.vue';
import GlobalInvoiceDetailPaper from '../components/GlobalInvoiceDetailPaper.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvoiceWorkspace } from '../composables/useInvoiceWorkspace';
import { supabase } from 'src/boot/supabase';
import { formatAmountBdt } from 'src/utils/currency';
import {
  showSuccessNotification,
  showWarningDialog,
  showWarningNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';

import { cleanEditorHtml } from 'src/utils/editor';
import { invoiceRepository } from '../repositories/invoiceRepository';
import type { TargetTotalSummary } from '../repositories/invoiceRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import NetworkStockSearchPanel from '../components/NetworkStockSearchPanel.vue';
import InvoiceBulkPasteDialog from '../components/InvoiceBulkPasteDialog.vue';
import WholesaleCollectPaymentDialog from '../components/WholesaleCollectPaymentDialog.vue';
import { walletRepository } from 'src/modules/wallet/repositories/walletRepository';
import type { InvoiceCollectionHistoryRow } from '../repositories/invoiceRepository';
import { invoiceGrossProfit, lineMargin } from 'src/modules/reporting_treasury/utils/margin';
import type { StockNetworkRow } from 'src/modules/global/types';
import { stockNetworkAvailableQty } from 'src/modules/global/utils/mapStockNetworkRow';
import { useInvoiceItemUnitCosts } from '../composables/useInvoiceItemUnitCosts';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from '../types';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
import { STOCK_AVAILABILITY_OPTIONS } from 'src/modules/procurement_stock/constants/stockAvailability';
import type { StockAvailability } from 'src/modules/procurement_stock/constants/stockAvailability';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();
const { isParentTenant } = useInvoiceWorkspace();
const queryClient = useQueryClient();
const canEditDraft = computed(
  () => invoice.value?.invoice_status === 'draft' && !isParentTenant.value,
);
const canMutateInvoice = computed(() => !isParentTenant.value);

const goBack = () => {
  void router.push({
    name: 'app-global-invoices-page',
    params: { tenantSlug: route.params.tenantSlug },
  });
};

const loading = ref(true);
const error = ref<string | null>(null);
const invoice = ref<GlobalInvoiceDetail | null>(null);
const items = ref<GlobalInvoiceItemRow[]>([]);
interface LinkedOrderRemittanceInfo {
  id: number;
  order_no: string;
  status: string;
  courier_remittance_ref: string | null;
  courier_bank_trx_id: string | null;
}
const linkedOrderRemittance = ref<LinkedOrderRemittanceInfo | null>(null);
const { resolveItemUnitCosts, getItemUnitCost } = useInvoiceItemUnitCosts();

const noteEditValue = ref('');
const editNoteDialog = ref(false);
const viewNoteDialog = ref(false);
const savingNote = ref(false);

const stockDialog = ref(false);
const addingItem = ref(false);

interface StockCartItem {
  global_stock_id: number;
  product_id: number | null;
  name: string;
  barcode: string | null;
  product_code: string | null;
  image_url: string | null;
  unitCost: number;
  holding_tenant_name: string | null;
  is_own_tenant: boolean;
  shipment_name: string | null;
  quantity: number;
  sell_price_amount: number;
  recipient_price_amount: number;
}
const stockCart = ref<StockCartItem[]>([]);

const paymentDialog = ref(false);
const codDialog = ref(false);
const settleDialog = ref(false);
const payoutDialog = ref(false);
const codAmount = ref(0);
const settleAmount = ref(0);
const payoutAmount = ref(0);
const paymentSaving = ref(false);

const localToday = (): string => {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
};
const paymentMethodOptions = ['cash', 'bkash', 'bank_transfer', 'nagad'];
const codDate = ref(localToday());
const codMethod = ref('cash');

const openPaymentDialog = async () => {
  paymentDialog.value = true;
  const profileId = invoice.value?.billing_profile_id;
  const tenantId = invoice.value?.parent_tenant_id ?? invoice.value?.tenant_id;
  if (!profileId || !tenantId) {
    storeCreditBalance.value = 0;
    return;
  }
  try {
    storeCreditBalance.value = await walletRepository.fetchLatestBalance({
      tenantId,
      entityType: 'customer',
      entityId: profileId,
    });
  } catch {
    storeCreditBalance.value = 0;
  }
};
const openCodDialog = () => {
  codAmount.value = 0;
  codDate.value = localToday();
  codMethod.value = 'cash';
  codDialog.value = true;
};

const goToProcessReturn = () => {
  if (!invoice.value?.id) return;
  void router.push({
    name: 'app-global-invoice-return-page',
    params: {
      tenantSlug: authStore.tenantSlug || '',
      id: String(invoice.value.id),
    },
  });
};


const returnDialog = ref(false);
const returnItemId = ref<number | null>(null);
const returnQty = ref(1);
const returnFaceAmount = ref(0);
const returnAccountingAmount = ref(0);
const returnCharge = ref(0);
const returnSaving = ref(false);
const returnGradeTagId = ref<number | null>(null);
const returnAvailability = ref<StockAvailability>('held');
const returnGradeOptions = ref<Tag[]>([]);
const returnAvailabilityOptions = STOCK_AVAILABILITY_OPTIONS;

const onToggleEditRecipient = () => {
  if (editingRecipient.value) {
    void onHeaderUpdate();
    editingRecipient.value = false;
  } else {
    editingRecipient.value = true;
  }
};

const onProcessReturnFromPaper = () => {
  if (invoice.value?.invoice_type === 'wholesale') {
    goToProcessReturn();
  } else {
    returnDialog.value = true;
  }
};

const postingInvoice = ref(false);
const voidingInvoice = ref(false);
const unpostingInvoice = ref(false);
const deletingInvoice = ref(false);
const convertingInvoice = ref(false);

const targetTotal = ref<number | null>(null);
const targetPreview = ref<TargetTotalSummary | null>(null);
const targetError = ref<string | null>(null);
const targetPreviewing = ref(false);
const applyingTarget = ref(false);
let targetDebounce: ReturnType<typeof setTimeout> | null = null;

const showPreview = computed(() => {
  if (!invoice.value) return false;
  // Proforma or Issued invoices can be previewed/printed
  return invoice.value.invoice_status === 'proforma_generated' || invoice.value.invoice_status === 'issued';
});
const showPayments = true;
const showReturns = true;
const editingRecipient = ref(false);

// Reactive form representing currently saved values on header
const form = reactive({
  discount_amount: 0,
  shipping_charge: 0,
  cod_charge_amount: 0,
  wrapping_charge: 0,
  print_charge: 0,
  recipient_name: '',
  recipient_phone: '',
  recipient_address: '',
  note: '',
  invoice_no: '',
  invoice_date: '',
});

const invoiceId = computed(() => Number(route.params.id));

const isDropship = computed(() => invoice.value?.invoice_type === 'dropship');

const loadLinkedOrderRemittance = async (inv: GlobalInvoiceDetail | null) => {
  if (!inv || inv.invoice_type !== 'dropship') {
    linkedOrderRemittance.value = null;
    return;
  }
  try {
    const { data } = await supabase
      .from('shop_orders')
      .select('id, order_no, status, courier_remittance_ref, courier_bank_trx_id')
      .eq('global_invoice_id', inv.id)
      .maybeSingle();
    linkedOrderRemittance.value = (data as LinkedOrderRemittanceInfo | null) ?? null;
  } catch {
    linkedOrderRemittance.value = null;
  }
};
const isWholesale = computed(() => invoice.value?.invoice_type === 'wholesale');
const showCharges = computed(() => !isWholesale.value);

const returnItemOptions = computed(() =>
  items.value.map((row) => ({ label: row.name_snapshot, value: row.id })),
);

const formatAmount = (value: number) => formatAmountBdt(value);

const getItemNameForReturn = (invoiceItemId: number) => {
  const item = items.value.find((i) => i.id === invoiceItemId);
  return item?.name_snapshot || `Item #${invoiceItemId}`;
};

const formatReturnDate = (dateStr: string) => {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return Number.isNaN(d.getTime()) ? dateStr : d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
};

const formatItemUnitCost = (row: GlobalInvoiceItemRow) => {
  const unitCost = getItemUnitCost(row);
  return unitCost == null ? '—' : formatAmount(unitCost);
};

const lineMarginForRow = (row: GlobalInvoiceItemRow) =>
  lineMargin({
    sell_price_amount: row.sell_price_amount,
    unit_cost_price: getItemUnitCost(row) ?? 0,
    quantity: row.quantity,
    line_discount_amount: row.line_discount_amount,
  });

const returnHistory = ref<any[]>([]);
const collectionHistory = ref<InvoiceCollectionHistoryRow[]>([]);
const storeCreditBalance = ref(0);

const collectionHistoryDisplay = computed(() => {
  const rows = collectionHistory.value.map((row) => ({
    id: `p-${row.id}`,
    created_at: row.created_at,
    kindLabel: row.kind === 'wallet_credit' ? 'Store credit' : 'Cash / bank',
    method: row.method,
    amount: row.amount,
  }));
  const settle = Number(invoice.value?.settlement_discount_amount ?? 0);
  if (settle > 0) {
    rows.push({
      id: 'settlement',
      created_at: invoice.value?.created_at || '',
      kindLabel: 'Settlement',
      method: 'write-off',
      amount: settle,
    });
  }
  return rows;
});

const totalReturnQuantity = computed(() => {
  return items.value.reduce((sum, row) => sum + (row.return_quantity || 0), 0);
});

const originalGrossSubtotal = computed(() => {
  return items.value.reduce(
    (sum, row) => sum + (row.quantity * row.sell_price_amount - (row.line_discount_amount || 0)),
    0,
  );
});

const totalReturnDeduction = computed(() => {
  return items.value.reduce(
    (sum, row) => sum + ((row.return_quantity || 0) * row.sell_price_amount),
    0,
  );
});

const totalCost = computed(() => {
  return items.value.reduce((sum, row) => sum + (getItemUnitCost(row) ?? 0) * (row.quantity - (row.return_quantity || 0)), 0);
});
const totalQuantity = computed(() => {
  return items.value.reduce((sum, row) => sum + (row.quantity - (row.return_quantity || 0)), 0);
});
const estimatedProfit = computed(() => {
  if (!invoice.value) return 0;
  return invoiceGrossProfit(
    {
      invoice_type: invoice.value.invoice_type as 'wholesale' | 'retail' | 'dropship',
      shipping_charge: invoice.value.shipping_charge,
      cod_charge_amount: invoice.value.cod_charge_amount,
      print_charge: invoice.value.print_charge,
      wrapping_charge: invoice.value.wrapping_charge,
      discount_amount: invoice.value.discount_amount,
      settlement_discount_amount: invoice.value.settlement_discount_amount,
      invoice_status: 'issued', // force posted to calculate profit
    },
    items.value.map((row) => ({
      ...row,
      id: row.id,
      quantity: row.quantity - (row.return_quantity || 0),
      unit_cost_price: getItemUnitCost(row) ?? 0,
    })),
  );
});

const averageProfitRate = computed(() => {
  const cost = totalCost.value;
  if (cost <= 0) return '-';
  const profit = estimatedProfit.value;
  const rate = (profit / cost) * 100;
  return `${rate.toFixed(2)}%`;
});

const loadInvoice = async () => {
  loading.value = true;
  error.value = null;
  try {
    const [inv, invItems, retItems, payItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(invoiceId.value),
      invoiceRepository.listGlobalInvoiceItems(invoiceId.value),
      invoiceRepository.listSalesReturnItems(invoiceId.value).catch(() => []),
      invoiceRepository.listInvoiceCollectionHistory(invoiceId.value).catch(() => []),
    ]);
    invoice.value = inv;
    items.value = invItems;
    returnHistory.value = retItems;
    collectionHistory.value = payItems;
    await resolveItemUnitCosts(invItems);
    await loadLinkedOrderRemittance(inv);

    // Sync form values
    form.discount_amount = inv.discount_amount;
    form.shipping_charge = inv.shipping_charge;
    form.cod_charge_amount = inv.cod_charge_amount ?? 0;
    form.wrapping_charge = inv.wrapping_charge;
    form.print_charge = inv.print_charge;
    form.recipient_name = inv.recipient_name || '';
    form.recipient_phone = inv.recipient_phone || '';
    form.recipient_address = inv.recipient_address || '';
    form.note = inv.note || '';
    form.invoice_no = inv.invoice_no || '';
    form.invoice_date = inv.invoice_date || '';
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load invoice.';
  } finally {
    loading.value = false;
  }
};

const refreshInvoiceHeader = async () => {
  try {
    const inv = await invoiceRepository.getGlobalInvoiceById(invoiceId.value);
    invoice.value = inv;
    await loadLinkedOrderRemittance(inv);

    // Sync form values
    form.discount_amount = inv.discount_amount;
    form.shipping_charge = inv.shipping_charge;
    form.cod_charge_amount = inv.cod_charge_amount ?? 0;
    form.wrapping_charge = inv.wrapping_charge;
    form.print_charge = inv.print_charge;
    form.recipient_name = inv.recipient_name || '';
    form.recipient_phone = inv.recipient_phone || '';
    form.recipient_address = inv.recipient_address || '';
    form.note = inv.note || '';
    form.invoice_no = inv.invoice_no || '';
    form.invoice_date = inv.invoice_date || '';
  } catch (e) {
    console.error('Failed to refresh invoice header', e);
  }
};

const onSelectStockRow = (row: StockNetworkRow) => {
  const unitCost = row.resolvedUnitCost ?? 0;
  const maxQty = stockNetworkAvailableQty(row);
  const existingIdx = stockCart.value.findIndex(
    (item) => item.global_stock_id === row.global_stock_id,
  );
  if (existingIdx > -1) {
    const existing = stockCart.value[existingIdx];
    if (existing) {
      if (existing.quantity >= maxQty) return;
      existing.quantity++;
      stockCart.value.splice(existingIdx, 1);
      stockCart.value.unshift(existing);
    }
  } else {
    if (maxQty <= 0) return;
    stockCart.value.unshift({
      global_stock_id: row.global_stock_id,
      product_id: row.product_id,
      name: row.name,
      barcode: row.barcode,
      product_code: row.product_code,
      image_url: row.image_url,
      unitCost,
      holding_tenant_name: row.holding_tenant_name ?? null,
      is_own_tenant: row.is_own_tenant,
      shipment_name: row.shipment_name ?? null,
      quantity: 1,
      sell_price_amount: unitCost,
      recipient_price_amount: unitCost,
    });
  }
};

const onAddCartItems = async () => {
  if (!invoice.value || stockCart.value.length === 0) return;
  addingItem.value = true;
  try {
    // Process items in opposite order of the stack display (oldest first)
    // to avoid Postgres lock contention and preserve chronological list order
    const itemsToInsert = [...stockCart.value].reverse();
    for (const item of itemsToInsert) {
      const payload = {
        invoice_id: invoice.value.id,
        global_stock_id: item.global_stock_id,
        quantity: item.quantity,
        sell_price_amount: item.sell_price_amount,
      };
      await invoiceRepository.addGlobalInvoiceItem(payload);
    }
    stockDialog.value = false;
    stockCart.value = [];
    await loadInvoice();
    showSuccessNotification('Items added to invoice successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to add items.');
  } finally {
    addingItem.value = false;
  }
};

const onRemoveItem = async (itemId: number) => {
  if (!invoice.value) return;
  try {
    await invoiceRepository.removeGlobalInvoiceItem(itemId);
    items.value = items.value.filter((item) => item.id !== itemId);
    await refreshInvoiceHeader();
    showSuccessNotification('Item removed successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to remove item.');
  }
};

const onUpdateItemField = async (
  row: GlobalInvoiceItemRow,
  field: 'quantity' | 'sell_price_amount',
  value: any,
) => {
  if (!invoice.value) return;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    showWarningNotification('Value must be 0 or greater.');
    return;
  }
  if (field === 'quantity' && parsed <= 0) {
    showWarningNotification('Quantity must be greater than 0.');
    return;
  }

  const quantity = field === 'quantity' ? parsed : row.quantity;
  const sellPrice = field === 'sell_price_amount' ? parsed : row.sell_price_amount;

  try {
    await invoiceRepository.updateGlobalInvoiceItem({
      id: row.id,
      quantity,
      sell_price_amount: sellPrice,
    });
    const itemIdx = items.value.findIndex((item) => item.id === row.id);
    const existing = itemIdx > -1 ? items.value[itemIdx] : null;
    if (existing) {
      existing.quantity = quantity;
      existing.sell_price_amount = sellPrice;
    }
    await refreshInvoiceHeader();
    showSuccessNotification('Item updated successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update item.');
  }
};

const openBulkPaste = () => {
  $q.dialog({
    component: InvoiceBulkPasteDialog,
    componentProps: { items: items.value, isDropship: isDropship.value },
  }).onOk(() => {
    void (async () => {
      items.value = await invoiceRepository.listGlobalInvoiceItems(invoiceId.value);
      await resolveItemUnitCosts(items.value);
      await refreshInvoiceHeader();
      showSuccessNotification('Bulk update applied.');
    })();
  });
};

const onTargetTotalModelUpdate = (value: number | null) => {
  targetTotal.value = value;
};

const onTargetTotalInput = () => {
  if (targetDebounce) clearTimeout(targetDebounce);
  targetError.value = null;
  const value = targetTotal.value;
  if (!invoice.value || value === null || !Number.isFinite(value) || value < 0) {
    targetPreview.value = null;
    targetPreviewing.value = false;
    return;
  }
  targetPreviewing.value = true;
  targetDebounce = setTimeout(() => {
    void (async () => {
      try {
        targetPreview.value = await invoiceRepository.applyGlobalInvoiceTargetTotal({
          id: invoice.value!.id,
          target_total: value,
          dry_run: true,
        });
        targetError.value = null;
      } catch (e) {
        targetPreview.value = null;
        targetError.value = e instanceof Error ? e.message : 'Cannot preview adjustment.';
      } finally {
        targetPreviewing.value = false;
      }
    })();
  }, 400);
};

const onApplyTargetTotal = async () => {
  if (!invoice.value || targetTotal.value === null) return;
  applyingTarget.value = true;
  try {
    await invoiceRepository.applyGlobalInvoiceTargetTotal({
      id: invoice.value.id,
      target_total: targetTotal.value,
      dry_run: false,
    });
    targetTotal.value = null;
    targetPreview.value = null;
    targetError.value = null;
    await loadInvoice();
    showSuccessNotification('Invoice adjusted to target total.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to adjust invoice total.');
  } finally {
    applyingTarget.value = false;
  }
};

const getMonthYear = (dateStr: string) => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('en-GB', { month: 'short', year: 'numeric' });
};

const onDateChange = async (val: string) => {
  if (!invoice.value) return;

  const monthYear = getMonthYear(val);
  const isWholesale = invoice.value.invoice_type === 'wholesale';
  const isDropship = invoice.value.invoice_type === 'dropship';
  const isRetail = invoice.value.invoice_type === 'retail';
  const isRetailDirect = isRetail && !invoice.value.billing_profile_id;

  let expectedProfileName = '';
  if (isWholesale || isDropship || (isRetail && invoice.value.billing_profile_id)) {
    expectedProfileName = invoice.value.billing_profiles?.name || '';
  } else if (isRetailDirect) {
    expectedProfileName = 'Retail Direct';
  }

  const currentNo = form.invoice_no.trim();
  if (!currentNo || currentNo.startsWith('Invoice - ')) {
    const newName = expectedProfileName
      ? `Invoice - ${expectedProfileName} - ${monthYear}`
      : `Invoice - ${monthYear}`;
    form.invoice_no = newName;
  }

  await onHeaderUpdate();
};

const onHeaderUpdate = async () => {
  if (!invoice.value) return;
  try {
    await invoiceRepository.updateGlobalInvoiceHeader({
      id: invoice.value.id,
      discount_amount: form.discount_amount,
      shipping_charge: form.shipping_charge,
      cod_charge_amount: form.cod_charge_amount,
      wrapping_charge: form.wrapping_charge,
      print_charge: form.print_charge,
      recipient_name: form.recipient_name.trim() || null,
      recipient_phone: form.recipient_phone.trim() || null,
      recipient_address: form.recipient_address.trim() || null,
      note: cleanEditorHtml(form.note || ''),
      invoice_no: form.invoice_no.trim() || null,
      invoice_date: form.invoice_date || null,
    });
    await refreshInvoiceHeader();
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update invoice details.');
  }
};

const openEditNoteDialog = () => {
  noteEditValue.value = invoice.value?.note || '';
  editNoteDialog.value = true;
};

const saveNote = async () => {
  if (!invoice.value) return;
  savingNote.value = true;
  try {
    await invoiceRepository.updateGlobalInvoiceHeader({
      id: invoice.value.id,
      discount_amount: form.discount_amount,
      shipping_charge: form.shipping_charge,
      cod_charge_amount: form.cod_charge_amount,
      wrapping_charge: form.wrapping_charge,
      print_charge: form.print_charge,
      recipient_name: form.recipient_name.trim() || null,
      recipient_phone: form.recipient_phone.trim() || null,
      recipient_address: form.recipient_address.trim() || null,
      note: cleanEditorHtml(noteEditValue.value),
      invoice_no: form.invoice_no.trim() || null,
      invoice_date: form.invoice_date || null,
    });
    await refreshInvoiceHeader();
    editNoteDialog.value = false;
    showSuccessNotification('Invoice note updated successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update invoice note.');
  } finally {
    savingNote.value = false;
  }
};

const onPostInvoice = async () => {
  if (!invoice.value) return;
  postingInvoice.value = true;
  try {
    await invoiceRepository.postGlobalInvoice(invoice.value.id);
    await loadInvoice();
    showSuccessNotification('Invoice posted successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to post invoice.');
  } finally {
    postingInvoice.value = false;
  }
};

const onVoidInvoice = async () => {
  if (!invoice.value) return;
  voidingInvoice.value = true;
  try {
    await invoiceRepository.voidGlobalInvoice(invoice.value.id);
    await loadInvoice();
    showSuccessNotification('Invoice voided successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to void invoice.');
  } finally {
    voidingInvoice.value = false;
  }
};

const onUnpostInvoice = async () => {
  if (!invoice.value) return;
  unpostingInvoice.value = true;
  try {
    await invoiceRepository.unpostGlobalInvoice(invoice.value.id);
    await loadInvoice();
    showSuccessNotification('Invoice unposted (reverted to draft) successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to unpost invoice.');
  } finally {
    unpostingInvoice.value = false;
  }
};

const canUnpostOrVoid = computed(() => {
  if (!invoice.value) return false;
  if (invoice.value.paid_amount > 0) return false;
  const hasReturns = items.value.some((item) => item.return_quantity > 0);
  return !hasReturns;
});

const isTransitionDisabled = (targetStatus: string) => {
  if (!invoice.value) return true;
  const current = invoice.value.invoice_status;
  if (current === targetStatus) return true;

  if (current === 'draft') {
    return targetStatus !== 'issued';
  }
  if (current === 'issued') {
    if (targetStatus === 'draft' || targetStatus === 'voided') {
      return !canUnpostOrVoid.value;
    }
    return true;
  }
  if (current === 'voided') {
    return true;
  }
  return true;
};

const changeInvoiceStatus = (newStatus: string) => {
  if (!invoice.value) return;
  const current = invoice.value.invoice_status;
  if (current === newStatus) return;

  if (newStatus === 'issued') {
    $q.dialog({
      title: 'Post Invoice',
      message:
        'Are you sure you want to post this invoice? This will lock the invoice and deduct the items from stock.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void onPostInvoice();
    });
  } else if (newStatus === 'draft') {
    $q.dialog({
      title: 'Undo Post / Unpost Invoice',
      message:
        'Are you sure you want to unpost this invoice and revert it to draft? This will restore the stock quantities.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void onUnpostInvoice();
    });
  } else if (newStatus === 'voided') {
    $q.dialog({
      title: 'Void Invoice',
      message:
        'Are you sure you want to void this invoice? This action will cancel the invoice and restore the stock quantities. It cannot be undone.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void onVoidInvoice();
    });
  }
};

const onDeleteInvoice = async () => {
  if (!invoice.value) return;
  const isVoided = invoice.value.invoice_status === 'voided';
  const confirmed = await requestConfirmation(
    isVoided
      ? 'Are you sure you want to delete this voided invoice? This action cannot be undone.'
      : 'Are you sure you want to delete this draft invoice? This action cannot be undone.',
    isVoided ? 'Delete Voided Invoice' : 'Delete Invoice Draft',
    'Delete',
  );
  if (!confirmed) return;
  deletingInvoice.value = true;
  try {
    await invoiceRepository.deleteGlobalInvoice(invoice.value.id);
    await queryClient.invalidateQueries({ queryKey: salesInvoiceQueryKeys.root });
    showSuccessNotification(
      isVoided ? 'Voided invoice deleted successfully.' : 'Draft invoice deleted successfully.',
    );
    void router.push({
      name: 'app-global-invoices-page',
      params: { tenantSlug: authStore.tenantSlug },
    });
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to delete invoice.');
  } finally {
    deletingInvoice.value = false;
  }
};

const onConvertWholesaleToRetail = async () => {
  if (!invoice.value) return;
  const confirmed = await requestConfirmation(
    'Are you sure you want to convert this wholesale draft invoice to retail account mode? This action cannot be undone.',
    'Convert Invoice to Retail',
    'Convert',
  );
  if (!confirmed) return;
  convertingInvoice.value = true;
  try {
    await invoiceRepository.convertWholesaleDraftToRetail(invoice.value.id);
    showSuccessNotification('Wholesale invoice converted to Retail successfully.');
    await loadInvoice();
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to convert invoice.');
  } finally {
    convertingInvoice.value = false;
  }
};

const openPreview = () => {
  void router.push({
    name: 'app-global-invoice-preview',
    params: { tenantSlug: authStore.tenantSlug, id: invoiceId.value },
  });
};

const onCollectPayment = async (payload: {
  cashAmount: number;
  cashMethod: string;
  walletAmount: number;
  settlementAmount: number;
}) => {
  if (!invoice.value) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.collectWholesaleInvoicePayment({
      invoice_id: invoice.value.id,
      cash_amount: payload.cashAmount,
      cash_method: payload.cashMethod,
      wallet_amount: payload.walletAmount,
      settlement_amount: payload.settlementAmount,
    });
    paymentDialog.value = false;
    await loadInvoice();
    showSuccessNotification('Payment recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payment failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const onRecordCod = async () => {
  if (!invoice.value) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.recordRecipientInvoiceCollection(invoice.value.id, codAmount.value, {
      payment_date: codDate.value,
      method: codMethod.value,
    });
    codDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('COD recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'COD recording failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const openSettleDialog = () => {
  settleAmount.value = invoice.value?.due_amount ?? 0;
  settleDialog.value = true;
};

const onApplySettlement = async () => {
  if (!invoice.value) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.applySettlementDiscount(invoice.value.id, settleAmount.value);
    settleDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('Settlement discount applied.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Settlement failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const onRecordPayout = async () => {
  if (!invoice.value?.billing_profile_id) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.createMiddleManPayout({
      tenant_id: invoice.value.issued_by_tenant_id || invoice.value.parent_tenant_id,
      billing_profile_id: invoice.value.billing_profile_id,
      global_invoice_id: invoice.value.id,
      amount: payoutAmount.value,
    });
    payoutDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('Payout recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payout failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const onAddReturn = async () => {
  if (!invoice.value || !returnItemId.value) return;
  returnSaving.value = true;
  try {
    await invoiceRepository.addGlobalReturnItem({
      invoice_id: invoice.value.id,
      invoice_item_id: returnItemId.value,
      quantity: returnQty.value,
      return_face_amount: returnFaceAmount.value,
      return_accounting_amount: returnAccountingAmount.value,
      return_charge_amount: returnCharge.value || 0,
      to_grade_tag_id: returnGradeTagId.value,
      to_availability: returnAvailability.value,
    });
    returnDialog.value = false;
    await loadInvoice();
    showSuccessNotification('Return recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Return failed.');
  } finally {
    returnSaving.value = false;
  }
};

watch(stockDialog, (open) => {
  if (!open) {
    stockCart.value = [];
  }
});

watch(returnDialog, async (open) => {
  if (!open) return;
  returnAvailability.value = 'held';
  try {
    returnGradeOptions.value = await tagRepository.listTagsForCategory({
      moduleKey: 'stock_grade',
      code: 'warehouse',
    });
    const standard = returnGradeOptions.value.find((g) => g.slug === 'standard');
    returnGradeTagId.value = standard?.id ?? returnGradeOptions.value[0]?.id ?? null;
  } catch {
    returnGradeOptions.value = [];
    returnGradeTagId.value = null;
  }
});

watch(returnGradeTagId, (gradeId) => {
  const g = returnGradeOptions.value.find((opt) => opt.id === gradeId);
  if (g?.metadata?.maps_to_availability === 'unsellable') {
    returnAvailability.value = 'unsellable';
  } else if (returnAvailability.value === 'unsellable') {
    returnAvailability.value = 'held';
  }
});

watch([returnItemId, returnQty], () => {
  if (!returnItemId.value) return;
  const item = items.value.find((i) => i.id === returnItemId.value);
  if (item) {
    const qty = Number(returnQty.value || 0);
    const sellPrice = Number(item.sell_price_amount || 0);

    returnAccountingAmount.value = sellPrice * qty;
    returnFaceAmount.value = sellPrice * qty;
  }
});

onMounted(() => {
  void loadInvoice();
});
</script>

<style scoped>
.global-invoice-details-page {
  background: #eef1f4;
  min-height: 100%;
}

.global-invoice-details-page__inner {
  max-width: 880px;
  margin: 0 auto;
  padding: 1rem 1rem 2rem;
}

.global-invoice-details-page__toolbar {
  max-width: 800px;
  margin: 0 auto;
}

.global-invoice-details-page__paper-wrap {
  max-width: 800px;
  margin: 0 auto;
}

.global-invoice-details-page__actions {
  max-width: 800px;
  margin: 0.75rem auto 0;
}

.global-invoice-details-page__action-btn {
  min-height: 44px;
  border-radius: 8px;
}

.invoice-paper-skeleton {
  background: #fffdf8;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 2px;
}

.pill-btn {
  border-radius: 8px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.invoice-note-preview--full {
  max-height: 70vh;
  overflow-y: auto;
}

.invoice-note-preview :deep(p) {
  margin: 0 0 8px 0;
}

.invoice-note-preview :deep(p:last-child) {
  margin-bottom: 0;
}

.invoice-note-preview :deep(ul),
.invoice-note-preview :deep(ol) {
  margin: 0 0 8px 0;
  padding-left: 20px;
}

.invoice-note-preview :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 12px 0;
}

.invoice-note-preview :deep(th),
.invoice-note-preview :deep(td) {
  border: 1px solid rgba(0, 0, 0, 0.12);
  padding: 8px 12px;
  text-align: left;
}

.invoice-note-preview :deep(th) {
  background-color: rgba(0, 0, 0, 0.04);
  font-weight: bold;
}
</style>
