<template>
  <q-page class="wholesale-invoice-return-page page-fixed-layout bg-grey-1 column no-wrap">
    <!-- Top Fixed Compact Bar -->
    <div class="return-page-header row items-center justify-between q-px-md q-py-sm bg-white border-bottom shadow-1">
      <div class="row items-center q-gutter-x-sm">
        <q-btn
          flat
          dense
          round
          icon="ph ph-arrow-left"
          color="grey-7"
          @click="goBack"
        >
          <q-tooltip>Back to Invoice</q-tooltip>
        </q-btn>
        <div>
          <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center q-gutter-xs">
            <span>Process Return: {{ invoice?.invoice_no || `Invoice #${invoiceId}` }}</span>
            <q-badge color="purple-1" text-color="purple-9" label="Wholesale Return" class="text-weight-bold q-ml-xs" />
          </div>
          <div class="text-caption text-grey-6">
            Customer: <strong class="text-grey-9">{{ invoice?.billing_profiles?.name || invoice?.recipient_name || 'Wholesale Client' }}</strong>
            <span class="q-mx-xs">•</span>
            Invoice Date: {{ invoice?.invoice_date || '—' }}
          </div>
        </div>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          dense
          no-caps
          label="Cancel"
          color="grey-7"
          class="q-px-sm text-weight-bold border-btn"
          @click="goBack"
        />
        <q-btn
          unelevated
          dense
          no-caps
          color="primary"
          icon="ph ph-arrow-u-down-left"
          label="Submit Return"
          class="q-px-md text-weight-bold submit-return-btn"
          :loading="isSubmitting"
          :disable="!hasEligibleReturnItems || isSubmitting"
          @click="onSubmitReturn"
        >
          <q-tooltip v-if="!hasEligibleReturnItems">Select at least one item with return quantity > 0</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="col column items-center justify-center q-pa-xl">
      <q-spinner-tail color="primary" size="48px" />
      <div class="text-subtitle2 text-grey-7 q-mt-md">Loading invoice return details...</div>
    </div>

    <!-- Error State -->
    <div v-else-if="errorMessage" class="col column items-center justify-center q-pa-xl">
      <q-icon name="ph ph-warning-circle" color="negative" size="48px" />
      <div class="text-subtitle1 text-weight-bold text-negative q-mt-sm">{{ errorMessage }}</div>
      <q-btn flat dense no-caps color="primary" label="Return to Invoices" class="q-mt-md" @click="goBack" />
    </div>

    <!-- Main Content Area: 2-Panel Non-Scrolling Layout -->
    <div v-else class="col row no-wrap return-body-container q-pa-md q-col-gutter-md overflow-hidden">
      
      <!-- Left Panel: Return Items Configuration (Flex scrollable table) -->
      <div class="col-12 col-md-8 column no-wrap full-height">
        <q-card flat class="floating-surface shadow-1 col column no-wrap overflow-hidden">
          
          <!-- Table Toolbar -->
          <div class="row items-center justify-between q-px-md q-py-sm border-bottom bg-white">
            <div class="row items-center q-gutter-sm">
              <q-checkbox
                v-model="selectAll"
                dense
                label="Select All Items for Return"
                class="text-weight-bold text-caption text-grey-9"
                @update:model-value="onToggleSelectAll"
              />
            </div>
            <div class="text-caption text-grey-6">
              Returning <strong class="text-primary">{{ selectedCount }}</strong> of {{ invoiceItems.length }} lines
            </div>
          </div>

          <!-- Items Table -->
          <div class="col overflow-auto">
            <table class="wholesale-return-table full-width">
              <thead>
                <tr>
                  <th style="width: 40px" class="text-center">#</th>
                  <th class="text-left" style="min-width: 220px">Product & Shipment</th>
                  <th class="text-center" style="width: 130px">Invoiced / Avail</th>
                  <th class="text-center" style="width: 140px">Return Qty</th>
                  <th class="text-left" style="min-width: 160px">Stock Condition</th>
                  <th class="text-left" style="min-width: 150px">Note / Reason</th>
                  <th class="text-right" style="width: 110px">Return Value</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(item) in returnTableRows"
                  :key="item.id"
                  :class="{ 'row-selected': item.input.selected }"
                >
                  <!-- Select Checkbox -->
                  <td class="text-center">
                    <q-checkbox
                      v-model="item.input.selected"
                      dense
                      :disable="item.maxReturnable <= 0"
                      @update:model-value="(val) => onToggleItemSelect(item.id, !!val)"
                    />
                  </td>

                  <!-- Product Name & Metadata -->
                  <td>
                    <div class="row items-center no-wrap q-gutter-x-sm">
                      <q-avatar square size="34px" rounded class="bg-grey-2 border-light">
                        <img
                          v-if="item.image_url"
                          :src="item.image_url"
                          alt="Product"
                          style="object-fit: cover"
                        />
                        <q-icon v-else name="ph ph-package" color="grey-6" size="20px" />
                      </q-avatar>
                      <div class="min-width-0">
                        <div class="text-weight-bold text-grey-9 text-xs ellipsis-2-lines">
                          {{ item.name_snapshot }}
                        </div>
                        <div class="text-caption text-grey-6 text-xxs">
                          Unit: {{ formatBdt(item.sell_price_amount) }}
                          <span v-if="item.product_code_snapshot" class="q-ml-xs">({{ item.product_code_snapshot }})</span>
                        </div>
                      </div>
                    </div>
                  </td>

                  <!-- Invoiced & Available counts -->
                  <td class="text-center">
                    <div class="text-caption text-weight-bold text-grey-9">
                      {{ item.quantity }} pcs
                    </div>
                    <div class="text-xxs" :class="item.maxReturnable > 0 ? 'text-positive' : 'text-grey-5'">
                      {{ item.maxReturnable }} returnable
                    </div>
                  </td>

                  <!-- Return Qty Input Controls -->
                  <td class="text-center">
                    <div class="row items-center justify-center no-wrap q-gutter-xs">
                      <q-btn
                        flat
                        dense
                        round
                        size="xs"
                        icon="ph ph-minus"
                        class="qty-btn"
                        :disable="!item.input.selected || item.input.quantity <= 0"
                        @click="decrementQty(item.id)"
                      />
                      <q-input
                        v-model.number="item.input.quantity"
                        type="number"
                        dense
                        outlined
                        min="0"
                        :max="item.maxReturnable"
                        class="qty-input text-center text-weight-bold"
                        :disable="!item.input.selected"
                        @update:model-value="() => onQtyChange(item.id)"
                      />
                      <q-btn
                        flat
                        dense
                        round
                        size="xs"
                        icon="ph ph-plus"
                        class="qty-btn"
                        :disable="!item.input.selected || item.input.quantity >= item.maxReturnable"
                        @click="incrementQty(item.id)"
                      />
                    </div>
                  </td>

                  <!-- Condition: Grade Tag & Availability -->
                  <td>
                    <div class="column q-gutter-xs" :class="{ 'opacity-40': !item.input.selected }">
                      <q-select
                        v-model="item.input.to_grade_tag_id"
                        :options="gradeTagOptions"
                        option-value="id"
                        option-label="name"
                        emit-value
                        map-options
                        dense
                        outlined
                        class="condition-select"
                        :disable="!item.input.selected"
                        @update:model-value="(gradeId) => onGradeTagChange(item.id, gradeId)"
                      />
                      <q-select
                        v-model="item.input.to_availability"
                        :options="availabilityOptions"
                        dense
                        outlined
                        emit-value
                        map-options
                        class="condition-select"
                        :disable="!item.input.selected"
                      />
                    </div>
                  </td>

                  <!-- Note / Reason -->
                  <td>
                    <q-input
                      v-model="item.input.note"
                      placeholder="e.g. Broken zipper"
                      dense
                      outlined
                      class="soft-input text-caption"
                      :disable="!item.input.selected"
                    />
                  </td>

                  <!-- Line Return Value -->
                  <td class="text-right text-weight-bold">
                    <span :class="item.returnValue > 0 ? 'text-primary' : 'text-grey-5'">
                      {{ formatBdt(item.returnValue) }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>

          </div>
        </q-card>
      </div>

      <!-- Right Panel: Live Settlement Preview Card -->
      <div class="col-12 col-md-4 column no-wrap full-height">
        <q-card flat class="floating-surface shadow-1 col column no-wrap q-pa-md overflow-auto">
          
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm row items-center justify-between">
            <span>Settlement Preview</span>
            <q-badge color="blue-1" text-color="blue-9" label="Live In-Memory" class="text-weight-bold" />
          </div>

          <!-- Summary Rows -->
          <div class="column q-gutter-y-xs text-caption border-bottom q-pb-sm q-mb-sm">
            <div class="row justify-between text-grey-7">
              <span>Original Invoice Total:</span>
              <span class="text-weight-bold text-grey-9">{{ formatBdt(previewSummary.originalTotal) }}</span>
            </div>
            <div class="row justify-between text-grey-7">
              <span>Paid by Customer:</span>
              <span class="text-weight-bold text-positive">{{ formatBdt(previewSummary.originalPaid) }}</span>
            </div>
            <div class="row justify-between text-grey-7">
              <span>Original Due Amount:</span>
              <span class="text-weight-bold text-negative">{{ formatBdt(previewSummary.originalDue) }}</span>
            </div>
          </div>

          <!-- Return Value & Charges -->
          <div class="column q-gutter-y-xs text-caption border-bottom q-pb-sm q-mb-sm">
            <div class="row justify-between text-primary text-weight-bold">
              <span>Gross Return Value:</span>
              <span>- {{ formatBdt(previewSummary.totalReturnValue) }}</span>
            </div>
            
            <div class="row justify-between items-center text-grey-7 q-mt-xs">
              <span>Restocking Fee / Charge:</span>
              <div style="width: 110px">
                <q-input
                  v-model.number="returnChargeAmount"
                  type="number"
                  dense
                  outlined
                  min="0"
                  prefix="৳"
                  class="charge-input text-right"
                />
              </div>
            </div>

            <div class="row justify-between text-grey-9 text-weight-bold q-mt-xs">
              <span>Net Return Credit:</span>
              <span class="text-primary">{{ formatBdt(previewSummary.netReturnCredit) }}</span>
            </div>
          </div>

          <!-- Revised Invoice Outcome -->
          <div class="bg-grey-1 rounded-borders-8 q-pa-sm q-mb-md border-light">
            <div class="text-xxs text-weight-bolder text-grey-6 text-uppercase q-mb-xs">Outcome After Return</div>
            <div class="row justify-between text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">
              <span>Revised Invoice Total:</span>
              <span>{{ formatBdt(previewSummary.newTotal) }}</span>
            </div>
            <div class="row justify-between text-caption text-grey-8">
              <span>New Remaining Due:</span>
              <span class="text-weight-bold" :class="previewSummary.newDue > 0 ? 'text-negative' : 'text-positive'">
                {{ formatBdt(previewSummary.newDue) }}
              </span>
            </div>
            <div v-if="previewSummary.excessPaidRefund > 0" class="row justify-between text-caption text-purple-9 text-weight-bold q-mt-xs">
              <span>Customer Refund Due:</span>
              <span>{{ formatBdt(previewSummary.excessPaidRefund) }}</span>
            </div>
          </div>

          <!-- Refund Channel Selection (When Excess Paid > 0) -->
          <div v-if="previewSummary.excessPaidRefund > 0" class="refund-channel-box q-pa-sm rounded-borders-8 q-mb-md">
            <div class="text-caption text-weight-bold text-grey-9 q-mb-xs row items-center">
              <q-icon name="ph ph-wallet" color="primary" class="q-mr-xs" />
              Select Refund Channel:
            </div>
            
            <q-option-group
              v-model="refundMethod"
              :options="refundMethodOptions"
              dense
              color="primary"
              class="q-gutter-xs text-caption"
            />
          </div>

          <!-- Internal Return Note -->
          <div class="q-mb-md">
            <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Overall Return Audit Note:</div>
            <q-input
              v-model="overallReturnNote"
              placeholder="Internal memo for audit..."
              type="textarea"
              rows="2"
              dense
              outlined
              class="soft-input text-caption"
            />
          </div>

          <!-- Bottom Action Buttons -->
          <div class="column q-gutter-y-sm q-mt-auto">
            <q-btn
              unelevated
              no-caps
              color="primary"
              icon="ph ph-check-circle"
              label="Confirm & Submit Return"
              class="full-width text-weight-bold submit-btn"
              :loading="isSubmitting"
              :disable="!hasEligibleReturnItems || isSubmitting"
              @click="onSubmitReturn"
            />
            <div class="text-xxs text-grey-6 text-center">
              Submits atomic stock return movement & recalculates invoice dues.
            </div>
          </div>

        </q-card>
      </div>

    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { invoiceRepository } from '../repositories/invoiceRepository';
import { computeWholesaleReturnPreview } from '../services/wholesaleReturnEngine';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
import type { StockAvailability } from 'src/modules/procurement_stock/constants/stockAvailability';
import type {
  GlobalInvoiceDetail,
  GlobalInvoiceItemRow,
  WholesaleReturnItemInput,
} from '../types';
import { formatAmountBdt } from 'src/utils/currency';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const invoiceId = computed(() => {
  const param = route.params.id || route.query.id;
  return param ? Number(param) : 0;
});

const isLoading = ref(true);
const isSubmitting = ref(false);
const errorMessage = ref<string | null>(null);

const invoice = ref<GlobalInvoiceDetail | null>(null);
const invoiceItems = ref<GlobalInvoiceItemRow[]>([]);
const gradeTags = ref<Tag[]>([]);

const selectAll = ref(false);
const returnChargeAmount = ref<number>(0);
const refundMethod = ref<'wallet_credit' | 'payout'>('wallet_credit');
const overallReturnNote = ref('');

interface ReturnItemState {
  selected: boolean;
  quantity: number;
  to_grade_tag_id: number | null;
  to_availability: StockAvailability;
  note: string;
}

const returnInputs = ref<Record<number, ReturnItemState>>({});

const formatBdt = (val?: number | null) => formatAmountBdt(val ?? 0);

const availabilityOptions: { label: string; value: StockAvailability }[] = [
  { label: 'Held (Quarantine / Default)', value: 'held' },
  { label: 'Sellable (Mint Condition)', value: 'sellable' },
  { label: 'Unsellable (Damaged / Scrap)', value: 'unsellable' },
];

const gradeTagOptions = computed(() => {
  return gradeTags.value.map((t) => ({
    id: t.id,
    name: t.name,
  }));
});

const refundMethodOptions = [
  { label: 'Credit to Customer Wallet (Store Credit)', value: 'wallet_credit' },
  { label: 'Direct Cash / Bank / MFS Payout', value: 'payout' },
];

const getMaxReturnable = (item: GlobalInvoiceItemRow) => {
  const invQty = Number(item.quantity ?? 0);
  const retQty = Number(item.return_quantity ?? 0);
  return Math.max(invQty - retQty, 0);
};


const selectedCount = computed(() => {
  return Object.values(returnInputs.value).filter((s) => s.selected && s.quantity > 0).length;
});

const hasEligibleReturnItems = computed(() => {
  return selectedCount.value > 0;
});

const previewSummary = computed(() => {
  if (!invoice.value) {
    return {
      originalSubtotal: 0,
      originalTotal: 0,
      originalPaid: 0,
      originalDue: 0,
      totalReturnValue: 0,
      returnCharge: 0,
      netReturnCredit: 0,
      newSubtotal: 0,
      newTotal: 0,
      newDue: 0,
      excessPaidRefund: 0,
      settlementType: 'no_money_exchanged' as const,
      lineSummaries: [],
    };
  }

  const inputs: WholesaleReturnItemInput[] = [];
  for (const item of invoiceItems.value) {
    const s = returnInputs.value[item.id];
    if (s && s.selected && s.quantity > 0) {
      inputs.push({
        invoice_item_id: item.id,
        quantity: s.quantity,
        to_availability: s.to_availability,
        to_grade_tag_id: s.to_grade_tag_id,
        note: s.note,
      });
    }
  }

  return computeWholesaleReturnPreview(
    invoice.value,
    invoiceItems.value,
    inputs,
    returnChargeAmount.value,
  );
});

const returnTableRows = computed(() => {
  return invoiceItems.value.map((item) => {
    const invQty = Number(item.quantity ?? 0);
    const retQty = Number(item.return_quantity ?? 0);
    const maxReturnable = Math.max(invQty - retQty, 0);

    const input = returnInputs.value[item.id] ?? {
      selected: false,
      quantity: 0,
      to_grade_tag_id: null,
      to_availability: 'held' as StockAvailability,
      note: '',
    };

    const returnValue = input.selected ? Math.round(input.quantity * Number(item.sell_price_amount ?? 0) * 100) / 100 : 0;

    return {
      ...item,
      maxReturnable,
      input,
      returnValue,
    };
  });
});

const onToggleItemSelect = (itemId: number, val: boolean) => {
  const state = returnInputs.value[itemId];
  if (!state) return;
  state.selected = val;
  const item = invoiceItems.value.find((i) => i.id === itemId);
  if (val && state.quantity === 0 && item) {
    state.quantity = getMaxReturnable(item);
  }
};

const onToggleSelectAll = (val: boolean) => {
  for (const item of invoiceItems.value) {
    const max = getMaxReturnable(item);
    const state = returnInputs.value[item.id];
    if (state && max > 0) {
      state.selected = val;
      state.quantity = val ? max : 0;
    }
  }
};

const incrementQty = (itemId: number) => {
  const state = returnInputs.value[itemId];
  const item = invoiceItems.value.find((i) => i.id === itemId);
  if (!state || !item) return;
  const max = getMaxReturnable(item);
  if (state.quantity < max) {
    state.quantity += 1;
    state.selected = true;
  }
};

const decrementQty = (itemId: number) => {
  const state = returnInputs.value[itemId];
  if (state && state.quantity > 0) {
    state.quantity -= 1;
    if (state.quantity === 0) {
      state.selected = false;
    }
  }
};

const onQtyChange = (itemId: number) => {
  const state = returnInputs.value[itemId];
  const item = invoiceItems.value.find((i) => i.id === itemId);
  if (!state || !item) return;
  const max = getMaxReturnable(item);
  if (state.quantity > max) state.quantity = max;
  if (state.quantity < 0) state.quantity = 0;
  state.selected = state.quantity > 0;
};


const onGradeTagChange = (itemId: number, gradeId: number | null) => {
  const tag = gradeTags.value.find((t) => t.id === gradeId);
  const state = returnInputs.value[itemId];
  if (!state) return;
  if (tag?.metadata?.maps_to_availability === 'unsellable') {
    state.to_availability = 'unsellable';
  } else if (state.to_availability === 'unsellable') {
    state.to_availability = 'held';
  }
};

const loadData = async () => {
  if (!invoiceId.value) {
    errorMessage.value = 'Invalid Invoice ID';
    isLoading.value = false;
    return;
  }

  isLoading.value = true;
  errorMessage.value = null;

  try {
    const [invData, itemsData, tagsData] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(invoiceId.value),
      invoiceRepository.listGlobalInvoiceItems(invoiceId.value),
      tagRepository.listTagsForCategory({
        moduleKey: 'stock_grade',
        code: 'warehouse',
      }).catch(() => [] as Tag[]),
    ]);

    if (!invData) {
      errorMessage.value = 'Invoice not found.';
      return;
    }

    if (invData.invoice_status !== 'posted') {
      errorMessage.value = 'Only issued/posted wholesale invoices can process returns.';
      return;
    }

    invoice.value = invData;
    invoiceItems.value = itemsData;
    gradeTags.value = tagsData;

    const defaultGrade = tagsData.find((t) => t.slug === 'standard')?.id ?? tagsData[0]?.id ?? null;

    // Initialize state mapping for each item
    const initInputs: Record<number, ReturnItemState> = {};
    for (const item of itemsData) {
      initInputs[item.id] = {
        selected: false,
        quantity: 0,
        to_grade_tag_id: defaultGrade,
        to_availability: 'held',
        note: '',
      };
    }
    returnInputs.value = initInputs;

  } catch (err) {
    console.error('Error loading invoice return page data:', err);
    errorMessage.value = err instanceof Error ? err.message : 'Failed to load invoice';
  } finally {
    isLoading.value = false;
  }
};

const onSubmitReturn = async () => {
  if (!invoice.value || !hasEligibleReturnItems.value || isSubmitting.value) return;

  const returnPayloadItems: WholesaleReturnItemInput[] = [];
  for (const item of invoiceItems.value) {
    const s = returnInputs.value[item.id];
    if (s && s.selected && s.quantity > 0) {
      returnPayloadItems.push({
        invoice_item_id: item.id,
        quantity: s.quantity,
        to_availability: s.to_availability,
        to_grade_tag_id: s.to_grade_tag_id,
        note: s.note || null,
      });
    }
  }

  isSubmitting.value = true;
  try {
    await invoiceRepository.processWholesaleInvoiceReturn({
      invoice_id: invoice.value.id,
      items: returnPayloadItems,
      return_charge_amount: returnChargeAmount.value,
      refund_method: previewSummary.value.excessPaidRefund > 0 ? refundMethod.value : null,
      note: overallReturnNote.value || null,
    });

    showSuccessNotification('Wholesale return recorded and stock received back into quarantine.');
    goBack();
  } catch (err) {
    console.error('Error processing return:', err);
    showWarningDialog(err instanceof Error ? err.message : 'Return failed');
  } finally {
    isSubmitting.value = false;
  }
};

const goBack = () => {
  if (invoice.value?.id) {
    void router.push({
      name: 'app-global-invoices-create-wholesale',
      params: {
        tenantSlug: authStore.tenantSlug || '',
      },
      query: {
        id: String(invoice.value.id),
      },
    });
  } else {
    void router.push({
      name: 'app-global-invoices-page',
      params: {
        tenantSlug: authStore.tenantSlug || '',
      },
    });
  }
};

onMounted(() => {
  void loadData();
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.border-bottom {
  border-bottom: 1px solid rgba(226, 232, 240, 0.8);
}

.border-light {
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.rounded-borders-8 {
  border-radius: 8px;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.wholesale-return-table {
  border-collapse: collapse;
  font-size: 13px;
}

.wholesale-return-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
  color: #0f172a;
  font-weight: 700;
  padding: 8px 12px;
  border-bottom: 1px solid #e2e8f0;
}

.wholesale-return-table tbody tr td {
  padding: 8px 12px;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: middle;
}

.wholesale-return-table tbody tr.row-selected {
  background-color: #f5f3ff;
  box-shadow: inset 3px 0 0 #7c3aed;
}

.qty-btn {
  width: 24px;
  height: 24px;
  background: #f1f5f9;
}

.qty-input {
  width: 60px;
}

.qty-input :deep(.q-field__control) {
  height: 28px;
  padding: 0 4px;
}

.condition-select :deep(.q-field__control) {
  height: 28px;
  min-height: 28px;
  font-size: 11px;
}

.charge-input :deep(.q-field__control) {
  height: 28px;
  font-size: 12px;
}

.refund-channel-box {
  background: #faf5ff;
  border: 1px solid #e9d5ff;
}

.submit-return-btn,
.submit-btn {
  border-radius: 8px;
}

.border-btn {
  border: 1px solid #cbd5e1;
  border-radius: 8px;
}

.text-xxs {
  font-size: 10px;
}

.opacity-40 {
  opacity: 0.4;
}
</style>
