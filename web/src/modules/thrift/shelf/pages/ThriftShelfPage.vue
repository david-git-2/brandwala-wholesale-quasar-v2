<template>
  <q-page class="q-pa-md thrift-shelf-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Shelves</div>
            <div class="text-caption text-grey-8">Manage warehouse shelf locations</div>
          </div>
          <div class="col-12 col-sm-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Add Shelf"
              @click="openDialog()"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="thriftStore.shelves"
        :columns="columns"
        row-key="id"
        v-model:pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50]"
        :loading="thriftStore.loading"
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
              icon="o_edit"
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
              icon="delete"
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

    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Shelf' : 'New Shelf' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
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
            no-caps
            size="sm"
            class="pill-btn slim-btn"
            label="Save"
            @click="save"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Shelf</span>
        </q-card-section>
        <q-card-section>
          Delete shelf <strong>{{ selectedRow?.shelf_code }}</strong
          >?
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
import { useThriftStore } from '../../shared/stores/thriftStore';
import { useQuasar, type QTableColumn } from 'quasar';
import type { ThriftShelf } from '../types';

const $q = useQuasar();
const authStore = useAuthStore();
const thriftStore = useThriftStore();

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

onMounted(async () => {
  if (authStore.tenantId) {
    await thriftStore.loadModuleData(authStore.tenantId);
  }
});

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
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
}
</style>
