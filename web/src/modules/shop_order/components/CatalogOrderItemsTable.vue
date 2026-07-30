<template>
  <q-card flat bordered class="catalog-items-card q-pa-none costing-items-surface">
    <!-- Header Section -->
    <div class="row items-center justify-between q-pa-sm bg-grey-1 border-bottom">
      <div class="row items-center q-gutter-x-sm">
        <div class="text-subtitle1 text-weight-bold text-grey-9">
          Order Items ({{ items.length }})
        </div>
        <q-chip dense outline color="primary" class="text-caption text-weight-bold">
          Total Weight: {{ totalWeight.toFixed(2) }} kg
        </q-chip>
      </div>

      <div class="row items-center q-gutter-x-xs">
        <q-btn
          v-if="isCostingMode"
          flat
          dense
          no-caps
          color="grey-8"
          icon="ph ph-arrows-clockwise"
          label="Recalculate Offers"
          class="q-px-sm text-caption"
          @click="recalculateAllOffers"
        >
          <q-tooltip>Recalculate staff offers using current rates</q-tooltip>
        </q-btn>

        <!-- Columns Selector Button with Quick Menu & Dialog Trigger -->
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          icon="ph ph-columns"
          label="Columns"
          class="q-px-sm text-caption"
          @click="$emit('open-column-selector')"
        >
          <q-menu anchor="bottom end" self="top end">
            <q-list style="min-width: 260px; max-height: 420px" class="q-pa-xs">
              <q-item class="q-pb-none">
                <q-item-section>
                  <div class="text-subtitle2 q-mb-xs text-weight-bold">Show Columns</div>
                  <q-input
                    v-model="quickColumnSearch"
                    dense
                    outlined
                    placeholder="Search columns..."
                    clearable
                  >
                    <template #prepend>
                      <q-icon name="ph ph-magnifying-glass" size="16px" />
                    </template>
                  </q-input>
                </q-item-section>
              </q-item>
              <q-item clickable class="q-py-xs">
                <q-item-section>
                  <q-checkbox
                    v-model="allQuickColumnsSelected"
                    label="Select / Deselect All"
                    dense
                    class="text-caption text-weight-bold"
                  />
                </q-item-section>
              </q-item>
              <q-separator class="q-my-xs" />
              <q-scroll-area style="height: 220px">
                <div v-if="!filteredQuickColumns.length" class="text-caption text-grey-6 q-pa-sm">
                  No matching columns found
                </div>
                <div v-else class="q-px-sm">
                  <div v-for="col in filteredQuickColumns" :key="col.value" class="q-py-xs">
                    <q-checkbox
                      :model-value="resolvedVisibleColumns.includes(col.value)"
                      :label="col.label"
                      dense
                      class="text-caption"
                      @update:model-value="(val) => toggleColumn(col.value, val)"
                    />
                  </div>
                </div>
              </q-scroll-area>
              <q-separator class="q-my-xs" />
              <q-item clickable v-close-popup class="text-primary text-caption text-weight-bold text-center" @click="$emit('open-column-selector')">
                <q-item-section>More Column Settings...</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
      </div>
    </div>

    <!-- Table Container -->
    <div class="product-based-costing-table">
      <q-table
        flat
        bordered
        :rows="items"
        :columns="columns"
        :visible-columns="resolvedVisibleColumns"
        row-key="id"
        hide-pagination
        :pagination="{ rowsPerPage: 0 }"
        :style="{ height: 'clamp(360px, calc(100vh - 300px), 78vh)' }"
        :table-style="{ maxHeight: '100%' }"
        class="costing-q-table"
      >
        <!-- Mobile Card View Slot -->
        <template #item="slotProps">
          <div class="col-12 col-sm-6 q-pa-xs q-sm-pa-sm">
            <q-card flat bordered class="costing-item-card floating-surface shadow-1">
              <!-- Card Header -->
              <div class="card-header row items-center justify-between q-px-md q-py-sm">
                <div class="row items-center q-gutter-xs">
                  <q-badge color="grey-3" text-color="grey-9" class="text-weight-bold">
                    #{{ slotProps.rowIndex + 1 }}
                  </q-badge>
                  <span v-if="slotProps.row.sku" class="text-caption font-mono text-grey-7">
                    {{ slotProps.row.sku }}
                  </span>
                </div>
              </div>

              <q-separator />

              <!-- Card Body -->
              <q-card-section class="q-pa-md">
                <div class="row q-col-gutter-sm items-start">
                  <!-- Image (1 Inch = 96px) -->
                  <div class="col-4 col-sm-3 text-center">
                    <div class="card-image-wrapper">
                      <SmartImage
                        :src="slotProps.row.image_url"
                        :alt="slotProps.row.name || 'Product image'"
                        img-class="card-image"
                        fallback-class="card-image-placeholder"
                      />
                    </div>
                  </div>

                  <!-- Info -->
                  <div class="col-8 col-sm-9">
                    <div class="card-item-name text-weight-bold text-grey-9">
                      {{ slotProps.row.name }}
                    </div>
                    <div v-if="slotProps.row.sku" class="text-caption text-grey-7 q-mt-xs font-mono">
                      SKU: {{ slotProps.row.sku }}
                    </div>
                  </div>
                </div>
              </q-card-section>

              <q-separator />

              <!-- Costing Grid -->
              <q-card-section class="q-pa-md bg-grey-0">
                <div class="row q-col-gutter-sm card-costing-grid">
                  <!-- Qty -->
                  <div class="col-6 col-sm-3 text-center">
                    <div class="metric-label">Qty</div>
                    <div class="metric-value font-mono font-weight-medium">
                      {{ slotProps.row.quantity }}
                    </div>
                  </div>

                  <!-- List Price -->
                  <div v-if="isColVisible('list_price')" class="col-6 col-sm-3 text-center">
                    <div class="metric-label">List Price</div>
                    <div class="metric-value font-mono">
                      {{ formatAmount(slotProps.row.unit_list_price_amount) }}
                    </div>
                  </div>

                  <!-- Weight (kg) -->
                  <div v-if="isColVisible('weight_kg')" class="col-6 col-sm-3 text-center">
                    <div class="metric-label">Weight (kg)</div>
                    <q-input
                      v-if="isCostingMode"
                      v-model.number="slotProps.row.weight_kg"
                      dense
                      outlined
                      type="number"
                      step="0.01"
                      min="0"
                      class="soft-input text-center dense-input"
                      @focus="onInputFocus"
                      @keydown.enter.prevent="handleEnterKey"
                      @update:model-value="onItemWeightChange(slotProps.row)"
                    />
                    <div v-else class="metric-value font-mono">
                      {{ slotProps.row.weight_kg ?? '0.00' }}
                    </div>
                  </div>

                  <!-- Cost Price -->
                  <div
                    v-if="isColVisible('cost_price')"
                    class="col-6 col-sm-3 text-center bg-gbp-light q-pa-xs rounded-borders"
                  >
                    <div class="metric-label text-green-9">Cost ({{ buyCurrencySymbol }})</div>
                    <q-input
                      v-if="isCostingMode"
                      v-model.number="slotProps.row.cost_price_amount"
                      dense
                      outlined
                      type="number"
                      step="0.01"
                      min="0"
                      class="soft-input text-center dense-input text-weight-bold text-green-10"
                      @focus="onInputFocus"
                      @keydown.enter.prevent="handleEnterKey"
                      @update:model-value="onItemCostChange(slotProps.row)"
                    />
                    <div v-else class="metric-value text-green-10 text-weight-bold font-mono">
                      {{ formatAmount(slotProps.row.cost_price_amount) }}
                    </div>
                  </div>

                  <!-- Profit Base -->
                  <div v-if="isColVisible('profit_base')" class="col-6 col-sm-3 text-center">
                    <div class="metric-label">Profit Base ({{ currencySymbol }})</div>
                    <div class="metric-value font-mono">
                      {{ formatAmount(getItemProfitBase(slotProps.row)) }}
                    </div>
                  </div>

                  <!-- Staff Offer -->
                  <div
                    v-if="isColVisible('staff_offer')"
                    class="col-6 col-sm-3 text-center bg-offer-light q-pa-xs rounded-borders"
                  >
                    <div class="metric-label text-primary">Staff Offer ({{ currencySymbol }})</div>
                    <q-input
                      v-if="isCostingMode"
                      v-model.number="slotProps.row.staff_offer_amount"
                      dense
                      outlined
                      type="number"
                      step="1"
                      min="0"
                      class="soft-input text-center dense-input text-weight-bold text-primary"
                      @focus="onInputFocus"
                      @keydown.enter.prevent="handleEnterKey"
                    />
                    <div v-else class="metric-value text-primary text-weight-bold font-mono">
                      {{ formatAmount(slotProps.row.staff_offer_amount) }}
                    </div>
                  </div>

                  <!-- Customer Counter -->
                  <div
                    v-if="isColVisible('customer_offer')"
                    class="col-6 col-sm-3 text-center bg-offer-light q-pa-xs rounded-borders"
                  >
                    <div class="metric-label text-deep-orange">Customer Counter</div>
                    <div class="metric-value text-deep-orange text-weight-bold font-mono">
                      {{ slotProps.row.customer_offer_amount != null ? formatAmount(slotProps.row.customer_offer_amount) : '—' }}
                    </div>
                  </div>

                  <!-- Final Price -->
                  <div
                    v-if="isColVisible('final_price')"
                    class="col-6 col-sm-3 text-center bg-offer-light q-pa-xs rounded-borders"
                  >
                    <div class="metric-label text-purple-9">Final Price</div>
                    <q-input
                      v-if="isFinalPricingMode"
                      v-model.number="slotProps.row.final_price_amount"
                      dense
                      outlined
                      type="number"
                      step="1"
                      min="0"
                      class="soft-input text-center dense-input text-weight-bold text-purple"
                      @focus="onInputFocus"
                      @keydown.enter.prevent="handleEnterKey"
                    />
                    <div v-else class="metric-value text-purple-10 text-weight-bold font-mono">
                      {{ slotProps.row.final_price_amount != null ? formatAmount(slotProps.row.final_price_amount) : '—' }}
                    </div>
                  </div>

                  <!-- Confirmed Qty -->
                  <div v-if="isColVisible('confirmed_quantity')" class="col-6 col-sm-3 text-center">
                    <div class="metric-label">Confirmed Qty</div>
                    <div class="metric-value font-mono text-weight-bold">
                      {{ slotProps.row.confirmed_quantity ?? slotProps.row.quantity }}
                    </div>
                  </div>

                  <!-- Ordered Qty -->
                  <div v-if="isColVisible('ordered_quantity')" class="col-6 col-sm-3 text-center">
                    <div class="metric-label">Ordered Qty</div>
                    <q-input
                      v-if="isProcuringMode"
                      v-model.number="slotProps.row.ordered_quantity"
                      dense
                      outlined
                      type="number"
                      min="0"
                      class="soft-input text-center dense-input text-indigo-9 text-weight-bold"
                      @focus="onInputFocus"
                      @keydown.enter.prevent="handleEnterKey"
                    />
                    <div v-else class="metric-value font-mono text-indigo-8 text-weight-bold">
                      {{ slotProps.row.ordered_quantity ?? '—' }}
                    </div>
                  </div>

                  <!-- Delivered Qty -->
                  <div v-if="isColVisible('delivered_quantity')" class="col-6 col-sm-3 text-center">
                    <div class="metric-label">Delivered Qty</div>
                    <q-input
                      v-if="isOrderedMode || isProcuringMode"
                      v-model.number="slotProps.row.delivered_quantity"
                      dense
                      outlined
                      type="number"
                      min="0"
                      class="soft-input text-center dense-input text-positive text-weight-bold"
                      @focus="onInputFocus"
                      @keydown.enter.prevent="handleEnterKey"
                    />
                    <div v-else class="metric-value font-mono text-positive text-weight-bold">
                      {{ slotProps.row.delivered_quantity ?? '—' }}
                    </div>
                  </div>

                  <!-- Total Amount -->
                  <div class="col-6 col-sm-3 text-center bg-bdt-light q-pa-xs rounded-borders">
                    <div class="metric-label text-amber-9">Total Amount</div>
                    <div class="metric-value text-amber-10 font-mono text-weight-bold">
                      {{ formatAmount(getItemTotalAmount(slotProps.row)) }} {{ currencySymbol }}
                    </div>
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </template>

        <!-- Desktop Body Slot -->
        <template #body="slotProps">
          <q-tr :props="slotProps">
            <!-- SL -->
            <q-td key="sl" :props="slotProps" class="col-sl text-center">
              {{ slotProps.rowIndex + 1 }}
            </q-td>

            <!-- Image (1 Inch = 96px x 96px) -->
            <q-td key="image" :props="slotProps" class="col-image text-center">
              <SmartImage
                :src="slotProps.row.image_url"
                :alt="slotProps.row.name || 'Product image'"
                img-class="table-image"
                fallback-class="table-image-placeholder"
              />
            </q-td>

            <!-- Name -->
            <q-td key="name" :props="slotProps" class="col-name">
              <div class="name-cell-content row items-center justify-between no-wrap">
                <span class="name-cell-text text-weight-bold text-grey-9">{{ slotProps.row.name }}</span>
              </div>
            </q-td>

            <!-- SKU -->
            <q-td v-if="isColVisible('sku')" key="sku" :props="slotProps" class="col-sku text-left">
              <div class="row items-center no-wrap">
                <span class="font-mono text-caption text-grey-8">{{ slotProps.row.sku || '—' }}</span>
                <q-btn
                  v-if="slotProps.row.sku"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-6"
                  class="q-ml-xs"
                  @click="handleCopy(slotProps.row.sku, 'SKU')"
                >
                  <q-tooltip>Copy SKU</q-tooltip>
                </q-btn>
              </div>
            </q-td>

            <!-- Qty -->
            <q-td key="quantity" :props="slotProps" class="col-qty text-center text-weight-bold">
              {{ slotProps.row.quantity }}
            </q-td>

            <!-- List Price -->
            <q-td
              v-if="isColVisible('list_price')"
              key="list_price"
              :props="slotProps"
              class="col-list-price text-right font-mono text-grey-8"
            >
              {{ formatAmount(slotProps.row.unit_list_price_amount) }}
            </q-td>

            <!-- Weight (kg) - Tab key navigates and auto-selects -->
            <q-td
              v-if="isColVisible('weight_kg')"
              key="weight_kg"
              :props="slotProps"
              class="col-weight text-right"
            >
              <q-input
                v-if="isCostingMode"
                v-model.number="slotProps.row.weight_kg"
                dense
                outlined
                type="number"
                step="0.01"
                min="0"
                class="soft-input text-right dense-input"
                @focus="onInputFocus"
                @keydown.enter.prevent="handleEnterKey"
                @update:model-value="onItemWeightChange(slotProps.row)"
              />
              <span v-else class="text-caption font-mono">{{ slotProps.row.weight_kg ?? '0.00' }}</span>
            </q-td>

            <!-- Cost Price - Tab key navigates and auto-selects -->
            <q-td
              v-if="isColVisible('cost_price')"
              key="cost_price"
              :props="slotProps"
              class="col-cost-price text-right bg-gbp"
            >
              <q-input
                v-if="isCostingMode"
                v-model.number="slotProps.row.cost_price_amount"
                dense
                outlined
                type="number"
                step="0.01"
                min="0"
                class="soft-input text-right dense-input"
                @focus="onInputFocus"
                @keydown.enter.prevent="handleEnterKey"
                @update:model-value="onItemCostChange(slotProps.row)"
              />
              <span v-else class="text-caption font-mono text-weight-bold">{{ formatAmount(slotProps.row.cost_price_amount) }}</span>
            </q-td>

            <!-- Profit Base -->
            <q-td
              v-if="isColVisible('profit_base')"
              key="profit_base"
              :props="slotProps"
              class="col-profit-base text-right font-mono text-grey-8"
            >
              {{ formatAmount(getItemProfitBase(slotProps.row)) }}
            </q-td>

            <!-- Staff Offer - Tab key navigates and auto-selects -->
            <q-td
              v-if="isColVisible('staff_offer')"
              key="staff_offer"
              :props="slotProps"
              class="col-staff-offer text-right bg-offer"
            >
              <q-input
                v-if="isCostingMode"
                v-model.number="slotProps.row.staff_offer_amount"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                class="soft-input text-right dense-input text-weight-bold text-primary"
                @focus="onInputFocus"
                @keydown.enter.prevent="handleEnterKey"
              />
              <span v-else class="text-caption text-weight-bold text-primary font-mono">
                {{ formatAmount(slotProps.row.staff_offer_amount) }}
              </span>
            </q-td>

            <!-- Customer Counter -->
            <q-td
              v-if="isColVisible('customer_offer')"
              key="customer_offer"
              :props="slotProps"
              class="col-customer-offer text-right bg-offer"
            >
              <span class="text-caption text-deep-orange text-weight-bold font-mono">
                {{ slotProps.row.customer_offer_amount != null ? formatAmount(slotProps.row.customer_offer_amount) : '—' }}
              </span>
            </q-td>

            <!-- Final Price - Tab key navigates and auto-selects -->
            <q-td
              v-if="isColVisible('final_price')"
              key="final_price"
              :props="slotProps"
              class="col-final-price text-right bg-offer"
            >
              <q-input
                v-if="isFinalPricingMode"
                v-model.number="slotProps.row.final_price_amount"
                dense
                outlined
                type="number"
                step="1"
                min="0"
                class="soft-input text-right dense-input text-weight-bold text-purple"
                @focus="onInputFocus"
                @keydown.enter.prevent="handleEnterKey"
              />
              <span v-else class="text-caption text-weight-bold text-purple font-mono">
                {{ slotProps.row.final_price_amount != null ? formatAmount(slotProps.row.final_price_amount) : '—' }}
              </span>
            </q-td>

            <!-- Confirmed Qty -->
            <q-td
              v-if="isColVisible('confirmed_quantity')"
              key="confirmed_quantity"
              :props="slotProps"
              class="col-confirmed-qty text-center text-weight-bold"
            >
              {{ slotProps.row.confirmed_quantity ?? slotProps.row.quantity }}
            </q-td>

            <!-- Ordered Qty - Tab key navigates and auto-selects -->
            <q-td
              v-if="isColVisible('ordered_quantity')"
              key="ordered_quantity"
              :props="slotProps"
              class="col-ordered-qty text-center"
            >
              <q-input
                v-if="isProcuringMode"
                v-model.number="slotProps.row.ordered_quantity"
                dense
                outlined
                type="number"
                min="0"
                class="soft-input text-center dense-input text-indigo-9 text-weight-bold"
                @focus="onInputFocus"
                @keydown.enter.prevent="handleEnterKey"
              />
              <span v-else class="text-caption text-weight-bold text-indigo-8 font-mono">
                {{ slotProps.row.ordered_quantity ?? '—' }}
              </span>
            </q-td>

            <!-- Delivered Qty - Tab key navigates and auto-selects -->
            <q-td
              v-if="isColVisible('delivered_quantity')"
              key="delivered_quantity"
              :props="slotProps"
              class="col-delivered-qty text-center"
            >
              <q-input
                v-if="isOrderedMode || isProcuringMode"
                v-model.number="slotProps.row.delivered_quantity"
                dense
                outlined
                type="number"
                min="0"
                class="soft-input text-center dense-input text-positive text-weight-bold"
                @focus="onInputFocus"
                @keydown.enter.prevent="handleEnterKey"
              />
              <span v-else class="text-caption text-weight-bold text-positive font-mono">
                {{ slotProps.row.delivered_quantity ?? '—' }}
              </span>
            </q-td>

            <!-- Total Amount -->
            <q-td
              key="total_amount"
              :props="slotProps"
              class="col-total-amount text-right font-mono text-weight-bold text-grey-9 bg-bdt"
            >
              {{ formatAmount(getItemTotalAmount(slotProps.row)) }}
            </q-td>
          </q-tr>
        </template>

        <!-- Bottom Totals Row Slot -->
        <template #bottom-row>
          <q-tr class="totals-row">
            <q-td class="totals-row__cell col-sl text-center">Total</q-td>
            <q-td class="totals-row__cell col-image" />
            <q-td class="totals-row__cell col-name text-left q-px-sm">
              {{ items.length }} Items
            </q-td>
            <q-td v-if="isColVisible('sku')" class="totals-row__cell col-sku" />
            <q-td class="totals-row__cell col-qty text-center q-pa-sm">
              {{ totalQuantity }}
            </q-td>
            <q-td v-if="isColVisible('list_price')" class="totals-row__cell col-list-price" />
            <q-td v-if="isColVisible('weight_kg')" class="totals-row__cell col-weight text-right q-pa-sm">
              {{ totalWeight.toFixed(2) }} kg
            </q-td>
            <q-td v-if="isColVisible('cost_price')" class="totals-row__cell col-cost-price text-right">
              <div class="totals-row__value bg-gbp">
                {{ buyCurrencySymbol }}
              </div>
            </q-td>
            <q-td v-if="isColVisible('profit_base')" class="totals-row__cell col-profit-base" />
            <q-td v-if="isColVisible('staff_offer')" class="totals-row__cell col-staff-offer" />
            <q-td v-if="isColVisible('customer_offer')" class="totals-row__cell col-customer-offer" />
            <q-td v-if="isColVisible('final_price')" class="totals-row__cell col-final-price" />
            <q-td v-if="isColVisible('confirmed_quantity')" class="totals-row__cell col-confirmed-qty text-center q-pa-sm">
              {{ totalConfirmedQuantity }}
            </q-td>
            <q-td v-if="isColVisible('ordered_quantity')" class="totals-row__cell col-ordered-qty text-center q-pa-sm text-indigo-8">
              {{ totalOrderedQuantity }}
            </q-td>
            <q-td v-if="isColVisible('delivered_quantity')" class="totals-row__cell col-delivered-qty text-center q-pa-sm text-positive">
              {{ totalDeliveredQuantity }}
            </q-td>
            <q-td class="totals-row__cell col-total-amount text-right">
              <div class="totals-row__value bg-offer text-primary">
                {{ formatAmount(grandTotalAmount) }} {{ currencySymbol }}
              </div>
            </q-td>
          </q-tr>
        </template>

        <template #no-data>
          <div class="full-width row flex-center q-pa-md text-grey-7">No order items found</div>
        </template>
      </q-table>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar, copyToClipboard, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import type { ShopOrder, ShopOrderItem } from '../types';

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
}>();

const $q = useQuasar();

const quickColumnSearch = ref('');

const allToggleableColumns = [
  { label: 'SKU / Code', value: 'sku' },
  { label: 'List Price', value: 'list_price' },
  { label: 'Weight (kg)', value: 'weight_kg' },
  { label: 'Cost Price', value: 'cost_price' },
  { label: 'Profit Base', value: 'profit_base' },
  { label: 'Staff Offer', value: 'staff_offer' },
  { label: 'Customer Counter', value: 'customer_offer' },
  { label: 'Final Offer Price', value: 'final_price' },
  { label: 'Confirmed Qty', value: 'confirmed_quantity' },
  { label: 'Ordered Qty', value: 'ordered_quantity' },
  { label: 'Delivered Qty', value: 'delivered_quantity' },
];

const defaultVisibleColumns = [
  'sku',
  'weight_kg',
  'cost_price',
  'staff_offer',
  'customer_offer',
  'final_price',
];

const resolvedVisibleColumns = computed<string[]>(() => {
  return props.visibleColumns?.length ? props.visibleColumns : defaultVisibleColumns;
});

const filteredQuickColumns = computed(() => {
  const query = quickColumnSearch.value.trim().toLowerCase();
  if (!query) return allToggleableColumns;
  return allToggleableColumns.filter((c) => c.label.toLowerCase().includes(query));
});

const allQuickColumnsSelected = computed({
  get: () => allToggleableColumns.every((col) => resolvedVisibleColumns.value.includes(col.value)),
  set: (val: boolean) => {
    const alwaysVisible = ['sl', 'image', 'name', 'quantity', 'total_amount'];
    const next = val
      ? [...alwaysVisible, ...allToggleableColumns.map((c) => c.value)]
      : [...alwaysVisible];
    emit('update:visible-columns', next);
  },
});

function toggleColumn(colValue: string, active: boolean) {
  const current = [...resolvedVisibleColumns.value];
  if (active) {
    if (!current.includes(colValue)) {
      current.push(colValue);
    }
  } else {
    const idx = current.indexOf(colValue);
    if (idx !== -1) {
      current.splice(idx, 1);
    }
  }
  emit('update:visible-columns', current);
}

function isColVisible(colKey: string): boolean {
  return resolvedVisibleColumns.value.includes(colKey);
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

// On Tab / Keyboard Input Navigation Helpers
function onInputFocus(evt: Event) {
  const target = evt.target as HTMLInputElement | null;
  if (target && typeof target.select === 'function') {
    target.select();
  }
}

function handleEnterKey(evt: Event) {
  const target = evt.target as HTMLInputElement | null;
  if (target) {
    target.blur();
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

const handleCopy = (text: string, label: string) => {
  copyToClipboard(text)
    .then(() => {
      $q.notify({
        type: 'positive',
        message: `${label} copied to clipboard!`,
        timeout: 1000,
      });
    })
    .catch(() => {
      $q.notify({
        type: 'negative',
        message: `Failed to copy ${label}`,
        timeout: 1000,
      });
    });
};

const columns = computed<QTableColumn[]>(() => [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center',
    style: 'width: 42px; min-width: 42px; max-width: 42px; text-align: center;',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'image_url',
    align: 'center',
    style: 'width: 140px; min-width: 140px; max-width: 140px; text-align: center;',
  },
  {
    name: 'name',
    label: 'Product Item',
    field: 'name',
    align: 'left',
    classes: 'col-name-wrap',
    headerClasses: 'col-name-wrap',
    style: 'text-align: left;',
  },
  {
    name: 'sku',
    label: 'SKU',
    field: 'sku',
    align: 'left',
    style: 'text-align: left;',
  },
  {
    name: 'quantity',
    label: 'Qty',
    field: 'quantity',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'list_price',
    label: 'List Price',
    field: 'unit_list_price_amount',
    align: 'right',
    style: 'text-align: right;',
  },
  {
    name: 'weight_kg',
    label: 'Weight (kg)',
    field: 'weight_kg',
    align: 'right',
    style: 'text-align: right;',
  },
  {
    name: 'cost_price',
    label: `Cost Price (${props.buyCurrencySymbol || '£'})`,
    field: 'cost_price_amount',
    align: 'right',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: right;',
  },
  {
    name: 'profit_base',
    label: `Profit Base (${props.currencySymbol || '৳'})`,
    field: 'profit_base',
    align: 'right',
    style: 'text-align: right;',
  },
  {
    name: 'staff_offer',
    label: `Staff Offer (${props.currencySymbol || '৳'})`,
    field: 'staff_offer_amount',
    align: 'right',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: right;',
  },
  {
    name: 'customer_offer',
    label: `Customer Counter (${props.currencySymbol || '৳'})`,
    field: 'customer_offer_amount',
    align: 'right',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: right;',
  },
  {
    name: 'final_price',
    label: `Final Price (${props.currencySymbol || '৳'})`,
    field: 'final_price_amount',
    align: 'right',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: right;',
  },
  {
    name: 'confirmed_quantity',
    label: 'Confirmed Qty',
    field: 'confirmed_quantity',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'ordered_quantity',
    label: 'Ordered Qty',
    field: 'ordered_quantity',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'delivered_quantity',
    label: 'Delivered Qty',
    field: 'delivered_quantity',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'total_amount',
    label: `Total Amount (${props.currencySymbol || '৳'})`,
    field: 'total_amount',
    align: 'right',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: right;',
  },
]);
</script>

<style scoped lang="scss">
.catalog-items-card {
  border-radius: 8px;
  overflow: hidden;
}

.product-based-costing-table {
  width: 100%;
}

.costing-q-table {
  max-width: 100%;
  background: var(--bw-theme-base, #eef2f5);
}

.product-based-costing-table :deep(.costing-q-table .q-table__middle) {
  height: 100%;
  max-height: 100% !important;
  overflow: scroll !important;
}

:deep(.q-table) {
  min-width: max-content;
  width: max-content;
}

.product-based-costing-table :deep(.costing-q-table table) {
  table-layout: fixed;
  min-width: max-content;
  width: max-content;
}

.product-based-costing-table :deep(.costing-q-table thead tr th) {
  position: sticky;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
  font-weight: 700;
}

.product-based-costing-table :deep(.costing-q-table thead tr:first-child th) {
  top: 0;
  z-index: 1;
}

/* Sticky left columns for SL (1st), Image (2nd), Name (3rd) */
.product-based-costing-table :deep(.costing-q-table td:first-child),
.product-based-costing-table :deep(.costing-q-table th:first-child) {
  position: sticky;
  left: 0;
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(2)),
.product-based-costing-table :deep(.costing-q-table th:nth-child(2)) {
  position: sticky;
  left: 42px;
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(3)),
.product-based-costing-table :deep(.costing-q-table th:nth-child(3)) {
  position: sticky;
  left: 182px;
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:first-child) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:nth-child(3)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

/* 1 Inch Image Size = 96px x 96px */
.table-image {
  width: 96px;
  height: 96px;
  display: block;
  margin: 0 auto;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
  overflow: hidden;
}

.table-image :deep(.smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  object-position: center;
}

.table-image-placeholder {
  width: 96px;
  height: 96px;
  margin: 0 auto;
  border: 1px dashed #bbb;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  color: #777;
  background: #fafafa;
}

.col-sl {
  min-width: 42px;
  width: 42px;
  max-width: 42px;
}

.col-image {
  min-width: 140px;
  width: 140px;
  max-width: 140px;
}

.col-name {
  min-width: 220px;
  width: 220px;
  max-width: 220px;
}

.col-name-wrap {
  min-width: 220px;
  max-width: 260px;
  white-space: normal;
  word-break: break-word;
  line-height: 1.3;
}

.col-sku {
  min-width: 120px;
  width: 120px;
}

.col-qty {
  min-width: 80px;
  width: 80px;
}

.col-list-price {
  min-width: 110px;
  width: 110px;
}

.col-weight {
  min-width: 110px;
  width: 110px;
}

.col-cost-price {
  min-width: 120px;
  width: 120px;
}

.col-profit-base {
  min-width: 110px;
  width: 110px;
}

.col-staff-offer {
  min-width: 130px;
  width: 130px;
}

.col-customer-offer {
  min-width: 130px;
  width: 130px;
}

.col-final-price {
  min-width: 130px;
  width: 130px;
}

.col-confirmed-qty {
  min-width: 100px;
  width: 100px;
}

.col-ordered-qty {
  min-width: 100px;
  width: 100px;
}

.col-delivered-qty {
  min-width: 100px;
  width: 100px;
}

.col-total-amount {
  min-width: 130px;
  width: 130px;
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

.totals-row {
  background: inherit;
}

.totals-row__cell {
  font-weight: 700;
  color: inherit;
  white-space: normal;
  word-break: break-word;
  padding: 0;
  text-align: center;
}

.totals-row__value {
  display: block;
  width: 100%;
  min-height: 100%;
  padding: 8px 16px;
  text-align: center;
}

:deep(.bg-gbp) {
  background-color: #e6f4ea !important;
}

:deep(.bg-bdt) {
  background-color: #fff8e1 !important;
}

:deep(.bg-offer) {
  background-color: #f3e5f5 !important;
}

/* Card View Styles for Mobile */
.costing-item-card {
  border-radius: 12px;
  transition: all 0.3s ease;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.costing-item-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.06) !important;
}

.card-header {
  background-color: var(--bw-theme-surface-variant, #fafafa);
  min-height: 44px;
}

.card-image-wrapper {
  width: 100%;
  aspect-ratio: 1;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}

.card-image {
  width: 100%;
  height: 100%;
  display: block;
  overflow: hidden;
}

.card-image :deep(.smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  object-position: center;
}

.card-image-placeholder {
  width: 100%;
  height: 100%;
  background-color: #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #aaa;
  font-size: 11px;
}

.card-item-name {
  font-size: 14px;
  line-height: 1.4;
  color: #2c3e50;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.card-costing-grid {
  font-size: 13px;
}

.metric-label {
  font-size: 11px;
  color: #7f8c8d;
  margin-bottom: 2px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.metric-value {
  font-size: 14px;
  color: #2c3e50;
}

.bg-gbp-light {
  background-color: color-mix(in srgb, #e6f4ea 35%, var(--bw-theme-surface, #fff));
}

.bg-offer-light {
  background-color: color-mix(in srgb, #f3e5f5 35%, var(--bw-theme-surface, #fff));
}

.bg-bdt-light {
  background-color: color-mix(in srgb, #fff8e1 35%, var(--bw-theme-surface, #fff));
}
</style>
