<template>
  <q-page class="q-pa-md thrift-type-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Types</div>
            <div class="text-caption text-grey-8">Global dress types and tenant-specific styles</div>
          </div>
          <div class="col-12 col-sm-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Add Type"
              @click="openDialog()"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="thriftStore.types"
        :columns="columns"
        row-key="id"
        :loading="thriftStore.loading"
        class="thrift-table"
      >
        <template #body-cell-scope="props">
          <q-td :props="props">
            <q-chip dense square :color="props.row.is_global ? 'blue-grey-2' : 'teal-2'" text-color="dark">
              {{ props.row.is_global ? 'Global' : 'Tenant' }}
            </q-chip>
          </q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right q-gutter-x-xs">
            <q-btn
              v-if="!props.row.is_global"
              flat round dense icon="o_edit" color="warning" size="sm"
              @click.stop="openDialog(props.row)"
            >
              <q-tooltip>Edit</q-tooltip>
            </q-btn>
            <q-btn
              v-if="!props.row.is_global"
              flat round dense icon="delete" color="negative" size="sm"
              @click.stop="confirmDelete(props.row)"
            >
              <q-tooltip>Delete</q-tooltip>
            </q-btn>
            <span v-if="props.row.is_global" class="text-caption text-grey-6">Read-only</span>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 420px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Type' : 'New Type' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-md">
          <q-input v-model="form.name" outlined dense label="Type Name *" class="soft-input" :rules="[val => !!val || 'Required']" />
          <q-input v-model="form.description" outlined dense label="Description" class="soft-input" type="textarea" autogrow />
        </q-card-section>
        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save" @click="save" />
        </q-card-section>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Type</span>
        </q-card-section>
        <q-card-section>
          Delete type <strong>{{ selectedRow?.name }}</strong>?
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
import { useThriftStore } from '../stores/thriftStore';
import { useQuasar, type QTableColumn } from 'quasar';
import type { ThriftType } from '../types';

const $q = useQuasar();
const authStore = useAuthStore();
const thriftStore = useThriftStore();

const dialogOpen = ref(false);
const deleteConfirmOpen = ref(false);
const editingId = ref<number | null>(null);
const selectedRow = ref<ThriftType | null>(null);

const form = ref({ name: '', description: '' });

const columns: QTableColumn[] = [
  { name: 'scope', align: 'left', label: 'Scope', field: 'is_global' },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'description', align: 'left', label: 'Description', field: 'description' },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await thriftStore.loadModuleData(authStore.tenantId);
  }
});

function openDialog(row?: ThriftType) {
  if (row) {
    editingId.value = row.id;
    form.value = { name: row.name, description: row.description || '' };
  } else {
    editingId.value = null;
    form.value = { name: '', description: '' };
  }
  dialogOpen.value = true;
}

async function save() {
  if (!authStore.tenantId || !form.value.name) return;
  $q.loading.show();
  try {
    if (editingId.value) {
      await thriftStore.updateType(editingId.value, form.value.name, form.value.description);
      $q.notify({ type: 'positive', message: 'Type updated' });
    } else {
      await thriftStore.createType(
        authStore.tenantId,
        form.value.name,
        form.value.description,
        authStore.user?.email || '',
      );
      $q.notify({ type: 'positive', message: 'Type created' });
    }
    dialogOpen.value = false;
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  } finally {
    $q.loading.hide();
  }
}

function confirmDelete(row: ThriftType) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value) return;
  $q.loading.show();
  try {
    await thriftStore.deleteType(selectedRow.value.id);
    $q.notify({ type: 'positive', message: 'Type deleted' });
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
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
}
.hero-surface { border-radius: 16px; }
.pill-btn { border-radius: 999px; }
.slim-btn { min-height: 32px; }
.soft-input :deep(.q-field__control) { border-radius: 12px; }
</style>
