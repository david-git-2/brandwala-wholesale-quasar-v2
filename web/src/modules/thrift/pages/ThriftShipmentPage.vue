<template>
  <q-page class="q-pa-md thrift-shipment-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Shipments</div>
            <div class="text-caption text-grey-8">Manage thrift catalog shipments</div>
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
        :rows="shipments"
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
        <template #body-cell-purchase_currency="props">
          <q-td :props="props">{{ currencyCode(props.row.purchase_currency_id) }}</q-td>
        </template>
        <template #body-cell-cost_currency="props">
          <q-td :props="props">{{ currencyCode(props.row.cost_currency_id) }}</q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right q-gutter-x-xs">
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
      <q-card style="width: 420px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Shipment' : 'New Shipment' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-md">
          <q-input v-model="form.name" outlined dense label="Shipment Name *" class="soft-input" :rules="[val => !!val || 'Required']" />
          <q-input v-model.number="form.cargo_conversion_rate" type="number" step="0.0001" outlined dense label="Cargo Conversion Rate" class="soft-input" />
          <q-input v-model.number="form.cargo_rate" type="number" step="0.01" outlined dense label="Cargo Rate" class="soft-input" />
          <q-input v-model.number="form.product_conversion_rate" type="number" step="0.0001" outlined dense label="Product Conversion Rate" class="soft-input" />
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
import { ref, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCurrencyStore } from 'src/modules/thrift_currency/stores/thriftCurrencyStore';
import type { ThriftCurrency } from 'src/modules/thrift_currency/types';
import { useQuasar, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';

const $q = useQuasar();
const authStore = useAuthStore();
const currencyStore = useThriftCurrencyStore();

const shipments = ref<Array<Record<string, unknown>>>([]);
const loading = ref(false);
const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<Record<string, unknown> | null>(null);

const form = ref({
  name: '',
  cargo_conversion_rate: null as number | null,
  cargo_rate: null as number | null,
  product_conversion_rate: null as number | null,
  purchase_currency_id: null as number | null,
  cost_currency_id: null as number | null,
});

const tablePagination = ref({ page: 1, rowsPerPage: 20 });

const columns: QTableColumn[] = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center', sortable: false, headerStyle: 'width: 50px' },
  { name: 'id', align: 'left', label: 'ID', field: 'id', sortable: true, headerStyle: 'width: 70px' },
  { name: 'name', align: 'left', label: 'Shipment Name', field: 'name', sortable: true },
  { name: 'cargo_conversion_rate', align: 'right', label: 'Cargo Conv. Rate', field: 'cargo_conversion_rate', sortable: true },
  { name: 'cargo_rate', align: 'right', label: 'Cargo Rate', field: 'cargo_rate', sortable: true },
  { name: 'product_conversion_rate', align: 'right', label: 'Product Conv. Rate', field: 'product_conversion_rate', sortable: true },
  { name: 'purchase_currency', align: 'left', label: 'Purchase', field: 'purchase_currency_id', sortable: true },
  { name: 'cost_currency', align: 'left', label: 'Cost', field: 'cost_currency_id', sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

function currencyOptionLabel(option: ThriftCurrency) {
  return `${option.code} (${option.symbol}) — ${option.name}`;
}

function currencyCode(id: unknown): string {
  const currency = currencyStore.currencyById(id as number);
  return currency?.code ?? '—';
}

async function loadShipments() {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const { data, error } = await supabase
      .from('thrift_shipments')
      .select('*')
      .eq('tenant_id', authStore.tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    shipments.value = (data || []) as Array<Record<string, unknown>>;
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Failed to load shipments' });
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await currencyStore.loadCurrencies();
  await loadShipments();
});

function defaultPurchaseCurrencyId(): number | null {
  return currencyStore.currencies.find((c) => c.code === 'GBP')?.id ?? null;
}

function defaultCostCurrencyId(): number | null {
  return currencyStore.currencies.find((c) => c.code === 'BDT')?.id ?? null;
}

function openDialog(row?: Record<string, unknown>) {
  if (row) {
    editingId.value = row.id as number;
    form.value = {
      name: row.name as string,
      cargo_conversion_rate: (row.cargo_conversion_rate as number) || null,
      cargo_rate: (row.cargo_rate as number) || null,
      product_conversion_rate: (row.product_conversion_rate as number) || null,
      purchase_currency_id: row.purchase_currency_id as number,
      cost_currency_id: row.cost_currency_id as number,
    };
  } else {
    editingId.value = null;
    form.value = {
      name: '',
      cargo_conversion_rate: null,
      cargo_rate: null,
      product_conversion_rate: null,
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
      cargo_conversion_rate: form.value.cargo_conversion_rate || null,
      cargo_rate: form.value.cargo_rate || null,
      product_conversion_rate: form.value.product_conversion_rate || null,
      purchase_currency_id: form.value.purchase_currency_id,
      cost_currency_id: form.value.cost_currency_id,
    };

    if (editingId.value) {
      const { error } = await supabase
        .from('thrift_shipments')
        .update(payload)
        .eq('id', editingId.value);
      if (error) throw error;
      $q.notify({ type: 'positive', message: 'Shipment updated successfully' });
    } else {
      const { error } = await supabase
        .from('thrift_shipments')
        .insert({
          ...payload,
          inserted_by: authStore.user?.email || '',
        });
      if (error) throw error;
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

function confirmDelete(row: Record<string, unknown>) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value) return;
  $q.loading.show();
  try {
    const { error } = await supabase
      .from('thrift_shipments')
      .delete()
      .eq('id', selectedRow.value.id as number);
    if (error) throw error;
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
