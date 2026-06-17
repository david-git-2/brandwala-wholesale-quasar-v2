<template>
  <q-page class="q-pa-md thrift-box-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Boxes</div>
            <div class="text-caption text-grey-8">Manage packing boxes within shipments</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Add Box"
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
        :rows="boxes"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-shipment="props">
          <q-td :props="props">
            {{ getShipmentName(props.row.shipment_id) }}
          </q-td>
        </template>
        <template #body-cell-weight="props">
          <q-td :props="props">
            {{ props.value ? `${props.value} kg` : '—' }}
          </q-td>
        </template>
        <template #body-cell-received_weight="props">
          <q-td :props="props">
            {{ props.value ? `${props.value} kg` : '—' }}
          </q-td>
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
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Box' : 'New Box' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-md">
          <q-input v-model="form.name" outlined dense label="Box Name / Number *" class="soft-input" :rules="[val => !!val || 'Required']" />
          
          <q-select
            v-model="form.shipment_id"
            outlined
            dense
            label="Shipment *"
            :options="shipments"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            class="soft-input"
            :rules="[val => !!val || 'Required']"
          />

          <q-input v-model.number="form.weight" type="number" step="0.001" outlined dense label="Weight (kg)" class="soft-input" />
          <q-input v-model.number="form.received_weight" type="number" step="0.001" outlined dense label="Received Weight (kg)" class="soft-input" />
        </q-card-section>
        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Box" @click="save" />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Box</span>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete box <strong>{{ selectedRow?.name }}</strong>? This action cannot be undone.
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
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useQuasar, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';

const $q = useQuasar();
const authStore = useAuthStore();

const boxes = ref<any[]>([]);
const shipments = ref<any[]>([]);
const loading = ref(false);
const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<any>(null);

const form = ref({
  name: '',
  shipment_id: null as number | null,
  weight: 0,
  received_weight: 0,
});

const columns: QTableColumn[] = [
  { name: 'name', align: 'left', label: 'Box Name / Number', field: 'name', sortable: true },
  { name: 'shipment', align: 'left', label: 'Shipment', field: 'shipment' },
  { name: 'weight', align: 'right', label: 'Weight', field: 'weight', sortable: true },
  { name: 'received_weight', align: 'right', label: 'Received Weight', field: 'received_weight', sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

async function loadShipments() {
  if (!authStore.tenantId) return;
  const { data } = await supabase
    .from('thrift_shipments')
    .select('id, name')
    .eq('tenant_id', authStore.tenantId)
    .order('name', { ascending: true });
  shipments.value = data || [];
}

async function loadBoxes() {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const { data, error } = await supabase
      .from('thrift_boxes')
      .select('*')
      .eq('tenant_id', authStore.tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    boxes.value = data || [];
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Failed to load boxes' });
  } finally {
    loading.value = false;
  }
}

function getShipmentName(shipmentId: number) {
  const sh = shipments.value.find(s => s.id === shipmentId);
  return sh ? sh.name : `Shipment #${shipmentId}`;
}

onMounted(async () => {
  await Promise.all([
    loadShipments(),
    loadBoxes(),
  ]);
});

function openDialog(row?: any) {
  if (row) {
    editingId.value = row.id;
    form.value = {
      name: row.name,
      shipment_id: row.shipment_id,
      weight: row.weight || 0,
      received_weight: row.received_weight || 0,
    };
  } else {
    editingId.value = null;
    form.value = {
      name: '',
      shipment_id: shipments.value[0]?.id || null,
      weight: 0,
      received_weight: 0,
    };
  }
  dialogOpen.value = true;
}

async function save() {
  if (!authStore.tenantId || !form.value.name || !form.value.shipment_id) return;
  $q.loading.show();
  try {
    const payload = {
      tenant_id: authStore.tenantId,
      name: form.value.name,
      shipment_id: form.value.shipment_id,
      weight: form.value.weight || null,
      received_weight: form.value.received_weight || null,
    };

    if (editingId.value) {
      const { error } = await supabase
        .from('thrift_boxes')
        .update(payload)
        .eq('id', editingId.value);
      if (error) throw error;
      $q.notify({ type: 'positive', message: 'Box updated successfully' });
    } else {
      const { error } = await supabase
        .from('thrift_boxes')
        .insert({
          ...payload,
          inserted_by: authStore.user?.email || '',
        });
      if (error) throw error;
      $q.notify({ type: 'positive', message: 'Box created successfully' });
    }
    dialogOpen.value = false;
    await loadBoxes();
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Save failed' });
  } finally {
    $q.loading.hide();
  }
}

function confirmDelete(row: any) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value) return;
  $q.loading.show();
  try {
    const { error } = await supabase
      .from('thrift_boxes')
      .delete()
      .eq('id', selectedRow.value.id);
    if (error) throw error;
    $q.notify({ type: 'positive', message: 'Box deleted successfully' });
    deleteConfirmOpen.value = false;
    selectedRow.value = null;
    await loadBoxes();
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Delete failed' });
  } finally {
    $q.loading.hide();
  }
}
</script>

<style scoped>
.thrift-box-page {
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
