<template>
  <q-page class="q-pa-md costing-list-page">
    <PageInitialLoader v-if="initialLoading" />
    <section v-else class="bw-page__stack">
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="text-h6 text-weight-bold">Costing files</div>
              <div class="text-caption text-grey-8">Manage costing files and open details</div>
            </div>
            <div class="col-auto">
              <q-btn
                color="primary"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                label="Create costing file"
                :disable="!tenantStore.selectedTenant?.id"
                @click="openCreateDialog"
              />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <div class="row items-center justify-between q-mb-sm">
        <div class="row items-center q-gutter-sm toolbar-left">
          <q-btn
            v-if="!showSearchInput"
            flat
            round
            dense
            icon="search"
            aria-label="Show search"
            @click="showSearchInput = true"
          />

          <q-input
            v-else
            v-model="searchText"
            outlined
            dense
            class="soft-input toolbar-search"
            label="Search"
            clearable
            autofocus
            @keyup.enter="loadFiles"
            @clear="loadFiles"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn
                flat
                round
                dense
                icon="close"
                aria-label="Hide search"
                @click="
                  () => {
                    searchText = '';
                    showSearchInput = false;
                    loadFiles();
                  }
                "
              />
            </template>
          </q-input>

          <q-btn
            flat
            round
            dense
            icon="filter_alt"
            aria-label="Filters"
            @click="filterDrawerOpen = true"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>

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

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card v-if="!tenantStore.selectedTenant" flat bordered>
        <q-card-section class="text-grey-7">
          Select a tenant to load costing files.
        </q-card-section>
      </q-card>

      <template v-if="files.length">
        <q-card v-if="viewMode === 'table'" flat class="floating-surface shadow-1">
          <q-table
            flat
            :rows="filteredFiles"
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
                <q-td key="group" :props="slotProps">{{
                  customerGroupNameById(slotProps.row.customer_group_id)
                }}</q-td>
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
                    {{ slotProps.row.status ?? 'pending' }}
                  </q-chip>
                </q-td>
                <q-td key="actions" :props="slotProps" class="text-right">
                  <q-btn
                    flat
                    round
                    dense
                    icon="more_vert"
                    aria-label="Costing file actions"
                    @click.stop
                  >
                    <q-menu auto-close>
                      <q-list dense style="min-width: 120px">
                        <q-item clickable v-ripple @click="openEditDialog(slotProps.row.id)">
                          <q-item-section>Edit</q-item-section>
                        </q-item>
                        <q-item clickable v-ripple @click="openDeleteDialog(slotProps.row.id)">
                          <q-item-section class="text-negative">Delete</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </q-td>
              </q-tr>
            </template>
          </q-table>
        </q-card>

        <section v-else class="costing-page__grid">
          <q-card
            v-for="file in filteredFiles"
            :key="file.id"
            flat
            bordered
            class="costing-page__card cursor-pointer"
            :style="{
              '--costing-card-accent': customerGroupAccentColorById(file.customer_group_id),
              ...statusSurfaceStyle(file.status),
            }"
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
                  {{ file.status ?? 'pending' }}
                </q-chip>
              </div>
              <div class="text-overline q-mt-xs">Costing file #{{ file.id }}</div>
              <div class="text-subtitle1">#{{ file.id }} {{ file.name }}</div>
              <div class="text-body2 text-grey-7">{{ file.market || 'Not set' }}</div>
              <div class="text-caption q-mt-xs text-grey-7">
                {{ customerGroupNameById(file.customer_group_id) }}
              </div>
              <div class="text-caption q-mt-xs text-grey-7">
                Created by: {{ file.created_by_label || file.created_by_email || 'Unknown' }}
              </div>
            </q-card-section>
            <q-card-actions align="right">
              <q-btn
                flat
                round
                dense
                icon="more_vert"
                aria-label="Costing file actions"
                @click.stop
              >
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable v-ripple @click="openEditDialog(file.id)">
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="openDeleteDialog(file.id)">
                      <q-item-section class="text-negative">Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
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

      <q-card v-else-if="loadingFiles" flat bordered>
        <q-card-section class="text-grey-7">Loading costing files...</q-card-section>
      </q-card>

      <q-card v-else flat bordered>
        <q-card-section class="text-center">
          <div class="text-subtitle1">No costing files found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">Create a costing file to get started.</div>
        </q-card-section>
      </q-card>

      <q-dialog v-model="createDialog" persistent>
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Create costing file</div>
          </q-card-section>

          <q-card-section class="costing-page__dialog-body">
            <q-input v-model="createForm.name" label="Name" outlined dense />
            <q-input v-model="createForm.market" label="Market" outlined dense />
            <q-select
              v-model="createForm.customerGroupId"
              label="Customer group"
              outlined
              dense
              emit-value
              map-options
              :options="customerGroupOptions"
            />
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

      <q-dialog v-model="editDialog" persistent @hide="closeEditDialog">
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Edit costing file</div>
          </q-card-section>

          <q-card-section class="costing-page__dialog-body">
            <q-input v-model="editForm.name" label="Name" outlined dense />
            <q-input v-model="editForm.market" label="Market" outlined dense />
            <q-select
              v-model="editForm.customerGroupId"
              label="Customer group"
              outlined
              dense
              emit-value
              map-options
              :options="customerGroupOptions"
            />
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="closeEditDialog" />
            <q-btn
              color="primary"
              unelevated
              label="Save"
              :loading="editing"
              :disable="!canEdit"
              @click="handleEdit"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <q-dialog v-model="deleteDialog" persistent @hide="closeDeleteDialog">
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Delete costing file</div>
          </q-card-section>

          <q-card-section>
            <div class="text-body2">
              Delete
              <strong>{{ filePendingDelete?.name ?? 'this costing file' }}</strong>
              ?
            </div>
            <div class="text-body2 text-grey-7 q-mt-sm">
              This will also delete all related costing file items.
            </div>
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="closeDeleteDialog" />
            <q-btn
              color="negative"
              unelevated
              label="Delete"
              :loading="deleting"
              @click="handleDelete"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <q-select
          v-model="selectedCustomerGroupId"
          label="Customer group"
          outlined
          dense
          class="soft-input q-mb-md"
          emit-value
          map-options
          :options="customerGroupFilterOptions"
          @update:model-value="handleCustomerGroupFilterChange"
        />
        <div class="row q-gutter-sm justify-end">
          <q-btn
            flat
            no-caps
            label="Reset"
            @click="
              () => {
                selectedCustomerGroupId = null;
                page = 1;
                loadFiles();
              }
            "
          />
        </div>
      </FilterSidebar>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useRouter } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore';
import { customerGroupService } from 'src/modules/tenant/services/customerGroupService';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { handleApiFailure } from 'src/utils/appFeedback';
import { formatCurrentDateTimeForName } from 'src/utils/dateTime';
import { type QTableColumn } from 'quasar';
import FilterSidebar from 'src/components/FilterSidebar.vue';

const router = useRouter();
const tenantStore = useTenantStore();
const costingFileStore = useCostingFileStore();
const {
  items: files,
  listLoading: loadingFiles,
  error,
  totalItems,
} = storeToRefs(costingFileStore);

const creating = ref(false);
const editing = ref(false);
const deleting = ref(false);
const initialLoading = ref(true);
const createDialog = ref(false);
const editDialog = ref(false);
const deleteDialog = ref(false);
const editingFileId = ref<number | null>(null);
const deletingFileId = ref<number | null>(null);
const page = ref(1);
const pageSize = 20;
const viewMode = ref<'table' | 'card'>('table');
const showSearchInput = ref(false);
const searchText = ref('');
const filterDrawerOpen = ref(false);

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
  { name: 'group', label: 'Customer group', field: 'customer_group_id', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
];
const activeFilterCount = computed(() => (selectedCustomerGroupId.value == null ? 0 : 1));
const filteredFiles = computed(() => {
  const query = searchText.value.trim().toLowerCase();
  if (!query) {
    return files.value;
  }

  return files.value.filter((file) => {
    const idText = String(file.id ?? '');
    const name = String(file.name ?? '').toLowerCase();
    const market = String(file.market ?? '').toLowerCase();
    const status = String(file.status ?? '').toLowerCase();
    const customerGroup = customerGroupNameById(file.customer_group_id).toLowerCase();
    return (
      idText.includes(query) ||
      name.includes(query) ||
      market.includes(query) ||
      status.includes(query) ||
      customerGroup.includes(query)
    );
  });
});

const customerGroupOptions = ref<{ label: string; value: number; accentColor: string | null }[]>(
  [],
);
const selectedCustomerGroupId = ref<number | null>(null);

const createForm = reactive({
  name: '',
  market: '',
  customerGroupId: null as number | null,
});

const editForm = reactive({
  name: '',
  market: '',
  customerGroupId: null as number | null,
});

const canCreate = computed(
  () =>
    Boolean(tenantStore.selectedTenant?.id) &&
    Boolean(createForm.customerGroupId) &&
    createForm.name.trim().length > 0 &&
    createForm.market.trim().length > 0,
);

const canEdit = computed(
  () =>
    Boolean(editingFileId.value) &&
    Boolean(editForm.customerGroupId) &&
    editForm.name.trim().length > 0 &&
    editForm.market.trim().length > 0,
);

const customerGroupNameById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.label ??
  `#${customerGroupId}`;
const customerGroupAccentColorById = (customerGroupId: number) =>
  customerGroupOptions.value
    .find((option) => option.value === customerGroupId)
    ?.accentColor?.trim() || 'var(--bw-theme-primary)';
const buildCreateFileName = (customerGroupId: number | null) => {
  const customerGroupName =
    customerGroupOptions.value.find((option) => option.value === customerGroupId)?.label ??
    'Costing File';
  return formatCurrentDateTimeForName(customerGroupName);
};
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
const customerGroupFilterOptions = computed(() => [
  { label: 'All customer groups', value: null },
  ...customerGroupOptions.value,
]);

const totalPages = computed(() => Math.max(1, Math.ceil((totalItems.value || 0) / pageSize)));

const filePendingDelete = computed(
  () => files.value.find((file) => file.id === deletingFileId.value) ?? null,
);

const resetCreateForm = () => {
  createForm.name = buildCreateFileName(createForm.customerGroupId);
  createForm.market = '';
  createForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null;
  createForm.name = buildCreateFileName(createForm.customerGroupId);
};

const resetEditForm = () => {
  editForm.name = '';
  editForm.market = '';
  editForm.customerGroupId = customerGroupOptions.value[0]?.value ?? null;
};

const loadCustomerGroupContext = async () => {
  const tenantId = tenantStore.selectedTenant?.id;

  if (!tenantId) {
    customerGroupOptions.value = [];
    resetCreateForm();
    return;
  }

  const result = await customerGroupService.listCustomerGroupsByTenant(tenantId);

  if (!result.success) {
    handleApiFailure(result, 'Failed to load customer groups for costing file creation.');
    customerGroupOptions.value = [];
    resetCreateForm();
    return;
  }

  customerGroupOptions.value = (result.data ?? []).map((group) => ({
    label: group.name,
    value: group.id,
    accentColor: group.accent_color ?? null,
  }));
  resetCreateForm();
  resetEditForm();
};

const loadFiles = async () => {
  const tenantId = tenantStore.selectedTenant?.id;

  if (!tenantId) {
    costingFileStore.items = [];
    costingFileStore.totalItems = 0;
    return;
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId, {
    customerGroupId: selectedCustomerGroupId.value,
    page: page.value,
    pageSize: pagination.value.rowsPerPage,
  });
};

const onRequest = async (props: { pagination: { page: number; rowsPerPage: number } }) => {
  page.value = props.pagination.page;
  pagination.value.page = props.pagination.page;
  pagination.value.rowsPerPage = props.pagination.rowsPerPage;
  await loadFiles();
};

const loadPageData = async () => {
  await loadCustomerGroupContext();
  await loadFiles();
};

const handleCustomerGroupFilterChange = async () => {
  page.value = 1;
  await loadFiles();
};

const handlePageChange = async () => {
  await loadFiles();
};

const openFile = async (id: number) => {
  await router.push({
    name: 'admin-costing-file-details-page',
    params: { id: String(id) },
  });
};

const openEditDialog = (id: number) => {
  const file = files.value.find((item) => item.id === id);

  if (!file) {
    return;
  }

  editingFileId.value = file.id;
  editForm.name = file.name;
  editForm.market = file.market ?? '';
  editForm.customerGroupId = file.customer_group_id;
  editDialog.value = true;
};

const openCreateDialog = () => {
  resetCreateForm();
  createDialog.value = true;
};

const closeEditDialog = () => {
  editDialog.value = false;
  editingFileId.value = null;
  resetEditForm();
};

const openDeleteDialog = (id: number) => {
  deletingFileId.value = id;
  deleteDialog.value = true;
};

const closeDeleteDialog = () => {
  deleteDialog.value = false;
  deletingFileId.value = null;
};

const handleCreate = async () => {
  const tenantId = tenantStore.selectedTenant?.id;
  const customerGroupId = createForm.customerGroupId;

  if (!tenantId || !customerGroupId) {
    return;
  }

  creating.value = true;
  try {
    const result = await costingFileStore.createCostingFile({
      tenantId,
      customerGroupId,
      name: createForm.name.trim(),
      market: createForm.market.trim(),
      status: 'customer_submitted',
    });

    if (!result.success || !result.data) {
      handleApiFailure(result, 'Failed to create costing file.');
      return;
    }

    resetCreateForm();
    createDialog.value = false;
    await loadFiles();
    await openFile(result.data.id);
  } finally {
    creating.value = false;
  }
};

const handleEdit = async () => {
  const id = editingFileId.value;
  const customerGroupId = editForm.customerGroupId;

  if (!id || !customerGroupId) {
    return;
  }

  editing.value = true;
  try {
    const result = await costingFileStore.updateCostingFile({
      id,
      name: editForm.name.trim(),
      market: editForm.market.trim(),
      customerGroupId,
    });

    if (!result.success) {
      handleApiFailure(result, 'Failed to update costing file.');
      return;
    }

    closeEditDialog();
    await loadFiles();
  } finally {
    editing.value = false;
  }
};

const handleDelete = async () => {
  const id = deletingFileId.value;

  if (!id) {
    return;
  }

  deleting.value = true;
  try {
    const result = await costingFileStore.deleteCostingFile({ id });

    if (!result.success) {
      handleApiFailure(result, 'Failed to delete costing file.');
      return;
    }

    closeDeleteDialog();
    await loadFiles();
  } finally {
    deleting.value = false;
  }
};

watch(
  () => tenantStore.selectedTenant?.id ?? null,
  async () => {
    try {
      createDialog.value = false;
      closeEditDialog();
      closeDeleteDialog();
      selectedCustomerGroupId.value = null;
      page.value = 1;
      await loadPageData();
    } finally {
      initialLoading.value = false;
    }
  },
  { immediate: true },
);
</script>

<style scoped>
.costing-list-page {
  background: transparent;
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

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
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

.costing-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 260px));
  gap: 0.75rem;
}

.costing-page__card {
  width: 100%;
  border-left: 4px solid var(--costing-card-accent, var(--bw-theme-primary));
}

.costing-page__dialog {
  min-width: min(520px, 92vw);
}

.costing-page__dialog-body {
  display: grid;
  gap: 1rem;
}

.costing-page__pagination {
  display: flex;
  justify-content: center;
  padding-top: 0.5rem;
}

@media (max-width: 599px) {
  .costing-page__grid {
    grid-template-columns: 1fr;
  }
}
</style>
