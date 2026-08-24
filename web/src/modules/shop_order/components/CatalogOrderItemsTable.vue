<template>
  <q-card flat bordered class="catalog-items-card q-pa-none costing-items-surface shadow-1">
    <!-- Filter Header Bar when order status is confirmed -->
    <div v-if="order?.status === 'confirmed'" class="row items-center justify-between q-px-md q-py-sm bg-grey-2 border-bottom">
      <div class="row items-center q-gutter-x-sm">
        <span class="text-caption text-weight-bold text-grey-8">Filter Status:</span>
        <q-btn-toggle
          v-model="statusFilter"
          dense
          unelevated
          toggle-color="primary"
          color="white"
          text-color="grey-9"
          :options="[
            { label: 'Accepted Only', value: 'accepted' },
            { label: 'Rejected Only', value: 'rejected' },
            { label: 'All Items', value: 'all' },
          ]"
          class="shadow-1"
        />
      </div>
      <div class="text-caption text-grey-7">
        Showing {{ filteredRows.length }} of {{ items.length }} items
      </div>
    </div>

    <!-- Table matching ProductBasedCostingItemsTable style -->
    <q-table
      flat
      bordered
      :rows="filteredRows"
        :columns="tableColumns"
        :visible-columns="resolvedVisibleColumns"
        row-key="id"
        hide-pagination
        :pagination="{ rowsPerPage: 0 }"
        :style="{ height: 'clamp(360px, calc(100vh - 300px), 78vh)' }"
        :table-style="{ maxHeight: '100%' }"
        class="costing-q-table"
      >
        <!-- Custom Header Cell Slot with Product Based Costing Header Styling -->
        <template #header-cell="props">
          <q-th
            :props="props"
            :class="[getHeaderSectionClass(props.col.name), getHeaderAlignClass(props.col)]"
            class="text-weight-bold font-mono text-caption catalog-table-header"
          >
            <span class="header-label-wrap">{{ formatTableHeaderLabel(props.col.name, props.col.label) }}</span>
          </q-th>
        </template>

        <!-- Desktop Body Row Slot -->
        <template #body="slotProps">
          <q-tr :props="slotProps" class="catalog-row-hover">
            <!-- 1. SL -->
            <q-td v-if="isColVisible('sl')" key="sl" :props="slotProps" class="sec-info text-center text-weight-bold">
              {{ slotProps.rowIndex + 1 }}
            </q-td>

            <!-- 2. Image (1 Inch = 96px x 96px) -->
            <q-td v-if="isColVisible('image')" key="image" :props="slotProps" class="sec-info text-center">
              <div class="inch-image-wrapper">
                <SmartImage
                  :src="slotProps.row.image_url"
                  :alt="slotProps.row.name || 'Product image'"
                  img-class="inch-image"
                  fallback-class="inch-image-placeholder"
                />
              </div>
            </q-td>

            <!-- 3. Name (Wrapped) -->
            <q-td v-if="isColVisible('name')" key="name" :props="slotProps" class="sec-info col-name-wrap text-left">
              <div class="name-cell-wrap text-weight-bold text-grey-9 text-body2">
                {{ slotProps.row.name }}
              </div>
            </q-td>

            <!-- 4. Brand -->
            <q-td v-if="isColVisible('brand')" key="brand" :props="slotProps" class="sec-info text-center col-info-meta">
              <q-badge outline color="blue-grey-8" class="text-caption font-mono">
                {{ slotProps.row.brand || '—' }}
              </q-badge>
            </q-td>

            <!-- 5. Note -->
            <q-td v-if="isColVisible('note')" key="note" :props="slotProps" class="sec-info text-caption text-grey-7 text-center col-info-meta">
              {{ slotProps.row.note || '—' }}
            </q-td>

            <!-- 6. Code / Barcode / Product ID -->
            <q-td v-if="isColVisible('code_barcode_id')" key="code_barcode_id" :props="slotProps" class="sec-info text-center col-info-meta">
              <div class="column q-gutter-y-2xs font-mono text-caption items-center">
                <span v-if="slotProps.row.barcode" class="text-weight-medium text-grey-9">
                  <q-icon name="ph ph-barcode" size="14px" /> {{ slotProps.row.barcode }}
                </span>
                <span v-if="slotProps.row.sku" class="text-grey-7">SKU: {{ slotProps.row.sku }}</span>
                <span class="text-grey-6 text-2xs">ID: #{{ slotProps.row.product_id }}</span>
              </div>
            </q-td>

            <!-- 7. Qty (Customer) -->
            <q-td v-if="isColVisible('qty_customer')" key="qty_customer" :props="slotProps" class="sec-qty text-center text-weight-bold text-amber-10 font-mono">
              {{ slotProps.row.quantity }}
            </q-td>

            <!-- 8. Ordered Qty -->
            <q-td v-if="isColVisible('ordered_qty')" key="ordered_qty" :props="slotProps" class="sec-qty text-center editable-cell col-editable-qty">
              <q-input
                v-model.number="slotProps.row.ordered_quantity"
                type="number"
                dense
                borderless
                input-class="text-center font-mono text-weight-bold text-indigo-9"
                class="cell-input"
                min="0"
                step="1"
                @blur="onOrderedQtyBlur(slotProps.row)"
                @keyup.enter="blurInput"
              />
            </q-td>

            <!-- 9. Delivered Qty -->
            <q-td v-if="isColVisible('delivered_qty')" key="delivered_qty" :props="slotProps" class="sec-qty text-center editable-cell col-editable-qty">
              <q-input
                v-model.number="slotProps.row.delivered_quantity"
                type="number"
                dense
                borderless
                input-class="text-center font-mono text-weight-bold text-positive"
                class="cell-input"
                min="0"
                step="1"
                @blur="onDeliveredQtyBlur(slotProps.row)"
                @keyup.enter="blurInput"
              />
            </q-td>

            <!-- 10. Purchase Price Unit -->
            <q-td v-if="isColVisible('purchase_price_unit')" key="purchase_price_unit" :props="slotProps" class="sec-purchase text-center bg-purchase-accent editable-cell col-editable-money">
              <q-input
                v-model.number="slotProps.row.cost_price_amount"
                type="number"
                dense
                borderless
                input-class="text-center font-mono text-weight-bold text-green-10"
                class="cell-input"
                min="0"
                step="0.01"
                @blur="onItemCostBlur(slotProps.row)"
                @keyup.enter="blurInput"
              />
            </q-td>

            <!-- 11. Total Purchase Price -->
            <q-td v-if="isColVisible('purchase_price_total')" key="purchase_price_total" :props="slotProps" class="sec-purchase text-center font-mono text-weight-bold text-green-9 bg-purchase-accent">
              {{ formatAmount((slotProps.row.cost_price_amount || 0) * slotProps.row.quantity) }}
            </q-td>

            <!-- 12. Product Weight (gm) -->
            <q-td v-if="isColVisible('product_weight_gm')" key="product_weight_gm" :props="slotProps" class="sec-weight text-center font-mono editable-cell col-editable-weight">
              <q-input
                :model-value="slotProps.row.product_weight_gm ?? getProductWeightGm(slotProps.row)"
                type="number"
                dense
                borderless
                input-class="text-center font-mono"
                class="cell-input"
                min="0"
                step="1"
                @update:model-value="(val) => { slotProps.row.product_weight_gm = Number(val) || 0; }"
                @focus="clearZeroOnFocus(slotProps.row, 'product_weight_gm')"
                @blur="onItemProductWeightBlur(slotProps.row)"
                @keyup.enter="blurInput"
              />
            </q-td>

            <!-- 13. Package Weight (gm) -->
            <q-td v-if="isColVisible('package_weight_gm')" key="package_weight_gm" :props="slotProps" class="sec-weight text-center font-mono editable-cell col-editable-weight">
              <q-input
                :model-value="slotProps.row.package_weight_gm ?? getPackageWeightGm(slotProps.row)"
                type="number"
                dense
                borderless
                input-class="text-center font-mono"
                class="cell-input"
                min="0"
                step="1"
                @update:model-value="(val) => { slotProps.row.package_weight_gm = Number(val) || 0; }"
                @focus="clearZeroOnFocus(slotProps.row, 'package_weight_gm')"
                @blur="onItemPackageWeightBlur(slotProps.row)"
                @keyup.enter="blurInput"
              />
            </q-td>

            <!-- 14. Total Weight (gm) -->
            <q-td v-if="isColVisible('total_weight_gm')" key="total_weight_gm" :props="slotProps" class="sec-weight text-center font-mono">
              {{ Math.round(getTotalWeightGm(slotProps.row)) }} g
            </q-td>

            <!-- 15. Cargo Rate -->
            <q-td v-if="isColVisible('cargo_rate')" key="cargo_rate" :props="slotProps" class="sec-purchase text-center font-mono text-grey-8">
              {{ cargoRate.toFixed(2) }} /kg
            </q-td>

            <!-- 16. Cargo Cost (Purchase Currency) / Unit -->
            <q-td v-if="isColVisible('cargo_cost_unit_purchase')" key="cargo_cost_unit_purchase" :props="slotProps" class="sec-purchase text-center font-mono text-weight-medium">
              {{ formatAmount(getCargoCostUnitPurchase(slotProps.row)) }}
            </q-td>

            <!-- 17. Total Cost (Purchase Cost) / Unit -->
            <q-td v-if="isColVisible('landed_cost_unit_purchase')" key="landed_cost_unit_purchase" :props="slotProps" class="sec-landed text-center font-mono text-weight-bold text-teal-10">
              {{ formatAmount(getLandedCostUnitPurchase(slotProps.row)) }}
            </q-td>

            <!-- 18. Row Total Cost (Purchase) -->
            <q-td v-if="isColVisible('landed_cost_row_purchase')" key="landed_cost_row_purchase" :props="slotProps" class="sec-landed text-center font-mono text-weight-bold text-teal-9">
              {{ formatAmount(getLandedCostRowPurchase(slotProps.row)) }}
            </q-td>

            <!-- 19. Cost (Selling Currency) / Unit -->
            <q-td v-if="isColVisible('landed_cost_unit_sell')" key="landed_cost_unit_sell" :props="slotProps" class="sec-landed text-center font-mono text-weight-bold text-teal-10">
              {{ formatAmount(getLandedCostUnitSell(slotProps.row)) }}
            </q-td>

            <!-- 20. Row Total Cost (Selling Currency) -->
            <q-td v-if="isColVisible('landed_cost_row_sell')" key="landed_cost_row_sell" :props="slotProps" class="sec-landed text-center font-mono text-weight-bold text-teal-9">
              {{ formatAmount(getLandedCostRowSell(slotProps.row)) }}
            </q-td>

            <!-- 21. First Offer Unit (Selling Currency) -->
            <q-td v-if="isColVisible('first_offer_unit')" key="first_offer_unit" :props="slotProps" class="sec-first-offer text-center bg-offer editable-cell col-editable-offer">
              <div class="row items-center justify-center no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="slotProps.row.is_first_offer_manual"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                  class="q-mr-xs"
                >
                  <q-tooltip>First offer price manually locked — won't auto-recalculate</q-tooltip>
                </q-icon>

                <q-input
                  :model-value="getFirstOfferUnitAmount(slotProps.row)"
                  type="number"
                  dense
                  borderless
                  input-class="text-center text-deep-purple-9 text-weight-bold font-mono"
                  class="cell-input"
                  min="0"
                  step="1"
                  @update:model-value="(val) => onFirstOfferManualUpdate(slotProps.row, val)"
                  @blur="onFirstOfferBlur(slotProps.row)"
                  @keyup.enter="blurInput"
                />

                <q-btn
                  v-if="slotProps.row.is_first_offer_manual"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-arrows-clockwise"
                  color="grey-7"
                  class="q-ml-xs"
                  @click.stop="onUnlockFirstOffer(slotProps.row)"
                >
                  <q-tooltip>Unlock & reset to auto price</q-tooltip>
                </q-btn>
              </div>
            </q-td>

            <!-- 22. First Offer Row Total -->
            <q-td v-if="isColVisible('first_offer_row')" key="first_offer_row" :props="slotProps" class="sec-first-offer text-center font-mono text-weight-bold text-deep-purple-8 bg-offer">
              {{ formatAmount(getFirstOfferUnitAmount(slotProps.row) * slotProps.row.quantity) }}
            </q-td>

            <!-- 23. First Offer Margin % -->
            <q-td v-if="isColVisible('first_offer_margin')" key="first_offer_margin" :props="slotProps" class="sec-first-offer text-center font-mono text-weight-bold bg-offer" :class="getMarginColorClass(getFirstOfferMargin(slotProps.row))">
              {{ getFirstOfferMargin(slotProps.row).toFixed(1) }}%
            </q-td>

            <!-- 24. Counter Offer Unit -->
            <q-td v-if="isColVisible('counter_offer_unit')" key="counter_offer_unit" :props="slotProps" class="sec-counter-offer text-center font-mono text-weight-bold text-orange-9">
              {{ slotProps.row.customer_offer_amount != null ? formatAmount(slotProps.row.customer_offer_amount) : '—' }}
            </q-td>

            <!-- 25. Counter Offer Row Total -->
            <q-td v-if="isColVisible('counter_offer_row')" key="counter_offer_row" :props="slotProps" class="sec-counter-offer text-center font-mono text-weight-bold text-orange-8">
              {{ slotProps.row.customer_offer_amount != null ? formatAmount(slotProps.row.customer_offer_amount * slotProps.row.quantity) : '—' }}
            </q-td>

            <!-- 26. Counter Offer Margin % -->
            <q-td v-if="isColVisible('counter_offer_margin')" key="counter_offer_margin" :props="slotProps" class="sec-counter-offer text-center font-mono text-weight-bold" :class="getMarginColorClass(getCounterOfferMargin(slotProps.row))">
              {{ slotProps.row.customer_offer_amount != null ? `${getCounterOfferMargin(slotProps.row).toFixed(1)}%` : '—' }}
            </q-td>

            <!-- 27. Final Offer Unit -->
            <q-td v-if="isColVisible('final_offer_unit')" key="final_offer_unit" :props="slotProps" class="sec-final-offer text-center bg-final-offer editable-cell col-editable-offer">
              <div class="row items-center justify-center no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="slotProps.row.is_final_offer_manual"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                  class="q-mr-xs"
                >
                  <q-tooltip>Final offer price manually locked — won't auto-recalculate</q-tooltip>
                </q-icon>

                <q-input
                  :model-value="getFinalOfferUnitAmount(slotProps.row)"
                  type="number"
                  dense
                  borderless
                  input-class="text-center text-green-10 text-weight-bold font-mono"
                  class="cell-input"
                  min="0"
                  step="1"
                  @update:model-value="(val) => { slotProps.row.final_price_amount = Number(val) || 0; }"
                  @blur="onFinalOfferBlur(slotProps.row)"
                  @keyup.enter="blurInput"
                />

                <q-btn
                  v-if="slotProps.row.is_final_offer_manual"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-arrows-clockwise"
                  color="grey-7"
                  class="q-ml-xs"
                  @click.stop="onUnlockFinalOffer(slotProps.row)"
                >
                  <q-tooltip>Unlock & reset to auto price</q-tooltip>
                </q-btn>
              </div>
            </q-td>

            <!-- 28. Final Offer Row Total -->
            <q-td v-if="isColVisible('final_offer_row')" key="final_offer_row" :props="slotProps" class="sec-final-offer text-center font-mono text-weight-bold text-green-9 bg-final-offer">
              {{ formatAmount(getFinalOfferUnitAmount(slotProps.row) * slotProps.row.quantity) }}
            </q-td>

            <!-- 29. Final Offer Margin % -->
            <q-td v-if="isColVisible('final_offer_margin')" key="final_offer_margin" :props="slotProps" class="sec-final-offer text-center font-mono text-weight-bold bg-final-offer" :class="getMarginColorClass(getFinalOfferMargin(slotProps.row))">
              {{ `${getFinalOfferMargin(slotProps.row).toFixed(1)}%` }}
            </q-td>

            <!-- 30. Status -->
            <q-td v-if="isColVisible('status')" key="status" :props="slotProps" class="sec-action text-center">
              <q-chip dense outline :color="getItemStatusColor(slotProps.row)" class="text-caption text-weight-bold uppercase">
                {{ getItemStatusLabel(slotProps.row) }}
              </q-chip>
            </q-td>

            <!-- 31. Action -->
            <q-td v-if="isColVisible('action')" key="action" :props="slotProps" class="sec-action text-center">
              <div class="row items-center justify-center q-gutter-x-2xs">
                <q-btn flat round dense icon="ph ph-pencil-simple" size="xs" color="blue-9" @click.stop="openEditDialog(slotProps.row)">
                  <q-tooltip>Edit Item Details</q-tooltip>
                </q-btn>
                <q-btn flat round dense icon="ph ph-copy" size="xs" color="grey-7" @click.stop="handleCopy(slotProps.row.name, 'Name')">
                  <q-tooltip>Copy Item Name</q-tooltip>
                </q-btn>
              </div>
            </q-td>
          </q-tr>
        </template>

        <!-- Summary Totals Row Slot -->
        <template #bottom-row>
          <q-tr class="totals-summary-row">
            <td v-if="isColVisible('sl')" class="sec-info text-center text-weight-bold">Total</td>
            <td v-if="isColVisible('image')" class="sec-info" />
            <td v-if="isColVisible('name')" class="sec-info text-weight-bold text-left q-px-sm">{{ items.length }} Items</td>
            <td v-if="isColVisible('brand')" class="sec-info" />
            <td v-if="isColVisible('note')" class="sec-info" />
            <td v-if="isColVisible('code_barcode_id')" class="sec-info" />

            <td v-if="isColVisible('qty_customer')" class="sec-qty text-center font-mono text-weight-bold text-amber-10">{{ totalQuantity }}</td>
            <td v-if="isColVisible('ordered_qty')" class="sec-qty text-center font-mono text-weight-bold text-indigo-9">{{ totalOrderedQty }}</td>
            <td v-if="isColVisible('delivered_qty')" class="sec-qty text-center font-mono text-weight-bold text-positive">{{ totalDeliveredQty }}</td>

            <td v-if="isColVisible('purchase_price_unit')" class="sec-purchase bg-purchase-accent" />
            <td v-if="isColVisible('purchase_price_total')" class="sec-purchase text-center font-mono text-weight-bold text-green-9 bg-purchase-accent">{{ formatAmount(grandTotalPurchasePrice) }}</td>
            <td v-if="isColVisible('product_weight_gm')" class="sec-weight" />
            <td v-if="isColVisible('package_weight_gm')" class="sec-weight" />
            <td v-if="isColVisible('total_weight_gm')" class="sec-weight text-center font-mono text-weight-bold">{{ totalWeightGm.toLocaleString() }} g</td>
            <td v-if="isColVisible('cargo_rate')" class="sec-purchase" />
            <td v-if="isColVisible('cargo_cost_unit_purchase')" class="sec-purchase" />

            <td v-if="isColVisible('landed_cost_unit_purchase')" class="sec-landed" />
            <td v-if="isColVisible('landed_cost_row_purchase')" class="sec-landed text-center font-mono text-weight-bold text-teal-9">{{ formatAmount(grandTotalLandedPurchase) }}</td>
            <td v-if="isColVisible('landed_cost_unit_sell')" class="sec-landed" />
            <td v-if="isColVisible('landed_cost_row_sell')" class="sec-landed text-center font-mono text-weight-bold text-teal-9">{{ formatAmount(grandTotalLandedSell) }}</td>

            <td v-if="isColVisible('first_offer_unit')" class="sec-first-offer bg-offer" />
            <td v-if="isColVisible('first_offer_row')" class="sec-first-offer text-center font-mono text-weight-bold text-deep-purple-9 bg-offer">{{ formatAmount(grandTotalFirstOffer) }}</td>
            <td v-if="isColVisible('first_offer_margin')" class="sec-first-offer text-center font-mono text-weight-bold bg-offer">{{ overallFirstOfferMargin.toFixed(1) }}%</td>

            <td v-if="isColVisible('counter_offer_unit')" class="sec-counter-offer" />
            <td v-if="isColVisible('counter_offer_row')" class="sec-counter-offer text-center font-mono text-weight-bold text-orange-9">{{ formatAmount(grandTotalCounterOffer) }}</td>
            <td v-if="isColVisible('counter_offer_margin')" class="sec-counter-offer text-center font-mono text-weight-bold">{{ overallCounterOfferMargin.toFixed(1) }}%</td>

            <td v-if="isColVisible('final_offer_unit')" class="sec-final-offer bg-final-offer" />
            <td v-if="isColVisible('final_offer_row')" class="sec-final-offer text-center font-mono text-weight-bold text-green-9 bg-final-offer">{{ formatAmount(grandTotalFinalOffer) }}</td>
            <td v-if="isColVisible('final_offer_margin')" class="sec-final-offer text-center font-mono text-weight-bold bg-final-offer">{{ overallFinalOfferMargin.toFixed(1) }}%</td>

            <td v-if="isColVisible('status')" class="sec-action" />
          </q-tr>
        </template>
      </q-table>

    <!-- On-Tap Edit Dialog -->
    <CatalogOrderItemEditDialog
      v-model="showEditDialog"
      :item="editingItem"
      :order="order"
      :currency-symbol="currencySymbol"
      :buy-currency-symbol="buyCurrencySymbol"
      @save-item="handleSaveEditedItem"
    />
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar, copyToClipboard, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import type { ShopOrder, ShopOrderItem } from '../types';
import CatalogOrderItemEditDialog from './CatalogOrderItemEditDialog.vue';
import {
  getProductWeightGm as catalogGetProductWeightGm,
  getPackageWeightGm as catalogGetPackageWeightGm,
  getTotalWeightGm as catalogGetTotalWeightGm,
  getCargoCostUnitPurchase as catalogGetCargoCostUnitPurchase,
  getLandedCostUnitPurchase as catalogGetLandedCostUnitPurchase,
  getLandedCostRowPurchase as catalogGetLandedCostRowPurchase,
  getLandedCostUnitSell as catalogGetLandedCostUnitSell,
  getLandedCostRowSell as catalogGetLandedCostRowSell,
  calculateItemFirstOfferPrice,
  getFirstOfferMargin as catalogGetFirstOfferMargin,
  getCounterOfferMargin as catalogGetCounterOfferMargin,
  getFinalOfferUnitAmount as catalogGetFinalOfferUnitAmount,
  getFinalOfferMargin as catalogGetFinalOfferMargin,
} from '../utils/catalogPricingUtils';
import { normalizeCatalogOrderStatus } from '../utils/catalogOrderStatus';

const props = defineProps<{
  order: ShopOrder | null;
  items: ShopOrderItem[];
  currencySymbol?: string;
  buyCurrencySymbol?: string;
  visibleColumns?: string[];
}>();

const emit = defineEmits<{
  (e: 'open-column-selector'): void;
  (e: 'update:visible-columns', columns: string[]): void;
  (
    e: 'update-item',
    payload: {
      itemId: number;
      productId: number | null;
      payload: {
        product_weight_gm?: number | null | undefined;
        package_weight_gm?: number | null | undefined;
        weight_kg?: number | null | undefined;
        cost_price_amount?: number | null | undefined;
        staff_offer_amount?: number | null | undefined;
        is_first_offer_manual?: boolean | null | undefined;
        final_price_amount?: number | null | undefined;
        is_final_offer_manual?: boolean | null | undefined;
        ordered_quantity?: number | null | undefined;
        delivered_quantity?: number | null | undefined;
      };
    },
  ): void;
}>();

const $q = useQuasar();
const showEditDialog = ref(false);
const editingItem = ref<ShopOrderItem | null>(null);

function openEditDialog(item: ShopOrderItem) {
  editingItem.value = item;
  showEditDialog.value = true;
}

function emitItemUpdate(item: ShopOrderItem, payload: Record<string, any>) {
  emit('update-item', {
    itemId: item.id,
    productId: item.product_id ?? null,
    payload,
  });
}

function handleSaveEditedItem(updated: ShopOrderItem) {
  const target = props.items.find((i) => i.id === updated.id);
  if (target) {
    target.weight_kg = updated.weight_kg ?? null;
    target.product_weight_gm = updated.product_weight_gm ?? null;
    target.package_weight_gm = updated.package_weight_gm ?? null;
    target.cost_price_amount = updated.cost_price_amount ?? null;
    target.staff_offer_amount = updated.staff_offer_amount ?? null;
    target.final_price_amount = updated.final_price_amount ?? null;
    target.ordered_quantity = updated.ordered_quantity ?? 0;
    target.delivered_quantity = updated.delivered_quantity ?? 0;

    emitItemUpdate(target, {
      product_weight_gm: target.product_weight_gm,
      package_weight_gm: target.package_weight_gm,
      weight_kg: target.weight_kg,
      cost_price_amount: target.cost_price_amount,
      staff_offer_amount: target.staff_offer_amount,
      final_price_amount: target.final_price_amount,
      ordered_quantity: target.ordered_quantity,
      delivered_quantity: target.delivered_quantity,
    });
  }
}

const buyCurrency = computed(() => props.buyCurrencySymbol || '£');
const sellCurrency = computed(() => props.currencySymbol || '৳');

// Define table columns matching ProductBasedCostingItemsTable metrics
// Tight widths for inline editable cells
const COL_WIDTH = {
  sl: 44,
  image: 96,
  name: 230,
  nameMax: 260,
  infoMeta: 150,
  qty: 101,
  money: 113,
  weight: 109,
  offer: 133,
  numeric: 118,
  status: 96,
  action: 72,
  offerInput: 97,
} as const;

const colWidthStyle = (px: number) => `width: ${px}px; min-width: ${px}px; max-width: ${px}px;`;

const editableColWidths = {
  qty: colWidthStyle(COL_WIDTH.qty),
  money: colWidthStyle(COL_WIDTH.money),
  weight: colWidthStyle(COL_WIDTH.weight),
  offer: colWidthStyle(COL_WIDTH.offer),
} as const;

const infoColWidths = colWidthStyle(COL_WIDTH.infoMeta);
const numericColWidths = colWidthStyle(COL_WIDTH.numeric);

const tableColumns = computed<QTableColumn[]>(() => [
  // 1. Basic Info Section (sec-info)
  { name: 'sl', label: 'SL', field: 'id', align: 'center', style: colWidthStyle(COL_WIDTH.sl), headerStyle: colWidthStyle(COL_WIDTH.sl) },
  { name: 'image', label: 'Image', field: 'image_url', align: 'center', style: colWidthStyle(COL_WIDTH.image), headerStyle: colWidthStyle(COL_WIDTH.image) },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    style: `width: ${COL_WIDTH.name}px; min-width: ${COL_WIDTH.name}px; max-width: ${COL_WIDTH.nameMax}px;`,
    headerStyle: `width: ${COL_WIDTH.name}px; min-width: ${COL_WIDTH.name}px; max-width: ${COL_WIDTH.nameMax}px;`,
  },
  { name: 'brand', label: 'Brand', field: 'brand', align: 'center', style: infoColWidths, headerStyle: infoColWidths },
  { name: 'note', label: 'Note', field: 'note', align: 'center', style: infoColWidths, headerStyle: infoColWidths },
  { name: 'code_barcode_id', label: 'Barcode / Code / ID', field: 'barcode', align: 'center', style: infoColWidths, headerStyle: infoColWidths },

  // 2. Quantities Section (sec-qty)
  { name: 'qty_customer', label: 'Qty (Customer)', field: 'quantity', align: 'center', style: editableColWidths.qty, headerStyle: editableColWidths.qty },
  { name: 'ordered_qty', label: 'Ordered Qty', field: 'ordered_quantity', align: 'center', style: editableColWidths.qty, headerStyle: editableColWidths.qty },
  { name: 'delivered_qty', label: 'Delivered Qty', field: 'delivered_quantity', align: 'center', style: editableColWidths.qty, headerStyle: editableColWidths.qty },

  // 3. Purchase & Freight Section (sec-purchase)
  { name: 'purchase_price_unit', label: `Price (${buyCurrency.value}) / Unit`, field: 'cost_price_amount', align: 'center', style: editableColWidths.money, headerStyle: editableColWidths.money },
  { name: 'purchase_price_total', label: `Total Purchase (${buyCurrency.value})`, field: (row) => (row.cost_price_amount || 0) * row.quantity, align: 'center', style: colWidthStyle(COL_WIDTH.money + 12), headerStyle: colWidthStyle(COL_WIDTH.money + 12) },
  { name: 'product_weight_gm', label: 'Product Weight (gm)', field: (row) => getProductWeightGm(row), align: 'center', style: editableColWidths.weight, headerStyle: editableColWidths.weight },
  { name: 'package_weight_gm', label: 'Package Weight (gm)', field: (row) => getPackageWeightGm(row), align: 'center', style: editableColWidths.weight, headerStyle: editableColWidths.weight },
  { name: 'total_weight_gm', label: 'Total Weight (gm)', field: (row) => getTotalWeightGm(row), align: 'center', style: colWidthStyle(COL_WIDTH.weight), headerStyle: colWidthStyle(COL_WIDTH.weight) },
  { name: 'cargo_rate', label: `Cargo Rate (${buyCurrency.value}/kg)`, field: () => cargoRate.value, align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'cargo_cost_unit_purchase', label: `Cargo Cost (${buyCurrency.value}) / Unit`, field: (row) => getCargoCostUnitPurchase(row), align: 'center', style: numericColWidths, headerStyle: numericColWidths },

  // 4. Landed Cost Section (sec-landed)
  { name: 'landed_cost_unit_purchase', label: `Total Cost (${buyCurrency.value})`, field: (row) => getLandedCostUnitPurchase(row), align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'landed_cost_row_purchase', label: `Row Total Cost (${buyCurrency.value})`, field: (row) => getLandedCostRowPurchase(row), align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'landed_cost_unit_sell', label: `Cost (${sellCurrency.value})`, field: (row) => getLandedCostUnitSell(row), align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'landed_cost_row_sell', label: `Row Total Cost (${sellCurrency.value})`, field: (row) => getLandedCostRowSell(row), align: 'center', style: numericColWidths, headerStyle: numericColWidths },

  // 5. First Offer Section (sec-first-offer)
  { name: 'first_offer_unit', label: `1st Offer Unit (${sellCurrency.value})`, field: (row) => getFirstOfferUnitAmount(row), align: 'center', style: editableColWidths.offer, headerStyle: editableColWidths.offer },
  { name: 'first_offer_row', label: `Row Total 1st Offer (${sellCurrency.value})`, field: (row) => getFirstOfferUnitAmount(row) * row.quantity, align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'first_offer_margin', label: 'Profit Margin %', field: (row) => getFirstOfferMargin(row), align: 'center', style: colWidthStyle(COL_WIDTH.qty), headerStyle: colWidthStyle(COL_WIDTH.qty) },

  // 6. Counter Offer Section (sec-counter-offer)
  { name: 'counter_offer_unit', label: `Counter Offer (${sellCurrency.value}) / Unit`, field: 'customer_offer_amount', align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'counter_offer_row', label: `Row Total Counter (${sellCurrency.value})`, field: (row) => (row.customer_offer_amount || 0) * row.quantity, align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'counter_offer_margin', label: 'Profit Margin %', field: (row) => getCounterOfferMargin(row), align: 'center', style: colWidthStyle(COL_WIDTH.qty), headerStyle: colWidthStyle(COL_WIDTH.qty) },

  // 7. Final Offer Section (sec-final-offer)
  { name: 'final_offer_unit', label: `Final Offer (${sellCurrency.value})`, field: 'final_price_amount', align: 'center', style: editableColWidths.offer, headerStyle: editableColWidths.offer },
  { name: 'final_offer_row', label: `Row Total Final (${sellCurrency.value})`, field: (row) => (row.final_price_amount || 0) * row.quantity, align: 'center', style: numericColWidths, headerStyle: numericColWidths },
  { name: 'final_offer_margin', label: 'Profit Margin %', field: (row) => getFinalOfferMargin(row), align: 'center', style: colWidthStyle(COL_WIDTH.qty), headerStyle: colWidthStyle(COL_WIDTH.qty) },

  // 8. Status & Action Section (sec-action)
  { name: 'status', label: 'Status', field: 'negotiation_status', align: 'center', style: colWidthStyle(COL_WIDTH.status), headerStyle: colWidthStyle(COL_WIDTH.status) },
  { name: 'action', label: 'Action', field: 'id', align: 'center', style: colWidthStyle(COL_WIDTH.action), headerStyle: colWidthStyle(COL_WIDTH.action) },
]);

const defaultVisibleColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'qty_customer',
  'ordered_qty',
  'delivered_qty',
  'code_barcode_id',
  'purchase_price_unit',
  'purchase_price_total',
  'total_weight_gm',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'counter_offer_unit',
  'counter_offer_row',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_row',
  'final_offer_margin',
  'status',
  'action',
];

const LEGACY_COLUMN_MAPPING: Record<string, string[]> = {
  sku: ['code_barcode_id'],
  weight_kg: ['total_weight_gm', 'product_weight_gm'],
  cost_price: ['purchase_price_unit', 'purchase_price_total'],
  list_price: ['purchase_price_unit'],
  profit_base: ['landed_cost_unit_sell'],
  staff_offer: ['first_offer_unit', 'first_offer_row', 'first_offer_margin'],
  customer_offer: ['counter_offer_unit', 'counter_offer_row', 'counter_offer_margin'],
  final_price: ['final_offer_unit', 'final_offer_row', 'final_offer_margin'],
  confirmed_quantity: ['qty_customer'],
  ordered_quantity: ['ordered_qty'],
  delivered_quantity: ['delivered_qty'],
  quantity: ['qty_customer'],
};

const validColumnNames = computed(() => tableColumns.value.map((c) => c.name));

const resolvedVisibleColumns = computed<string[]>(() => {
  if (!props.visibleColumns || !props.visibleColumns.length) {
    return defaultVisibleColumns;
  }

  const mapped = new Set<string>();
  mapped.add('sl');
  mapped.add('image');
  mapped.add('name');
  mapped.add('status');
  mapped.add('action');

  props.visibleColumns.forEach((col) => {
    if (validColumnNames.value.includes(col)) {
      mapped.add(col);
    } else if (LEGACY_COLUMN_MAPPING[col]) {
      LEGACY_COLUMN_MAPPING[col].forEach((c) => mapped.add(c));
    }
  });

  return Array.from(mapped);
});


function isColVisible(colKey: string): boolean {
  return resolvedVisibleColumns.value.includes(colKey);
}

function getHeaderSectionClass(colName: string): string {
  if (['sl', 'image', 'name', 'brand', 'note', 'code_barcode_id'].includes(colName)) return 'sec-info-hdr';
  if (['qty_customer', 'ordered_qty', 'delivered_qty'].includes(colName)) return 'sec-qty-hdr';
  if (['purchase_price_unit', 'purchase_price_total', 'cargo_rate', 'cargo_cost_unit_purchase'].includes(colName)) return 'sec-purchase-hdr';
  if (['product_weight_gm', 'package_weight_gm', 'total_weight_gm'].includes(colName)) return 'sec-weight-hdr';
  if (['landed_cost_unit_purchase', 'landed_cost_row_purchase', 'landed_cost_unit_sell', 'landed_cost_row_sell'].includes(colName)) return 'sec-landed-hdr';
  if (['first_offer_unit', 'first_offer_row', 'first_offer_margin'].includes(colName)) return 'sec-first-offer-hdr';
  if (['counter_offer_unit', 'counter_offer_row', 'counter_offer_margin'].includes(colName)) return 'sec-counter-offer-hdr';
  if (['final_offer_unit', 'final_offer_row', 'final_offer_margin'].includes(colName)) return 'sec-final-offer-hdr';
  return 'sec-action-hdr';
}

function getHeaderAlignClass(col: QTableColumn): string {
  if (col.name === 'name') return 'text-left';
  return 'text-center';
}

function formatTableHeaderLabel(colName: string, fallback: string): string {
  const buy = buyCurrency.value;
  const sell = sellCurrency.value;
  const labels: Record<string, string> = {
    qty_customer: 'Qty\n(Customer)',
    ordered_qty: 'Ordered\nQty',
    delivered_qty: 'Delivered\nQty',
    code_barcode_id: 'Barcode /\nCode / ID',
    purchase_price_unit: `Price\n(${buy})\n/ Unit`,
    purchase_price_total: `Total\nPurchase\n(${buy})`,
    product_weight_gm: 'Product\nWeight\n(gm)',
    package_weight_gm: 'Package\nWeight\n(gm)',
    total_weight_gm: 'Total\nWeight\n(gm)',
    cargo_rate: `Cargo\nRate\n(${buy}/kg)`,
    cargo_cost_unit_purchase: `Cargo Cost\n(${buy})\n/ Unit`,
    landed_cost_unit_purchase: `Total Cost\n(${buy})`,
    landed_cost_row_purchase: `Row Total\nCost\n(${buy})`,
    landed_cost_unit_sell: `Cost\n(${sell})`,
    landed_cost_row_sell: `Row Total\nCost\n(${sell})`,
    first_offer_unit: `1st Offer\nUnit\n(${sell})`,
    first_offer_row: `Row Total\n1st Offer\n(${sell})`,
    first_offer_margin: 'Profit\nMargin\n%',
    counter_offer_unit: `Counter Offer\n(${sell})\n/ Unit`,
    counter_offer_row: `Row Total\nCounter\n(${sell})`,
    counter_offer_margin: 'Profit\nMargin\n%',
    final_offer_unit: `Final Offer\n(${sell})`,
    final_offer_row: `Row Total\nFinal\n(${sell})`,
    final_offer_margin: 'Profit\nMargin\n%',
  };
  return labels[colName] ?? fallback;
}

const status = computed(() => props.order?.status || 'submitted');
const isCostingMode = computed(() => normalizeCatalogOrderStatus(status.value) === 'submitted');

const FX = computed(() => props.order?.conversion_rate ?? 140);
const cargoRate = computed(() => props.order?.cargo_rate ?? 0);
const profitRate = computed(() => props.order?.first_offer_rate ?? props.order?.profit_rate ?? 25);
const finalOfferRate = computed(() => props.order?.final_offer_rate ?? null);
const profitBasis = computed(() => props.order?.profit_basis || 'total_cost');

// Calculation Helpers
function getProductWeightGm(item: ShopOrderItem): number {
  return catalogGetProductWeightGm(item);
}

function getPackageWeightGm(item: ShopOrderItem): number {
  return catalogGetPackageWeightGm(item, props.order?.package_weight_kg);
}

function getTotalWeightGm(item: ShopOrderItem): number {
  return catalogGetTotalWeightGm(item, props.order?.package_weight_kg);
}

function getCargoCostUnitPurchase(item: ShopOrderItem): number {
  return catalogGetCargoCostUnitPurchase(item, cargoRate.value, props.order?.package_weight_kg);
}

function getLandedCostUnitPurchase(item: ShopOrderItem): number {
  return catalogGetLandedCostUnitPurchase(item, cargoRate.value, props.order?.package_weight_kg);
}

function getLandedCostRowPurchase(item: ShopOrderItem): number {
  return catalogGetLandedCostRowPurchase(item, cargoRate.value, props.order?.package_weight_kg);
}

function getLandedCostUnitSell(item: ShopOrderItem): number {
  return catalogGetLandedCostUnitSell(item, cargoRate.value, FX.value, props.order?.package_weight_kg);
}

function getLandedCostRowSell(item: ShopOrderItem): number {
  return catalogGetLandedCostRowSell(item, cargoRate.value, FX.value, props.order?.package_weight_kg);
}

function getFirstOfferUnitAmount(item: ShopOrderItem): number {
  if (item.is_first_offer_manual) {
    return Number(item.staff_offer_amount || 0);
  }
  const calc = calculateItemOffer(item);
  if (calc > 0) {
    item.staff_offer_amount = calc;
  }
  return Number(item.staff_offer_amount || 0);
}

function getFirstOfferMargin(item: ShopOrderItem): number {
  return catalogGetFirstOfferMargin(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function getCounterOfferMargin(item: ShopOrderItem): number {
  return catalogGetCounterOfferMargin(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function getFinalOfferUnitAmount(item: ShopOrderItem): number {
  return catalogGetFinalOfferUnitAmount(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function getFinalOfferMargin(item: ShopOrderItem): number {
  return catalogGetFinalOfferMargin(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

const statusFilter = ref<'accepted' | 'rejected' | 'all'>('accepted');

const getItemStatusLabel = (item: ShopOrderItem): string => {
  if (props.order?.status === 'confirmed') {
    const qty = Number(item.quantity || 0);
    return qty > 0 ? 'accepted' : 'rejected';
  }
  return item.negotiation_status || item.customer_decision_status || 'Submitted';
};

const filteredRows = computed(() => {
  if (props.order?.status !== 'confirmed' || statusFilter.value === 'all') {
    return props.items;
  }
  return props.items.filter((item) => {
    const isAccepted = Number(item.quantity || 0) > 0;
    return statusFilter.value === 'accepted' ? isAccepted : !isAccepted;
  });
});

function getMarginColorClass(margin: number): string {
  if (margin >= 20) return 'text-positive';
  if (margin >= 10) return 'text-warning';
  return 'text-negative';
}

function getItemStatusColor(item: ShopOrderItem): string {
  if (props.order?.status === 'confirmed') {
    return Number(item.quantity || 0) > 0 ? 'positive' : 'negative';
  }
  const st = item.negotiation_status || item.customer_decision_status;
  if (st === 'confirmed' || st === 'accepted') return 'positive';
  if (st === 'countered') return 'orange';
  if (st === 'priced') return 'primary';
  return 'grey-7';
}

function calculateItemOffer(item: ShopOrderItem): number {
  return calculateItemFirstOfferPrice(
    item,
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
}

function blurInput(event: KeyboardEvent) {
  (event.target as HTMLInputElement | null)?.blur();
}

function clearZeroOnFocus(item: ShopOrderItem, field: 'product_weight_gm' | 'package_weight_gm') {
  const current = Number(item[field] ?? 0);
  if (current !== 0) return;
  (item as any)[field] = null;
}

function onOrderedQtyBlur(item: ShopOrderItem) {
  item.ordered_quantity = Math.max(0, Number(item.ordered_quantity) || 0);
  emitItemUpdate(item, { ordered_quantity: item.ordered_quantity });
}

function onDeliveredQtyBlur(item: ShopOrderItem) {
  item.delivered_quantity = Math.max(0, Number(item.delivered_quantity) || 0);
  emitItemUpdate(item, { delivered_quantity: item.delivered_quantity });
}

const firstOfferSaveTimers = new Map<number, ReturnType<typeof setTimeout>>();

function persistFirstOfferManual(item: ShopOrderItem) {
  const newPrice = Math.max(0, Number(item.staff_offer_amount) || 0);
  item.staff_offer_amount = newPrice;
  item.is_first_offer_manual = true;
  emitItemUpdate(item, {
    staff_offer_amount: newPrice,
    is_first_offer_manual: true,
  });
}

function onFirstOfferManualUpdate(item: ShopOrderItem, val: string | number | null) {
  item.staff_offer_amount = Math.max(0, Number(val) || 0);
  item.is_first_offer_manual = true;

  const pending = firstOfferSaveTimers.get(item.id);
  if (pending) clearTimeout(pending);
  firstOfferSaveTimers.set(
    item.id,
    setTimeout(() => {
      firstOfferSaveTimers.delete(item.id);
      persistFirstOfferManual(item);
    }, 400),
  );
}

function onFirstOfferBlur(item: ShopOrderItem) {
  const pending = firstOfferSaveTimers.get(item.id);
  if (pending) {
    clearTimeout(pending);
    firstOfferSaveTimers.delete(item.id);
  }
  if (!item.is_first_offer_manual) return;
  persistFirstOfferManual(item);
}

function onFinalOfferBlur(item: ShopOrderItem) {
  const next = Math.max(0, Number(item.final_price_amount) || 0);
  const auto = catalogGetFinalOfferUnitAmount(
    { ...item, is_final_offer_manual: false, final_price_amount: null },
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
  if (!item.is_final_offer_manual && next === auto) return;
  onFinalOfferPriceSave(item, next);
}

function onUnlockFirstOffer(item: ShopOrderItem) {
  const pending = firstOfferSaveTimers.get(item.id);
  if (pending) {
    clearTimeout(pending);
    firstOfferSaveTimers.delete(item.id);
  }
  item.is_first_offer_manual = false;
  const autoOffer = calculateItemOffer(item);
  item.staff_offer_amount = autoOffer;
  emitItemUpdate(item, {
    staff_offer_amount: autoOffer,
    is_first_offer_manual: false,
  });
}

function onFinalOfferPriceSave(item: ShopOrderItem, val: any) {
  const newPrice = Number(val) || 0;
  item.final_price_amount = newPrice;
  item.is_final_offer_manual = true;
  emitItemUpdate(item, {
    final_price_amount: newPrice,
    is_final_offer_manual: true,
  });
}

function onUnlockFinalOffer(item: ShopOrderItem) {
  item.is_final_offer_manual = false;
  const autoOffer = catalogGetFinalOfferUnitAmount(
    { ...item, is_final_offer_manual: false, final_price_amount: null },
    {
      conversion_rate: FX.value,
      cargo_rate: cargoRate.value,
      first_offer_rate: profitRate.value,
      final_offer_rate: finalOfferRate.value,
      profit_basis: profitBasis.value,
    },
    props.order?.package_weight_kg,
  );
  item.final_price_amount = autoOffer;
  emitItemUpdate(item, {
    final_price_amount: autoOffer,
    is_final_offer_manual: false,
  });
}

function onItemCostBlur(item: ShopOrderItem) {
  item.cost_price_amount = Math.max(0, Number(item.cost_price_amount) || 0);
  if (isCostingMode.value && !item.is_first_offer_manual) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
  emitItemUpdate(item, { cost_price_amount: item.cost_price_amount, staff_offer_amount: item.staff_offer_amount });
}

function onItemProductWeightBlur(item: ShopOrderItem) {
  const prodGm = Math.max(0, Number(item.product_weight_gm ?? getProductWeightGm(item)) || 0);
  item.product_weight_gm = prodGm;
  const pkgGm = getPackageWeightGm(item);
  item.weight_kg = (prodGm + pkgGm) / 1000;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
  emitItemUpdate(item, {
    product_weight_gm: prodGm,
    weight_kg: item.weight_kg,
    staff_offer_amount: item.staff_offer_amount,
  });
}

function onItemPackageWeightBlur(item: ShopOrderItem) {
  const pkgGm = Math.max(0, Number(item.package_weight_gm ?? getPackageWeightGm(item)) || 0);
  item.package_weight_gm = pkgGm;
  const prodGm = getProductWeightGm(item);
  item.weight_kg = (prodGm + pkgGm) / 1000;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
  emitItemUpdate(item, {
    package_weight_gm: pkgGm,
    weight_kg: item.weight_kg,
    staff_offer_amount: item.staff_offer_amount,
  });
}

// Totals calculations
const totalQuantity = computed(() => props.items.reduce((sum, i) => sum + (i.quantity || 0), 0));
const totalOrderedQty = computed(() => props.items.reduce((sum, i) => sum + (i.ordered_quantity || 0), 0));
const totalDeliveredQty = computed(() => props.items.reduce((sum, i) => sum + (i.delivered_quantity || 0), 0));

const totalWeightGm = computed(() => props.items.reduce((sum, i) => sum + (getTotalWeightGm(i) * i.quantity), 0));

const grandTotalPurchasePrice = computed(() => props.items.reduce((sum, i) => sum + ((i.cost_price_amount || 0) * i.quantity), 0));
const grandTotalLandedPurchase = computed(() => props.items.reduce((sum, i) => sum + getLandedCostRowPurchase(i), 0));
const grandTotalLandedSell = computed(() => props.items.reduce((sum, i) => sum + getLandedCostRowSell(i), 0));

const grandTotalFirstOffer = computed(() => props.items.reduce((sum, i) => sum + ((i.staff_offer_amount || 0) * i.quantity), 0));
const overallFirstOfferMargin = computed(() => {
  if (grandTotalLandedSell.value <= 0) return 0;
  return ((grandTotalFirstOffer.value - grandTotalLandedSell.value) / grandTotalLandedSell.value) * 100;
});

const grandTotalCounterOffer = computed(() => props.items.reduce((sum, i) => sum + ((i.customer_offer_amount || 0) * i.quantity), 0));
const overallCounterOfferMargin = computed(() => {
  if (grandTotalLandedSell.value <= 0) return 0;
  return ((grandTotalCounterOffer.value - grandTotalLandedSell.value) / grandTotalLandedSell.value) * 100;
});

const grandTotalFinalOffer = computed(() => props.items.reduce((sum, i) => sum + (getFinalOfferUnitAmount(i) * i.quantity), 0));
const overallFinalOfferMargin = computed(() => {
  if (grandTotalLandedSell.value <= 0) return 0;
  return ((grandTotalFinalOffer.value - grandTotalLandedSell.value) / grandTotalLandedSell.value) * 100;
});

function formatAmount(val: number | null | undefined): string {
  if (val == null || Number.isNaN(val)) return '0.00';
  return Number(val).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function handleCopy(text: string, label: string) {
  void copyToClipboard(text);
  $q.notify({ type: 'positive', message: `Copied ${label}`, timeout: 1200 });
}
</script>

<style scoped>
.catalog-items-card {
  border-radius: 12px;
  overflow: hidden;
}

/* Product Based Costing Colors */
:deep(.bg-purchase-accent) {
  background-color: #e6f4ea !important;
}

:deep(.bg-offer) {
  background-color: #f3e5f5 !important;
}

:deep(.bg-final-offer) {
  background-color: #e8f5e9 !important;
}

/* 1 Inch Image Wrapper (1 inch = 96px) */
.inch-image-wrapper {
  width: 96px;
  height: 96px;
  min-width: 96px;
  min-height: 96px;
  margin: 0 auto;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
}

.inch-image {
  width: 96px;
  height: 96px;
  object-fit: contain;
}

.inch-image-placeholder {
  width: 96px;
  height: 96px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f1f5f9;
  color: #94a3b8;
}

/* Table header — multi-line labels */
:deep(.costing-q-table thead th),
:deep(.costing-q-table tbody td) {
  padding-left: 10px;
  padding-right: 10px;
}

:deep(.costing-q-table thead tr) {
  height: auto;
}

:deep(.costing-q-table thead th) {
  white-space: normal !important;
  vertical-align: bottom;
  padding-top: 8px;
  padding-bottom: 8px;
}

.catalog-table-header {
  letter-spacing: 0.02em;
  font-size: 10px;
  line-height: 1.2;
}

.header-label-wrap {
  display: inline-block;
  white-space: pre-line;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.2;
  text-transform: uppercase;
  max-width: 100%;
}

/* Section Header Theme Colors matching Product Based Costing Details */
.sec-info-hdr {
  background-color: #f8fafc !important;
  color: #334155 !important;
  border-bottom: 2px solid #cbd5e1 !important;
}

.sec-qty-hdr {
  background-color: #fff8e1 !important;
  color: #b45309 !important;
  border-bottom: 2px solid #fde68a !important;
}

.sec-purchase-hdr {
  background-color: #e6f4ea !important;
  color: #137333 !important;
  border-bottom: 2px solid #a8dab5 !important;
}

.sec-weight-hdr {
  background-color: #ffffff !important;
  color: #334155 !important;
  border-bottom: 2px solid #e2e8f0 !important;
}

.sec-landed-hdr {
  background-color: #e0f2fe !important;
  color: #0369a1 !important;
  border-bottom: 2px solid #7dd3fc !important;
}

.sec-first-offer-hdr {
  background-color: #f3e5f5 !important;
  color: #7b1fa2 !important;
  border-bottom: 2px solid #ce93d8 !important;
}

.sec-counter-offer-hdr {
  background-color: #ffe0b2 !important;
  color: #e65100 !important;
  border-bottom: 2px solid #ffcc80 !important;
}

.sec-final-offer-hdr {
  background-color: #e8f5e9 !important;
  color: #2e7d32 !important;
  border-bottom: 2px solid #a5d6a7 !important;
}

.sec-action-hdr {
  background-color: #f5f5f5 !important;
  color: #424242 !important;
  border-bottom: 2px solid #e0e0e0 !important;
}

/* Table Body Cell Background Accents */
.sec-info {
  background-color: #ffffff;
}

.sec-qty {
  background-color: #fffdf5;
}

.sec-purchase {
  background-color: #f4fbf7;
}

.sec-weight {
  background-color: #ffffff;
}

.sec-landed {
  background-color: #f0f9ff;
}

.sec-first-offer {
  background-color: #faf5fc;
}

.sec-counter-offer {
  background-color: #fff8f0;
}

.sec-final-offer {
  background-color: #f1f8f3;
}

.sec-action {
  background-color: #ffffff;
}

.catalog-row-hover:hover td {
  filter: brightness(0.97);
}

/* Dense Input Styling */
.col-editable-qty {
  width: 101px;
  min-width: 101px;
  max-width: 101px;
  padding: 4px 6px !important;
}

.col-editable-money {
  width: 113px;
  min-width: 113px;
  max-width: 113px;
  padding: 4px 6px !important;
}

.col-editable-weight {
  width: 109px;
  min-width: 109px;
  max-width: 109px;
  padding: 4px 6px !important;
  background-color: #ffffff !important;
}

.col-editable-offer {
  width: 133px;
  min-width: 133px;
  max-width: 133px;
  padding: 4px 6px !important;
}

.editable-cell {
  cursor: text;
}

.editable-cell .cell-input {
  width: 100%;
  max-width: 100%;
  font-size: 12px;
}

.col-editable-offer .cell-input {
  flex: 1 1 auto;
  min-width: 0;
  max-width: 97px;
}

.editable-cell :deep(.q-field__control) {
  min-height: 26px;
  height: 26px;
  padding: 0 2px;
}

.editable-cell :deep(.q-field__native) {
  padding: 0;
  text-align: center;
}

.cell-input :deep(.q-field__control) {
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  min-height: 26px;
  height: 26px;
  background: #ffffff;
}

.cell-input:hover :deep(.q-field__control) {
  border-color: #94a3b8;
}

.cell-input.q-field--focused :deep(.q-field__control),
.cell-input:focus-within :deep(.q-field__control) {
  border-color: var(--q-primary);
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--q-primary) 28%, transparent);
}

.cell-input :deep(input[type='number']::-webkit-outer-spin-button),
.cell-input :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

.cell-input :deep(input[type='number']) {
  -moz-appearance: textfield;
}

.totals-summary-row td {
  font-weight: 700;
  padding: 10px 12px;
  font-size: 12px;
  border-top: 2px solid #cbd5e1;
}

.text-2xs {
  font-size: 10px;
}

.col-name-wrap,
.name-cell-wrap {
  width: 230px !important;
  min-width: 230px !important;
  max-width: 260px !important;
  text-align: left !important;
  white-space: normal !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.3;
  font-size: 13px;
}

.col-info-meta {
  width: 150px;
  min-width: 150px;
  max-width: 150px;
  text-align: center !important;
  white-space: normal !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.3;
  vertical-align: top;
}
</style>
