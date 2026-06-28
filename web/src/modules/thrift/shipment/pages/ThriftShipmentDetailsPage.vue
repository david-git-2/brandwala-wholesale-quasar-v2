<template>
  <q-page class="q-pa-md thrift-shipment-details-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-auto">
            <q-btn flat round icon="arrow_back" color="primary" @click="goBack" />
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

    <div class="row q-col-gutter-md q-mb-md">
      <!-- Cost Inputs Editor -->
      <div class="col-12 col-md-8">
        <q-card flat class="floating-surface shadow-1 h-100">
          <q-card-section>
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-md">Shipment Landed Cost Inputs</div>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-4">
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
              </div>
              <div class="col-12 col-sm-4">
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
              </div>
              <div class="col-12 col-sm-4">
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
              </div>
            </div>

            <div class="row q-col-gutter-md q-mt-xs">
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="costForm.labor_total_cost"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Labor Total"
                  class="soft-input"
                  @change="saveShipmentCosts"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="costForm.transportation_total_cost"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Transport Total"
                  class="soft-input"
                  @change="saveShipmentCosts"
                />
              </div>
              <div class="col-12 col-sm-3">
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
              </div>
              <div class="col-12 col-sm-3">
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
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Cost Summary Strip -->
      <div class="col-12 col-md-4">
        <q-card flat class="floating-surface shadow-1 h-100 bg-theme-gradient text-white">
          <q-card-section class="column justify-between h-100">
            <div class="text-subtitle2 text-weight-bold opacity-80">Shipment Totals Summary</div>
            <div class="q-py-md">
              <div class="row items-baseline justify-between q-py-xs border-bottom-translucent">
                <span class="text-caption opacity-80">Total Items (U):</span>
                <span class="text-h6 text-weight-bold">{{ U }}</span>
              </div>
              <div class="row items-baseline justify-between q-py-xs border-bottom-translucent">
                <span class="text-caption opacity-80">Cargo Total:</span>
                <span class="text-h6 text-weight-bold">{{ formatCost(cargoCost) }}</span>
              </div>
              <div class="row items-baseline justify-between q-py-xs">
                <span class="text-caption opacity-80">Ops Total:</span>
                <span class="text-h6 text-weight-bold">{{ formatCost(opsCost) }}</span>
              </div>
            </div>
            <div class="text-caption opacity-60">
              * Ops cost includes default settings for Hand-tag: {{ formatCost(settingsStore.handTagUnitCost) }} and Sticker: {{ formatCost(settingsStore.stickerUnitCost) }}.
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Items Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="stocks"
        :columns="columns"
        row-key="id"
        v-model:pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50, 100]"
        :loading="loading"
        class="thrift-table"
      >
        <!-- Image cell -->
        <template #body-cell-image_url="props">
          <q-td :props="props">
            <q-avatar rounded size="36px" class="bg-grey-2">
              <img :src="props.row.image_url" v-if="props.row.image_url" />
              <q-icon name="image" color="grey" v-else />
            </q-avatar>
          </q-td>
        </template>

        <!-- Measurements cell -->
        <template #body-cell-measurements="props">
          <q-td :props="props">
            <div class="row items-center justify-between no-wrap">
              <div class="text-caption text-grey-8 ellipsis" style="max-width: 140px;">
                {{ getFormattedMeasurements(props.row) }}
              </div>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="straighten"
                color="secondary"
                @click="openMeasurementsDialog(props.row)"
              >
                <q-tooltip>Edit Measurements</q-tooltip>
              </q-btn>
            </div>
          </q-td>
        </template>

        <!-- Origin purchase / unit price cell -->
        <template #body-cell-origin_unit_price="props">
          <q-td :props="props" class="cursor-pointer text-right">
            {{ formatPurchase(props.row.origin_unit_price || 0) }}
            <q-popup-edit
              :model-value="props.row.origin_unit_price || 0"
              v-slot="scope"
              buttons
              @save="val => saveStockValue(props.row, 'origin_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="0.01" dense autofocus />
            </q-popup-edit>
          </q-td>
        </template>

        <!-- Extra origin cell -->
        <template #body-cell-extra_origin_unit_price="props">
          <q-td :props="props" class="cursor-pointer text-right">
            {{ formatPurchase(props.row.extra_origin_unit_price || 0) }}
            <q-popup-edit
              :model-value="props.row.extra_origin_unit_price || 0"
              v-slot="scope"
              buttons
              @save="val => saveStockValue(props.row, 'extra_origin_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="0.01" dense autofocus />
            </q-popup-edit>
          </q-td>
        </template>

        <!-- Product cost cell -->
        <template #body-cell-product_unit_cost="props">
          <q-td :props="props" class="text-right">
            {{ formatCost(costingBreakdowns[props.row.id]?.product_unit_cost || 0) }}
          </q-td>
        </template>

        <!-- Cargo share per unit cell -->
        <template #body-cell-cargo_share_per_unit="props">
          <q-td :props="props" class="text-right">
            {{ formatCost(costingBreakdowns[props.row.id]?.cargo_share_per_unit || 0) }}
          </q-td>
        </template>

        <!-- Ops share per unit cell -->
        <template #body-cell-ops_share_per_unit="props">
          <q-td :props="props" class="text-right">
            {{ formatCost(costingBreakdowns[props.row.id]?.ops_share_per_unit || 0) }}
          </q-td>
        </template>

        <!-- Additional charges cell -->
        <template #body-cell-additional_charges_cost="props">
          <q-td :props="props" class="cursor-pointer text-right">
            {{ formatCost(props.row.additional_charges_cost || 0) }}
            <q-popup-edit
              :model-value="props.row.additional_charges_cost || 0"
              v-slot="scope"
              buttons
              @save="val => saveStockValue(props.row, 'additional_charges_cost', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="0.01" dense autofocus />
            </q-popup-edit>
          </q-td>
        </template>

        <!-- Landed unit cost cell -->
        <template #body-cell-landed_unit_cost="props">
          <q-td :props="props" class="text-right text-weight-bold text-teal">
            {{ formatCost(costingBreakdowns[props.row.id]?.landed_unit_cost || 0) }}
          </q-td>
        </template>

        <!-- Suggested sell price cell -->
        <template #body-cell-suggested_sell_unit_price="props">
          <q-td :props="props" class="text-right">
            {{ formatCost(costingBreakdowns[props.row.id]?.suggested_sell_unit_price || 0) }}
          </q-td>
        </template>

        <!-- Listed sell price cell -->
        <template #body-cell-listed_unit_price="props">
          <q-td :props="props" class="cursor-pointer text-right text-weight-bold">
            {{ formatCost(props.row.pricing?.listed_unit_price || 0) }}
            <q-popup-edit
              :model-value="props.row.pricing?.listed_unit_price || 0"
              v-slot="scope"
              buttons
              @save="val => saveStockPricingValue(props.row, 'listed_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="1" dense autofocus />
            </q-popup-edit>
          </q-td>
        </template>

        <!-- Manual listed cost flag toggle cell -->
        <template #body-cell-is_listed_price_manual="props">
          <q-td :props="props" class="text-center">
            <q-toggle
              :model-value="!!props.row.pricing?.is_listed_price_manual"
              color="primary"
              dense
              @update:model-value="val => saveStockPricingValue(props.row, 'is_listed_price_manual', val)"
            />
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Measurements dialog -->
    <thrift-stock-measurements-dialog
      v-model="measurementsDialogOpen"
      :stock="selectedStock"
      v-if="selectedStock"
      @ok="onMeasurementsUpdated"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';
import { useThriftSettingsStore } from 'src/modules/thrift/settings/stores/thriftSettingsStore';
import { thriftShipmentRepository } from '../repositories/thriftShipmentRepository';
import { thriftStockRepository } from '../../stock/repositories/thriftStockRepository';
import type { ThriftShipment } from '../types';
import type { ThriftStock } from '../../stock/types';
import { useThriftShipmentCosting } from '../../shared/composables/useThriftShipmentCosting';
import { formatThriftStockMeasurements } from '../../shared/utils/formatThriftStockMeasurements';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import ThriftStockMeasurementsDialog from '../../stock/components/ThriftStockMeasurementsDialog.vue';
import { useQuasar, type QTableColumn } from 'quasar';

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

const measurementsDialogOpen = ref(false);
const selectedStock = ref<ThriftStock | null>(null);

const costForm = ref({
  total_cargo_weight_kg: null as number | null,
  cargo_rate: null as number | null,
  cargo_conversion_rate: null as number | null,
  labor_total_cost: null as number | null,
  transportation_total_cost: null as number | null,
  default_markup_rate: null as number | null,
  product_conversion_rate: null as number | null,
});

const markupPercentage = computed({
  get: () => costForm.value.default_markup_rate != null ? Math.round(costForm.value.default_markup_rate * 100) : null,
  set: (val: number | null) => {
    costForm.value.default_markup_rate = val != null ? val / 100 : null;
  },
});

// Costing engine integration
const { U, cargoCost, opsCost, costingBreakdowns } = useThriftShipmentCosting(
  shipment,
  stocks,
  computed(() => settingsStore.settings),
);

const tablePagination = ref({ page: 1, rowsPerPage: 50 });

const columns: QTableColumn[] = [
  { name: 'image_url', align: 'center', label: 'Image', field: 'image_url' },
  { name: 'barcode', align: 'left', label: 'Barcode', field: 'barcode', sortable: true },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'brand_name', align: 'left', label: 'Brand', field: 'brand_name', sortable: true },
  { name: 'category_name', align: 'left', label: 'Category', field: 'category_name', sortable: true },
  { name: 'type_name', align: 'left', label: 'Type', field: 'type_name', sortable: true },
  { name: 'measurements', align: 'left', label: 'Measurements', field: 'measurements' },
  { name: 'origin_unit_price', align: 'right', label: 'Origin Price', field: 'origin_unit_price' },
  { name: 'extra_origin_unit_price', align: 'right', label: 'Extra Origin', field: 'extra_origin_unit_price' },
  { name: 'product_unit_cost', align: 'right', label: 'Product Cost', field: 'product_unit_cost' },
  { name: 'cargo_share_per_unit', align: 'right', label: 'Cargo/Unit', field: 'cargo_share_per_unit' },
  { name: 'ops_share_per_unit', align: 'right', label: 'Ops/Unit', field: 'ops_share_per_unit' },
  { name: 'additional_charges_cost', align: 'right', label: 'Add\'l Charges', field: 'additional_charges_cost' },
  { name: 'landed_unit_cost', align: 'right', label: 'Landed Cost', field: 'landed_unit_cost', sortable: true },
  { name: 'suggested_sell_unit_price', align: 'right', label: 'Suggested Sell', field: 'suggested_sell_unit_price' },
  { name: 'listed_unit_price', align: 'right', label: 'Listed Sell', field: 'listed_unit_price' },
  { name: 'is_listed_price_manual', align: 'center', label: 'Manual', field: 'is_listed_price_manual' },
];

function goBack() {
  void router.push(`/${authStore.tenantSlug || 'tenant'}/app/thrift/shipments`);
}

function currencyCode(id: unknown): string {
  const currency = currencyStore.currencyById(id as number);
  return currency?.code ?? '—';
}

function formatCost(amount: number): string {
  if (!shipment.value) return String(amount);
  const currency = currencyStore.currencyById(shipment.value.cost_currency_id);
  return formatThriftAmount(amount, currency);
}

function formatPurchase(amount: number): string {
  if (!shipment.value) return String(amount);
  const currency = currencyStore.currencyById(shipment.value.purchase_currency_id);
  return formatThriftAmount(amount, currency);
}

function getFormattedMeasurements(row: ThriftStock): string {
  return formatThriftStockMeasurements(row);
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
      default_markup_rate: costForm.value.default_markup_rate,
      product_conversion_rate: costForm.value.product_conversion_rate,
    };
    const updated = await thriftShipmentRepository.updateShipment(shipment.value.id, payload);
    shipment.value = updated;
    $q.notify({ type: 'positive', message: 'Shipment costs updated' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Failed to update shipment costs' });
  }
}

async function saveStockValue(row: ThriftStock, field: keyof ThriftStock, value: number) {
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
    const pricingPatch = { [field]: value };
    const pricing = {
      cost_of_goods_sold: Number(row.pricing?.cost_of_goods_sold) || 0,
      target_price: Number(row.pricing?.target_price) || 0,
      listed_unit_price: Number(row.pricing?.listed_unit_price) || 0,
      is_listed_price_manual: !!row.pricing?.is_listed_price_manual,
      extra_expense_cost: Number(row.pricing?.extra_expense_cost) || 0,
      ...pricingPatch,
    };

    const updated = await thriftStockRepository.updateStock(row.id, {}, pricing);
    row.pricing = updated.pricing;
    $q.notify({ type: 'positive', message: 'Price updated' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  }
}

function openMeasurementsDialog(row: ThriftStock) {
  selectedStock.value = row;
  measurementsDialogOpen.value = true;
}

function onMeasurementsUpdated(updatedMeasurements: unknown) {
  if (selectedStock.value) {
    selectedStock.value.measurements = updatedMeasurements as any;
  }
}
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
  border-bottom: 1px solid rgba(255, 255, 255, 0.15);
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

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
</style>
