<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Costing</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Product Based Costing</h1>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Create Costing File"
            :loading="isCreating"
            @click="openCreateDialog"
          />
        </div>
      </section>

      <div v-if="isLoading" class="q-gutter-y-md">
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-skeleton type="QInput" height="36px" />
            </div>
            <div class="col-auto row q-gutter-x-sm">
              <q-skeleton type="QBtn" width="36px" height="36px" />
              <q-skeleton type="QBtn" width="90px" height="36px" />
            </div>
          </div>
        </q-card>

        <q-card flat class="floating-surface shadow-1 q-pa-md">
          <q-markup-table flat borderless>
            <thead>
              <tr>
                <th style="width: 60px"><q-skeleton type="text" width="40px" /></th>
                <th><q-skeleton type="text" width="120px" /></th>
                <th><q-skeleton type="text" width="100px" /></th>
                <th><q-skeleton type="text" width="80px" /></th>
                <th class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="n in 6" :key="n">
                <td><q-skeleton type="text" width="30px" /></td>
                <td><q-skeleton type="text" width="70%" /></td>
                <td><q-skeleton type="text" width="50%" /></td>
                <td><q-skeleton type="QBadge" width="70px" height="24px" /></td>
                <td class="text-right"><q-skeleton type="QBtn" width="24px" height="24px" class="q-ml-auto" /></td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card>
      </div>

      <div v-else-if="isError">error: {{ error?.message ?? 'Failed to load product based costing files.' }}</div>

      <template v-else>
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-auto row items-center q-gutter-sm toolbar-left">
              <q-btn
                v-if="!showSearchInput"
                flat
                round
                dense
                icon="ph ph-magnifying-glass"
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
                @keyup.enter="onApplyFilters"
                @clear="onApplyFilters"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
                <template #append>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-x"
                    aria-label="Hide search"
                    @click="
                      () => {
                        searchText = '';
                        showSearchInput = false;
                        onApplyFilters();
                      }
                    "
                  />
                </template>
              </q-input>

              <q-btn flat round dense icon="ph ph-funnel" aria-label="Filters" @click="openFilterDrawer">
                <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                  {{ activeFilterCount }}
                </q-badge>
              </q-btn>
            </div>

            <div class="col-auto">
              <q-btn-toggle
                v-model="viewMode"
                dense
                unelevated
                no-caps
                toggle-color="primary"
                color="white"
                text-color="primary"
                :options="[
                  { icon: 'ph ph-rows', value: 'table' },
                  { icon: 'ph ph-squares-four', value: 'card' },
                ]"
              />
            </div>
          </div>
        </q-card>

        <q-card v-if="viewMode === 'table'" flat class="floating-surface shadow-1">
          <q-table
            flat
            :rows="items"
            :columns="tableColumns"
            row-key="id"
            :loading="isFetching"
            :pagination="tablePagination"
            :rows-per-page-options="[10, 20, 50]"
            @request="onTableRequest"
            class="costing-list-table"
          >
            <template #body="slotProps">
              <q-tr
                :props="slotProps"
                class="cursor-pointer"
                :style="statusSurfaceStyle(slotProps.row.status)"
                @click="onSelect(slotProps.row)"
              >
                <q-td key="id" :props="slotProps">#{{ slotProps.row.id }}</q-td>
                <q-td key="name" :props="slotProps">{{ slotProps.row.name ?? '-' }}</q-td>
                <q-td key="order_for" :props="slotProps">{{ slotProps.row.order_for ?? '-' }}</q-td>
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
                    icon="ph ph-dots-three-vertical"
                    aria-label="Costing file actions"
                    @click.stop
                  >
                    <q-menu auto-close>
                      <q-list dense style="min-width: 120px">
                        <q-item clickable v-ripple @click="onCopy(slotProps.row)">
                          <q-item-section>Copy</q-item-section>
                        </q-item>
                        <q-item clickable v-ripple @click="openEditDialog(slotProps.row)">
                          <q-item-section>Edit</q-item-section>
                        </q-item>
                        <q-item clickable v-ripple @click="onDelete(slotProps.row)">
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
        <div v-else>
          <CostingFileCard
            :items="items"
            @select="onSelect"
            @copy="onCopy"
            @edit="openEditDialog"
            @delete="onDelete"
          />
        </div>

        <div v-if="viewMode !== 'table' && totalPages > 1" class="row justify-center q-mt-md">
          <q-pagination
            v-model="page"
            :max="totalPages"
            :max-pages="8"
            boundary-numbers
            direction-links
            @update:model-value="onPageChange"
          />
        </div>
      </template>

      <ProductBasedCostingFileDialog
        v-model="dialogOpen"
        :data="selectedRow"
        @submit="handleDialogSubmit"
      />

      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <q-select
          v-model="draftStatusFilter"
          :options="statusFilterOptions"
          outlined
          dense
          class="soft-input q-mb-md"
          emit-value
          map-options
          label="Status"
          @update:model-value="onDrawerStatusChange"
        />
        <div class="row q-gutter-sm justify-end">
          <q-btn flat no-caps label="Reset" @click="onResetFilters" />
        </div>
      </FilterSidebar>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQuasar, type QTableColumn } from 'quasar';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import { useRouter, useRoute } from 'vue-router';
import type { ProductBasedCostingFile, ProductBasedCostingFileListInput } from '../types';
import CostingFileCard from '../components/CostingFileCard.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { useProductBasedCostingFilesQuery } from '../composables/useProductBasedCostingFilesQuery';
import {
  useCreateProductBasedCostingFileMutation,
  useUpdateProductBasedCostingFileMutation,
  useDeleteProductBasedCostingFileMutation,
  useCopyProductBasedCostingFileMutation,
} from '../composables/useProductBasedCostingFileMutations';

const $q = useQuasar();
const router = useRouter();
const route = useRoute();

const page = ref(1);
const pageSize = ref(20);
const searchText = ref('');
const showSearchInput = ref(false);
const statusFilter = ref<string>('__all__');
const draftStatusFilter = ref<string>('__all__');
const filterDrawerOpen = ref(false);
const viewMode = ref<'table' | 'card'>('table');

const queryParams = computed<ProductBasedCostingFileListInput>(() => {
  const payload: ProductBasedCostingFileListInput = {
    page: page.value,
    page_size: pageSize.value,
  };

  const searchValue = searchText.value.trim();
  if (searchValue) {
    payload.search = searchValue;
  }

  if (statusFilter.value === '__pending__') {
    payload.status = null;
  } else if (statusFilter.value !== '__all__') {
    payload.status = statusFilter.value;
  }

  return payload;
});

const {
  data: filesPageData,
  isLoading,
  isFetching,
  isError,
  error,
} = useProductBasedCostingFilesQuery(queryParams);

const items = computed(() => filesPageData.value?.data ?? []);
const total = computed(() => filesPageData.value?.meta.total ?? 0);
const totalPages = computed(() => filesPageData.value?.meta.total_pages ?? 1);

const tablePagination = computed(() => ({
  page: page.value,
  rowsPerPage: pageSize.value,
  rowsNumber: total.value,
}));

const { mutateAsync: createCostingFile, isPending: isCreating } =
  useCreateProductBasedCostingFileMutation();
const { mutateAsync: updateCostingFile } = useUpdateProductBasedCostingFileMutation();
const { mutateAsync: deleteCostingFile } = useDeleteProductBasedCostingFileMutation();
const { mutateAsync: copyCostingFile } = useCopyProductBasedCostingFileMutation();

const tableColumns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'order_for', label: 'Created For', field: 'order_for', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
];

const statusFilterOptions = [
  { label: 'All', value: '__all__' },
  { label: 'Pending', value: '__pending__' },
  { label: 'Offered', value: 'offered' },
  { label: 'Processing', value: 'processing' },
  { label: 'Ordered', value: 'ordered' },
  { label: 'Invoicing', value: 'invoicing' },
  { label: 'Invoiced', value: 'invoiced' },
  { label: 'Cancelled', value: 'cancelled' },
];

const activeFilterCount = computed(() => (statusFilter.value !== '__all__' ? 1 : 0));

type CostingFileForm = {
  id: number | null;
  name: string;
  order_for: string;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
};

const dialogOpen = ref(false);
const selectedRow = ref<CostingFileForm | null>(null);

function openCreateDialog() {
  selectedRow.value = null;
  dialogOpen.value = true;
}

function openEditDialog(row: ProductBasedCostingFile) {
  selectedRow.value = {
    id: row.id,
    name: row.name ?? '',
    order_for: row.order_for ?? '',
    note: row.note ?? '',
    vendor_code: row.vendor_code ?? null,
    market_code: row.market_code ?? null,
  };
  dialogOpen.value = true;
}

async function handleDialogSubmit(payload: CostingFileForm) {
  if (payload.id) {
    await updateCostingFile({
      id: payload.id,
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code,
    });
  } else {
    await createCostingFile({
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code,
    });
  }
}

const onSelect = async (item: ProductBasedCostingFile) => {
  const tenantSlug = route.params.tenantSlug;

  await router.push({
    name: 'product-based-costing-file-details-page',
    params: {
      tenantSlug,
      id: item.id,
    },
  });
};

const onDelete = (item: ProductBasedCostingFile) => {
  $q.dialog({
    title: 'Confirm Deletion',
    message: `Are you sure you want to delete costing file #${item.id} (${item.name || 'Untitled'})?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void deleteCostingFile(item.id);
  });
};

const onCopy = (item: ProductBasedCostingFile) => {
  void copyCostingFile(item);
};

const onApplyFilters = () => {
  page.value = 1;
};

const normalizeStatus = (status: string | null | undefined) => {
  const value = (status ?? '').trim().toLowerCase();
  return value || 'pending';
};

const statusSurfaceStyle = (status: string | null | undefined) => {
  const value = normalizeStatus(status);
  if (value === 'pending') {
    return {
      backgroundColor: '#fffbf2',
      boxShadow: 'inset 6px 0 0 #d8a54a',
    };
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#f3f7ff',
      boxShadow: 'inset 6px 0 0 #6f93d8',
    };
  }
  if (value === 'processing') {
    return {
      backgroundColor: '#f2fbf6',
      boxShadow: 'inset 6px 0 0 #59aa7d',
    };
  }
  if (value === 'ordered') {
    return {
      backgroundColor: '#f7fbff',
      boxShadow: 'inset 6px 0 0 #6d91b0',
    };
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#f8f9fa',
      boxShadow: 'inset 6px 0 0 #3f51b5',
    };
  }
  if (value === 'invoiced') {
    return {
      backgroundColor: '#f2fbfb',
      boxShadow: 'inset 6px 0 0 #009688',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#fff4f6',
      boxShadow: 'inset 6px 0 0 #c97586',
    };
  }
  return {
    backgroundColor: '#f8f9fb',
    boxShadow: 'inset 6px 0 0 #8ea0b8',
  };
};

const statusChipStyle = (status: string | null | undefined) => {
  const value = normalizeStatus(status);
  if (value === 'pending') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
      boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
    };
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
      boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
    };
  }
  if (value === 'processing') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
      boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
    };
  }
  if (value === 'ordered') {
    return {
      backgroundColor: '#d8e8f7',
      color: '#1b4562',
      border: '1px solid #9fc0db',
      boxShadow: '0 1px 2px rgba(27, 69, 98, 0.18)',
    };
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
      boxShadow: '0 1px 2px rgba(40, 53, 147, 0.18)',
    };
  }
  if (value === 'invoiced') {
    return {
      backgroundColor: '#e0f2f1',
      color: '#00695c',
      border: '1px solid #b2dfdb',
      boxShadow: '0 1px 2px rgba(0, 105, 92, 0.18)',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
      boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
    };
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
    boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  };
};

const statusDotColor = (status: string | null | undefined) => {
  const value = normalizeStatus(status);
  if (value === 'pending') return '#9a6a24';
  if (value === 'offered') return '#3f67b3';
  if (value === 'processing') return '#2f8b5d';
  if (value === 'ordered') return '#2f6e92';
  if (value === 'invoicing') return '#3f51b5';
  if (value === 'invoiced') return '#009688';
  if (value === 'cancelled') return '#a64c62';
  return '#66758c';
};

const onResetFilters = () => {
  searchText.value = '';
  statusFilter.value = '__all__';
  draftStatusFilter.value = '__all__';
  page.value = 1;
  filterDrawerOpen.value = false;
};

const onPageChange = (nextPage: number) => {
  page.value = nextPage;
};

const onTableRequest = (payload: {
  pagination: { page: number; rowsPerPage: number; rowsNumber?: number };
}) => {
  page.value = payload.pagination.page;
  pageSize.value = payload.pagination.rowsPerPage;
};

const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  statusFilter.value = draftStatusFilter.value;
  page.value = 1;
};

const onDrawerStatusChange = () => {
  onApplyDrawerFilters();
};
</script>

<style scoped>
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

.costing-list-table :deep(.q-table__middle) {
  max-height: calc(100vh - 280px);
  overflow: auto;
}

.costing-list-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}

@media (max-width: 599px) {
  .full-width-mobile {
    width: 100%;
  }
}
</style>
