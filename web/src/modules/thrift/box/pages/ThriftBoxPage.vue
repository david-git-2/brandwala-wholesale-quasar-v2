<template>
  <q-page class="q-pa-md thrift-box-page">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Thrift Boxes</h1>
        </div>
        <div class="col-auto">
          <q-btn
            v-if="canCreate"
            color="primary"
            unelevated
            no-caps
            label="Add Box"
            @click="openDialog()"
          />
        </div>
      </section>

      <!-- Skeleton Loading State -->
      <ThriftBoxSkeleton v-if="loading" />

      <!-- Table -->
      <q-card v-else flat class="floating-surface shadow-1">
        <q-table
          flat
          :rows="boxes"
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
              <q-btn
                v-if="canEdit"
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
                v-if="canDelete"
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

      <!-- Create / Edit Dialog -->
      <q-dialog v-model="dialogOpen" persistent>
        <q-card style="width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
          <q-card-section class="row items-center justify-between q-pb-sm">
            <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Box' : 'New Box' }}</div>
            <q-btn flat round dense icon="ph ph-x" v-close-popup />
          </q-card-section>
          <q-separator />
          <q-card-section class="q-pt-md q-gutter-md">
            <q-input
              v-model="form.name"
              outlined
              dense
              label="Box Name / Number *"
              class="soft-input"
              :rules="[(val) => !!val || 'Required']"
            />

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
              :rules="[(val) => !!val || 'Required']"
            />

            <q-input
              v-model.number="form.weight"
              type="number"
              step="0.001"
              outlined
              dense
              label="Weight (kg)"
              class="soft-input"
            />
            <q-input
              v-model.number="form.received_weight"
              type="number"
              step="0.001"
              outlined
              dense
              label="Received Weight (kg)"
              class="soft-input"
            />
          </q-card-section>
          <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
            <q-btn flat no-caps label="Cancel" v-close-popup />
            <q-btn
              color="primary"
              unelevated
              no-caps
              label="Save Box"
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
            <span class="q-ml-sm text-weight-bold">Delete Box</span>
          </q-card-section>
          <q-card-section>
            Are you sure you want to delete box <strong>{{ selectedRow?.name }}</strong
            >? This action cannot be undone.
          </q-card-section>
          <q-card-actions align="right">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn color="negative" label="Delete" @click="deleteItem" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useQuasar, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useQueryClient } from '@tanstack/vue-query';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import ThriftBoxSkeleton from '../components/ThriftBoxSkeleton.vue';
import { useThriftBoxesQuery } from '../../shared/composables/useThriftMasterDataQuery';
import { useThriftShipmentsQuery } from '../../shipment/composables/useThriftShipmentQuery';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';

const $q = useQuasar();
const authStore = useAuthStore();
const queryClient = useQueryClient();
const { hasModuleAccess } = useModulePermissions();

const canCreate = computed(() => hasModuleAccess('thrift_box', 'create'));
const canEdit = computed(() => hasModuleAccess('thrift_box', 'edit'));
const canDelete = computed(() => hasModuleAccess('thrift_box', 'delete'));

const tenantIdRef = computed(() => authStore.tenantId ?? 0);

const { data: boxesData, isLoading: loading } = useThriftBoxesQuery(tenantIdRef);
const boxes = computed(() => (boxesData.value || []) as unknown as Array<Record<string, unknown>>);

const { data: shipmentsData } = useThriftShipmentsQuery(tenantIdRef);
const shipments = computed(() => (shipmentsData.value || []) as unknown as Array<Record<string, unknown>>);


const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<Record<string, unknown> | null>(null);

const form = ref({
  name: '',
  shipment_id: null as number | null,
  weight: 0,
  received_weight: 0,
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
  {
    name: 'id',
    label: 'ID',
    field: 'id',
    align: 'left',
    sortable: true,
    headerStyle: 'width: 70px',
  },
  { name: 'name', align: 'left', label: 'Box Name / Number', field: 'name', sortable: true },
  { name: 'shipment', align: 'left', label: 'Shipment', field: 'shipment' },
  { name: 'weight', align: 'right', label: 'Weight', field: 'weight', sortable: true },
  {
    name: 'received_weight',
    align: 'right',
    label: 'Received Weight',
    field: 'received_weight',
    sortable: true,
  },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

function getShipmentName(shipmentId: number) {
  const sh = shipments.value.find((s) => s.id === shipmentId);
  return sh ? (sh.name as string) : `Shipment #${shipmentId}`;
}

function openDialog(row?: Record<string, unknown>) {
  if (row) {
    if (!canEdit.value) return;
    editingId.value = row.id as number;
    form.value = {
      name: row.name as string,
      shipment_id: row.shipment_id as number,
      weight: (row.weight as number) || 0,
      received_weight: (row.received_weight as number) || 0,
    };
  } else {
    if (!canCreate.value) return;
    editingId.value = null;
    form.value = {
      name: '',
      shipment_id: (shipments.value[0]?.id as number) || null,
      weight: 0,
      received_weight: 0,
    };
  }
  dialogOpen.value = true;
}

async function save() {
  if (editingId.value ? !canEdit.value : !canCreate.value) return;
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
      const { error } = await supabase.from('thrift_boxes').insert({
        ...payload,
        inserted_by: authStore.user?.email || '',
      });
      if (error) throw error;
      $q.notify({ type: 'positive', message: 'Box created successfully' });
    }
    dialogOpen.value = false;
    await queryClient.invalidateQueries({ queryKey: thriftQueryKeys.boxes(tenantIdRef.value) });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  } finally {
    $q.loading.hide();
  }
}

function confirmDelete(row: Record<string, unknown>) {
  if (!canDelete.value) return;
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value || !canDelete.value) return;
  $q.loading.show();
  try {
    const { error } = await supabase.from('thrift_boxes').delete().eq('id', selectedRow.value.id);
    if (error) throw error;
    $q.notify({ type: 'positive', message: 'Box deleted successfully' });
    deleteConfirmOpen.value = false;
    selectedRow.value = null;
    await queryClient.invalidateQueries({ queryKey: thriftQueryKeys.boxes(tenantIdRef.value) });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Delete failed' });
  } finally {
    $q.loading.hide();
  }
}
</script>

<style scoped>
.thrift-box-page {
  background: transparent;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
</style>
