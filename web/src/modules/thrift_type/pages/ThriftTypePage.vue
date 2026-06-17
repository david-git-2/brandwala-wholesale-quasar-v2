<template>
  <q-page class="q-pa-md thrift-type-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Types</div>
            <div class="text-caption text-grey-8">Manage product styles like T-Shirt, Jacket, or Vintage Oversized</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none">
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

    <!-- Table -->
    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="types"
        :columns="columns"
        row-key="id"
        :loading="loading"
        class="thrift-table"
      >
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn flat round dense icon="o_edit" size="sm" @click.stop="openDialog(props.row)">
              <q-tooltip>Edit</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>

    <!-- Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="width: 420px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Type' : 'New Type' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-pt-md q-gutter-sm">
          <q-input v-model="form.name" outlined dense label="Type Name *" class="soft-input" />
          <q-input v-model="form.description" outlined dense label="Description (Optional)" class="soft-input" />
        </q-card-section>
        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Type" @click="save" />
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftTypeStore } from '../stores/thriftTypeStore';
import { useQuasar, type QTableColumn } from 'quasar';

const $q = useQuasar();
const authStore = useAuthStore();
const store = useThriftTypeStore();

const dialogOpen = ref(false);
const editingId = ref<number | null>(null);
const form = ref({ name: '', description: '' });

const types = computed(() => store.types);
const loading = computed(() => store.loading);

const columns: QTableColumn[] = [
  { name: 'name', align: 'left', label: 'Style / Type Name', field: 'name', sortable: true },
  { name: 'description', align: 'left', label: 'Description', field: 'description' },
  { name: 'inserted_by', align: 'left', label: 'Created By', field: 'inserted_by' },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await store.loadTypes(authStore.tenantId);
  }
});

function openDialog(row?: { id: number; name: string; description?: string | null }) {
  editingId.value = row?.id ?? null;
  form.value = { name: row?.name ?? '', description: row?.description ?? '' };
  dialogOpen.value = true;
}

async function save() {
  if (!authStore.tenantId || !form.value.name) return;
  $q.loading.show();
  try {
    await store.createType(
      authStore.tenantId,
      form.value.name,
      form.value.description,
      authStore.user?.email || 'admin@brandwala.com'
    );
    $q.notify({ type: 'positive', message: 'Type saved successfully' });
    form.value = { name: '', description: '' };
    editingId.value = null;
    dialogOpen.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Saving failed' });
  } finally {
    $q.loading.hide();
  }
}
</script>

<style scoped>
.thrift-type-page {
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
