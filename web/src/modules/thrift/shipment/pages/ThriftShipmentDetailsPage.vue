<template>
  <q-page class="q-pa-md thrift-shipment-details-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-auto">
            <q-btn flat round icon="arrow_back" color="BW-Grey-7" @click="goBack" />
          </div>
          <div class="col">
            <div class="text-h6 text-weight-bold">
              {{ shipment?.name || 'Shipment Details' }}
            </div>
            <div class="text-caption text-grey-8">
              Landed costing breakdown and item details
            </div>
          </div>
          <div class="col-auto row q-gutter-x-sm" v-if="shipment">
            <q-chip outline color="primary" text-color="white" dense>
              Purchase: {{ currencyCode(shipment.purchase_currency_id) }}
            </q-chip>
            <q-chip outline color="secondary" text-color="white" dense>
              Cost: {{ currencyCode(shipment.cost_currency_id) }}
            </q-chip>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Empty State when no stocks exist in the shipment -->
    <q-banner v-if="!loading && stocks.length === 0" inline-actions class="bg-blue-1 text-blue-9 rounded-borders q-mb-md q-pa-md">
      <template v-slot:avatar>
        <q-icon name="info" color="blue-8" size="24px" />
      </template>
      <div class="text-subtitle2 text-weight-bold">No stock in this shipment yet</div>
      <div class="text-caption">Register items in the mobile app or catalog page to populate this shipment.</div>
    </q-banner>

    <!-- Skeleton loader for the entire page body when first loading -->
    <div class="row q-col-gutter-md" v-if="loading && !shipment">
      <!-- Left sidebar skeleton -->
      <div class="col-12 col-md-3">
        <q-card flat class="floating-surface shadow-1 q-mb-md">
          <q-card-section>
            <q-skeleton type="text" width="60%" class="q-mb-sm" />
            <q-separator class="q-my-sm" />
            <div v-for="n in 2" :key="n" class="row justify-between q-py-xs">
              <q-skeleton type="text" width="40%" />
              <q-skeleton type="text" width="20%" />
            </div>
          </q-card-section>
        </q-card>
        <q-card flat class="floating-surface shadow-1">
          <q-card-section class="q-gutter-y-sm">
            <q-skeleton type="text" width="50%" />
            <q-skeleton v-for="n in 6" :key="n" type="QInput" height="40px" />
          </q-card-section>
        </q-card>
      </div>

      <!-- Main table area skeleton -->
      <div class="col-12 col-md-9">
        <q-card flat class="floating-surface shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <q-skeleton type="text" width="120px" height="32px" />
            <div class="row q-gutter-sm">
              <q-skeleton type="QInput" width="200px" height="32px" />
              <q-skeleton type="QBtn" width="100px" height="32px" />
            </div>
          </q-card-section>
          
          <thrift-shipment-items-table
            :stocks="[]"
            :visibleColumns="visibleColumns"
            :costingBreakdowns="{}"
            :purchaseCurrency="undefined"
            :costCurrency="undefined"
            :loading="true"
          />
        </q-card>
      </div>
    </div>

    <div class="row q-col-gutter-md" v-else>
      <!-- Collapsible Left Sidebar (col-3) -->
      <div v-show="isLeftColumnVisible" class="col-12 col-md-3 transition-sidebar">
        <!-- Summary card -->
        <q-card flat class="floating-surface shadow-1 q-mb-md">
          <q-card-section>
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-xs">Shipment Summary</div>
            <q-separator class="q-my-sm" />
            <div class="row justify-between q-py-xs">
              <span class="text-caption text-grey-8">Total Items (U):</span>
              <span class="text-subtitle2 text-weight-bold text-grey-9">{{ U }}</span>
            </div>
            <div class="row justify-between q-py-xs">
              <span class="text-caption text-grey-8">Unique Stocks:</span>
              <span class="text-subtitle2 text-weight-bold text-grey-9">{{ stocks.length }}</span>
            </div>
          </q-card-section>
        </q-card>

        <!-- Cost Inputs Editor -->
        <q-card flat class="floating-surface shadow-1">
          <q-card-section>
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-md">Landed Cost Inputs</div>
            
            <div class="column q-gutter-y-sm">
              <div class="text-caption text-weight-bold text-grey-7 q-mb-none">CARGO</div>
              <q-input
                v-model.number="costForm.total_cargo_weight_kg"
                type="number"
                step="0.1"
                min="0"
                outlined
                dense
                label="Total Cargo Weight (kg)"
                class="soft-input"
                @change="saveShipmentCosts"
              />
              <q-input
                v-model.number="costForm.cargo_rate"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Cargo Rate"
                class="soft-input"
                @change="saveShipmentCosts"
              />
              <q-input
                v-model.number="costForm.cargo_conversion_rate"
                type="number"
                step="0.0001"
                min="0"
                outlined
                dense
                label="Cargo Conv. Rate"
                class="soft-input"
                @change="saveShipmentCosts"
              />

              <q-separator class="q-my-xs" />
              <div class="text-caption text-weight-bold text-grey-7 q-mb-none">OPERATIONS</div>
              <q-input
                v-model.number="costForm.labor_total_cost"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Labor Total Cost"
                class="soft-input"
                @change="saveShipmentCosts"
              />
              <q-input
                v-model.number="costForm.transportation_total_cost"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Transport Total Cost"
                class="soft-input"
                @change="saveShipmentCosts"
              />
              <q-input
                v-model.number="costForm.washing_total_cost"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Washing Total Cost"
                class="soft-input"
                @change="saveShipmentCosts"
              />

              <q-separator class="q-my-xs" />
              <div class="text-caption text-weight-bold text-grey-7 q-mb-none">RATES & MARKUP</div>
              <q-input
                v-model.number="costForm.product_conversion_rate"
                type="number"
                step="0.0001"
                min="0"
                outlined
                dense
                label="Product Conv. Rate"
                class="soft-input"
                @change="saveShipmentCosts"
              />
              <q-input
                v-model.number="markupPercentage"
                type="number"
                step="1"
                min="0"
                outlined
                dense
                label="Default Markup (%)"
                class="soft-input"
                suffix="%"
                @change="saveShipmentCosts"
              />
              <div class="text-caption text-grey-6 text-italic" style="font-size: 10px; line-height: 1.2;">
                Suggested sell = landed × (1 + markup)
              </div>
              <div class="q-pa-xs q-mt-xs bg-grey-2 rounded-borders text-caption text-grey-8" style="font-size: 11px;">
                <div>Sample Preview (using Default Origin: {{ formatPurchase(settingsStore.settings?.default_origin_unit_price || 0) }}):</div>
                <div class="row justify-between text-weight-bold text-grey-9 q-mt-xs">
                  <span>Suggested Sell:</span>
                  <span>{{ formatCost(sampleSuggestedPrice) }}</span>
                </div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Right Panel Table (col-9 or col-12) -->
      <div :class="isLeftColumnVisible ? 'col-12 col-md-9' : 'col-12'" class="transition-table">
        <q-card flat class="floating-surface shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div class="row items-center q-gutter-x-sm">
              <q-btn
                flat
                round
                dense
                color="primary"
                :icon="isLeftColumnVisible ? 'keyboard_double_arrow_left' : 'keyboard_double_arrow_right'"
                @click="isLeftColumnVisible = !isLeftColumnVisible"
              >
                <q-tooltip>{{ isLeftColumnVisible ? 'Collapse Sidebar' : 'Expand Sidebar' }}</q-tooltip>
              </q-btn>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Shipment Items</div>
            </div>

            <div class="row items-center q-gutter-x-md">
              <q-input
                v-model="searchText"
                placeholder="Search barcode, name, brand..."
                dense
                outlined
                clearable
                style="width: 250px;"
                class="soft-input"
              >
                <template v-slot:append>
                  <q-icon name="search" />
                </template>
              </q-input>

              <!-- Columns menu picker -->
              <q-btn-dropdown outline dense color="primary" icon="view_column" label="Columns">
                <q-list class="q-pa-xs" style="min-width: 180px;">
                  <div class="text-caption text-weight-bold text-grey-7 q-px-sm q-py-xs border-bottom-translucent">Visible Columns</div>
                  <q-item v-for="col in columnsList" :key="col.name" clickable dense class="q-py-none">
                    <q-item-section>
                      <q-checkbox
                        :model-value="visibleColumns.has(col.name)"
                        :label="col.label"
                        dense
                        @update:model-value="toggleColumn(col.name)"
                      />
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </div>
          </q-card-section>

          <thrift-shipment-items-table
            :stocks="filteredStocks"
            :visibleColumns="visibleColumns"
            :costingBreakdowns="costingBreakdowns"
            :purchaseCurrency="purchaseCurrency"
            :costCurrency="costCurrency"
            :loading="loading"
            @edit-measurements="openMeasurementsDialog"
            @open-landed-breakdown="openLandedBreakdownDialog"
            @save-stock-value="saveStockValue"
            @save-pricing-value="saveStockPricingValue"
            @reset-listed-price="resetListedPriceToSuggested"
            @reset-item-markup="resetItemMarkupToShipment"
          />
        </q-card>
      </div>
    </div>

    <!-- Bottom Row Summaries -->
    <div class="row q-col-gutter-md q-mt-md">
      <div class="col-12">
        <q-card flat class="floating-surface shadow-1">
          <q-card-section>
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-md">SHIPMENT COST OVERVIEW</div>
            
            <div class="row q-col-gutter-md">
              <!-- Units Section -->
              <div class="col-12 col-md-3">
                <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">HOW COSTS ARE SPLIT</div>
                <div class="q-pa-sm bg-grey-1 rounded-borders h-100 column justify-center" style="min-height: 120px;">
                  <div class="row justify-between items-center">
                    <span class="text-body2 text-grey-8">Unit Count (U):</span>
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{ U }}</span>
                  </div>
                  <div class="text-caption text-grey-6 q-mt-xs">
                    Cargo splits by item weight when set; ops bills divide by U.
                  </div>
                </div>
              </div>

              <!-- Shipment Bills Section -->
              <div class="col-12 col-md-3">
                <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">SHIPMENT TOTALS ({{ costCurrency?.code || '—' }})</div>
                <div class="q-gutter-y-xs">
                  <div class="row justify-between text-body2">
                    <span class="text-grey-8">Cargo Total:</span>
                    <span class="text-weight-medium">{{ formatCost(cargoCost) }}</span>
                  </div>
                  <div class="row justify-between text-body2">
                    <span class="text-grey-8">Labor:</span>
                    <span>{{ formatCost(costForm.labor_total_cost || 0) }}</span>
                  </div>
                  <div class="row justify-between text-body2">
                    <span class="text-grey-8">Transport:</span>
                    <span>{{ formatCost(costForm.transportation_total_cost || 0) }}</span>
                  </div>
                  <div class="row justify-between text-body2">
                    <span class="text-grey-8">Washing:</span>
                    <span>{{ formatCost(costForm.washing_total_cost || 0) }}</span>
                  </div>
                  <div class="row justify-between text-body2">
                    <span class="text-grey-8">Hand tags (total):</span>
                    <span>{{ formatCost(handTagTotal) }}</span>
                  </div>
                  <div class="row justify-between text-body2">
                    <span class="text-grey-8">Stickers (total):</span>
                    <span>{{ formatCost(stickerTotal) }}</span>
                  </div>
                  <q-separator class="q-my-xs" />
                  <div class="row justify-between text-body2 text-weight-bold">
                    <span class="text-grey-9">Ops Total:</span>
                    <span class="text-primary">{{ formatCost(opsCost) }}</span>
                  </div>
                </div>
              </div>

              <!-- Per Unit Share Section -->
              <div class="col-12 col-md-3">
                <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">PER-UNIT SHARE ({{ costCurrency?.code || '—' }})</div>
                <div class="q-gutter-y-sm">
                  <div class="q-pa-sm bg-blue-1 rounded-borders" style="border: 1px solid rgba(33, 150, 243, 0.12);">
                    <div class="row justify-between items-baseline">
                      <span class="text-caption text-blue-9">Cargo Share:</span>
                      <span class="text-subtitle2 text-weight-bold text-blue-10">{{ formatCost(cargoSharePerUnit) }}</span>
                    </div>
                    <div class="text-caption text-grey-6" style="font-size: 10px;">
                      {{ usesWeightBasedCargo ? 'By weight (avg shown)' : 'Cargo Total ÷ U' }}
                    </div>
                  </div>
                  <div class="q-pa-sm bg-orange-1 rounded-borders" style="border: 1px solid rgba(255, 152, 0, 0.12);">
                    <div class="row justify-between items-baseline">
                      <span class="text-caption text-orange-9">Ops Share:</span>
                      <span class="text-subtitle2 text-weight-bold text-orange-10">{{ formatCost(opsSharePerUnit) }}</span>
                    </div>
                    <div class="text-caption text-grey-6" style="font-size: 10px;">
                      Ops Total ÷ U
                    </div>
                  </div>
                </div>
              </div>

              <!-- Each Item Formula Section -->
              <div class="col-12 col-md-3">
                <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">PER-ITEM LANDED COST</div>
                <div class="q-pa-sm bg-teal-1 rounded-borders h-100 column justify-center" style="border: 1px solid rgba(0, 150, 136, 0.12); min-height: 120px;">
                  <div class="text-caption text-teal-9 text-weight-bold q-mb-xs">Landed Cost Formula</div>
                  <div class="text-caption text-grey-8" style="line-height: 1.4; font-size: 11px;">
                    <code>Product Cost</code> + <br />
                    <code>Cargo Share</code> + <br />
                    <code>Ops Share</code> + <br />
                    <code>Add'l Charges</code>
                  </div>
                  <div class="text-caption text-grey-6 q-mt-xs" style="font-size: 10px;">
                    Computed per item from origin, weight-based cargo share, ops share, and add'l charges.
                  </div>
                </div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Measurements dialog -->
    <thrift-stock-measurements-dialog
      v-if="selectedStock"
      :key="selectedStock.id"
      v-model="measurementsDialogOpen"
      :stock="selectedStock"
      @ok="onMeasurementsUpdated"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';
import { useThriftSettingsStore } from 'src/modules/thrift/settings/stores/thriftSettingsStore';
import { thriftShipmentRepository } from '../repositories/thriftShipmentRepository';
import { thriftStockRepository } from '../../stock/repositories/thriftStockRepository';
import type { ThriftShipment } from '../types';
import type { ThriftStock, ThriftStockMeasurements } from '../../stock/types';
import type { ThriftCurrency } from '../../currency/types';
import { useThriftShipmentCosting } from '../../shared/composables/useThriftShipmentCosting';
import ThriftStockMeasurementsDialog from '../../stock/components/ThriftStockMeasurementsDialog.vue';
import ThriftLandedCostBreakdownDialog from '../../stock/components/ThriftLandedCostBreakdownDialog.vue';
import ThriftShipmentItemsTable from '../components/ThriftShipmentItemsTable.vue';
import { computeThriftUnitCosts } from '../../shared/utils/computeThriftUnitCosts';
import { buildAutoListedPricingPatch } from '../../shared/utils/buildAutoListedPricingPatch';
import { useQuasar } from 'quasar';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const currencyStore = useThriftCurrencyStore();
const settingsStore = useThriftSettingsStore();

const shipmentId = Number(route.params.id);
const shipment = ref<ThriftShipment | null>(null);
const stocks = ref<ThriftStock[]>([]);
const loading = ref(false);
const searchText = ref('');
const isLeftColumnVisible = ref(true);

const measurementsDialogOpen = ref(false);
const selectedStock = ref<ThriftStock | null>(null);

const costForm = ref({
  total_cargo_weight_kg: null as number | null,
  cargo_rate: null as number | null,
  cargo_conversion_rate: null as number | null,
  labor_total_cost: null as number | null,
  transportation_total_cost: null as number | null,
  washing_total_cost: null as number | null,
  default_markup_rate: null as number | null,
  product_conversion_rate: null as number | null,
});

const markupPercentage = computed({
  get: () => costForm.value.default_markup_rate != null ? Math.round(costForm.value.default_markup_rate * 100) : null,
  set: (val: number | null) => {
    costForm.value.default_markup_rate = val != null ? val / 100 : null;
  },
});

const sampleSuggestedPrice = computed(() => {
  const origin = settingsStore.settings?.default_origin_unit_price ?? 0;
  const prodConv = costForm.value.product_conversion_rate ?? 1.0;
  const productCost = origin * prodConv;
  const cargoShare = cargoSharePerUnit.value;
  const opsShare = opsSharePerUnit.value;
  const landed = productCost + cargoShare + opsShare;
  const markup = costForm.value.default_markup_rate ?? 0;
  return landed * (1 + markup);
});

// Currencies mapping helpers
const purchaseCurrency = computed<ThriftCurrency | undefined>(() => {
  return shipment.value ? currencyStore.currencyById(shipment.value.purchase_currency_id) : undefined;
});

const costCurrency = computed<ThriftCurrency | undefined>(() => {
  return shipment.value ? currencyStore.currencyById(shipment.value.cost_currency_id) : undefined;
});

// Costing engine integration
const {
  U,
  cargoCost,
  opsCost,
  cargoSharePerUnit,
  opsSharePerUnit,
  handTagTotal,
  stickerTotal,
  usesWeightBasedCargo,
  costingBreakdowns,
} = useThriftShipmentCosting(
  shipment,
  stocks,
  computed(() => settingsStore.settings),
);

// Client-side stock filtering
const filteredStocks = computed(() => {
  const query = searchText.value.toLowerCase().trim();
  if (!query) return stocks.value;
  return stocks.value.filter((s) => {
    return (
      (s.name && s.name.toLowerCase().includes(query)) ||
      (s.brand_name && s.brand_name.toLowerCase().includes(query)) ||
      (s.barcode && s.barcode.toLowerCase().includes(query))
    );
  });
});

// Columns Selector logic
const columnsList = [
  { name: 'barcode', label: 'Barcode' },
  { name: 'name', label: 'Name' },
  { name: 'brand_name', label: 'Brand' },
  { name: 'category_name', label: 'Category' },
  { name: 'type_name', label: 'Type' },
  { name: 'measurements', label: 'Measurements' },
  { name: 'origin_unit_price', label: 'Origin Price' },
  { name: 'extra_origin_unit_price', label: 'Extra Origin' },
  { name: 'product_unit_cost', label: 'Product Cost' },
  { name: 'cargo_share_per_unit', label: 'Cargo/Unit' },
  { name: 'ops_share_per_unit', label: 'Ops/Unit' },
  { name: 'additional_charges_cost', label: 'Add\'l Charges' },
  { name: 'landed_unit_cost', label: 'Landed Cost' },
  { name: 'item_markup_pct', label: 'Item Markup %' },
  { name: 'effective_markup_pct', label: 'Effective Markup %' },
  { name: 'suggested_sell_unit_price', label: 'Suggested Sell' },
  { name: 'listed_unit_price', label: 'Listed Sell' },
];

const visibleColumns = ref<Set<string>>(new Set([
  'barcode',
  'name',
  'measurements',
  'origin_unit_price',
  'landed_unit_cost',
  'item_markup_pct',
  'effective_markup_pct',
  'listed_unit_price',
]));

// Persist visible columns in localStorage
const storageKey = 'thrift-shipment-detail-columns';

function loadPersistedColumns() {
  try {
    const saved = localStorage.getItem(storageKey);
    if (saved) {
      const arr = JSON.parse(saved);
      if (Array.isArray(arr)) {
        visibleColumns.value = new Set(arr);
      }
    }
  } catch (err) {
    console.error('Failed to load persisted columns:', err);
  }
}

function toggleColumn(colName: string) {
  if (visibleColumns.value.has(colName)) {
    visibleColumns.value.delete(colName);
  } else {
    visibleColumns.value.add(colName);
  }
  try {
    localStorage.setItem(storageKey, JSON.stringify([...visibleColumns.value]));
  } catch (err) {
    console.error('Failed to persist columns:', err);
  }
}

function goBack() {
  void router.push(`/${authStore.tenantSlug || 'tenant'}/app/thrift/shipments`);
}

function currencyCode(id: unknown): string {
  const currency = currencyStore.currencyById(id as number);
  return currency?.code ?? '—';
}

function formatCost(amount: number): string {
  return formatThriftAmount(amount, costCurrency.value);
}

function formatPurchase(amount: number): string {
  return formatThriftAmount(amount, purchaseCurrency.value);
}

function formatThriftAmount(amount: number, currency: ThriftCurrency | undefined): string {
  if (currency?.symbol === '৳' || currency?.code === 'BDT') {
    return `${currency.symbol || '৳'}${Math.round(amount)}`;
  }
  return `${currency?.symbol || '$'}${amount.toFixed(2)}`;
}

async function loadData() {
  if (!authStore.tenantId || !shipmentId) return;
  loading.value = true;
  try {
    const [shipmentRow, stockRows] = await Promise.all([
      thriftShipmentRepository.fetchShipmentById(authStore.tenantId, shipmentId),
      thriftStockRepository.fetchStocksByShipment(authStore.tenantId, shipmentId),
    ]);

    if (!shipmentRow) {
      $q.notify({ type: 'negative', message: 'Shipment not found' });
      goBack();
      return;
    }

    shipment.value = shipmentRow;
    stocks.value = stockRows;

    costForm.value = {
      total_cargo_weight_kg: shipmentRow.total_cargo_weight_kg ?? null,
      cargo_rate: shipmentRow.cargo_rate ?? null,
      cargo_conversion_rate: shipmentRow.cargo_conversion_rate ?? null,
      labor_total_cost: shipmentRow.labor_total_cost ?? null,
      transportation_total_cost: shipmentRow.transportation_total_cost ?? null,
      washing_total_cost: shipmentRow.washing_total_cost ?? null,
      default_markup_rate: shipmentRow.default_markup_rate ?? null,
      product_conversion_rate: shipmentRow.product_conversion_rate ?? null,
    };
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Failed to load details' });
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  if (!authStore.tenantId) return;
  loadPersistedColumns();
  await Promise.all([
    currencyStore.loadCurrencies(),
    settingsStore.loadSettings(authStore.tenantId),
    loadData(),
  ]);
});

async function saveShipmentCosts() {
  if (!shipment.value) return;
  try {
    const payload = {
      total_cargo_weight_kg: costForm.value.total_cargo_weight_kg,
      cargo_rate: costForm.value.cargo_rate,
      cargo_conversion_rate: costForm.value.cargo_conversion_rate,
      labor_total_cost: costForm.value.labor_total_cost,
      transportation_total_cost: costForm.value.transportation_total_cost,
      washing_total_cost: costForm.value.washing_total_cost,
      default_markup_rate: costForm.value.default_markup_rate,
      product_conversion_rate: costForm.value.product_conversion_rate,
    };
    const updated = await thriftShipmentRepository.updateShipment(shipment.value.id, payload);
    shipment.value = updated;
    
    // Wait for the cost calculations to propagate
    await nextTick();
    
    // Batch update all non-locked stock prices
    const autoStocks = stocks.value.filter(s => !s.pricing?.is_listed_price_manual);
    if (autoStocks.length > 0) {
      await Promise.all(
        autoStocks.map(async (stock) => {
          const breakdown = costingBreakdowns.value[stock.id];
          if (!breakdown) return;
          const pricing = buildAutoListedPricingPatch(stock, breakdown);
          const updatedStock = await thriftStockRepository.updateStock(stock.id, {}, pricing);
          if (updatedStock.pricing) {
            stock.pricing = updatedStock.pricing;
          }
        })
      );
      stocks.value = [...stocks.value];
    }
    
    $q.notify({ type: 'positive', message: 'Shipment costs and auto-prices saved successfully' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Failed to update shipment costs' });
  }
}

async function saveStockValue(row: ThriftStock, field: string, value: number) {
  try {
    const pricing = {
      cost_of_goods_sold: Number(row.pricing?.cost_of_goods_sold) || 0,
      target_price: Number(row.pricing?.target_price) || 0,
      listed_unit_price: Number(row.pricing?.listed_unit_price) || 0,
      is_listed_price_manual: !!row.pricing?.is_listed_price_manual,
      extra_expense_cost: Number(row.pricing?.extra_expense_cost) || 0,
    };

    const updated = await thriftStockRepository.updateStock(row.id, { [field]: value }, pricing);
    Object.assign(row, updated);
    $q.notify({ type: 'positive', message: 'Item updated' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  }
}

async function saveStockPricingValue(row: ThriftStock, field: string, value: unknown) {
  try {
    const pricingPatch: Record<string, unknown> = { [field]: value };
    if (field === 'listed_unit_price') {
      pricingPatch.is_listed_price_manual = true;
      pricingPatch.markup_rate_override = null;
    }
    if (field === 'markup_rate_override') {
      pricingPatch.is_listed_price_manual = false;
    }
    if (field === 'is_listed_price_manual' && value === false) {
      pricingPatch.is_listed_price_manual = false;
    }

    const isManual = pricingPatch.is_listed_price_manual !== undefined
      ? !!pricingPatch.is_listed_price_manual
      : !!row.pricing?.is_listed_price_manual;

    if (!isManual && shipment.value) {
      const currentPricing = {
        cost_of_goods_sold: Number(row.pricing?.cost_of_goods_sold) || 0,
        target_price: Number(row.pricing?.target_price) || 0,
        listed_unit_price: Number(row.pricing?.listed_unit_price) || 0,
        is_listed_price_manual: false,
        markup_rate_override: row.pricing?.markup_rate_override ?? null,
        extra_expense_cost: Number(row.pricing?.extra_expense_cost) || 0,
        ...pricingPatch,
      };
      
      const settings = settingsStore.opsCostSettingsForEngine;
      const mergedStocks = stocks.value.map(item => item.id === row.id ? { ...item, pricing: currentPricing } : item);
      const U = mergedStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
      const breakdown = computeThriftUnitCosts(row, shipment.value, settings, Math.max(U, 1), currentPricing, mergedStocks);
      
      pricingPatch.listed_unit_price = breakdown.suggested_sell_unit_price;
    }

    const pricing = {
      cost_of_goods_sold: Number(row.pricing?.cost_of_goods_sold) || 0,
      target_price: Number(row.pricing?.target_price) || 0,
      listed_unit_price: Number(row.pricing?.listed_unit_price) || 0,
      is_listed_price_manual: !!row.pricing?.is_listed_price_manual,
      markup_rate_override: row.pricing?.markup_rate_override ?? null,
      extra_expense_cost: Number(row.pricing?.extra_expense_cost) || 0,
      ...pricingPatch,
    };

    const updated = await thriftStockRepository.updateStock(row.id, {}, pricing);
    if (updated.pricing) {
      row.pricing = updated.pricing;
      const idx = stocks.value.findIndex(s => s.id === row.id);
      if (idx !== -1) {
        stocks.value[idx]!.pricing = updated.pricing;
        stocks.value = [...stocks.value];
      }
    }
    $q.notify({ type: 'positive', message: 'Price updated' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  }
}

async function resetListedPriceToSuggested(row: ThriftStock) {
  try {
    await saveStockPricingValue(row, 'is_listed_price_manual', false);
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Reset failed' });
  }
}

async function resetItemMarkupToShipment(row: ThriftStock) {
  try {
    await saveStockPricingValue(row, 'markup_rate_override', null);
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Reset failed' });
  }
}

function openMeasurementsDialog(row: ThriftStock) {
  selectedStock.value = row;
  measurementsDialogOpen.value = true;
}

function openLandedBreakdownDialog(row: ThriftStock) {
  const breakdown = costingBreakdowns.value[row.id];
  if (!breakdown) return;
  $q.dialog({
    component: ThriftLandedCostBreakdownDialog,
    componentProps: {
      stock: row,
      breakdown,
      shipmentName: shipment.value?.name || '',
      formatCost: (amount: number) => formatCost(amount),
    },
  });
}

function onMeasurementsUpdated(payload: { size: string; measurements: ThriftStockMeasurements | null }) {
  if (selectedStock.value) {
    selectedStock.value.size = payload.size;
    selectedStock.value.measurements = payload.measurements;
  }
}
watch(
  () => route.params.id,
  (newVal) => {
    if (newVal && Number(newVal) !== shipmentId) {
      window.location.reload();
    }
  }
);
</script>

<style scoped>
.thrift-shipment-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.bg-theme-gradient {
  background: linear-gradient(135deg, #1f4068, #162447);
}

.hero-surface {
  border-radius: 16px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.border-bottom-translucent {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.opacity-80 {
  opacity: 0.8;
}

.opacity-60 {
  opacity: 0.6;
}

.h-100 {
  height: 100%;
}

.transition-sidebar {
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.transition-table {
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}
</style>
