<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden bg-grey-1">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner
        v-if="isError"
        class="bw-status-banner bg-negative text-white flex-shrink-0"
        dense
        rounded
      >
        {{
          $t('product_based_costing.error_prefix', {
            message: error?.message ?? $t('product_based_costing.load_failed'),
          })
        }}
      </q-banner>

      <!-- Toolbar -->
      <q-card flat bordered class="q-pa-xs flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="col-12 col-lg-auto">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <q-btn
                v-for="tab in filterTabs"
                :key="tab.value"
                dense
                unelevated
                no-caps
                :color="quickFilter === tab.value ? 'primary' : 'transparent'"
                :text-color="quickFilter === tab.value ? 'white' : 'grey-8'"
                class="quick-filter-btn text-xs"
                @click="setQuickFilter(tab.value)"
              >
                {{ tab.label }}
              </q-btn>
            </div>
          </div>

          <div class="col-12 col-lg row items-center justify-end q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              clearable
              style="min-width: 200px"
              class="col-grow col-sm-auto dense-search-input"
              :placeholder="$t('product_based_costing.search')"
              @keyup.enter="onApplyFilters"
              @clear="onApplyFilters"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" />
              </template>
            </q-input>

            <q-btn flat round dense icon="ph ph-funnel" @click="openFilterDrawer">
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip>{{ $t('product_based_costing.filters') }}</q-tooltip>
            </q-btn>

            <q-btn
              color="primary"
              unelevated
              no-caps
              dense
              class="rounded-sq-btn text-weight-bold q-px-sm"
              :label="$t('product_based_costing.create_file')"
              icon="ph ph-plus"
              :loading="isCreating"
              @click="openCreateDialog"
            />
          </div>
        </div>
      </q-card>

      <FilterSidebar v-model="filterDrawerOpen" :title="$t('product_based_costing.filters')">
        <q-select
          v-model="draftStatusFilter"
          :options="statusFilterOptions"
          outlined
          dense
          class="soft-input q-mb-md"
          emit-value
          map-options
          :label="$t('product_based_costing.status')"
          @update:model-value="onDrawerStatusChange"
        />
        <div class="row q-gutter-sm justify-end">
          <q-btn flat no-caps :label="$t('product_based_costing.reset')" @click="onResetFilters" />
        </div>
      </FilterSidebar>

      <!-- Skeleton -->
      <q-markup-table
        v-if="isLoading"
        flat
        bordered
        class="pbc-list-table treasury-table-wrap col"
      >
        <thead>
          <tr>
            <th><q-skeleton type="text" width="48px" /></th>
            <th><q-skeleton type="text" width="140px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th class="text-right"><q-skeleton type="text" width="32px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 8" :key="n">
            <td><q-skeleton type="text" width="40px" height="14px" /></td>
            <td><q-skeleton type="text" width="80%" height="14px" /></td>
            <td><q-skeleton type="text" width="60%" height="14px" /></td>
            <td><q-skeleton type="QBadge" width="72px" height="18px" /></td>
            <td class="text-right">
              <q-skeleton type="QBtn" size="sm" width="24px" height="24px" class="q-ml-auto" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>

      <!-- Empty -->
      <div
        v-else-if="!items.length && quickFilter === '__all__' && !searchText.trim()"
        class="column items-center justify-center q-pa-lg text-grey-6 empty-state-block col"
      >
        <q-icon name="ph ph-calculator" size="48px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium q-mb-xs">{{ $t('product_based_costing.title') }}</div>
        <div class="text-caption text-grey-6 q-mb-sm">{{ $t('product_based_costing.subtitle') }}</div>
        <q-btn
          color="primary"
          unelevated
          no-caps
          dense
          class="rounded-sq-btn text-weight-bold q-px-md"
          :label="$t('product_based_costing.create_file')"
          icon="ph ph-plus"
          :loading="isCreating"
          @click="openCreateDialog"
        />
      </div>

      <!-- No matches -->
      <div
        v-else-if="!items.length"
        class="column items-center justify-center text-center text-grey-7 q-py-lg col"
      >
        <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium">{{ $t('product_based_costing.no_matches') }}</div>
      </div>

      <!-- Table -->
      <div v-else class="treasury-table-wrap col">
        <q-card flat bordered class="q-pa-none full-height column no-wrap">
          <q-table
            flat
            :rows="items"
            :columns="tableColumns"
            row-key="id"
            :loading="isFetching"
            :pagination="tablePagination"
            :rows-per-page-options="[10, 20, 50]"
            class="pbc-list-table cursor-pointer col"
            @request="onTableRequest"
            @row-click="(_, row) => onSelect(row)"
          >
            <template #body="slotProps">
              <q-tr
                :props="slotProps"
                class="pbc-list-row cursor-pointer"
                :style="statusRowStyle(slotProps.row.status)"
                @click="onSelect(slotProps.row)"
              >
                <q-td key="id" :props="slotProps">
                  <span class="text-weight-bold text-primary font-mono">PBC-{{ slotProps.row.id }}</span>
                </q-td>

                <q-td key="name" :props="slotProps">
                  <div class="text-weight-bold line-clamp-1">
                    {{ slotProps.row.name ?? $t('product_based_costing.untitled') }}
                  </div>
                  <div v-if="slotProps.row.created_at" class="text-caption text-grey-6 text-xxs row items-center">
                    <q-icon name="ph ph-calendar-blank" size="10px" class="q-mr-xs" />
                    {{ formatAppDate(slotProps.row.created_at) }}
                  </div>
                </q-td>

                <q-td key="order_for" :props="slotProps">
                  <div class="text-weight-medium line-clamp-1">
                    {{ slotProps.row.order_for ?? '-' }}
                  </div>
                </q-td>

                <q-td key="status" :props="slotProps">
                  <div
                    class="pbc-status-badge row inline items-center no-wrap"
                    :style="statusBadgeStyle(slotProps.row.status)"
                  >
                    <q-icon :name="getStatusIcon(slotProps.row.status)" size="13px" class="q-mr-xs" />
                    <span class="text-weight-bolder text-uppercase text-xxs" style="letter-spacing: 0.04em">
                      {{ statusLabel(slotProps.row.status) }}
                    </span>
                  </div>
                </q-td>

                <q-td key="actions" :props="slotProps" class="text-right" @click.stop>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-dots-three-vertical"
                    :aria-label="$t('product_based_costing.file_actions')"
                  >
                    <q-menu auto-close>
                      <q-list dense style="min-width: 140px">
                        <q-item clickable v-ripple @click="onSelect(slotProps.row)">
                          <q-item-section avatar style="min-width: 28px">
                            <q-icon name="ph ph-arrow-square-out" size="18px" />
                          </q-item-section>
                          <q-item-section>{{ $t('product_based_costing.open_file') }}</q-item-section>
                        </q-item>
                        <q-item clickable v-ripple @click="onCopy(slotProps.row)">
                          <q-item-section avatar style="min-width: 28px">
                            <q-icon name="ph ph-copy" size="18px" />
                          </q-item-section>
                          <q-item-section>{{ $t('product_based_costing.copy') }}</q-item-section>
                        </q-item>
                        <q-item clickable v-ripple @click="openEditDialog(slotProps.row)">
                          <q-item-section avatar style="min-width: 28px">
                            <q-icon name="ph ph-pencil-simple" size="18px" />
                          </q-item-section>
                          <q-item-section>{{ $t('product_based_costing.edit') }}</q-item-section>
                        </q-item>
                        <q-separator />
                        <q-item clickable v-ripple @click="onDelete(slotProps.row)">
                          <q-item-section avatar style="min-width: 28px">
                            <q-icon name="ph ph-trash" size="18px" color="negative" />
                          </q-item-section>
                          <q-item-section class="text-negative">{{ $t('product_based_costing.delete') }}</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </q-td>
              </q-tr>
            </template>
          </q-table>
        </q-card>
      </div>
    </div>

    <ProductBasedCostingFileDialog
      v-model="dialogOpen"
      :data="selectedRow"
      @submit="handleDialogSubmit"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useQuasar, type QTableColumn } from 'quasar';
import { useRouter, useRoute } from 'vue-router';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { formatAppDate } from 'src/utils/dateTime';
import type { ProductBasedCostingFile, ProductBasedCostingFileListInput } from '../types';
import { useProductBasedCostingFilesQuery } from '../composables/useProductBasedCostingFilesQuery';
import {
  useCreateProductBasedCostingFileMutation,
  useUpdateProductBasedCostingFileMutation,
  useDeleteProductBasedCostingFileMutation,
  useCopyProductBasedCostingFileMutation,
} from '../composables/useProductBasedCostingFileMutations';
import { normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';

const $q = useQuasar();
const { t, te } = useI18n();
const router = useRouter();
const route = useRoute();

const page = ref(1);
const pageSize = ref(20);
const searchText = ref('');
const statusFilter = ref<string>('__all__');
const draftStatusFilter = ref<string>('__all__');
const filterDrawerOpen = ref(false);
const quickFilter = ref('__all__');

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

const tableColumns = computed<QTableColumn[]>(() => [
  { name: 'id', label: t('product_based_costing.col_id'), field: 'id', align: 'left', style: 'width: 88px' },
  { name: 'name', label: t('product_based_costing.col_name'), field: 'name', align: 'left' },
  {
    name: 'order_for',
    label: t('product_based_costing.col_created_for'),
    field: 'order_for',
    align: 'left',
  },
  { name: 'status', label: t('product_based_costing.col_status'), field: 'status', align: 'left', style: 'width: 150px' },
  { name: 'actions', label: '', field: 'actions', align: 'right', style: 'width: 48px' },
]);

const statusFilterOptions = computed(() => [
  { label: t('product_based_costing.filter_all'), value: '__all__' },
  { label: t('product_based_costing.status_pending'), value: '__pending__' },
  { label: t('product_based_costing.status_offered'), value: 'offered' },
  { label: t('product_based_costing.status_confirmed'), value: 'confirmed' },
  { label: t('product_based_costing.status_procuring'), value: 'procuring' },
  { label: t('product_based_costing.status_ready_for_shipment'), value: 'ready_for_shipment' },
  { label: t('product_based_costing.status_delivered'), value: 'delivered' },
  { label: t('product_based_costing.status_cancelled'), value: 'cancelled' },
]);

const filterTabs = computed(() => [
  { label: t('product_based_costing.filter_all'), value: '__all__' },
  { label: t('product_based_costing.status_pending'), value: '__pending__' },
  { label: t('product_based_costing.status_offered'), value: 'offered' },
  { label: t('product_based_costing.status_confirmed'), value: 'confirmed' },
  { label: t('product_based_costing.status_procuring'), value: 'procuring' },
  { label: t('product_based_costing.status_ready_for_shipment'), value: 'ready_for_shipment' },
  { label: t('product_based_costing.status_delivered'), value: 'delivered' },
]);

watch(statusFilter, (value) => {
  quickFilter.value = value;
});

const statusLabel = (status: string | null | undefined) => {
  const value = normalizePbcFileStatus((status ?? 'pending').trim().toLowerCase() || 'pending');
  const key = `product_based_costing.status_${value}`;
  return te(key) ? t(key) : value.replaceAll('_', ' ');
};

const activeFilterCount = computed(() => (statusFilter.value !== '__all__' ? 1 : 0));

type CostingFileForm = {
  id: number | null;
  name: string;
  order_for: string;
  billing_profile_id: number | null;
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
    billing_profile_id: row.billing_profile_id ?? null,
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
      billing_profile_id: payload.billing_profile_id,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code,
    });
  } else {
    await createCostingFile({
      name: payload.name,
      order_for: payload.order_for,
      billing_profile_id: payload.billing_profile_id,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code,
    });
  }
}

const onSelect = async (item: ProductBasedCostingFile) => {
  await router.push({
    name: 'product-based-costing-file-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: item.id,
    },
  });
};

const onDelete = (item: ProductBasedCostingFile) => {
  $q.dialog({
    title: t('product_based_costing.confirm_delete_title'),
    message: t('product_based_costing.confirm_delete_message', {
      id: item.id,
      name: item.name || t('product_based_costing.untitled'),
    }),
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

const normalizeStatus = (status: string | null | undefined) =>
  normalizePbcFileStatus((status ?? '').trim().toLowerCase() || 'pending');

type StatusVisual = {
  rowBackground: string;
  rowAccent: string;
  chipBackground: string;
  chipText: string;
  chipBorder: string;
  chipShadow: string;
  icon: string;
};

const getStatusVisual = (status: string | null | undefined): StatusVisual => {
  const value = normalizeStatus(status);
  const map: Record<string, StatusVisual> = {
    pending: {
      rowBackground: '#fffbf2',
      rowAccent: '#d8a54a',
      chipBackground: '#efd399',
      chipText: '#6a4a14',
      chipBorder: '#d8b672',
      chipShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
      icon: 'ph ph-hourglass',
    },
    offered: {
      rowBackground: '#f3f7ff',
      rowAccent: '#6f93d8',
      chipBackground: '#c8d8f8',
      chipText: '#27487a',
      chipBorder: '#a9c4f3',
      chipShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
      icon: 'ph ph-paper-plane-tilt',
    },
    confirmed: {
      rowBackground: '#e6f7ff',
      rowAccent: '#1890ff',
      chipBackground: '#bae7ff',
      chipText: '#0050b3',
      chipBorder: '#91d5ff',
      chipShadow: '0 1px 2px rgba(0, 80, 179, 0.18)',
      icon: 'ph ph-check-circle',
    },
    procuring: {
      rowBackground: '#f0f5ff',
      rowAccent: '#2f54eb',
      chipBackground: '#d6e4ff',
      chipText: '#10239e',
      chipBorder: '#adc6ff',
      chipShadow: '0 1px 2px rgba(16, 35, 158, 0.18)',
      icon: 'ph ph-shopping-cart',
    },
    ready_for_shipment: {
      rowBackground: '#f6ffed',
      rowAccent: '#52c41a',
      chipBackground: '#d9f7be',
      chipText: '#237804',
      chipBorder: '#b7eb8f',
      chipShadow: '0 1px 2px rgba(35, 120, 4, 0.18)',
      icon: 'ph ph-package',
    },
    delivered: {
      rowBackground: '#e6fffb',
      rowAccent: '#13c2c2',
      chipBackground: '#b5f5ec',
      chipText: '#00474f',
      chipBorder: '#87e8de',
      chipShadow: '0 1px 2px rgba(0, 71, 79, 0.18)',
      icon: 'ph ph-truck',
    },
    cancelled: {
      rowBackground: '#fff4f6',
      rowAccent: '#c97586',
      chipBackground: '#f2c7d0',
      chipText: '#6f2b3a',
      chipBorder: '#e3a6b3',
      chipShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
      icon: 'ph ph-x-circle',
    },
  };
  return map[value] ?? {
    rowBackground: '#f8f9fb',
    rowAccent: '#8ea0b8',
    chipBackground: '#dbe5f3',
    chipText: '#3b4b66',
    chipBorder: '#b9c8dd',
    chipShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
    icon: 'ph ph-circle',
  };
};

const statusRowStyle = (status: string | null | undefined) => {
  const visual = getStatusVisual(status);
  return {
    backgroundColor: visual.rowBackground,
    boxShadow: `inset 3px 0 0 ${visual.rowAccent}`,
  };
};

const statusBadgeStyle = (status: string | null | undefined) => {
  const visual = getStatusVisual(status);
  return {
    backgroundColor: visual.chipBackground,
    color: visual.chipText,
    border: `1px solid ${visual.chipBorder}`,
    boxShadow: visual.chipShadow,
  };
};

const getStatusIcon = (status: string | null | undefined) => getStatusVisual(status).icon;

const onResetFilters = () => {
  searchText.value = '';
  statusFilter.value = '__all__';
  draftStatusFilter.value = '__all__';
  quickFilter.value = '__all__';
  page.value = 1;
  filterDrawerOpen.value = false;
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

const onDrawerStatusChange = () => {
  statusFilter.value = draftStatusFilter.value;
  quickFilter.value = draftStatusFilter.value;
  page.value = 1;
};

const setQuickFilter = (value: string) => {
  quickFilter.value = value;
  statusFilter.value = value;
  draftStatusFilter.value = value;
  page.value = 1;
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.rounded-sq-btn {
  border-radius: 8px;
}

.quick-filter-toggle {
  background: rgba(0, 0, 0, 0.03);
  border-radius: 8px;
  padding: 2px;
  overflow-x: auto;
  flex-wrap: nowrap;
}

.quick-filter-toggle :deep(.q-btn) {
  border-radius: 6px;
  font-weight: 600;
  padding: 2px 10px;
}

.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.pbc-list-table {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.pbc-list-table :deep(.q-table__container) {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  box-shadow: none;
  background: transparent;
}

.pbc-list-table :deep(.q-table__middle) {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.pbc-list-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  font-weight: 700;
  color: #0f172a;
  background: #f8fafc;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 8px 12px;
  border-bottom: 1px solid #e2e8f0;
}

body.body--dark .pbc-list-table :deep(thead tr th) {
  background: #1c1c1c;
  color: #a1a1aa;
  border-bottom: 1px solid #2e2e2e;
}

.pbc-list-table :deep(tbody tr) {
  transition: background-color 0.15s ease;
}

.pbc-list-table :deep(tbody tr:hover) {
  background-color: #f1f5f9 !important;
}

body.body--dark .pbc-list-table :deep(tbody tr:hover) {
  background-color: #242424 !important;
}

.pbc-list-table :deep(tbody td) {
  padding: 6px 12px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 12.5px;
}

body.body--dark .pbc-list-table :deep(tbody td) {
  border-bottom: 1px solid #262626;
  color: #ededed;
}

.pbc-status-badge {
  border-radius: 6px;
  padding: 3px 8px;
  display: inline-flex;
  align-items: center;
  font-weight: 700;
}

.line-clamp-1 {
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
}

.text-xxs {
  font-size: 9px;
  line-height: 1;
}

.empty-state-block {
  border: 1px dashed rgba(0, 0, 0, 0.12);
  border-radius: 12px;
  background: #fff;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
