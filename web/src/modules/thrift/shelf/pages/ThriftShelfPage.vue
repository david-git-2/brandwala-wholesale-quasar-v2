<template>
  <q-page class="q-pa-md thrift-shelf-page">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Thrift Shelves</h1>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Add Shelf"
            @click="openDialog()"
          />
        </div>
      </section>

      <!-- Loading Skeleton State -->
      <ThriftShelfSkeleton v-if="shelvesLoading" />

      <!-- Table -->
      <q-card v-else flat class="floating-surface shadow-1">
        <q-table
          flat
          :rows="shelvesList"
          :columns="columns"
          row-key="id"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          :loading="shelvesLoading"
          class="thrift-table"
        >
          <template #body-cell-sl="props">
            <q-td :props="props">
              {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
            </q-td>
          </template>
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right q-gutter-x-xs">
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

      <!-- Create / Edit Dialog -->
      <q-dialog v-model="dialogOpen" persistent>
        <q-card style="width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
          <q-card-section class="row items-center justify-between q-pb-sm">
            <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Shelf' : 'New Shelf' }}</div>
            <q-btn flat round dense icon="ph ph-x" v-close-popup />
          </q-card-section>
          <q-separator />
          <q-card-section class="q-pt-md q-gutter-md">
            <q-input
              v-model="form.name"
              outlined
              dense
              label="Shelf Name *"
              class="soft-input"
              :rules="[(val) => !!val || 'Required']"
            />
            <q-input
              v-model="form.shelf_code"
              outlined
              dense
              label="Shelf Code *"
              class="soft-input"
              :rules="[(val) => !!val || 'Required']"
            />
            <q-input
              v-model="form.location_bay"
              outlined
              dense
              label="Location / Bay"
              class="soft-input"
            />
          </q-card-section>
          <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
            <q-btn flat no-caps label="Cancel" v-close-popup />
            <q-btn
              color="primary"
              unelevated
              no-caps
              label="Save Shelf"
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
            <span class="q-ml-sm text-weight-bold">Delete Shelf</span>
          </q-card-section>
          <q-card-section>
            Are you sure you want to delete shelf <strong>{{ selectedRow?.shelf_code }}</strong
            >?
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
import { useThriftStore } from '../../shared/stores/thriftStore';
import { useThriftShelvesQuery } from '../../shared/composables/useThriftMasterDataQuery';
import { useQuasar, type QTableColumn } from 'quasar';
import type { ThriftShelf } from '../types';
import ThriftShelfSkeleton from '../components/ThriftShelfSkeleton.vue';

const $q = useQuasar();
const authStore = useAuthStore();
const thriftStore = useThriftStore();

const tenantIdRef = computed(() => authStore.tenantId ?? 0);
const { data: shelvesData, isLoading: shelvesLoading, refetch: refetchShelves } = useThriftShelvesQuery(tenantIdRef);

const shelvesList = computed(() => shelvesData.value ?? []);

const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<ThriftShelf | null>(null);

const form = ref({ name: '', shelf_code: '', location_bay: '' });

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
  { name: 'shelf_code', align: 'left', label: 'Code', field: 'shelf_code', sortable: true },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'location_bay', align: 'left', label: 'Location / Bay', field: 'location_bay' },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

function openDialog(row?: ThriftShelf) {
  if (row) {
    editingId.value = row.id;
    form.value = {
      name: row.name,
      shelf_code: row.shelf_code,
      location_bay: row.location_bay || '',
    };
  } else {
    editingId.value = null;
    form.value = { name: '', shelf_code: '', location_bay: '' };
  }
  dialogOpen.value = true;
}

async function save() {
  if (!authStore.tenantId || !form.value.name || !form.value.shelf_code) return;
  $q.loading.show();
  try {
    if (editingId.value) {
      await thriftStore.updateShelf(
        editingId.value,
        form.value.name,
        form.value.location_bay,
        form.value.shelf_code,
      );
      $q.notify({ type: 'positive', message: 'Shelf updated' });
    } else {
      await thriftStore.createShelf(
        authStore.tenantId,
        form.value.name,
        form.value.location_bay,
        form.value.shelf_code,
        authStore.user?.email || '',
      );
      $q.notify({ type: 'positive', message: 'Shelf created' });
    }
    await refetchShelves();
    dialogOpen.value = false;
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  } finally {
    $q.loading.hide();
  }
}

function confirmDelete(row: ThriftShelf) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value) return;
  $q.loading.show();
  try {
    await thriftStore.deleteShelf(selectedRow.value.id);
    $q.notify({ type: 'positive', message: 'Shelf deleted' });
    await refetchShelves();
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
.thrift-shelf-page {
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
