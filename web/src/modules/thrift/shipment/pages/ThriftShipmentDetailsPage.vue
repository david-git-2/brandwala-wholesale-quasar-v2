<template>
  <ThriftShipmentDetailsSkeleton v-if="loading && !shipment" />
  <q-page v-else class="q-pa-md thrift-shipment-details-page">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <ThriftShipmentDetailsHeader
        :shipment-name="shipment?.name"
        :purchase-currency-code="currencyCode(shipment?.purchase_currency_id)"
        :cost-currency-code="currencyCode(shipment?.cost_currency_id)"
        @back="goBack"
      />


      <!-- Empty State when no stocks exist in the shipment -->
      <q-banner
        v-if="!loading && stocks.length === 0"
        inline-actions
        class="bg-blue-1 text-blue-9 rounded-borders q-pa-md"
      >
        <template v-slot:avatar>
          <q-icon name="ph ph-info" color="blue-8" size="24px" />
        </template>
        <div class="text-subtitle2 text-weight-bold">No stock in this shipment yet</div>
        <div class="text-caption">
          Register items in the mobile app or catalog page to populate this shipment.
        </div>
      </q-banner>

    <div class="row q-col-gutter-md" v-else>
      <!-- Collapsible Left Sidebar (col-3) -->
      <div
        v-show="canViewLandedCost && isLeftColumnVisible"
        class="col-12 col-md-3 transition-sidebar"
      >
        <ThriftShipmentCostInputsCard
          v-model:cost-form="costForm"
          v-model:markup-percentage="markupPercentage"
          :total-units="U"
          :stock-count="stocks.length"
          :formatted-default-origin="formatPurchase(settings?.default_origin_unit_price || 0)"
          :formatted-suggested-price="formatCost(sampleSuggestedPrice)"
          :can-edit-landed-cost="canEditLandedCost"
          @save="saveShipmentCosts"
        />
      </div>

      <!-- Right Panel Table (col-9 or col-12) -->
      <div
        :class="canViewLandedCost && isLeftColumnVisible ? 'col-12 col-md-9' : 'col-12'"
        class="transition-table"
      >
        <q-card flat class="floating-surface shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div class="row items-center q-gutter-x-sm">
              <q-btn
                v-if="canViewLandedCost"
                flat
                round
                dense
                color="primary"
                :icon="
                  isLeftColumnVisible ? 'keyboard_double_arrow_left' : 'keyboard_double_arrow_right'
                "
                @click="isLeftColumnVisible = !isLeftColumnVisible"
              >
                <q-tooltip>{{
                  isLeftColumnVisible ? 'Collapse Sidebar' : 'Expand Sidebar'
                }}</q-tooltip>
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
                style="width: 250px"
                class="soft-input"
              >
                <template v-slot:append>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
              </q-input>

              <!-- Columns menu picker -->
              <q-btn-dropdown outline dense color="primary" icon="ph ph-columns" label="Columns">
                <q-list class="q-pa-xs" style="min-width: 180px">
                  <div
                    class="text-caption text-weight-bold text-grey-7 q-px-sm q-py-xs border-bottom-translucent"
                  >
                    Visible Columns
                  </div>
                  <q-item
                    v-for="col in columnsList"
                    :key="col.name"
                    clickable
                    dense
                    class="q-py-none"
                  >
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
            :can-view-landed-cost="canViewLandedCost"
            :can-edit-landed-cost="canEditLandedCost"
            :can-view-measurements="canViewMeasurements"
            :can-edit-measurements="canEditMeasurements"
            :can-edit-listed-price="canEditListedPrice"
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
    <div v-if="canViewLandedCost" class="row q-col-gutter-md q-mt-md">
      <div class="col-12">
        <ThriftShipmentCostOverviewCard
          :cost-currency-code="costCurrency?.code"
          :total-units="U"
          :cargo-cost="cargoCost"
          :cost-form="costForm"
          :hand-tag-total="handTagTotal"
          :sticker-total="stickerTotal"
          :ops-cost="opsCost"
          :cargo-share-per-unit="cargoSharePerUnit"
          :ops-share-per-unit="opsSharePerUnit"
          :uses-weight-based-cargo="usesWeightBasedCargo"
          :format-cost="formatCost"
        />
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
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
import { storeToRefs } from 'pinia';
import { useRoute, useRouter } from 'vue-router';
import ThriftShipmentDetailsSkeleton from '../components/ThriftShipmentDetailsSkeleton.vue';
import ThriftShipmentDetailsHeader from '../components/ThriftShipmentDetailsHeader.vue';
import ThriftShipmentCostInputsCard from '../components/ThriftShipmentCostInputsCard.vue';
import ThriftShipmentCostOverviewCard from '../components/ThriftShipmentCostOverviewCard.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useThriftSettingsQuery } from 'src/modules/thrift/settings/composables/useThriftSettingsQuery';
import { useThriftShipmentDetailQuery } from '../composables/useThriftShipmentQuery';
import { useUpdateShipmentMutation } from '../composables/useThriftShipmentMutations';
import { useThriftStocksByShipmentQuery } from '../../stock/composables/useThriftStocksQuery';
import { thriftStockRepository } from '../../stock/repositories/thriftStockRepository';
import type { ThriftStock, ThriftStockMeasurements } from '../../stock/types';
import type { ThriftCurrency } from '../../currency/types';
import { useThriftShipmentCosting } from '../../shared/composables/useThriftShipmentCosting';
import ThriftStockMeasurementsDialog from '../../stock/components/ThriftStockMeasurementsDialog.vue';
import ThriftLandedCostBreakdownDialog from '../../stock/components/ThriftLandedCostBreakdownDialog.vue';
import ThriftShipmentItemsTable from '../components/ThriftShipmentItemsTable.vue';
import { computeThriftUnitCosts } from '../../shared/utils/computeThriftUnitCosts';
import { buildAutoListedPricingPatch } from '../../shared/utils/buildAutoListedPricingPatch';
import { useQuasar } from 'quasar';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';


const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const { hasModuleAccess } = useModulePermissions();

const canViewLandedCost = computed(() =>
  hasModuleAccess('thrift_shipment', 'view_landed_cost'),
);
const canEditLandedCost = computed(() =>
  hasModuleAccess('thrift_shipment', 'edit_landed_cost'),
);
const canViewMeasurements = computed(() =>
  hasModuleAccess('thrift_shipment', 'view_measurements'),
);
const canEditMeasurements = computed(() =>
  hasModuleAccess('thrift_shipment', 'edit_measurements'),
);
const canEditListedPrice = computed(() =>
  hasModuleAccess('thrift_shipment', 'edit_listed_price'),
);

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);
const { data: settingsData } = useThriftSettingsQuery(tenantId);
const settings = computed(() => settingsData.value || null);

const shipmentIdRef = computed(() => Number(route.params.id) || null);
const { data: shipmentData, isLoading: shipmentLoading } = useThriftShipmentDetailQuery(
  tenantId,
  shipmentIdRef,
);
const shipment = computed(() => shipmentData.value || null);

const { data: shipmentStocksData, isLoading: stocksLoading, refetch: refetchStocks } =
  useThriftStocksByShipmentQuery(tenantId, shipmentIdRef);
const stocks = computed(() => shipmentStocksData.value || []);

const updateMutation = useUpdateShipmentMutation(tenantId);

const loading = computed(() => shipmentLoading.value || stocksLoading.value);

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

watch(
  shipment,
  (newShipment) => {
    if (newShipment) {
      costForm.value = {
        total_cargo_weight_kg: newShipment.total_cargo_weight_kg ?? null,
        cargo_rate: newShipment.cargo_rate ?? null,
        cargo_conversion_rate: newShipment.cargo_conversion_rate ?? null,
        labor_total_cost: newShipment.labor_total_cost ?? null,
        transportation_total_cost: newShipment.transportation_total_cost ?? null,
        washing_total_cost: newShipment.washing_total_cost ?? null,
        default_markup_rate: newShipment.default_markup_rate ?? null,
        product_conversion_rate: newShipment.product_conversion_rate ?? null,
      };
    }
  },
  { immediate: true },
);

const markupPercentage = computed({
  get: () =>
    costForm.value.default_markup_rate != null
      ? Math.round(costForm.value.default_markup_rate * 100)
      : null,
  set: (val: number | null) => {
    costForm.value.default_markup_rate = val != null ? val / 100 : null;
  },
});

const sampleSuggestedPrice = computed(() => {
  const origin = settings.value?.default_origin_unit_price ?? 0;
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
  return shipment.value
    ? currencies.value.find((c) => c.id === shipment.value?.purchase_currency_id)
    : undefined;
});

const costCurrency = computed<ThriftCurrency | undefined>(() => {
  return shipment.value
    ? currencies.value.find((c) => c.id === shipment.value?.cost_currency_id)
    : undefined;
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
  settings,
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
const COST_COLUMN_NAMES = new Set([
  'origin_unit_price',
  'extra_origin_unit_price',
  'product_unit_cost',
  'cargo_share_per_unit',
  'ops_share_per_unit',
  'additional_charges_cost',
  'landed_unit_cost',
  'suggested_sell_unit_price',
]);

const allColumnsList = [
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
  { name: 'additional_charges_cost', label: "Add'l Charges" },
  { name: 'landed_unit_cost', label: 'Landed Cost' },
  { name: 'item_markup_pct', label: 'Item Markup %' },
  { name: 'effective_markup_pct', label: 'Effective Markup %' },
  { name: 'suggested_sell_unit_price', label: 'Suggested Sell' },
  { name: 'listed_unit_price', label: 'Listed Sell' },
];

const columnsList = computed(() =>
  allColumnsList.filter((col) => {
    if (!canViewLandedCost.value && COST_COLUMN_NAMES.has(col.name)) return false;
    if (!canViewMeasurements.value && col.name === 'measurements') return false;
    return true;
  }),
);

const defaultVisibleColumns = [
  'barcode',
  'name',
  'measurements',
  'origin_unit_price',
  'landed_unit_cost',
  'item_markup_pct',
  'effective_markup_pct',
  'listed_unit_price',
];

const allColumnNames = allColumnsList.map((c) => c.name);

const { visibleColumns: visibleColumnsRaw } = useMembershipColumnPreference({
  preferenceKey: 'ui.thriftShipment.detailsVisibleColumns',
  allColumnNames,
  defaultVisibleColumns,
});

const visibleColumns = computed(() => {
  const set = new Set(visibleColumnsRaw.value);
  if (!canViewLandedCost.value) {
    for (const name of COST_COLUMN_NAMES) {
      set.delete(name);
    }
  }
  if (!canViewMeasurements.value) {
    set.delete('measurements');
  }
  return set;
});

function toggleColumn(colName: string) {
  const idx = visibleColumnsRaw.value.indexOf(colName);
  if (idx !== -1) {
    visibleColumnsRaw.value.splice(idx, 1);
  } else {
    visibleColumnsRaw.value.push(colName);
  }
}

function goBack() {
  void router.push(`/${authStore.tenantSlug || 'tenant'}/app/thrift/shipments`);
}

function currencyCode(id: unknown): string {
  const currency = currencies.value.find((c) => c.id === Number(id));
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
  return `${currency?.symbol || ''}${amount.toFixed(2)}`;
}


async function saveShipmentCosts() {
  if (!shipment.value || !canEditLandedCost.value) return;
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
    await updateMutation.mutateAsync({ id: shipment.value.id, input: payload });

    // Wait for the cost calculations to propagate
    await nextTick();

    // Batch update all non-locked stock prices (requires edit_listed_price)
    if (canEditListedPrice.value) {
      const autoStocks = stocks.value.filter((s) => !s.pricing?.is_listed_price_manual);
      if (autoStocks.length > 0) {
        await Promise.all(
          autoStocks.map(async (stock) => {
            const breakdown = costingBreakdowns.value[stock.id];
            if (!breakdown) return;
            const pricing = buildAutoListedPricingPatch(stock, breakdown);
            await thriftStockRepository.updateStock(stock.id, {}, pricing);
          }),
        );
        await refetchStocks();
      }
    }

    $q.notify({
      type: 'positive',
      message: canEditListedPrice.value
        ? 'Shipment costs and auto-prices saved successfully'
        : 'Shipment costs saved successfully',
    });
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Failed to update shipment costs',
    });
  }
}

async function saveStockValue(row: ThriftStock, field: string, value: number) {
  if (!canEditLandedCost.value) return;
  try {
    const pricing = {
      cost_of_goods_sold: Number(row.pricing?.cost_of_goods_sold) || 0,
      target_price: Number(row.pricing?.target_price) || 0,
      listed_unit_price: Number(row.pricing?.listed_unit_price) || 0,
      is_listed_price_manual: !!row.pricing?.is_listed_price_manual,
      extra_expense_cost: Number(row.pricing?.extra_expense_cost) || 0,
    };

    await thriftStockRepository.updateStock(row.id, { [field]: value }, pricing);
    await refetchStocks();
    $q.notify({ type: 'positive', message: 'Item updated' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  }
}

async function saveStockPricingValue(row: ThriftStock, field: string, value: unknown) {
  const isListedPriceField =
    field === 'listed_unit_price' || field === 'is_listed_price_manual';
  const isMarkupField = field === 'markup_rate_override';
  if (isListedPriceField && !canEditListedPrice.value) return;
  if (isMarkupField && !canEditLandedCost.value) return;
  if (!isListedPriceField && !isMarkupField) return;
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

    const isManual =
      pricingPatch.is_listed_price_manual !== undefined
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

      const mergedStocks = stocks.value.map((item) =>
        item.id === row.id ? { ...item, pricing: currentPricing } : item,
      );
      const U = mergedStocks.reduce((acc, s) => acc + (s.quantity || 0), 0);
      const breakdown = computeThriftUnitCosts(
        row,
        shipment.value,
        settings.value || {},
        Math.max(U, 1),
        currentPricing,
        mergedStocks,
      );

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

    await thriftStockRepository.updateStock(row.id, {}, pricing);
    await refetchStocks();
    $q.notify({ type: 'positive', message: 'Price updated' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  }
}

async function resetListedPriceToSuggested(row: ThriftStock) {
  if (!canEditListedPrice.value) return;
  try {
    await saveStockPricingValue(row, 'is_listed_price_manual', false);
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Reset failed' });
  }
}

async function resetItemMarkupToShipment(row: ThriftStock) {
  if (!canEditLandedCost.value) return;
  try {
    await saveStockPricingValue(row, 'markup_rate_override', null);
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Reset failed' });
  }
}

function openMeasurementsDialog(row: ThriftStock) {
  if (!canEditMeasurements.value) return;
  selectedStock.value = row;
  measurementsDialogOpen.value = true;
}

function openLandedBreakdownDialog(row: ThriftStock) {
  if (!canViewLandedCost.value) return;
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

function onMeasurementsUpdated(payload: {
  size: string;
  measurements: ThriftStockMeasurements | null;
}) {
  if (selectedStock.value) {
    selectedStock.value.size = payload.size;
    selectedStock.value.measurements = payload.measurements;
  }
}
watch(
  shipmentIdRef,
  (newVal, oldVal) => {
    if (newVal && oldVal && newVal !== oldVal) {
      window.location.reload();
    }
  },
);
</script>

<style scoped>
.thrift-shipment-details-page {
  background: transparent;
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
