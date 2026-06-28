<template>
  <q-page class="q-pa-md thrift-shipment-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Shipments</div>
            <div class="text-caption text-grey-8">Manage cargo weights, ops costs, markup rates and default currencies</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Add Shipment"
              @click="openDialog()"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="shipmentRows"
        :columns="columns"
        row-key="id"
        v-model:pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50]"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-sl="props">
          <q-td :props="props">
            {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
          </q-td>
        </template>
        <template #body-cell-name="props">
          <q-td :props="props">
            <router-link
              :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/shipments/${props.row.id}`"
              class="text-primary text-weight-bold"
              style="text-decoration: none;"
            >
              {{ props.row.name }}
            </router-link>
          </q-td>
        </template>
        <template #body-cell-unit_count="props">
          <q-td :props="props" class="text-right">{{ props.row.unit_count }}</q-td>
        </template>
        <template #body-cell-purchase_currency="props">
          <q-td :props="props">{{ currencyCode(props.row.purchase_currency_id) }}</q-td>
        </template>
        <template #body-cell-cost_currency="props">
          <q-td :props="props">{{ currencyCode(props.row.cost_currency_id) }}</q-td>
        </template>
        <template #body-cell-cargo_cost="props">
          <q-td :props="props" class="text-right">
            {{ formatCost(props.row.cargo_cost, props.row.cost_currency_id) }}
          </q-td>
        </template>
        <template #body-cell-ops_cost="props">
          <q-td :props="props" class="text-right">
            {{ formatCost(props.row.ops_cost, props.row.cost_currency_id) }}
          </q-td>
        </template>
        <template #body-cell-default_markup_rate="props">
          <q-td :props="props" class="text-right">
            {{ props.row.default_markup_rate != null ? `${(props.row.default_markup_rate * 100).toFixed(0)}%` : '—' }}
          </q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right q-gutter-x-xs">
            <q-btn
              flat
              round
              dense
              icon="download"
              color="secondary"
              size="sm"
              :loading="downloadingShipmentId === props.row.id"
              :disable="downloadingShipmentId != null && downloadingShipmentId !== props.row.id"
              @click.stop="downloadShipmentImages(props.row)"
            >
              <q-tooltip>Download images from Cloudinary</q-tooltip>
            </q-btn>
            <q-btn flat round dense icon="o_edit" color="warning" size="sm" @click.stop="openDialog(props.row)">
              <q-tooltip>Edit</q-tooltip>
            </q-btn>
            <q-btn flat round dense icon="delete" color="negative" size="sm" @click.stop="confirmDelete(props.row)">
              <q-tooltip>Delete</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Create / Edit Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 500px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Shipment' : 'New Shipment' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-md scroll" style="max-height: 65vh;">
          <q-input v-model="form.name" outlined dense label="Shipment Name *" class="soft-input" :rules="[val => !!val || 'Required']" />
          
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.purchase_currency_id"
                outlined
                dense
                label="Purchase currency *"
                :options="currencyStore.currencies"
                option-value="id"
                :option-label="currencyOptionLabel"
                emit-value
                map-options
                class="soft-input"
                :rules="[val => !!val || 'Required']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.cost_currency_id"
                outlined
                dense
                label="Cost currency *"
                :options="currencyStore.currencies"
                option-value="id"
                :option-label="currencyOptionLabel"
                emit-value
                map-options
                class="soft-input"
                :rules="[val => !!val || 'Required']"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input v-model.number="form.product_conversion_rate" type="number" step="0.0001" outlined dense label="Product Conversion Rate" class="soft-input" />
            </div>
            <div class="col-12 col-sm-6">
              <q-input v-model.number="form.cargo_conversion_rate" type="number" step="0.0001" outlined dense label="Cargo Conversion Rate" class="soft-input" />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input v-model.number="form.cargo_rate" type="number" step="0.01" outlined dense label="Cargo Rate" class="soft-input" />
            </div>
            <div class="col-12 col-sm-6">
              <q-input v-model.number="form.total_cargo_weight_kg" type="number" step="0.1" outlined dense label="Total Cargo Weight (kg)" class="soft-input" />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input v-model.number="form.labor_total_cost" type="number" step="0.01" outlined dense label="Labor Total Cost" class="soft-input" />
            </div>
            <div class="col-12 col-sm-6">
              <q-input v-model.number="form.transportation_total_cost" type="number" step="0.01" outlined dense label="Transportation Total Cost" class="soft-input" />
            </div>
          </div>

          <q-input v-model.number="markupPercentage" type="number" step="1" min="0" outlined dense label="Default Markup (%)" class="soft-input" suffix="%" />
        </q-card-section>
        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Shipment" @click="save" />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Shipment</span>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete shipment <strong>{{ selectedRow?.name }}</strong>? This action cannot be undone.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="negative" label="Delete" @click="deleteItem" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';
import { useTenantPreferenceStore } from 'src/modules/tenant/stores/tenantPreferenceStore';
import { useThriftSettingsStore } from 'src/modules/thrift/settings/stores/thriftSettingsStore';
import { resolveActiveCurrencyId } from 'src/modules/tenant/utils/tenantPreferenceUtils';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useQuasar, type QTableColumn } from 'quasar';
import { thriftShipmentRepository } from '../repositories/thriftShipmentRepository';
import type { ThriftShipment, ThriftShipmentWithStats } from '../types';
import {
  computeShipmentCargoCost,
  computeShipmentOpsCost,
} from 'src/modules/thrift/shared/utils/computeThriftUnitCosts';
import {
  downloadShipmentImagesToDevice,
  ShipmentDownloadCancelledError,
} from 'src/utils/shipmentImageDownloadClient';

const $q = useQuasar();
const authStore = useAuthStore();
const currencyStore = useThriftCurrencyStore();
const preferenceStore = useTenantPreferenceStore();
const settingsStore = useThriftSettingsStore();

const shipments = ref<ThriftShipment[]>([]);
const unitCounts = ref<Map<number, number>>(new Map());
const loading = ref(false);
const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<ThriftShipment | null>(null);
const downloadingShipmentId = ref<number | null>(null);

const form = ref({
  name: '',
  cargo_conversion_rate: null as number | null,
  cargo_rate: null as number | null,
  product_conversion_rate: null as number | null,
  total_cargo_weight_kg: null as number | null,
  labor_total_cost: null as number | null,
  transportation_total_cost: null as number | null,
  default_markup_rate: null as number | null,
  purchase_currency_id: null as number | null,
  cost_currency_id: null as number | null,
});

const markupPercentage = computed({
  get: () => form.value.default_markup_rate != null ? Math.round(form.value.default_markup_rate * 100) : null,
  set: (val: number | null) => {
    form.value.default_markup_rate = val != null ? val / 100 : null;
  },
});

const shipmentRows = computed<ThriftShipmentWithStats[]>(() => {
  return shipments.value.map((s) => {
    const unit_count = unitCounts.value.get(s.id) || 0;
    const cargo_cost = computeShipmentCargoCost(s);
    const ops_cost = computeShipmentOpsCost(s, settingsStore.settings || {}, Math.max(unit_count, 1));
    return {
      ...s,
      unit_count,
      cargo_cost,
      ops_cost,
    };
  });
});

const tablePagination = ref({ page: 1, rowsPerPage: 20 });

const columns: QTableColumn[] = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center', sortable: false, headerStyle: 'width: 50px' },
  { name: 'id', align: 'left', label: 'ID', field: 'id', sortable: true, headerStyle: 'width: 70px' },
  { name: 'name', align: 'left', label: 'Shipment Name', field: 'name', sortable: true },
  { name: 'unit_count', align: 'right', label: 'Units', field: 'unit_count', sortable: true },
  { name: 'purchase_currency', align: 'left', label: 'Purchase Ccy', field: 'purchase_currency_id', sortable: true },
  { name: 'cost_currency', align: 'left', label: 'Cost Ccy', field: 'cost_currency_id', sortable: true },
  { name: 'cargo_conversion_rate', align: 'right', label: 'Cargo Conv. Rate', field: 'cargo_conversion_rate' },
  { name: 'cargo_rate', align: 'right', label: 'Cargo Rate', field: 'cargo_rate' },
  { name: 'total_cargo_weight_kg', align: 'right', label: 'Cargo (kg)', field: 'total_cargo_weight_kg' },
  { name: 'cargo_cost', align: 'right', label: 'Cargo Total', field: 'cargo_cost' },
  { name: 'labor_total_cost', align: 'right', label: 'Labor', field: 'labor_total_cost' },
  { name: 'transportation_total_cost', align: 'right', label: 'Transport', field: 'transportation_total_cost' },
  { name: 'ops_cost', align: 'right', label: 'Ops Total', field: 'ops_cost' },
  { name: 'default_markup_rate', align: 'right', label: 'Markup', field: 'default_markup_rate' },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

function currencyOptionLabel(option: ThriftCurrency) {
  return `${option.code} (${option.symbol}) — ${option.name}`;
}

function currencyCode(id: unknown): string {
  const currency = currencyStore.currencyById(id as number);
  return currency?.code ?? '—';
}

function formatCost(amount: number, ccyId: number): string {
  const currency = currencyStore.currencyById(ccyId);
  return formatThriftAmount(amount, currency);
}

async function loadShipments() {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const [list, counts] = await Promise.all([
      thriftShipmentRepository.fetchShipments(authStore.tenantId),
      thriftShipmentRepository.fetchUnitCountsByShipment(authStore.tenantId),
    ]);
    shipments.value = list;
    unitCounts.value = counts;
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Failed to load shipments' });
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  if (!authStore.tenantId) return;
  await Promise.all([
    currencyStore.loadCurrencies(),
    settingsStore.loadSettings(authStore.tenantId),
    loadShipments(),
  ]);
});

async function downloadShipmentImages(row: ThriftShipment) {
  if (!authStore.tenantId || !row.id) return;

  downloadingShipmentId.value = row.id;
  try {
    const result = await downloadShipmentImagesToDevice(authStore.tenantId, row.id);

    if (result.total === 0) {
      $q.notify({ type: 'info', message: result.message || 'No images found for this shipment' });
      return;
    }

    $q.notify({
      type: result.failed > 0 ? 'warning' : 'positive',
      message: result.message || `Downloaded ${result.downloaded} of ${result.total} image(s)`,
      timeout: result.failed > 0 ? 6000 : 3000,
    });
  } catch (err: unknown) {
    if (err instanceof ShipmentDownloadCancelledError) return;

    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Download failed',
    });
  } finally {
    downloadingShipmentId.value = null;
  }
}

function defaultPurchaseCurrencyId(): number | null {
  const activeIds = currencyStore.currencies.map((currency) => currency.id);
  return resolveActiveCurrencyId(
    preferenceStore.thriftDefaultPurchaseCurrencyId,
    activeIds,
  );
}

function defaultCostCurrencyId(): number | null {
  const activeIds = currencyStore.currencies.map((currency) => currency.id);
  return resolveActiveCurrencyId(
    preferenceStore.thriftDefaultCostCurrencyId,
    activeIds,
  );
}

function openDialog(row?: ThriftShipment) {
  if (row) {
    editingId.value = row.id;
    form.value = {
      name: row.name,
      cargo_conversion_rate: row.cargo_conversion_rate ?? null,
      cargo_rate: row.cargo_rate ?? null,
      product_conversion_rate: row.product_conversion_rate ?? null,
      total_cargo_weight_kg: row.total_cargo_weight_kg ?? null,
      labor_total_cost: row.labor_total_cost ?? null,
      transportation_total_cost: row.transportation_total_cost ?? null,
      default_markup_rate: row.default_markup_rate ?? null,
      purchase_currency_id: row.purchase_currency_id,
      cost_currency_id: row.cost_currency_id,
    };
  } else {
    editingId.value = null;
    form.value = {
      name: '',
      cargo_conversion_rate: null,
      cargo_rate: null,
      product_conversion_rate: null,
      total_cargo_weight_kg: null,
      labor_total_cost: null,
      transportation_total_cost: null,
      default_markup_rate: null,
      purchase_currency_id: defaultPurchaseCurrencyId(),
      cost_currency_id: defaultCostCurrencyId(),
    };
  }
  dialogOpen.value = true;
}

async function save() {
  if (!authStore.tenantId || !form.value.name) return;
  if (!form.value.purchase_currency_id || !form.value.cost_currency_id) return;
  $q.loading.show();
  try {
    const payload = {
      tenant_id: authStore.tenantId,
      name: form.value.name,
      cargo_conversion_rate: form.value.cargo_conversion_rate,
      cargo_rate: form.value.cargo_rate,
      product_conversion_rate: form.value.product_conversion_rate,
      total_cargo_weight_kg: form.value.total_cargo_weight_kg,
      labor_total_cost: form.value.labor_total_cost,
      transportation_total_cost: form.value.transportation_total_cost,
      default_markup_rate: form.value.default_markup_rate,
      purchase_currency_id: form.value.purchase_currency_id,
      cost_currency_id: form.value.cost_currency_id,
    };

    if (editingId.value) {
      await thriftShipmentRepository.updateShipment(editingId.value, payload);
      $q.notify({ type: 'positive', message: 'Shipment updated successfully' });
    } else {
      await thriftShipmentRepository.createShipment({
        ...payload,
        inserted_by: authStore.user?.email || '',
      });
      $q.notify({ type: 'positive', message: 'Shipment created successfully' });
    }
    dialogOpen.value = false;
    await loadShipments();
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  } finally {
    $q.loading.hide();
  }
}

function confirmDelete(row: ThriftShipment) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value) return;
  $q.loading.show();
  try {
    await thriftShipmentRepository.deleteShipment(selectedRow.value.id);
    $q.notify({ type: 'positive', message: 'Shipment deleted successfully' });
    deleteConfirmOpen.value = false;
    selectedRow.value = null;
    await loadShipments();
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Delete failed' });
  } finally {
    $q.loading.hide();
  }
}
</script>

<style scoped>
.thrift-shipment-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
</style>
