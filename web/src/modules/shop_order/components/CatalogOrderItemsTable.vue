<template>
  <q-card flat bordered class="catalog-items-card">
    <q-card-section class="row items-center justify-between q-py-sm bg-grey-1 border-bottom">
      <div class="row items-center q-gutter-x-sm">
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          Order Items ({{ items.length }})
        </div>
        <q-chip dense outline color="primary" class="text-caption">
          Total Weight: {{ totalWeight.toFixed(2) }} kg
        </q-chip>
      </div>

      <div class="row items-center q-gutter-x-xs">
        <q-btn
          flat
          dense
          no-caps
          color="grey-8"
          icon="ph ph-arrows-clockwise"
          label="Recalculate Offers"
          class="q-px-sm"
          v-if="isCostingMode"
          @click="recalculateAllOffers"
        >
          <q-tooltip>Recalculate staff offers using current rates</q-tooltip>
        </q-btn>
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          icon="ph ph-columns"
          label="Columns"
          class="q-px-sm"
          @click="$emit('open-column-selector')"
        />
      </div>
    </q-card-section>

    <!-- Table Container -->
    <div class="treasury-table-wrap overflow-auto">
      <table class="q-table bw-dense-table full-width">
        <thead>
          <tr class="bg-grey-2 text-grey-8 text-weight-bold text-caption">
            <th class="text-center" style="width: 40px">#</th>
            <th class="text-left" style="min-width: 200px">Product Item</th>
            <th v-if="isColVisible('sku')" class="text-left" style="width: 100px">SKU</th>
            <th class="text-center" style="width: 80px">Qty</th>
            <th v-if="isColVisible('list_price')" class="text-right" style="width: 110px">List Price</th>
            <th v-if="isColVisible('weight_kg')" class="text-right" style="width: 110px">
              Weight (kg)
            </th>
            <th v-if="isColVisible('cost_price')" class="text-right" style="width: 120px">
              Cost Price ({{ buyCurrencySymbol }})
            </th>
            <th v-if="isColVisible('profit_base')" class="text-right" style="width: 110px">
              Profit Base ({{ currencySymbol }})
            </th>
            <th v-if="isColVisible('staff_offer')" class="text-right" style="width: 130px">
              Staff Offer ({{ currencySymbol }})
            </th>
            <th v-if="isColVisible('customer_offer')" class="text-right" style="width: 130px">
              Customer Counter ({{ currencySymbol }})
            </th>
            <th v-if="isColVisible('final_price')" class="text-right" style="width: 130px">
              Final Price ({{ currencySymbol }})
            </th>
            <th v-if="isColVisible('confirmed_quantity')" class="text-center" style="width: 100px">
              Confirmed Qty
            </th>
            <th v-if="isColVisible('ordered_quantity')" class="text-center" style="width: 100px">
              Ordered Qty
            </th>
            <th v-if="isColVisible('delivered_quantity')" class="text-center" style="width: 100px">
              Delivered Qty
            </th>
            <th class="text-right" style="width: 130px">Total Amount ({{ currencySymbol }})</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, idx) in items" :key="item.id" class="border-bottom-subtle">
            <!-- Row Number -->
            <td class="text-center text-grey-6 text-caption">{{ idx + 1 }}</td>

            <!-- Item Info -->
            <td class="text-left">
              <div class="row items-center q-gutter-x-sm no-wrap">
                <q-img
                  :src="item.image_url || '/placeholder.png'"
                  style="width: 36px; height: 36px; border-radius: 4px"
                  fit="cover"
                  class="bg-grey-3 flex-shrink-0"
                />
                <div class="ellipsis" style="max-width: 220px">
                  <div class="text-weight-bold text-caption text-grey-9 ellipsis">
                    {{ item.name }}
                  </div>
                  <div v-if="item.sku" class="text-caption text-grey-6 text-2xs">
                    {{ item.sku }}
                  </div>
                </div>
              </div>
            </td>

            <!-- SKU -->
            <td v-if="isColVisible('sku')" class="text-left text-caption text-grey-7">
              {{ item.sku || '—' }}
            </td>

            <!-- Quantity -->
            <td class="text-center text-caption text-weight-bold">
              {{ item.quantity }}
            </td>

            <!-- List Price -->
            <td v-if="isColVisible('list_price')" class="text-right text-caption text-grey-7">
              {{ formatAmount(item.unit_list_price_amount) }}
            </td>

            <!-- Weight (kg) -->
            <td v-if="isColVisible('weight_kg')" class="text-right">
              <q-input
                v-if="isCostingMode"
                v-model.number="item.weight_kg"
                dense
                outlined
                type="number"
                step="0.01"
                min="0"
                class="soft-input text-right dense-input"
                @update:model-value="onItemWeightChange(item)"
              />
              <span v-else class="text-caption">{{ item.weight_kg ?? '0.00' }}</span>
            </td>

            <!-- Cost Price -->
            <td v-if="isColVisible('cost_price')" class="text-right">
              <q-input
                v-if="isCostingMode"
                v-model.number="item.cost_price_amount"
                dense
                outlined
                type="number"
                step="0.01"
                min="0"
                class="soft-input text-right dense-input"
                @update:model-value="onItemCostChange(item)"
              />
              <span v-else class="text-caption">{{ formatAmount(item.cost_price_amount) }}</span>
            </td>

            <!-- Profit Base -->
            <td v-if="isColVisible('profit_base')" class="text-right text-caption text-grey-8">
              {{ formatAmount(getItemProfitBase(item)) }}
            </td>

            <!-- Staff Offer -->
            <td v-if="isColVisible('staff_offer')" class="text-right">
              <q-input
                v-if="isCostingMode"
                v-model.number="item.staff_offer_amount"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                class="soft-input text-right dense-input text-weight-bold text-primary"
              />
              <span v-else class="text-caption text-weight-bold text-primary">
                {{ formatAmount(item.staff_offer_amount) }}
              </span>
            </td>

            <!-- Customer Counter -->
            <td v-if="isColVisible('customer_offer')" class="text-right text-caption text-deep-orange text-weight-bold">
              {{ item.customer_offer_amount != null ? formatAmount(item.customer_offer_amount) : '—' }}
            </td>

            <!-- Final Price -->
            <td v-if="isColVisible('final_price')" class="text-right">
              <q-input
                v-if="isFinalPricingMode"
                v-model.number="item.final_price_amount"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                class="soft-input text-right dense-input text-weight-bold text-purple"
              />
              <span v-else class="text-caption text-weight-bold text-purple">
                {{ item.final_price_amount != null ? formatAmount(item.final_price_amount) : '—' }}
              </span>
            </td>

            <!-- Confirmed Qty -->
            <td v-if="isColVisible('confirmed_quantity')" class="text-center text-caption text-weight-bold">
              {{ item.confirmed_quantity ?? item.quantity }}
            </td>

            <!-- Ordered Qty -->
            <td v-if="isColVisible('ordered_quantity')" class="text-center">
              <q-input
                v-if="isProcuringMode"
                v-model.number="item.ordered_quantity"
                dense
                outlined
                type="number"
                min="0"
                class="soft-input text-center dense-input text-indigo-9 text-weight-bold"
              />
              <span v-else class="text-caption text-weight-bold text-indigo-8">
                {{ item.ordered_quantity ?? '—' }}
              </span>
            </td>

            <!-- Delivered Qty -->
            <td v-if="isColVisible('delivered_quantity')" class="text-center">
              <q-input
                v-if="isOrderedMode || isProcuringMode"
                v-model.number="item.delivered_quantity"
                dense
                outlined
                type="number"
                min="0"
                class="soft-input text-center dense-input text-positive text-weight-bold"
              />
              <span v-else class="text-caption text-weight-bold text-positive">
                {{ item.delivered_quantity ?? '—' }}
              </span>
            </td>

            <!-- Total Amount -->
            <td class="text-right text-caption text-weight-bold text-grey-9">
              {{ formatAmount(getItemTotalAmount(item)) }}
            </td>
          </tr>
        </tbody>

        <tfoot>
          <tr class="bg-grey-2 text-weight-bold text-caption">
            <td colspan="2" class="text-left q-pa-sm">Total Summary</td>
            <td v-if="isColVisible('sku')"></td>
            <td class="text-center q-pa-sm">{{ totalQuantity }}</td>
            <td v-if="isColVisible('list_price')"></td>
            <td v-if="isColVisible('weight_kg')" class="text-right q-pa-sm">
              {{ totalWeight.toFixed(2) }} kg
            </td>
            <td v-if="isColVisible('cost_price')"></td>
            <td v-if="isColVisible('profit_base')"></td>
            <td v-if="isColVisible('staff_offer')"></td>
            <td v-if="isColVisible('customer_offer')"></td>
            <td v-if="isColVisible('final_price')"></td>
            <td v-if="isColVisible('confirmed_quantity')" class="text-center q-pa-sm">
              {{ totalConfirmedQuantity }}
            </td>
            <td v-if="isColVisible('ordered_quantity')" class="text-center q-pa-sm text-indigo-8">
              {{ totalOrderedQuantity }}
            </td>
            <td v-if="isColVisible('delivered_quantity')" class="text-center q-pa-sm text-positive">
              {{ totalDeliveredQuantity }}
            </td>
            <td class="text-right q-pa-sm text-primary">
              {{ formatAmount(grandTotalAmount) }} {{ currencySymbol }}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder, ShopOrderItem } from '../types';

const props = defineProps<{
  order: ShopOrder | null;
  items: ShopOrderItem[];
  currencySymbol?: string;
  buyCurrencySymbol?: string;
  visibleColumns?: string[];
}>();

defineEmits<{
  (e: 'open-column-selector'): void;
}>();

const defaultVisibleColumns = [
  'sku',
  'weight_kg',
  'cost_price',
  'staff_offer',
  'customer_offer',
  'final_price',
];

function isColVisible(colKey: string): boolean {
  const cols = props.visibleColumns?.length ? props.visibleColumns : defaultVisibleColumns;
  return cols.includes(colKey);
}

const status = computed(() => props.order?.status || 'submitted');

const isCostingMode = computed(() =>
  ['submitted', 'costing_pending'].includes(status.value),
);

const isFinalPricingMode = computed(() =>
  ['priced', 'countered'].includes(status.value),
);

const isProcuringMode = computed(() =>
  ['confirmed', 'procuring'].includes(status.value),
);

const isOrderedMode = computed(() =>
  ['ordered'].includes(status.value),
);

const FX = computed(() => props.order?.conversion_rate ?? 140);
const cargoRate = computed(() => props.order?.cargo_rate ?? 0);
const profitRate = computed(() => props.order?.profit_rate ?? 25);
const profitBasis = computed(() => props.order?.profit_basis || 'total_cost');

function calculateItemOffer(item: ShopOrderItem): number {
  const cost = Number(item.cost_price_amount || 0);
  const weight = Number(item.weight_kg || 0);
  const purchaseCostSell = cost * FX.value;
  const cargoCostSell = weight * cargoRate.value * FX.value;
  const totalCostSell = purchaseCostSell + cargoCostSell;
  const base = profitBasis.value === 'purchase' ? purchaseCostSell : totalCostSell;
  const rawOffer = Math.ceil(base + (base * profitRate.value) / 100);
  return Math.ceil(rawOffer / 5) * 5;
}

function getItemProfitBase(item: ShopOrderItem): number {
  const cost = Number(item.cost_price_amount || 0);
  const weight = Number(item.weight_kg || 0);
  const purchaseCostSell = cost * FX.value;
  const cargoCostSell = weight * cargoRate.value * FX.value;
  return profitBasis.value === 'purchase' ? purchaseCostSell : purchaseCostSell + cargoCostSell;
}

function onItemWeightChange(item: ShopOrderItem) {
  item.staff_offer_amount = calculateItemOffer(item);
}

function onItemCostChange(item: ShopOrderItem) {
  item.staff_offer_amount = calculateItemOffer(item);
}

function recalculateAllOffers() {
  for (const item of props.items) {
    item.staff_offer_amount = calculateItemOffer(item);
  }
}

function getItemUnitPrice(item: ShopOrderItem): number {
  if (item.final_price_amount != null && item.final_price_amount > 0) {
    return item.final_price_amount;
  }
  if (item.staff_offer_amount != null && item.staff_offer_amount > 0) {
    return item.staff_offer_amount;
  }
  if (item.customer_offer_amount != null && item.customer_offer_amount > 0) {
    return item.customer_offer_amount;
  }
  return item.unit_sell_price_amount || item.unit_list_price_amount || 0;
}

function getItemTotalAmount(item: ShopOrderItem): number {
  const unitPrice = getItemUnitPrice(item);
  const qty = item.confirmed_quantity ?? item.quantity;
  return unitPrice * qty;
}

const totalQuantity = computed(() =>
  props.items.reduce((sum, i) => sum + Number(i.quantity || 0), 0),
);

const totalConfirmedQuantity = computed(() =>
  props.items.reduce((sum, i) => sum + Number(i.confirmed_quantity ?? i.quantity ?? 0), 0),
);

const totalOrderedQuantity = computed(() =>
  props.items.reduce((sum, i) => sum + Number(i.ordered_quantity ?? 0), 0),
);

const totalDeliveredQuantity = computed(() =>
  props.items.reduce((sum, i) => sum + Number(i.delivered_quantity ?? 0), 0),
);

const totalWeight = computed(() =>
  props.items.reduce(
    (sum, i) => sum + Number(i.weight_kg || 0) * Number(i.quantity || 0),
    0,
  ),
);

const grandTotalAmount = computed(() =>
  props.items.reduce((sum, i) => sum + getItemTotalAmount(i), 0),
);

function formatAmount(val: number | null | undefined): string {
  if (val == null || isNaN(val)) return '0.00';
  return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
</script>

<style scoped lang="scss">
.catalog-items-card {
  border-radius: 8px;
}

.dense-input :deep(.q-field__control) {
  height: 28px;
  min-height: 28px;
  padding: 0 6px;
}

.dense-input :deep(.q-field__native) {
  padding: 0;
  font-size: 12px;
}

.text-2xs {
  font-size: 10px;
}
</style>
