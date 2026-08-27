<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { TargetTotalSummary } from '../repositories/invoiceRepository';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from '../types';

export interface InvoiceDetailFormState {
  discount_amount: number;
  shipping_charge: number;
  cod_charge: number;
  wrapping_charge: number;
  print_charge: number;
  recipient_name: string;
  recipient_phone: string;
  recipient_address: string;
  note: string;
  invoice_no: string;
  invoice_date: string;
}

export interface LinkedOrderRemittanceInfo {
  id: number;
  order_no: string;
  status: string;
  courier_remittance_ref: string | null;
  courier_bank_trx_id: string | null;
}

export interface CollectionHistoryDisplayRow {
  id: string;
  created_at: string;
  kindLabel: string;
  method: string | null;
  amount: number;
}

const props = defineProps<{
  invoice: GlobalInvoiceDetail;
  items: GlobalInvoiceItemRow[];
  form: InvoiceDetailFormState;
  tenantSlug: string | undefined;
  canEditDraft: boolean;
  canMutateInvoice: boolean;
  isParentTenant: boolean;
  isDropship: boolean;
  isWholesale: boolean;
  showCharges: boolean;
  showReturns: boolean;
  linkedOrderRemittance: LinkedOrderRemittanceInfo | null;
  collectionHistory: CollectionHistoryDisplayRow[];
  returnHistory: Array<{ id: number; invoice_item_id: number; quantity: number; note?: string | null; created_at: string }>;
  totalReturnQuantity: number;
  originalGrossSubtotal: number;
  totalReturnDeduction: number;
  totalCost: number;
  totalQuantity: number;
  estimatedProfit: number;
  averageProfitRate: string;
  formatItemUnitCost: (row: GlobalInvoiceItemRow) => string;
  lineMarginForRow: (row: GlobalInvoiceItemRow) => number;
  getItemNameForReturn: (invoiceItemId: number) => string;
  formatReturnDate: (dateStr: string) => string;
  postingInvoice: boolean;
  voidingInvoice: boolean;
  unpostingInvoice: boolean;
  isTransitionDisabled: (targetStatus: string) => boolean;
  targetTotal: number | null;
  targetPreview: TargetTotalSummary | null;
  targetError: string | null;
  targetPreviewing: boolean;
  applyingTarget: boolean;
  editingRecipient: boolean;
}>();

const emit = defineEmits<{
  (e: 'header-blur'): void;
  (e: 'date-change', value: string): void;
  (e: 'status-change', status: string): void;
  (e: 'update-item', row: GlobalInvoiceItemRow, field: 'quantity' | 'sell_price_amount', value: number): void;
  (e: 'remove-item', id: number): void;
  (e: 'open-bulk-paste'): void;
  (e: 'open-stock-dialog'): void;
  (e: 'toggle-edit-recipient'): void;
  (e: 'open-edit-note'): void;
  (e: 'view-note'): void;
  (e: 'process-return'): void;
  (e: 'update:target-total', value: number | null): void;
  (e: 'target-total-input'): void;
  (e: 'apply-target-total'): void;
}>();

const notePreviewRef = ref<HTMLElement | null>(null);
const noteOverflows = ref(false);

const docTypeLabel = computed(() => {
  if (props.isDropship) return 'Dropship invoice';
  if (props.isWholesale) return 'Wholesale invoice';
  return 'Retail invoice';
});

const formatAmount = (value: number) => formatAmountBdt(value);

const paymentStatusLabel = computed(() => {
  const status = props.invoice.payment_status;
  if (!status) return '—';
  return status.charAt(0).toUpperCase() + status.slice(1);
});

const invoiceStatusLabel = computed(() => {
  const status = props.invoice.invoice_status;
  if (status === 'proforma_generated') return 'Proforma';
  return status.charAt(0).toUpperCase() + status.slice(1);
});

const checkNoteOverflow = () => {
  const el = notePreviewRef.value;
  noteOverflows.value = el ? el.scrollHeight > el.clientHeight + 1 : false;
};

watch(
  () => props.invoice.note,
  async () => {
    await nextTick();
    checkNoteOverflow();
  },
);

onMounted(() => {
  void nextTick().then(checkNoteOverflow);
});
</script>

<template>
  <article class="invoice-paper">
    <header class="invoice-paper__header">
      <div class="invoice-paper__brand">
        <div class="invoice-paper__doc-type">{{ docTypeLabel }}</div>
        <div v-if="canEditDraft" class="q-mt-xs">
          <q-input
            :model-value="form.invoice_no"
            dense
            outlined
            hide-bottom-space
            placeholder="Invoice number"
            class="invoice-paper__field-input"
            @update:model-value="(v) => (form.invoice_no = String(v ?? ''))"
            @blur="emit('header-blur')"
          />
        </div>
        <div v-else class="invoice-paper__invoice-no">
          {{ invoice.invoice_no || 'Draft Invoice' }}
        </div>
        <div v-if="invoice.billing_profiles?.name" class="invoice-paper__brand-name">
          {{ invoice.billing_profiles.name }}
        </div>
      </div>

      <div class="invoice-paper__meta">
        <div class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Date</span>
          <span v-if="!canEditDraft">{{ form.invoice_date || invoice.invoice_date || '—' }}</span>
          <q-input
            v-else
            :model-value="form.invoice_date"
            dense
            outlined
            readonly
            hide-bottom-space
            class="invoice-paper__field-input"
            style="width: 8.5rem"
          >
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date
                    :model-value="form.invoice_date"
                    mask="YYYY-MM-DD"
                    @update:model-value="(v) => emit('date-change', String(v))"
                  >
                    <div class="row items-center justify-end">
                      <q-btn v-close-popup label="Close" color="primary" flat />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </div>
        <div class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Status</span>
          <span>{{ invoiceStatusLabel }}</span>
        </div>
        <div v-if="invoice.invoice_status === 'issued'" class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Payment</span>
          <span>{{ paymentStatusLabel }}</span>
        </div>
        <div class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Type</span>
          <span class="text-capitalize">{{ invoice.invoice_type }}</span>
        </div>
        <div v-if="invoice.invoice_status === 'issued'" class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Paid</span>
          <span>{{ formatAmount(invoice.paid_amount) }}</span>
        </div>
        <div v-if="invoice.invoice_status === 'issued'" class="invoice-paper__meta-row">
          <span class="invoice-paper__meta-label">Due</span>
          <span class="text-weight-bold">{{ formatAmount(invoice.due_amount) }}</span>
        </div>
      </div>
    </header>

    <div v-if="canMutateInvoice" class="invoice-paper__status-workflow">
      <template v-for="(st, idx) in ['draft', 'issued']" :key="st">
        <q-btn
          :color="invoice.invoice_status === st ? (st === 'issued' ? 'positive' : 'orange') : 'grey-3'"
          :text-color="invoice.invoice_status === st ? 'white' : 'grey-7'"
          :outline="invoice.invoice_status !== st"
          :unelevated="invoice.invoice_status === st"
          dense
          no-caps
          class="q-px-sm text-caption text-weight-bold"
          :loading="(st === 'issued' && postingInvoice) || (st === 'draft' && unpostingInvoice)"
          :disable="(postingInvoice || unpostingInvoice || voidingInvoice) || isTransitionDisabled(st)"
          :data-test="st === 'issued' ? 'post-invoice-btn' : 'draft-invoice-btn'"
          @click="emit('status-change', st)"
        >
          {{ st.charAt(0).toUpperCase() + st.slice(1) }}
        </q-btn>
        <q-icon v-if="idx === 0" name="ph ph-caret-right" color="grey-5" size="16px" />
      </template>
      <q-separator vertical class="q-mx-xs" />
      <q-btn
        :color="invoice.invoice_status === 'voided' ? 'negative' : 'grey-3'"
        :text-color="invoice.invoice_status === 'voided' ? 'white' : 'grey-7'"
        :outline="invoice.invoice_status !== 'voided'"
        :unelevated="invoice.invoice_status === 'voided'"
        dense
        no-caps
        class="q-px-sm text-caption text-weight-bold"
        data-test="void-invoice-btn"
        :loading="voidingInvoice"
        :disable="(postingInvoice || unpostingInvoice || voidingInvoice) || (isTransitionDisabled('voided') && invoice.invoice_status !== 'voided')"
        @click="emit('status-change', 'voided')"
      >
        Voided
      </q-btn>
    </div>

    <div class="invoice-paper__divider" />

    <section class="invoice-paper__addresses">
      <div class="invoice-paper__address-block">
        <div class="invoice-paper__section-label">Bill to</div>
        <div class="invoice-paper__recipient-name">{{ invoice.billing_profiles?.name || '—' }}</div>
        <div v-if="invoice.billing_profiles?.email" class="invoice-paper__line">
          {{ invoice.billing_profiles.email }}
        </div>
        <div v-if="invoice.billing_profiles?.phone" class="invoice-paper__line">
          {{ invoice.billing_profiles.phone }}
        </div>
      </div>

      <div class="invoice-paper__address-block">
        <div class="row items-center justify-between">
          <div class="invoice-paper__section-label">Ship to</div>
          <q-btn
            v-if="canEditDraft"
            flat
            dense
            no-caps
            color="primary"
            size="sm"
            :label="editingRecipient ? 'Done' : 'Edit'"
            @click="emit('toggle-edit-recipient')"
          />
        </div>
        <div v-if="editingRecipient && canEditDraft" class="q-gutter-y-xs q-mt-xs">
          <q-input
            v-model="form.recipient_name"
            label="Name"
            dense
            outlined
            hide-bottom-space
            class="invoice-paper__field-input"
            @blur="emit('header-blur')"
          />
          <q-input
            v-model="form.recipient_phone"
            label="Phone"
            dense
            outlined
            hide-bottom-space
            class="invoice-paper__field-input"
            @blur="emit('header-blur')"
          />
          <q-input
            v-model="form.recipient_address"
            label="Address"
            type="textarea"
            rows="2"
            dense
            outlined
            class="invoice-paper__field-input"
            @blur="emit('header-blur')"
          />
        </div>
        <template v-else>
          <div class="invoice-paper__recipient-name q-mt-sm">{{ invoice.recipient_name || '—' }}</div>
          <div v-if="invoice.recipient_phone" class="invoice-paper__line">{{ invoice.recipient_phone }}</div>
          <div v-if="invoice.recipient_address" class="invoice-paper__line invoice-paper__line--wrap">
            {{ invoice.recipient_address }}
          </div>
        </template>
      </div>
    </section>

    <div v-if="canEditDraft" class="invoice-paper__divider" />

    <section v-if="canEditDraft" class="invoice-paper__draft-tools">
      <div class="invoice-paper__section-label">Add items</div>
      <q-btn
        color="primary"
        unelevated
        dense
        no-caps
        icon="ph ph-plus"
        label="From stock"
        data-test="add-stock-btn"
        @click="emit('open-stock-dialog')"
      />
      <q-btn
        v-if="items.length > 0"
        color="secondary"
        unelevated
        dense
        no-caps
        icon="ph ph-clipboard"
        label="Bulk paste"
        @click="emit('open-bulk-paste')"
      />
    </section>

    <div class="invoice-paper__divider" />

    <section>
      <div class="invoice-paper__section-label q-mb-sm">Line items ({{ items.length }})</div>

      <div v-if="!items.length" class="invoice-paper__empty text-grey-6">
        No items yet. Add from stock to build this invoice.
      </div>

      <div v-else class="invoice-paper__table-wrap">
        <table class="invoice-paper__table">
          <thead>
            <tr>
              <th class="col-sl">#</th>
              <th class="col-thumb" />
              <th class="col-item">Product</th>
              <th class="col-qty">Qty</th>
              <th v-if="isParentTenant" class="col-money">Cost</th>
              <th class="col-money">{{ isParentTenant ? 'Sell' : 'Price' }}</th>
              <th class="col-money">Total</th>
              <th v-if="isParentTenant && invoice.invoice_status === 'issued'" class="col-money">Margin</th>
              <th v-if="canEditDraft" class="col-action" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, idx) in items" :key="row.id">
              <td class="col-sl">{{ idx + 1 }}</td>
              <td class="col-thumb">
                <div class="invoice-paper__thumb">
                  <SmartImage
                    :src="row.image_url"
                    alt="item"
                    img-class="invoice-item-image"
                    fallback-class="invoice-item-image-fallback"
                    :enable-edit="false"
                  />
                </div>
              </td>
              <td class="col-item">
                <div class="invoice-paper__item-name">{{ row.name_snapshot }}</div>
                <div v-if="row.return_quantity > 0" class="invoice-paper__item-meta">
                  Returned {{ row.return_quantity }} · Retained {{ row.quantity - row.return_quantity }}
                </div>
              </td>
              <td class="col-qty">
                <span
                  :class="{
                    'cursor-pointer text-primary': canEditDraft,
                    'text-strike text-grey-6': row.return_quantity > 0 && row.quantity - row.return_quantity <= 0,
                  }"
                >
                  {{ row.quantity }}
                </span>
                <q-popup-edit
                  v-if="canEditDraft"
                  :model-value="row.quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(val) => emit('update-item', row, 'quantity', Number(val))"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    dense
                    outlined
                    autofocus
                    min="1"
                    step="1"
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
              </td>
              <td v-if="isParentTenant" class="col-money text-grey-7">{{ formatItemUnitCost(row) }}</td>
              <td class="col-money">
                <span :class="{ 'cursor-pointer text-primary': canEditDraft }">
                  {{ formatAmount(row.sell_price_amount) }}
                </span>
                <q-popup-edit
                  v-if="canEditDraft"
                  :model-value="row.sell_price_amount"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  v-slot="scope"
                  @save="(val) => emit('update-item', row, 'sell_price_amount', Number(val))"
                >
                  <q-input
                    :model-value="scope.value ?? ''"
                    type="number"
                    dense
                    outlined
                    autofocus
                    min="0"
                    step="0.01"
                    @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                    @keyup.enter="scope.set"
                  />
                </q-popup-edit>
              </td>
              <td class="col-money text-weight-bold">
                <template v-if="row.return_quantity > 0">
                  <div class="text-caption text-grey-6 text-strike">
                    {{ formatAmount(row.quantity * row.sell_price_amount - (row.line_discount_amount || 0)) }}
                  </div>
                  <div>{{ formatAmount(row.line_total_amount) }}</div>
                </template>
                <template v-else>{{ formatAmount(row.line_total_amount) }}</template>
              </td>
              <td v-if="isParentTenant && invoice.invoice_status === 'issued'" class="col-money text-positive">
                {{ formatAmount(lineMarginForRow(row)) }}
              </td>
              <td v-if="canEditDraft" class="col-action">
                <q-btn
                  flat
                  round
                  dense
                  color="negative"
                  icon="ph ph-trash"
                  size="sm"
                  @click="emit('remove-item', row.id)"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <div v-if="canEditDraft && items.length > 0" class="invoice-paper__foot-section">
      <div class="invoice-paper__section-label q-mb-sm">Adjust to total</div>
      <div class="text-caption text-grey-7 q-mb-sm">
        Enter the final total; item prices auto-adjust to match.
      </div>
      <div class="row items-center q-gutter-sm no-wrap">
        <q-input
          :model-value="targetTotal"
          type="number"
          dense
          outlined
          class="invoice-paper__field-input col"
          min="0"
          placeholder="Desired total"
          :loading="targetPreviewing"
          @update:model-value="(v) => { emit('update:target-total', v === '' || v === null ? null : Number(v)); emit('target-total-input'); }"
        />
        <q-btn
          color="primary"
          no-caps
          dense
          unelevated
          label="Apply"
          :disable="!targetPreview || !!targetError || applyingTarget"
          :loading="applyingTarget"
          @click="emit('apply-target-total')"
        />
      </div>
      <div v-if="targetError" class="text-caption text-negative q-mt-xs">{{ targetError }}</div>
      <div v-else-if="targetPreview" class="q-mt-sm text-caption">
        <div class="row justify-between">
          <span>Current</span><span>{{ formatAmount(targetPreview.current_total) }}</span>
        </div>
        <div class="row justify-between">
          <span>Target</span><span>{{ formatAmount(targetPreview.target_total) }}</span>
        </div>
      </div>
    </div>

    <div class="invoice-paper__divider" />

    <section class="invoice-paper__summary">
      <div class="invoice-paper__summary-grid">
        <template v-if="totalReturnQuantity > 0">
          <div class="invoice-paper__summary-row">
            <span>Gross subtotal</span>
            <span>{{ formatAmount(originalGrossSubtotal) }}</span>
          </div>
          <div class="invoice-paper__summary-row text-purple-9">
            <span>Less returns</span>
            <span>-{{ formatAmount(totalReturnDeduction) }}</span>
          </div>
        </template>
        <div class="invoice-paper__summary-row">
          <span>{{ totalReturnQuantity > 0 ? 'Net subtotal' : 'Subtotal' }}</span>
          <span>{{ formatAmount(invoice.subtotal_amount) }}</span>
        </div>

        <div class="invoice-paper__summary-row invoice-paper__summary-row--editable">
          <span>Delivery</span>
          <q-input
            v-if="canEditDraft"
            v-model.number="form.shipping_charge"
            type="number"
            dense
            outlined
            hide-bottom-space
            min="0"
            class="invoice-paper__amount-input"
            input-class="text-right"
            @blur="emit('header-blur')"
          />
          <span v-else>{{ formatAmount(invoice.shipping_charge) }}</span>
        </div>

        <template v-if="showCharges">
          <div class="invoice-paper__summary-row invoice-paper__summary-row--editable">
            <span>COD charge</span>
            <q-input
              v-if="canEditDraft"
              v-model.number="form.cod_charge"
              type="number"
              dense
              outlined
              hide-bottom-space
              min="0"
              class="invoice-paper__amount-input"
              input-class="text-right"
              @blur="emit('header-blur')"
            />
            <span v-else>{{ formatAmount(invoice.cod_charge ?? 0) }}</span>
          </div>
          <div class="invoice-paper__summary-row invoice-paper__summary-row--editable">
            <span>Wrapping</span>
            <q-input
              v-if="canEditDraft"
              v-model.number="form.wrapping_charge"
              type="number"
              dense
              outlined
              hide-bottom-space
              min="0"
              class="invoice-paper__amount-input"
              input-class="text-right"
              @blur="emit('header-blur')"
            />
            <span v-else>{{ formatAmount(invoice.wrapping_charge) }}</span>
          </div>
          <div class="invoice-paper__summary-row invoice-paper__summary-row--editable">
            <span>Print</span>
            <q-input
              v-if="canEditDraft"
              v-model.number="form.print_charge"
              type="number"
              dense
              outlined
              hide-bottom-space
              min="0"
              class="invoice-paper__amount-input"
              input-class="text-right"
              @blur="emit('header-blur')"
            />
            <span v-else>{{ formatAmount(invoice.print_charge) }}</span>
          </div>
        </template>

        <div class="invoice-paper__summary-row invoice-paper__summary-row--editable">
          <span>Discount</span>
          <q-input
            v-if="canEditDraft"
            v-model.number="form.discount_amount"
            type="number"
            dense
            outlined
            hide-bottom-space
            min="0"
            class="invoice-paper__amount-input"
            input-class="text-right"
            @blur="emit('header-blur')"
          />
          <span v-else class="text-negative">-{{ formatAmount(invoice.discount_amount) }}</span>
        </div>

        <div v-if="(invoice.settlement_discount_amount ?? 0) > 0" class="invoice-paper__summary-row text-orange-9">
          <span>Settlement discount</span>
          <span>-{{ formatAmount(invoice.settlement_discount_amount ?? 0) }}</span>
        </div>

        <div class="invoice-paper__summary-row invoice-paper__summary-row--grand">
          <span>Total amount</span>
          <span>{{ formatAmount(invoice.total_amount) }}</span>
        </div>

        <div v-if="invoice.invoice_status === 'issued'" class="invoice-paper__summary-row">
          <span>Paid</span>
          <span>{{ formatAmount(invoice.paid_amount) }}</span>
        </div>
        <div
          v-if="invoice.invoice_status === 'issued'"
          class="invoice-paper__summary-row invoice-paper__summary-row--due"
        >
          <span>Balance due</span>
          <span>{{ formatAmount(invoice.due_amount) }}</span>
        </div>

        <div class="invoice-paper__summary-row">
          <span>{{ invoice.invoice_status === 'issued' ? 'Gross profit' : 'Est. gross profit' }}</span>
          <span :class="estimatedProfit >= 0 ? 'text-positive' : 'text-negative'">
            {{ formatAmount(estimatedProfit) }}
          </span>
        </div>
        <div class="invoice-paper__summary-row text-grey-7">
          <span>Total cost · {{ totalQuantity }} qty</span>
          <span>{{ formatAmount(totalCost) }} · {{ averageProfitRate }}</span>
        </div>
      </div>
    </section>

    <section v-if="invoice.note || canEditDraft" class="invoice-paper__foot-section">
      <div class="row items-center justify-between q-mb-xs">
        <div class="invoice-paper__section-label">Internal note</div>
        <q-btn
          v-if="canEditDraft"
          flat
          dense
          round
          color="primary"
          icon="ph ph-pencil-simple"
          size="sm"
          @click="emit('open-edit-note')"
        />
      </div>
      <div
        v-if="invoice.note"
        ref="notePreviewRef"
        class="invoice-paper__note-preview invoice-paper__note-preview--clamped"
        :class="{ 'invoice-paper__note-preview--overflow cursor-pointer': noteOverflows }"
        v-html="invoice.note"
        @click="noteOverflows && emit('view-note')"
      />
      <div v-else class="text-caption text-grey-5">No private notes.</div>
      <div
        v-if="noteOverflows"
        class="text-caption text-primary cursor-pointer q-mt-xs"
        @click="emit('view-note')"
      >
        View full note
      </div>
    </section>

    <section v-if="collectionHistory.length > 0" class="invoice-paper__foot-section">
      <div class="invoice-paper__section-label q-mb-sm">Payment history</div>
      <div v-for="row in collectionHistory" :key="row.id" class="row justify-between q-py-xs text-body2">
        <div>
          <div class="text-weight-medium">{{ row.kindLabel }}</div>
          <div class="text-caption text-grey-6">{{ row.method || '—' }} · {{ formatReturnDate(row.created_at) }}</div>
        </div>
        <div class="text-weight-bold">{{ formatAmount(row.amount) }}</div>
      </div>
    </section>

    <section v-if="returnHistory.length > 0" class="invoice-paper__foot-section">
      <div class="row items-center justify-between q-mb-sm">
        <div class="invoice-paper__section-label">Return history ({{ returnHistory.length }})</div>
        <q-badge color="purple-1" text-color="purple-9">{{ totalReturnQuantity }} units</q-badge>
      </div>
      <div v-for="ret in returnHistory" :key="ret.id" class="q-py-xs">
        <div class="row justify-between text-body2">
          <span class="text-weight-medium">{{ getItemNameForReturn(ret.invoice_item_id) }}</span>
          <span class="text-purple-9">-{{ ret.quantity }}</span>
        </div>
        <div class="text-caption text-grey-6">
          {{ formatReturnDate(ret.created_at) }}
          <span v-if="ret.note"> · {{ ret.note }}</span>
        </div>
      </div>
    </section>

    <section v-if="isDropship" class="invoice-paper__foot-section">
      <div class="invoice-paper__section-label q-mb-sm">Courier remittance</div>
      <div class="invoice-paper__line">
        Batch: {{ linkedOrderRemittance?.courier_remittance_ref || '—' }}
      </div>
      <div class="invoice-paper__line">
        Bank ref: {{ linkedOrderRemittance?.courier_bank_trx_id || '—' }}
      </div>
      <div v-if="linkedOrderRemittance" class="invoice-paper__line q-mt-xs">
        Order
        <router-link
          class="text-primary text-weight-medium"
          :to="{
            name: 'app-shop-dropship-order-detail-page',
            params: { tenantSlug, id: linkedOrderRemittance.id },
          }"
        >
          {{ linkedOrderRemittance.order_no }}
        </router-link>
        · {{ linkedOrderRemittance.status.replace(/_/g, ' ') }}
      </div>
    </section>

    <section
      v-if="showReturns && invoice.invoice_status === 'issued' && canMutateInvoice"
      class="invoice-paper__foot-section"
    >
      <q-btn
        color="purple"
        outline
        no-caps
        dense
        class="full-width"
        icon="ph ph-arrow-u-down-left"
        label="Process return"
        data-test="add-return-btn"
        @click="emit('process-return')"
      />
    </section>
  </article>
</template>

<style scoped lang="scss">
@import '../styles/invoice-paper.scss';

.text-underline-dashed {
  text-decoration: underline dashed;
}
</style>
