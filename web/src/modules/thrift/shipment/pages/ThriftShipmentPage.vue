<template>
  <ThriftShipmentSkeleton v-if="loading" />
  <q-page v-else class="q-pa-md thrift-shipment-page">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Thrift Shipments</h1>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <LearnMoreHelpBtn guide-id="thrift_shipment" />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Add Shipment"
            @click="openDialog()"
          />
        </div>
      </section>

      <!-- Table Card -->
      <q-card flat bordered>
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
                style="text-decoration: none"
              >
                {{ props.row.name }}
              </router-link>
            </q-td>
          </template>
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right q-gutter-x-xs">
              <q-btn
                flat
                round
                dense
                icon="ph ph-download-simple"
                color="secondary"
                size="sm"
                @click.stop="downloadShipmentImages(props.row)"
              >
                <q-tooltip>Download images from Cloudinary</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-pencil-simple"
                color="warning"
                size="sm"
                @click.stop="openDialog(props.row)"
              >
                <q-tooltip>Edit</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-trash"
                color="negative"
                size="sm"
                @click.stop="confirmDelete(props.row)"
              >
                <q-tooltip>Delete</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </div>

    <!-- Create / Edit Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 500px; max-width: 95vw" class="q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">
            {{ editingId ? 'Edit Shipment' : 'New Shipment' }}
          </div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-md scroll" style="max-height: 65vh">
          <q-input
            v-model="form.name"
            outlined
            dense
            label="Shipment Name *"
            :rules="[(val) => !!val || 'Required']"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.purchase_currency_id"
                outlined
                dense
                label="Purchase currency *"
                :options="currencies"
                option-value="id"
                :option-label="currencyOptionLabel"
                emit-value
                map-options
                :rules="[(val) => !!val || 'Required']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.cost_currency_id"
                outlined
                dense
                label="Cost currency *"
                :options="currencies"
                option-value="id"
                :option-label="currencyOptionLabel"
                emit-value
                map-options
                :rules="[(val) => !!val || 'Required']"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.product_conversion_rate"
                type="number"
                step="0.0001"
                outlined
                dense
                label="Product Conversion Rate"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.cargo_conversion_rate"
                type="number"
                step="0.0001"
                outlined
                dense
                label="Cargo Conversion Rate"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.cargo_rate"
                type="number"
                step="0.01"
                outlined
                dense
                label="Cargo Rate"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.total_cargo_weight_kg"
                type="number"
                step="0.1"
                outlined
                dense
                label="Total Cargo Weight (kg)"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.labor_total_cost"
                type="number"
                step="0.01"
                outlined
                dense
                label="Labor Total Cost"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.transportation_total_cost"
                type="number"
                step="0.01"
                outlined
                dense
                label="Transportation Total Cost"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.washing_total_cost"
                type="number"
                step="0.01"
                outlined
                dense
                label="Washing Total Cost"
              />
            </div>
          </div>

          <q-input
            v-model.number="markupPercentage"
            type="number"
            step="1"
            min="0"
            outlined
            dense
            label="Default Markup (%)"
            suffix="%"
          />
        </q-card-section>
        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Save Shipment"
            @click="save"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw">
        <q-card-section class="row items-center">
          <q-avatar icon="ph ph-warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Shipment</span>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete shipment <strong>{{ selectedRow?.name }}</strong
          >? This action cannot be undone.
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
import { ref, computed } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useThriftShipmentsQuery } from '../composables/useThriftShipmentQuery';
import {
  useCreateShipmentMutation,
  useUpdateShipmentMutation,
  useDeleteShipmentMutation,
} from '../composables/useThriftShipmentMutations';
import { useTenantPreferenceStore } from 'src/modules/tenant/stores/tenantPreferenceStore';
import { resolveActiveCurrencyId } from 'src/modules/tenant/utils/tenantPreferenceUtils';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import { useQuasar, type QTableColumn } from 'quasar';
import type { ThriftShipment } from '../types';
import ShipmentImageDownloadDialog from '../components/ShipmentImageDownloadDialog.vue';
import ThriftShipmentSkeleton from '../components/ThriftShipmentSkeleton.vue';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';

const $q = useQuasar();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);
const { data: shipmentsData, isLoading: loading } = useThriftShipmentsQuery(tenantId);
const shipments = computed(() => shipmentsData.value || []);

const createMutation = useCreateShipmentMutation(tenantId);
const updateMutation = useUpdateShipmentMutation(tenantId);
const deleteMutation = useDeleteShipmentMutation(tenantId);

const preferenceStore = useTenantPreferenceStore();

const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<ThriftShipment | null>(null);

const form = ref({
  name: '',
  cargo_conversion_rate: null as number | null,
  cargo_rate: null as number | null,
  product_conversion_rate: null as number | null,
  total_cargo_weight_kg: null as number | null,
  labor_total_cost: null as number | null,
  transportation_total_cost: null as number | null,
  washing_total_cost: null as number | null,
  default_markup_rate: null as number | null,
  purchase_currency_id: null as number | null,
  cost_currency_id: null as number | null,
});

const markupPercentage = computed({
  get: () =>
    form.value.default_markup_rate != null
      ? Math.round(form.value.default_markup_rate * 100)
      : null,
  set: (val: number | null) => {
    form.value.default_markup_rate = val != null ? val / 100 : null;
  },
});

const shipmentRows = computed(() => {
  return shipments.value;
});

const tablePagination = ref({ page: 1, rowsPerPage: 20 });

const columns: QTableColumn[] = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center',
    sortable: false,
    headerStyle: 'width: 50px',
  },
  { name: 'name', align: 'left', label: 'Shipment Name', field: 'name', sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

function currencyOptionLabel(option: ThriftCurrency) {
  return `${option.code} (${option.symbol}) — ${option.name}`;
}

function downloadShipmentImages(row: ThriftShipment) {
  $q.dialog({
    component: ShipmentImageDownloadDialog,
    componentProps: { shipmentId: row.id, shipmentName: row.name },
  });
}

function defaultPurchaseCurrencyId(): number | null {
  const activeIds = currencies.value.map((currency) => currency.id);
  return resolveActiveCurrencyId(preferenceStore.thriftDefaultPurchaseCurrencyId, activeIds);
}

function defaultCostCurrencyId(): number | null {
  const activeIds = currencies.value.map((currency) => currency.id);
  return resolveActiveCurrencyId(preferenceStore.thriftDefaultCostCurrencyId, activeIds);
}

// Dialog open & edit setups
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
      washing_total_cost: row.washing_total_cost ?? null,
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
      washing_total_cost: null,
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
      washing_total_cost: form.value.washing_total_cost,
      default_markup_rate: form.value.default_markup_rate,
      purchase_currency_id: form.value.purchase_currency_id,
      cost_currency_id: form.value.cost_currency_id,
    };

    if (editingId.value) {
      await updateMutation.mutateAsync({ id: editingId.value, input: payload });
      $q.notify({ type: 'positive', message: 'Shipment updated successfully' });
    } else {
      await createMutation.mutateAsync({
        ...payload,
        inserted_by: authStore.user?.email || '',
      });
      $q.notify({ type: 'positive', message: 'Shipment created successfully' });
    }
    dialogOpen.value = false;
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
    await deleteMutation.mutateAsync(selectedRow.value.id);
    $q.notify({ type: 'positive', message: 'Shipment deleted successfully' });
    deleteConfirmOpen.value = false;
    selectedRow.value = null;
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

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
</style>

