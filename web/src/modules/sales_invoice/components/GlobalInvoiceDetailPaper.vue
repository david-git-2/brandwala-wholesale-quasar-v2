<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import type { TargetTotalSummary } from '../repositories/invoiceRepository';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from '../types';
import InvoicePartiesStrip from './InvoicePartiesStrip.vue';
import InvoiceLinesTable from './InvoiceLinesTable.vue';
import InvoiceTotalsPanel from './InvoiceTotalsPanel.vue';

export interface InvoiceDetailFormState {
  discount_amount: number;
  shipping_charge: number;
  cod_charge_amount: number;
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

const props = defineProps<{
  invoice: GlobalInvoiceDetail;
  items: GlobalInvoiceItemRow[];
  form: InvoiceDetailFormState;
  tenantSlug: string | undefined;
  canEditDraft: boolean;
  isDropship: boolean;
  showCharges: boolean;
  showMargin: boolean;
  linkedOrderRemittance: LinkedOrderRemittanceInfo | null;
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
  (e: 'update-item', row: GlobalInvoiceItemRow, field: 'quantity' | 'sell_price_amount', value: number): void;
  (e: 'remove-item', id: number): void;
  (e: 'open-bulk-paste'): void;
  (e: 'open-stock-dialog'): void;
  (e: 'toggle-edit-recipient'): void;
  (e: 'open-edit-note'): void;
  (e: 'view-note'): void;
  (e: 'update:target-total', value: number | null): void;
  (e: 'target-total-input'): void;
  (e: 'apply-target-total'): void;
}>();

const notePreviewRef = ref<HTMLElement | null>(null);
const noteOverflows = ref(false);

const hasReturnedItems = computed(() => props.totalReturnQuantity > 0);

const showShipTo = computed(
  () => props.canEditDraft || !!props.invoice.recipient_name || !!props.invoice.recipient_phone,
);

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

const onTargetTotalUpdate = (value: number | null) => {
  emit('update:target-total', value);
};
</script>

<template>
  <div class="invoice-desk-body">
    <div class="invoice-desk-body__main">
      <div v-if="canEditDraft" class="invoice-desk-card row q-col-gutter-sm items-end">
        <div class="col-12 col-sm-4">
          <div class="invoice-desk-section-label">Invoice number</div>
          <q-input
            :model-value="form.invoice_no"
            dense
            outlined
            hide-bottom-space
            placeholder="Invoice number"
            @update:model-value="(v) => (form.invoice_no = String(v ?? ''))"
            @blur="emit('header-blur')"
          />
        </div>
        <div class="col-12 col-sm-4">
          <div class="invoice-desk-section-label">Date</div>
          <q-input
            :model-value="form.invoice_date"
            dense
            outlined
            readonly
            hide-bottom-space
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
      </div>

      <InvoicePartiesStrip
        mode="read"
        :bill-to-name="invoice.billing_profiles?.name"
        :bill-to-email="invoice.billing_profiles?.email"
        :bill-to-phone="invoice.billing_profiles?.phone"
        :ship-to-name="invoice.recipient_name"
        :ship-to-phone="invoice.recipient_phone"
        :ship-to-address="invoice.recipient_address"
        :show-ship-to="showShipTo"
        :can-edit-ship-to="canEditDraft"
        :editing-recipient="editingRecipient"
        :dropship-hint="isDropship"
        :recipient-form="form"
        @toggle-edit-recipient="emit('toggle-edit-recipient')"
        @recipient-blur="emit('header-blur')"
      />

      <div v-if="canEditDraft" class="invoice-desk-card row q-gutter-sm">
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
      </div>

      <InvoiceLinesTable
        mode="detail"
        :detail-items="items"
        :has-returned-items="hasReturnedItems"
        :can-edit-draft="canEditDraft"
        :show-margin="showMargin"
        :invoice-issued="invoice.invoice_status === 'issued'"
        :format-item-unit-cost="formatItemUnitCost"
        :line-margin-for-row="lineMarginForRow"
        @update-detail-item="(row, field, value) => emit('update-item', row, field, value)"
        @remove-detail-item="(id) => emit('remove-item', id)"
      />

      <section v-if="invoice.note || canEditDraft" class="invoice-desk-card invoice-desk-foot-card">
        <div class="row items-center justify-between q-mb-xs">
          <div class="invoice-desk-section-label q-mb-none">Internal note</div>
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
          class="note-preview note-preview--clamped"
          :class="{ 'note-preview--overflow cursor-pointer': noteOverflows }"
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

      <section v-if="returnHistory.length > 0" class="invoice-desk-card invoice-desk-foot-card">
        <div class="row items-center justify-between q-mb-sm">
          <div class="invoice-desk-section-label q-mb-none">Return history ({{ returnHistory.length }})</div>
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

      <section v-if="isDropship" class="invoice-desk-card invoice-desk-foot-card">
        <div class="invoice-desk-section-label q-mb-sm">Courier remittance</div>
        <div class="invoice-desk-party__line">
          Batch: {{ linkedOrderRemittance?.courier_remittance_ref || '—' }}
        </div>
        <div class="invoice-desk-party__line">
          Bank ref: {{ linkedOrderRemittance?.courier_bank_trx_id || '—' }}
        </div>
        <div v-if="linkedOrderRemittance" class="invoice-desk-party__line q-mt-xs">
          Order
          <router-link
            class="text-primary text-weight-medium"
            :to="{
              name: 'app-shop-order-detail-page',
              params: { tenantSlug, id: linkedOrderRemittance.id },
            }"
          >
            {{ linkedOrderRemittance.order_no }}
          </router-link>
          · {{ linkedOrderRemittance.status.replace(/_/g, ' ') }}
        </div>
      </section>
    </div>

    <aside class="invoice-desk-body__aside">
      <InvoiceTotalsPanel
        mode="detail"
        :item-count="items.length"
        :total-quantity="totalQuantity"
        :total-return-quantity="totalReturnQuantity"
        :original-gross-subtotal="originalGrossSubtotal"
        :total-return-deduction="totalReturnDeduction"
        :invoice-subtotal="invoice.subtotal_amount"
        :show-charges="showCharges"
        :is-dropship="isDropship"
        :can-edit-draft="canEditDraft"
        :invoice-issued="invoice.invoice_status === 'issued'"
        :paid-amount="invoice.paid_amount"
        :due-amount="invoice.due_amount"
        :settlement-discount="invoice.settlement_discount_amount ?? 0"
        :grand-total-amount="invoice.total_amount"
        :show-margin="showMargin"
        :estimated-profit="estimatedProfit"
        :total-cost="totalCost"
        :average-profit-rate="averageProfitRate"
        :target-total="targetTotal"
        :target-preview="targetPreview"
        :target-error="targetError"
        :target-previewing="targetPreviewing"
        :applying-target="applyingTarget"
        :charge-form="form"
        :target-total="targetTotal"
        @charge-blur="emit('header-blur')"
        @target-total-input="emit('target-total-input')"
        @apply-target-total="emit('apply-target-total')"
        @update:target-total="onTargetTotalUpdate"
      />
    </aside>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';

.note-preview {
  font-size: 0.82rem;
  color: var(--bw-theme-muted, #736a61);

  &--clamped {
    max-height: 120px;
    overflow: hidden;
    position: relative;
  }

  &--overflow::after {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 40px;
    background: linear-gradient(transparent, var(--bw-theme-surface, #fff));
  }
}
</style>
