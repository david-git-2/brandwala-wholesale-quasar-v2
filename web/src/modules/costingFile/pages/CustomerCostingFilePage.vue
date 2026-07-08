<template>
  <q-page class="q-pa-md costing-list-page theme-shop">
    <PageInitialLoader v-if="initialLoading" />
    <section v-else class="bw-page__stack costing-page">
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="text-h6 text-weight-bold">Customer costing files</div>
              <div class="text-caption text-grey-8">{{ subtitle }}</div>
            </div>
            <div class="col-auto">
              <q-btn
                color="primary"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                label="Create costing file"
                :disable="!canCreate"
                :loading="creating"
                @click="createDialog = true"
              />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <div class="row items-center justify-end q-mb-sm">
        <q-btn-toggle
          v-model="viewMode"
          dense
          unelevated
          no-caps
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="[
            { icon: 'table_rows', value: 'table' },
            { icon: 'grid_view', value: 'card' },
          ]"
        />
      </div>

      <q-card v-if="loadingFiles" flat bordered>
        <q-card-section class="text-grey-7">Loading costing files...</q-card-section>
      </q-card>
      <q-card v-else-if="!files.length" flat bordered>
        <q-card-section class="text-grey-7">No costing files yet.</q-card-section>
      </q-card>
      <template v-else>
        <q-card v-if="viewMode === 'table'" flat class="floating-surface shadow-1">
          <q-table
            flat
            :rows="files"
            :columns="tableColumns"
            row-key="id"
            :loading="loadingFiles"
            v-model:pagination="pagination"
            class="costing-list-table"
            @request="onRequest"
          >
            <template #body="slotProps">
              <q-tr
                :props="slotProps"
                class="cursor-pointer"
                :style="statusSurfaceStyle(slotProps.row.status)"
                @click="openFile(slotProps.row.id)"
              >
                <q-td key="id" :props="slotProps">#{{ slotProps.row.id }}</q-td>
                <q-td key="name" :props="slotProps">{{ slotProps.row.name ?? '-' }}</q-td>
                <q-td key="market" :props="slotProps">{{ slotProps.row.market ?? 'Not set' }}</q-td>
                <q-td key="status" :props="slotProps">
                  <q-chip
                    dense
                    square
                    :style="statusChipStyle(slotProps.row.status)"
                    class="costing-status-chip"
                  >
                    <span
                      class="status-dot"
                      :style="{ backgroundColor: statusDotColor(slotProps.row.status) }"
                    />
                    {{ formatStatusLabel(slotProps.row.status) }}
                  </q-chip>
                </q-td>
                <q-td key="actions" :props="slotProps" class="text-right">
                  <q-btn
                    v-if="slotProps.row.status === 'draft'"
                    flat
                    round
                    dense
                    color="negative"
                    icon="o_delete"
                    aria-label="Delete costing file"
                    :loading="deletingFileId === slotProps.row.id"
                    @click.stop="handleDelete(slotProps.row.id)"
                  />
                </q-td>
              </q-tr>
            </template>
          </q-table>
        </q-card>

        <section v-else class="costing-page__card-grid">
          <q-card
            v-for="file in files"
            :key="file.id"
            flat
            bordered
            class="costing-page__card cursor-pointer"
            :style="{ '--costing-card-accent': cardAccentColor }"
            @click="openFile(file.id)"
          >
            <q-card-section>
              <div class="row justify-end">
                <q-chip
                  dense
                  square
                  :style="statusChipStyle(file.status)"
                  class="costing-status-chip"
                >
                  <span
                    class="status-dot"
                    :style="{ backgroundColor: statusDotColor(file.status) }"
                  />
                  {{ formatStatusLabel(file.status) }}
                </q-chip>
              </div>
              <div class="text-overline q-mt-xs">Costing file</div>
              <div class="text-subtitle1">#{{ file.id }} {{ file.name }}</div>
              <div class="text-body2 text-grey-7">Market: {{ file.market || 'Not set' }}</div>
            </q-card-section>
            <q-card-actions v-if="file.status === 'draft'" align="right">
              <q-btn
                flat
                dense
                round
                color="negative"
                icon="o_delete"
                aria-label="Delete costing file"
                :loading="deletingFileId === file.id"
                @click.stop="handleDelete(file.id)"
              />
            </q-card-actions>
          </q-card>
        </section>

        <div v-if="viewMode === 'card' && totalPages > 1" class="costing-page__pagination">
          <q-pagination
            v-model="page"
            :max="totalPages"
            boundary-links
            direction-links
            color="primary"
            :max-pages="7"
            @update:model-value="handlePageChange"
          />
        </div>
      </template>

      <q-dialog v-model="createDialog" persistent>
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Create costing file</div>
          </q-card-section>

          <q-card-section class="text-body2">
            A draft file will be created for
            <strong>{{ customerGroupName }}</strong>
            with an auto-generated name.
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="createDialog = false" />
            <q-btn
              color="primary"
              unelevated
              label="Create"
              :loading="creating"
              :disable="!canCreate"
              @click="handleCreate"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useRouter } from 'vue-router';
import { type QTableColumn } from 'quasar';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore';
import { handleApiFailure } from 'src/utils/appFeedback';
import { formatCurrentDateTimeForName } from 'src/utils/dateTime';

const router = useRouter();
const authStore = useAuthStore();
const costingFileStore = useCostingFileStore();
const { items: files, listLoading: loadingFiles, totalItems } = storeToRefs(costingFileStore);
const createDialog = ref(false);
const creating = ref(false);
const deletingFileId = ref<number | null>(null);
const initialLoading = ref(true);
const page = ref(1);
const pageSize = 20;
const viewMode = ref<'table' | 'card'>('table');

const pagination = ref({
  sortBy: 'id',
  descending: true,
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
});

watch(
  totalItems,
  (newVal) => {
    pagination.value.rowsNumber = newVal || 0;
  },
  { immediate: true },
);

watch(page, (newVal) => {
  pagination.value.page = newVal;
});

const tableColumns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'market', label: 'Market', field: 'market', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
];

const statusSurfaceStyle = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending';
  if (value === 'draft') return { backgroundColor: '#f8fafc' };
  if (value === 'customer_submitted') return { backgroundColor: '#f2f4ff' };
  if (value === 'in_review') return { backgroundColor: '#fffbeb' };
  if (value === 'offered') return { backgroundColor: '#f0f4ff' };
  if (value === 'accepted') return { backgroundColor: '#e6f9f0' };
  if (value === 'po_placed') return { backgroundColor: '#edfbf2' };
  if (value === 'cancelled') return { backgroundColor: '#fef2f2' };
  return { backgroundColor: '#f8fafc' };
};

const onRequest = async (props: { pagination: { page: number; rowsPerPage: number } }) => {
  page.value = props.pagination.page;
  pagination.value.page = props.pagination.page;
  pagination.value.rowsPerPage = props.pagination.rowsPerPage;
  await loadFiles();
};

const cardAccentColor = computed(
  () => authStore.customerGroup?.accentColor?.trim() || 'var(--bw-theme-primary)',
);
const statusChipStyle = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending';
  if (value === 'draft') {
    return {
      backgroundColor: '#f1f5f9',
      color: '#475569',
      border: '1px solid #cbd5e1',
    };
  }
  if (value === 'customer_submitted') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    };
  }
  if (value === 'in_review') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    };
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
    };
  }
  if (value === 'accepted') {
    return {
      backgroundColor: '#d1fae5',
      color: '#065f46',
      border: '1px solid #a7f3d0',
    };
  }
  if (value === 'po_placed') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    };
  }
  return {
    backgroundColor: '#f1f5f9',
    color: '#475569',
    border: '1px solid #cbd5e1',
  };
};
const statusDotColor = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending';
  if (value === 'draft') return '#64748b';
  if (value === 'customer_submitted') return '#3f51b5';
  if (value === 'in_review') return '#9a6a24';
  if (value === 'offered') return '#3f67b3';
  if (value === 'accepted') return '#059669';
  if (value === 'po_placed') return '#2f8b5d';
  if (value === 'cancelled') return '#a64c62';
  return '#64748b';
};
const formatStatusLabel = (status: string) =>
  status.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
const customerGroupName = computed(() => authStore.customerGroup?.name?.trim() || 'Customer group');
const canCreate = computed(() => Boolean(authStore.customerGroupId && authStore.tenantId));
const totalPages = computed(() => Math.max(1, Math.ceil((totalItems.value || 0) / pageSize)));

const subtitle = computed(() =>
  authStore.customerGroup?.name
    ? `${authStore.customerGroup.name} can open costing files here.`
    : 'Customer group access is required.',
);

const buildCustomerFileName = () => formatCurrentDateTimeForName(customerGroupName.value);

const loadFiles = async () => {
  const customerGroupId = authStore.customerGroupId;
  const tenantId = authStore.tenantId;

  if (!customerGroupId || !tenantId) {
    costingFileStore.items = [];
    costingFileStore.totalItems = 0;
    return;
  }

  await costingFileStore.fetchCostingFilesByCustomerGroup(customerGroupId, tenantId, {
    page: page.value,
    pageSize: pagination.value.rowsPerPage,
  });
};

const handlePageChange = async () => {
  await loadFiles();
};

const handleCreate = async () => {
  const customerGroupId = authStore.customerGroupId;
  const tenantId = authStore.tenantId;

  if (!customerGroupId || !tenantId) {
    return;
  }

  creating.value = true;
  try {
    const result = await costingFileStore.createCostingFile({
      tenantId,
      customerGroupId,
      name: buildCustomerFileName(),
      market: '',
    });

    if (!result.success || !result.data) {
      handleApiFailure(result, 'Failed to create costing file.');
      return;
    }

    createDialog.value = false;
    await loadFiles();
    await openFile(result.data.id);
  } finally {
    creating.value = false;
  }
};

const handleDelete = async (id: number) => {
  deletingFileId.value = id;
  try {
    const result = await costingFileStore.deleteCostingFile({ id });

    if (!result.success) {
      handleApiFailure(result, 'Failed to delete costing file.');
      return;
    }

    await loadFiles();
  } finally {
    deletingFileId.value = null;
  }
};

const openFile = async (id: number) => {
  await router.push({
    name: 'customer-costing-file-details-page',
    params: { id: String(id) },
  });
};

onMounted(async () => {
  try {
    await loadFiles();
  } finally {
    initialLoading.value = false;
  }
});
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
}
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.costing-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
.costing-list-table :deep(tbody tr td) {
  background: inherit !important;
}
.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-transform: capitalize;
}
.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
.costing-page__card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 260px));
  gap: 0.75rem;
}
.costing-page__card {
  width: 100%;
  border-left: 4px solid var(--costing-card-accent, var(--bw-theme-primary));
}
.costing-page__dialog {
  width: min(440px, 92vw);
}
.costing-page__pagination {
  display: flex;
  justify-content: center;
  padding-top: 0.5rem;
}
.costing-page__empty {
  color: var(--bw-theme-muted);
}
@media (max-width: 900px) {
  .costing-page__card-grid {
    grid-template-columns: 1fr;
  }
}
</style>
