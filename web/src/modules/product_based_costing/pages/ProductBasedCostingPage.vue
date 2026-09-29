<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
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
      <div v-if="isLoading" class="col overflow-auto q-pa-sm">
        <div class="row q-col-gutter-sm">
          <div v-for="n in 6" :key="n" class="col-12">
            <q-card flat bordered class="q-px-sm q-py-xs">
              <q-skeleton type="text" width="70%" />
              <q-skeleton type="text" width="40%" class="q-mt-xs" />
            </q-card>
          </div>
        </div>
      </div>

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

      <!-- Card list -->
      <div v-else class="col overflow-auto q-pa-sm">
        <CostingFileCard
          :items="items"
          @select="onSelect"
          @copy="onCopy"
          @edit="openEditDialog"
          @delete="onDelete"
        />
        <q-infinite-scroll
          v-if="items.length"
          ref="infiniteScrollRef"
          :offset="200"
          @load="onLoadMoreFiles"
        >
          <template #loading>
            <div class="row justify-center q-py-md">
              <q-spinner-dots color="primary" size="32px" />
            </div>
          </template>
        </q-infinite-scroll>
        <div
          v-if="isFetching && !isFetchingNextPage && items.length"
          class="row justify-center q-py-sm"
        >
          <q-spinner-dots color="grey-6" size="24px" />
        </div>
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
import { useQuasar, type QInfiniteScroll } from 'quasar';
import { useRouter, useRoute } from 'vue-router';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import CostingFileCard from '../components/CostingFileCard.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import type { ProductBasedCostingFile, ProductBasedCostingFileListInput } from '../types';
import { useProductBasedCostingFilesQuery } from '../composables/useProductBasedCostingFilesQuery';
import {
  useCreateProductBasedCostingFileMutation,
  useUpdateProductBasedCostingFileMutation,
  useDeleteProductBasedCostingFileMutation,
  useCopyProductBasedCostingFileMutation,
} from '../composables/useProductBasedCostingFileMutations';
const $q = useQuasar();
const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const listLimit = 20;
const infiniteScrollRef = ref<QInfiniteScroll | null>(null);
const searchText = ref('');
const statusFilter = ref<string>('__all__');
const draftStatusFilter = ref<string>('__all__');
const filterDrawerOpen = ref(false);
const quickFilter = ref('__all__');

const queryParams = computed<ProductBasedCostingFileListInput>(() => {
  const payload: ProductBasedCostingFileListInput = {
    limit: listLimit,
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
  files: items,
  isLoading,
  isFetching,
  isError,
  error,
  fetchNextPage,
  isFetchingNextPage,
  hasMoreFiles,
} = useProductBasedCostingFilesQuery(queryParams);

watch(queryParams, () => {
  if (infiniteScrollRef.value) {
    infiniteScrollRef.value.reset();
    infiniteScrollRef.value.resume();
  }
});

const { mutateAsync: createCostingFile, isPending: isCreating } =
  useCreateProductBasedCostingFileMutation();
const { mutateAsync: updateCostingFile } = useUpdateProductBasedCostingFileMutation();
const { mutateAsync: deleteCostingFile } = useDeleteProductBasedCostingFileMutation();
const { mutateAsync: copyCostingFile } = useCopyProductBasedCostingFileMutation();

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

const activeFilterCount = computed(() => (statusFilter.value !== '__all__' ? 1 : 0));

type CostingFileForm = {
  id: number | null;
  name: string;
  order_for: string;
  customer_group_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
  buy_currency_id: number | null;
  sell_currency_id: number | null;
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
    customer_group_id: row.customer_group_id ?? null,
    note: row.note ?? '',
    vendor_code: row.vendor_code ?? null,
    market_code: row.market_code ?? null,
    buy_currency_id: row.buy_currency_id ?? null,
    sell_currency_id: row.sell_currency_id ?? null,
  };
  dialogOpen.value = true;
}

async function handleDialogSubmit(payload: CostingFileForm) {
  if (payload.id) {
    await updateCostingFile({
      id: payload.id,
      name: payload.name,
      order_for: payload.order_for,
      customer_group_id: payload.customer_group_id,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code,
      buy_currency_id: payload.buy_currency_id ?? undefined,
      sell_currency_id: payload.sell_currency_id ?? undefined,
    });
  } else {
    await createCostingFile({
      name: payload.name,
      order_for: payload.order_for,
      customer_group_id: payload.customer_group_id,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code,
      offer_pricing_mode: 'landed_cost_plus',
      buy_currency_id: payload.buy_currency_id ?? undefined,
      sell_currency_id: payload.sell_currency_id ?? undefined,
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

const onLoadMoreFiles = async (_index: number, done: (stop?: boolean) => void) => {
  if (!hasMoreFiles.value) {
    done(true);
    return;
  }
  try {
    await fetchNextPage();
    done(!hasMoreFiles.value);
  } catch {
    done(true);
  }
};

const onApplyFilters = () => {
  if (infiniteScrollRef.value) {
    infiniteScrollRef.value.reset();
    infiniteScrollRef.value.resume();
  }
};

const onResetFilters = () => {
  searchText.value = '';
  statusFilter.value = '__all__';
  draftStatusFilter.value = '__all__';
  quickFilter.value = '__all__';
  filterDrawerOpen.value = false;
  onApplyFilters();
};

const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value;
  filterDrawerOpen.value = true;
};

const onDrawerStatusChange = () => {
  statusFilter.value = draftStatusFilter.value;
  quickFilter.value = draftStatusFilter.value;
  onApplyFilters();
};

const setQuickFilter = (value: string) => {
  quickFilter.value = value;
  statusFilter.value = value;
  draftStatusFilter.value = value;
  onApplyFilters();
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
