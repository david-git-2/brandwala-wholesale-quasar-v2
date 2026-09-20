<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { InvoiceLineDraftItem } from '../types/wholesaleInvoiceDraft';
import type { GlobalInvoiceItemRow } from '../types';

type DetailRow = GlobalInvoiceItemRow;

const props = defineProps<{
  mode: 'composer' | 'detail';
  composerItems?: InvoiceLineDraftItem[];
  detailItems?: DetailRow[];
  hasReturnedItems?: boolean;
  canEditDraft?: boolean;
  showMargin?: boolean;
  invoiceIssued?: boolean;
  formatItemUnitCost?: (row: DetailRow) => string;
  lineMarginForRow?: (row: DetailRow) => number;
}>();

const emit = defineEmits<{
  (e: 'remove-composer-item', index: number): void;
  (e: 'remove-detail-item', id: number): void;
  (e: 'update-detail-item', row: DetailRow, field: 'quantity' | 'sell_price_amount', value: number): void;
}>();

const formatMoney = (amount: number) => formatAmountBdt(amount);

const calculateLineGross = (item: InvoiceLineDraftItem): number => {
  const sub = (item.quantity || 0) * (item.sell_price_amount || 0);
  return Math.max(0, sub - (item.line_discount_amount || 0));
};

const calculateLineTotal = (item: InvoiceLineDraftItem): number => {
  const kept = Math.max((item.quantity || 0) - (item.return_quantity || 0), 0);
  const sub = kept * (item.sell_price_amount || 0);
  const total = sub - (item.line_discount_amount || 0);
  return Math.max(0, total);
};

const itemCount = () =>
  props.mode === 'composer' ? props.composerItems?.length ?? 0 : props.detailItems?.length ?? 0;
</script>

<template>
  <div class="invoice-desk-card">
    <div class="invoice-desk-section-label">Line items ({{ itemCount() }})</div>

    <div v-if="itemCount() === 0" class="invoice-desk-empty">
      <div class="text-weight-bold">No items on this invoice yet</div>
      <div class="text-caption q-mt-xs">Search stock or paste a list to add products.</div>
    </div>

    <div v-else class="invoice-desk-table-wrap">
      <table class="invoice-desk-table">
        <thead>
          <tr>
            <th class="col-sl">#</th>
            <th class="col-thumb" />
            <th class="col-item">Item</th>
            <th v-if="mode === 'composer'" class="col-qty">ATP</th>
            <th class="col-qty">Qty</th>
            <th v-if="hasReturnedItems" class="col-qty">Returned</th>
            <th v-if="showMargin && mode === 'detail'" class="col-money">Cost</th>
            <th class="col-money">{{ showMargin && mode === 'detail' ? 'Sell' : 'Rate' }}</th>
            <th v-if="mode === 'composer'" class="col-money">Discount</th>
            <th class="col-money">Line total</th>
            <th v-if="showMargin && mode === 'detail' && invoiceIssued" class="col-money">Margin</th>
            <th v-if="mode === 'composer' || canEditDraft" class="col-action" />
          </tr>
        </thead>
        <tbody v-if="mode === 'composer'">
          <tr v-for="(item, index) in composerItems" :key="item.global_stock_id">
            <td class="col-sl">{{ index + 1 }}</td>
            <td class="col-thumb">
              <div class="invoice-desk-thumb">
                <img v-if="item.image_url" :src="item.image_url" alt="" />
                <q-icon v-else name="ph ph-image" color="grey-5" size="18px" />
              </div>
            </td>
            <td class="col-item">
              <div class="invoice-desk-item-name">{{ item.name }}</div>
              <div v-if="item.barcode || item.product_code" class="invoice-desk-item-meta">
                <span v-if="item.barcode">Barcode {{ item.barcode }}</span>
                <span v-if="item.barcode && item.product_code"> · </span>
                <span v-if="item.product_code">Code {{ item.product_code }}</span>
              </div>
            </td>
            <td class="col-qty">{{ item.available_atp }}</td>
            <td class="col-qty">
              <q-input
                v-model.number="item.quantity"
                type="number"
                outlined
                dense
                hide-bottom-space
                min="1"
                :max="item.available_atp"
                class="invoice-desk-cell-input invoice-desk-cell-input--qty"
                input-class="text-center"
              />
            </td>
            <td v-if="hasReturnedItems" class="col-qty">
              <template v-if="(item.return_quantity || 0) > 0">
                <div class="text-weight-bold">{{ item.return_quantity }}</div>
                <div class="invoice-desk-item-meta">Kept {{ item.quantity - item.return_quantity }}</div>
              </template>
              <span v-else class="text-grey-5">—</span>
            </td>
            <td class="col-money">
              <q-input
                v-model.number="item.sell_price_amount"
                type="number"
                outlined
                dense
                hide-bottom-space
                min="0"
                step="0.01"
                class="invoice-desk-cell-input"
                input-class="text-right"
              />
            </td>
            <td class="col-money">
              <q-input
                v-model.number="item.line_discount_amount"
                type="number"
                outlined
                dense
                hide-bottom-space
                min="0"
                step="0.01"
                class="invoice-desk-cell-input"
                input-class="text-right"
              />
            </td>
            <td class="col-money text-weight-bold invoice-desk-money">
              <template v-if="(item.return_quantity || 0) > 0">
                <div class="invoice-desk-item-meta text-strike">{{ formatMoney(calculateLineGross(item)) }}</div>
                <div>{{ formatMoney(calculateLineTotal(item)) }}</div>
              </template>
              <template v-else>{{ formatMoney(calculateLineTotal(item)) }}</template>
            </td>
            <td class="col-action">
              <q-btn
                flat
                round
                dense
                color="negative"
                icon="ph ph-trash"
                size="sm"
                aria-label="Remove item"
                @click="emit('remove-composer-item', index)"
              />
            </td>
          </tr>
        </tbody>
        <tbody v-else>
          <tr v-for="(row, idx) in detailItems" :key="row.id">
            <td class="col-sl">{{ idx + 1 }}</td>
            <td class="col-thumb">
              <div class="invoice-desk-thumb">
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
              <div class="invoice-desk-item-name">{{ row.name_snapshot }}</div>
              <div v-if="row.return_quantity > 0" class="invoice-desk-item-meta">
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
                @save="(val) => emit('update-detail-item', row, 'quantity', Number(val))"
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
            <td v-if="hasReturnedItems" class="col-qty">
              <span v-if="row.return_quantity > 0">{{ row.return_quantity }}</span>
              <span v-else class="text-grey-5">—</span>
            </td>
            <td v-if="showMargin" class="col-money text-grey-7 invoice-desk-money">
              {{ formatItemUnitCost?.(row) }}
            </td>
            <td class="col-money invoice-desk-money">
              <span :class="{ 'cursor-pointer text-primary': canEditDraft }">
                {{ formatMoney(row.sell_price_amount) }}
              </span>
              <q-popup-edit
                v-if="canEditDraft"
                :model-value="row.sell_price_amount"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                v-slot="scope"
                @save="(val) => emit('update-detail-item', row, 'sell_price_amount', Number(val))"
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
            <td class="col-money text-weight-bold invoice-desk-money">
              <template v-if="row.return_quantity > 0">
                <div class="text-caption text-grey-6 text-strike">
                  {{ formatMoney(row.quantity * row.sell_price_amount - (row.line_discount_amount || 0)) }}
                </div>
                <div>{{ formatMoney(row.line_total_amount) }}</div>
              </template>
              <template v-else>{{ formatMoney(row.line_total_amount) }}</template>
            </td>
            <td
              v-if="showMargin && invoiceIssued"
              class="col-money text-positive invoice-desk-money"
            >
              {{ formatMoney(lineMarginForRow?.(row) ?? 0) }}
            </td>
            <td v-if="canEditDraft" class="col-action">
              <q-btn
                flat
                round
                dense
                color="negative"
                icon="ph ph-trash"
                size="sm"
                @click="emit('remove-detail-item', row.id)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';

:deep(.invoice-item-image),
:deep(.invoice-item-image-fallback) {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
</style>
