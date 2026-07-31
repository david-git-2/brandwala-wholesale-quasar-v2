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
            :class="[getHeaderSectionClass(props.col.name)]"
            class="text-weight-bold font-mono text-caption uppercase-header"
          >
            {{ props.col.label }}
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
            <q-td v-if="isColVisible('name')" key="name" :props="slotProps" class="sec-info col-name-wrap">
              <div class="name-cell-wrap text-weight-bold text-grey-9 text-body2">
                {{ slotProps.row.name }}
              </div>
            </q-td>

            <!-- 4. Brand -->
            <q-td v-if="isColVisible('brand')" key="brand" :props="slotProps" class="sec-info text-left">
              <q-badge outline color="blue-grey-8" class="text-caption font-mono">
                {{ slotProps.row.brand || '—' }}
              </q-badge>
            </q-td>

            <!-- 5. Note -->
            <q-td v-if="isColVisible('note')" key="note" :props="slotProps" class="sec-info text-caption text-grey-7">
              {{ slotProps.row.note || '—' }}
            </q-td>

            <!-- 6. Code / Barcode / Product ID -->
            <q-td v-if="isColVisible('code_barcode_id')" key="code_barcode_id" :props="slotProps" class="sec-info text-left">
              <div class="column q-gutter-y-2xs font-mono text-caption">
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

            <!-- 8. Ordered Qty (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('ordered_qty')" key="ordered_qty" :props="slotProps" class="sec-qty text-center editable-cell">
              <span class="font-mono text-weight-bold text-indigo-9">
                {{ slotProps.row.ordered_quantity ?? '—' }}
              </span>
              <q-popup-edit
                v-slot="scope"
                :model-value="slotProps.row.ordered_quantity"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onItemFieldChange(slotProps.row, 'ordered_quantity', Number(val) || 0)"
              >
                <q-input v-model.number="scope.value" type="number" dense outlined autofocus min="0" />
              </q-popup-edit>
            </q-td>

            <!-- 9. Delivered Qty (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('delivered_qty')" key="delivered_qty" :props="slotProps" class="sec-qty text-center editable-cell">
              <span class="font-mono text-weight-bold text-positive">
                {{ slotProps.row.delivered_quantity ?? '—' }}
              </span>
              <q-popup-edit
                v-slot="scope"
                :model-value="slotProps.row.delivered_quantity"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onItemFieldChange(slotProps.row, 'delivered_quantity', Number(val) || 0)"
              >
                <q-input v-model.number="scope.value" type="number" dense outlined autofocus min="0" />
              </q-popup-edit>
            </q-td>

            <!-- 10. Purchase Price Unit (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('purchase_price_unit')" key="purchase_price_unit" :props="slotProps" class="sec-purchase text-right bg-purchase-accent editable-cell">
              <span class="font-mono text-weight-bold text-green-10">
                {{ formatAmount(slotProps.row.cost_price_amount, buyCurrency) }}
              </span>
              <q-popup-edit
                v-slot="scope"
                :model-value="slotProps.row.cost_price_amount"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onItemCostChange(slotProps.row, Number(val) || 0)"
              >
                <q-input v-model.number="scope.value" type="number" step="0.01" dense outlined autofocus min="0" />
              </q-popup-edit>
            </q-td>

            <!-- 11. Total Purchase Price -->
            <q-td v-if="isColVisible('purchase_price_total')" key="purchase_price_total" :props="slotProps" class="sec-purchase text-right font-mono text-weight-bold text-green-9 bg-purchase-accent">
              {{ formatAmount((slotProps.row.cost_price_amount || 0) * slotProps.row.quantity, buyCurrency) }}
            </q-td>

            <!-- 12. Product Weight (gm) (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('product_weight_gm')" key="product_weight_gm" :props="slotProps" class="sec-purchase text-right font-mono editable-cell">
              <span>{{ Math.round(getProductWeightGm(slotProps.row)) }} g</span>
              <q-popup-edit
                v-slot="scope"
                :model-value="slotProps.row.product_weight_gm ?? getProductWeightGm(slotProps.row)"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onItemProductWeightChange(slotProps.row, val)"
              >
                <q-input v-model.number="scope.value" type="number" step="1" dense outlined autofocus min="0" label="Product Weight (Grams)" />
              </q-popup-edit>
            </q-td>

            <!-- 13. Package Weight (gm) (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('package_weight_gm')" key="package_weight_gm" :props="slotProps" class="sec-purchase text-right font-mono editable-cell">
              <span>{{ Math.round(getPackageWeightGm(slotProps.row)) }} g</span>
              <q-popup-edit
                v-slot="scope"
                :model-value="slotProps.row.package_weight_gm ?? getPackageWeightGm(slotProps.row)"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onItemPackageWeightChange(slotProps.row, val)"
              >
                <q-input v-model.number="scope.value" type="number" step="1" dense outlined autofocus min="0" label="Package Weight (Grams)" />
              </q-popup-edit>
            </q-td>

            <!-- 14. Total Weight (gm) (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('total_weight_gm')" key="total_weight_gm" :props="slotProps" class="sec-purchase text-right font-mono editable-cell">
              <span>{{ Math.round(getTotalWeightGm(slotProps.row)) }} g</span>
              <q-popup-edit
                v-slot="scope"
                :model-value="slotProps.row.weight_kg"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onItemWeightChange(slotProps.row, val)"
              >
                <q-input v-model.number="scope.value" type="number" step="0.01" dense outlined autofocus min="0" label="Total Weight (KG)" />
              </q-popup-edit>
            </q-td>

            <!-- 15. Cargo Rate -->
            <q-td v-if="isColVisible('cargo_rate')" key="cargo_rate" :props="slotProps" class="sec-purchase text-right font-mono text-grey-8">
              {{ cargoRate.toFixed(2) }} /kg
            </q-td>

            <!-- 16. Cargo Cost (Purchase Currency) / Unit -->
            <q-td v-if="isColVisible('cargo_cost_unit_purchase')" key="cargo_cost_unit_purchase" :props="slotProps" class="sec-purchase text-right font-mono text-weight-medium">
              {{ formatAmount(getCargoCostUnitPurchase(slotProps.row), buyCurrency) }}
            </q-td>

            <!-- 17. Total Cost (Purchase Cost) / Unit -->
            <q-td v-if="isColVisible('landed_cost_unit_purchase')" key="landed_cost_unit_purchase" :props="slotProps" class="sec-landed text-right font-mono text-weight-bold text-teal-10">
              {{ formatAmount(getLandedCostUnitPurchase(slotProps.row), buyCurrency) }}
            </q-td>

            <!-- 18. Row Total Cost (Purchase) -->
            <q-td v-if="isColVisible('landed_cost_row_purchase')" key="landed_cost_row_purchase" :props="slotProps" class="sec-landed text-right font-mono text-weight-bold text-teal-9">
              {{ formatAmount(getLandedCostRowPurchase(slotProps.row), buyCurrency) }}
            </q-td>

            <!-- 19. Cost (Selling Currency) / Unit -->
            <q-td v-if="isColVisible('landed_cost_unit_sell')" key="landed_cost_unit_sell" :props="slotProps" class="sec-landed text-right font-mono text-weight-bold text-teal-10">
              {{ formatAmount(getLandedCostUnitSell(slotProps.row), sellCurrency) }}
            </q-td>

            <!-- 20. Row Total Cost (Selling Currency) -->
            <q-td v-if="isColVisible('landed_cost_row_sell')" key="landed_cost_row_sell" :props="slotProps" class="sec-landed text-right font-mono text-weight-bold text-teal-9">
              {{ formatAmount(getLandedCostRowSell(slotProps.row), sellCurrency) }}
            </q-td>

            <!-- 21. First Offer Unit (Selling Currency) (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('first_offer_unit')" key="first_offer_unit" :props="slotProps" class="sec-first-offer text-right bg-offer editable-cell">
              <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="slotProps.row.is_first_offer_manual"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                  class="q-mr-xs"
                >
                  <q-tooltip>First offer price manually locked — won't auto-recalculate</q-tooltip>
                </q-icon>

                <span class="font-mono text-weight-bold text-deep-purple-9">
                  {{ formatAmount(getFirstOfferUnitAmount(slotProps.row), sellCurrency) }}
                </span>

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

              <q-popup-edit
                v-slot="scope"
                :model-value="getFirstOfferUnitAmount(slotProps.row)"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onFirstOfferPriceSave(slotProps.row, val)"
              >
                <q-input v-model.number="scope.value" type="number" step="1" dense outlined autofocus min="0" label="1st Offer" />
              </q-popup-edit>
            </q-td>

            <!-- 22. First Offer Row Total -->
            <q-td v-if="isColVisible('first_offer_row')" key="first_offer_row" :props="slotProps" class="sec-first-offer text-right font-mono text-weight-bold text-deep-purple-8 bg-offer">
              {{ formatAmount(getFirstOfferUnitAmount(slotProps.row) * slotProps.row.quantity, sellCurrency) }}
            </q-td>

            <!-- 23. First Offer Margin % -->
            <q-td v-if="isColVisible('first_offer_margin')" key="first_offer_margin" :props="slotProps" class="sec-first-offer text-right font-mono text-weight-bold bg-offer" :class="getMarginColorClass(getFirstOfferMargin(slotProps.row))">
              {{ getFirstOfferMargin(slotProps.row).toFixed(1) }}%
            </q-td>

            <!-- 24. Counter Offer Unit -->
            <q-td v-if="isColVisible('counter_offer_unit')" key="counter_offer_unit" :props="slotProps" class="sec-counter-offer text-right font-mono text-weight-bold text-orange-9">
              {{ slotProps.row.customer_offer_amount != null ? formatAmount(slotProps.row.customer_offer_amount, sellCurrency) : '—' }}
            </q-td>

            <!-- 25. Counter Offer Row Total -->
            <q-td v-if="isColVisible('counter_offer_row')" key="counter_offer_row" :props="slotProps" class="sec-counter-offer text-right font-mono text-weight-bold text-orange-8">
              {{ slotProps.row.customer_offer_amount != null ? formatAmount(slotProps.row.customer_offer_amount * slotProps.row.quantity, sellCurrency) : '—' }}
            </q-td>

            <!-- 26. Counter Offer Margin % -->
            <q-td v-if="isColVisible('counter_offer_margin')" key="counter_offer_margin" :props="slotProps" class="sec-counter-offer text-right font-mono text-weight-bold" :class="getMarginColorClass(getCounterOfferMargin(slotProps.row))">
              {{ slotProps.row.customer_offer_amount != null ? `${getCounterOfferMargin(slotProps.row).toFixed(1)}%` : '—' }}
            </q-td>

            <!-- 27. Final Offer Unit (On Tap Popup Edit) -->
            <q-td v-if="isColVisible('final_offer_unit')" key="final_offer_unit" :props="slotProps" class="sec-final-offer text-right bg-final-offer editable-cell">
              <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="slotProps.row.is_final_offer_manual"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                  class="q-mr-xs"
                >
                  <q-tooltip>Final offer price manually locked — won't auto-recalculate</q-tooltip>
                </q-icon>

                <span class="font-mono text-weight-bold text-green-10">
                  {{ formatAmount(getFinalOfferUnitAmount(slotProps.row), sellCurrency) }}
                </span>

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

              <q-popup-edit
                v-slot="scope"
                :model-value="getFinalOfferUnitAmount(slotProps.row)"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(val) => onFinalOfferPriceSave(slotProps.row, val)"
              >
                <q-input v-model.number="scope.value" type="number" step="1" dense outlined autofocus min="0" label="Final Offer" />
              </q-popup-edit>
            </q-td>

            <!-- 28. Final Offer Row Total -->
            <q-td v-if="isColVisible('final_offer_row')" key="final_offer_row" :props="slotProps" class="sec-final-offer text-right font-mono text-weight-bold text-green-9 bg-final-offer">
              {{ formatAmount(getFinalOfferUnitAmount(slotProps.row) * slotProps.row.quantity, sellCurrency) }}
            </q-td>

            <!-- 29. Final Offer Margin % -->
            <q-td v-if="isColVisible('final_offer_margin')" key="final_offer_margin" :props="slotProps" class="sec-final-offer text-right font-mono text-weight-bold bg-final-offer" :class="getMarginColorClass(getFinalOfferMargin(slotProps.row))">
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
            <td v-if="isColVisible('purchase_price_total')" class="sec-purchase text-right font-mono text-weight-bold text-green-9 bg-purchase-accent">{{ formatAmount(grandTotalPurchasePrice, buyCurrency) }}</td>
            <td v-if="isColVisible('product_weight_gm')" class="sec-purchase" />
            <td v-if="isColVisible('package_weight_gm')" class="sec-purchase" />
            <td v-if="isColVisible('total_weight_gm')" class="sec-purchase text-right font-mono text-weight-bold">{{ totalWeightGm.toLocaleString() }} g</td>
            <td v-if="isColVisible('cargo_rate')" class="sec-purchase" />
            <td v-if="isColVisible('cargo_cost_unit_purchase')" class="sec-purchase" />

            <td v-if="isColVisible('landed_cost_unit_purchase')" class="sec-landed" />
            <td v-if="isColVisible('landed_cost_row_purchase')" class="sec-landed text-right font-mono text-weight-bold text-teal-9">{{ formatAmount(grandTotalLandedPurchase, buyCurrency) }}</td>
            <td v-if="isColVisible('landed_cost_unit_sell')" class="sec-landed" />
            <td v-if="isColVisible('landed_cost_row_sell')" class="sec-landed text-right font-mono text-weight-bold text-teal-9">{{ formatAmount(grandTotalLandedSell, sellCurrency) }}</td>

            <td v-if="isColVisible('first_offer_unit')" class="sec-first-offer bg-offer" />
            <td v-if="isColVisible('first_offer_row')" class="sec-first-offer text-right font-mono text-weight-bold text-deep-purple-9 bg-offer">{{ formatAmount(grandTotalFirstOffer, sellCurrency) }}</td>
            <td v-if="isColVisible('first_offer_margin')" class="sec-first-offer text-right font-mono text-weight-bold bg-offer">{{ overallFirstOfferMargin.toFixed(1) }}%</td>

            <td v-if="isColVisible('counter_offer_unit')" class="sec-counter-offer" />
            <td v-if="isColVisible('counter_offer_row')" class="sec-counter-offer text-right font-mono text-weight-bold text-orange-9">{{ formatAmount(grandTotalCounterOffer, sellCurrency) }}</td>
            <td v-if="isColVisible('counter_offer_margin')" class="sec-counter-offer text-right font-mono text-weight-bold">{{ overallCounterOfferMargin.toFixed(1) }}%</td>

            <td v-if="isColVisible('final_offer_unit')" class="sec-final-offer bg-final-offer" />
            <td v-if="isColVisible('final_offer_row')" class="sec-final-offer text-right font-mono text-weight-bold text-green-9 bg-final-offer">{{ formatAmount(grandTotalFinalOffer, sellCurrency) }}</td>
            <td v-if="isColVisible('final_offer_margin')" class="sec-final-offer text-right font-mono text-weight-bold bg-final-offer">{{ overallFinalOfferMargin.toFixed(1) }}%</td>

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
const tableColumns = computed<QTableColumn[]>(() => [
  // 1. Basic Info Section (sec-info)
  { name: 'sl', label: 'SL', field: 'id', align: 'center' },
  { name: 'image', label: 'Image', field: 'image_url', align: 'center' },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    sortable: true,
    style: 'width: 160px; max-width: 180px;',
    headerStyle: 'width: 160px; max-width: 180px;',
  },
  { name: 'brand', label: 'Brand', field: 'brand', align: 'left', sortable: true },
  { name: 'note', label: 'Note', field: 'note', align: 'left' },
  { name: 'code_barcode_id', label: 'Barcode / Code / ID', field: 'barcode', align: 'left' },

  // 2. Quantities Section (sec-qty)
  { name: 'qty_customer', label: 'Qty (Customer)', field: 'quantity', align: 'center', sortable: true },
  { name: 'ordered_qty', label: 'Ordered Qty', field: 'ordered_quantity', align: 'center', sortable: true },
  { name: 'delivered_qty', label: 'Delivered Qty', field: 'delivered_quantity', align: 'center', sortable: true },

  // 3. Purchase & Freight Section (sec-purchase)
  { name: 'purchase_price_unit', label: `Price (${buyCurrency.value}) / Unit`, field: 'cost_price_amount', align: 'right', sortable: true },
  { name: 'purchase_price_total', label: `Total Purchase (${buyCurrency.value})`, field: (row) => (row.cost_price_amount || 0) * row.quantity, align: 'right', sortable: true },
  { name: 'product_weight_gm', label: 'Product Weight (gm)', field: (row) => getProductWeightGm(row), align: 'right', sortable: true },
  { name: 'package_weight_gm', label: 'Package Weight (gm)', field: (row) => getPackageWeightGm(row), align: 'right', sortable: true },
  { name: 'total_weight_gm', label: 'Total Weight (gm)', field: (row) => getTotalWeightGm(row), align: 'right', sortable: true },
  { name: 'cargo_rate', label: `Cargo Rate (${buyCurrency.value}/kg)`, field: () => cargoRate.value, align: 'right' },
  { name: 'cargo_cost_unit_purchase', label: `Cargo Cost (${buyCurrency.value}) / Unit`, field: (row) => getCargoCostUnitPurchase(row), align: 'right' },

  // 4. Landed Cost Section (sec-landed)
  { name: 'landed_cost_unit_purchase', label: `Total Cost (${buyCurrency.value})`, field: (row) => getLandedCostUnitPurchase(row), align: 'right', sortable: true },
  { name: 'landed_cost_row_purchase', label: `Row Total Cost (${buyCurrency.value})`, field: (row) => getLandedCostRowPurchase(row), align: 'right', sortable: true },
  { name: 'landed_cost_unit_sell', label: `Cost (${sellCurrency.value})`, field: (row) => getLandedCostUnitSell(row), align: 'right', sortable: true },
  { name: 'landed_cost_row_sell', label: `Row Total Cost (${sellCurrency.value})`, field: (row) => getLandedCostRowSell(row), align: 'right', sortable: true },

  // 5. First Offer Section (sec-first-offer)
  { name: 'first_offer_unit', label: `1st Offer Unit (${sellCurrency.value})`, field: (row) => getFirstOfferUnitAmount(row), align: 'right', sortable: true },
  { name: 'first_offer_row', label: `Row Total 1st Offer (${sellCurrency.value})`, field: (row) => getFirstOfferUnitAmount(row) * row.quantity, align: 'right', sortable: true },
  { name: 'first_offer_margin', label: 'Profit Margin %', field: (row) => getFirstOfferMargin(row), align: 'right', sortable: true },

  // 6. Counter Offer Section (sec-counter-offer)
  { name: 'counter_offer_unit', label: `Counter Offer (${sellCurrency.value}) / Unit`, field: 'customer_offer_amount', align: 'right', sortable: true },
  { name: 'counter_offer_row', label: `Row Total Counter (${sellCurrency.value})`, field: (row) => (row.customer_offer_amount || 0) * row.quantity, align: 'right', sortable: true },
  { name: 'counter_offer_margin', label: 'Profit Margin %', field: (row) => getCounterOfferMargin(row), align: 'right', sortable: true },

  // 7. Final Offer Section (sec-final-offer)
  { name: 'final_offer_unit', label: `Final Offer (${sellCurrency.value})`, field: 'final_price_amount', align: 'right', sortable: true },
  { name: 'final_offer_row', label: `Row Total Final (${sellCurrency.value})`, field: (row) => (row.final_price_amount || 0) * row.quantity, align: 'right', sortable: true },
  { name: 'final_offer_margin', label: 'Profit Margin %', field: (row) => getFinalOfferMargin(row), align: 'right', sortable: true },

  // 8. Status & Action Section (sec-action)
  { name: 'status', label: 'Status', field: 'negotiation_status', align: 'center' },
  { name: 'action', label: 'Action', field: 'id', align: 'center' },
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
  if (['purchase_price_unit', 'purchase_price_total', 'product_weight_gm', 'package_weight_gm', 'total_weight_gm', 'cargo_rate', 'cargo_cost_unit_purchase'].includes(colName)) return 'sec-purchase-hdr';
  if (['landed_cost_unit_purchase', 'landed_cost_row_purchase', 'landed_cost_unit_sell', 'landed_cost_row_sell'].includes(colName)) return 'sec-landed-hdr';
  if (['first_offer_unit', 'first_offer_row', 'first_offer_margin'].includes(colName)) return 'sec-first-offer-hdr';
  if (['counter_offer_unit', 'counter_offer_row', 'counter_offer_margin'].includes(colName)) return 'sec-counter-offer-hdr';
  if (['final_offer_unit', 'final_offer_row', 'final_offer_margin'].includes(colName)) return 'sec-final-offer-hdr';
  return 'sec-action-hdr';
}

const status = computed(() => props.order?.status || 'submitted');
const isCostingMode = computed(() => ['submitted', 'costing_pending'].includes(status.value));

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

function onItemFieldChange(item: ShopOrderItem, field: string, val: any) {
  (item as any)[field] = val;
  if (field === 'final_price_amount') {
    item.is_final_offer_manual = true;
    emitItemUpdate(item, { [field]: val, is_final_offer_manual: true });
  } else {
    emitItemUpdate(item, { [field]: val });
  }
}

function onFirstOfferPriceSave(item: ShopOrderItem, val: any) {
  const newPrice = Number(val) || 0;
  item.staff_offer_amount = newPrice;
  item.is_first_offer_manual = true;
  emitItemUpdate(item, {
    staff_offer_amount: newPrice,
    is_first_offer_manual: true,
  });
}

function onUnlockFirstOffer(item: ShopOrderItem) {
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

function onItemCostChange(item: ShopOrderItem, val?: number | string | null) {
  if (val !== undefined) {
    item.cost_price_amount = Number(val) || 0;
  }
  if (isCostingMode.value && !item.is_first_offer_manual) {
    const rawOffer = calculateItemOffer(item);
    item.staff_offer_amount = rawOffer;
  }
  emitItemUpdate(item, { cost_price_amount: item.cost_price_amount, staff_offer_amount: item.staff_offer_amount });
}

function onItemWeightChange(item: ShopOrderItem, val?: number | string | null) {
  const wKg = Number(val) || 0;
  item.weight_kg = wKg;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    const rawOffer = calculateItemOffer(item);
    item.staff_offer_amount = rawOffer;
  }
  emitItemUpdate(item, { weight_kg: wKg });
}

function onItemProductWeightChange(item: ShopOrderItem, val?: number | string | null) {
  const prodGm = Number(val) || 0;
  item.product_weight_gm = prodGm;
  const pkgGm = getPackageWeightGm(item);
  item.weight_kg = (prodGm + pkgGm) / 1000;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    const rawOffer = calculateItemOffer(item);
    item.staff_offer_amount = rawOffer;
  }
  emitItemUpdate(item, { product_weight_gm: prodGm, weight_kg: item.weight_kg });
}

function onItemPackageWeightChange(item: ShopOrderItem, val?: number | string | null) {
  const pkgGm = Number(val) || 0;
  item.package_weight_gm = pkgGm;
  const prodGm = getProductWeightGm(item);
  item.weight_kg = (prodGm + pkgGm) / 1000;
  if (isCostingMode.value && !item.is_first_offer_manual) {
    const rawOffer = calculateItemOffer(item);
    item.staff_offer_amount = rawOffer;
  }
  emitItemUpdate(item, { package_weight_gm: pkgGm, weight_kg: item.weight_kg });
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

function formatAmount(val: number | null | undefined, symbol?: string): string {
  if (val == null || Number.isNaN(val)) return symbol ? `${symbol}0.00` : '0.00';
  const formatted = Number(val).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return symbol ? `${symbol}${formatted}` : formatted;
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

/* Uppercase Header Style */
.uppercase-header {
  letter-spacing: 0.04em;
  font-size: 11px;
  padding: 8px 12px;
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
.dense-input {
  max-width: 105px;
  font-size: 13px;
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
  width: 160px !important;
  min-width: 130px !important;
  max-width: 180px !important;
  white-space: normal !important;
  word-break: break-word !important;
  overflow-wrap: anywhere !important;
  line-height: 1.3;
  font-size: 13px;
}
</style>
