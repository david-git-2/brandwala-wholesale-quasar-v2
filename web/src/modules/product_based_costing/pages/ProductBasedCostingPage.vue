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
        <div class="pbc-toolbar">
          <div class="pbc-toolbar__tabs">
            <TfDrawerSectionTabs
              v-model="quickFilter"
              :tabs="quickFilterSectionTabs"
              ariaLabel="Filter costing files"
              @update:model-value="setQuickFilter"
            />
          </div>

          <div class="pbc-toolbar__actions">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              clearable
              class="pbc-toolbar__search dense-search-input"
              :placeholder="$t('product_based_costing.search')"
              @keyup.enter="onApplyFilters"
              @clear="onApplyFilters"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" />
              </template>
            </q-input>

            <TfBtn variant="icon" size="md" icon="ph ph-funnel" @click="openFilterDrawer">
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip :delay="400">{{ $t('product_based_costing.filters') }}</q-tooltip>
            </TfBtn>

            <TfBtn
              variant="primary"
              size="md"
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
        <template #footer>
          <div class="row q-gutter-sm justify-end">
            <TfBtn variant="tertiary" :label="$t('product_based_costing.reset')" @click="onResetFilters" />
          </div>
        </template>
      </FilterSidebar>

      <!-- Skeleton -->
      <div v-if="isLoading && !items.length" class="col overflow-auto q-pa-sm">
        <TfSkeletonRows :rows="6" :cols="2" height="20px" />
      </div>

      <!-- Empty -->
      <div
        v-else-if="!items.length && quickFilter === '__all__' && !searchText.trim()"
        class="column items-center justify-center q-pa-md empty-state-block col"
      >
        <TfEmptyState
          icon="ph ph-calculator"
          :title="$t('product_based_costing.title')"
          :message="$t('product_based_costing.subtitle')"
        >
        <TfBtn
          variant="primary"
          size="md"
          class="rounded-sq-btn text-weight-bold q-px-md"
          :label="$t('product_based_costing.create_file')"
          icon="ph ph-plus"
          :loading="isCreating"
          @click="openCreateDialog"
        />
        </TfEmptyState>
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
      <div
        v-else
        class="col overflow-auto q-pa-sm"
        :class="{ 'pbc-list--placeholder': isPlaceholderData }"
      >
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
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import CostingFileCard from '../components/CostingFileCard.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import type { ProductBasedCostingFileListInput, ProductBasedCostingFileListRow } from '../types';
import {
  PBC_FALLBACK_BUY_CURRENCY_CODE,
  PBC_FALLBACK_SELL_CURRENCY_CODE,
} from '../utils/pbcFileCurrencies';
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
  isPlaceholderData,
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
  { label: t('product_based_costing.status_packed'), value: 'packed' },
  { label: t('product_based_costing.status_delivered'), value: 'delivered' },
  { label: t('product_based_costing.status_cancelled'), value: 'cancelled' },
]);

const filterTabs = computed(() => [
  { label: t('product_based_costing.filter_all'), value: '__all__' },
  { label: t('product_based_costing.status_pending'), value: '__pending__' },
  { label: t('product_based_costing.status_offered'), value: 'offered' },
  { label: t('product_based_costing.status_confirmed'), value: 'confirmed' },
  { label: t('product_based_costing.status_procuring'), value: 'procuring' },
  { label: t('product_based_costing.status_packed'), value: 'packed' },
  { label: t('product_based_costing.status_delivered'), value: 'delivered' },
]);

const quickFilterSectionTabs = computed(() =>
  filterTabs.value.map((tab) => ({ name: tab.value, label: tab.label })),
);

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

function openEditDialog(row: ProductBasedCostingFileListRow) {
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
      buy_currency_id: payload.buy_currency_id ?? 0,
      sell_currency_id: payload.sell_currency_id ?? 0,
      buy_currency_code: PBC_FALLBACK_BUY_CURRENCY_CODE,
      sell_currency_code: PBC_FALLBACK_SELL_CURRENCY_CODE,
    });
  }
}

const onSelect = async (item: ProductBasedCostingFileListRow) => {
  await router.push({
    name: 'product-based-costing-file-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: item.id,
    },
  });
};

const onDelete = (item: ProductBasedCostingFileListRow) => {
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

const onCopy = (item: ProductBasedCostingFileListRow) => {
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

const setQuickFilter = (value: string | number) => {
  const next = String(value);
  quickFilter.value = next;
  statusFilter.value = next;
  draftStatusFilter.value = next;
  onApplyFilters();
};
</script>

<style scoped>
.pbc-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}
.pbc-toolbar__tabs {
  flex: 0 1 auto;
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}
.pbc-toolbar__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 4px;
  flex: 1 1 320px;
  min-width: 0;
}
.pbc-toolbar__search {
  flex: 1 1 140px;
  min-width: 0;
  max-width: 280px;
}
@media (max-width: 599px) {
  .pbc-toolbar__tabs,
  .pbc-toolbar__actions {
    flex-basis: 100%;
  }
  .pbc-toolbar__search {
    max-width: none;
  }
}
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.rounded-sq-btn {
  border-radius: 8px;
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
  color: var(--tf-neutral-ink);
  background: var(--tf-neutral-canvas);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 8px 12px;
  border-bottom: 1px solid var(--tf-neutral-border);
}


.pbc-list-table :deep(tbody tr) {
  transition: background-color 0.15s ease;
}

.pbc-list-table :deep(tbody tr:hover) {
  background-color: var(--tf-disabled-bg) !important;
}


.pbc-list-table :deep(tbody td) {
  padding: 6px 12px;
  border-bottom: 1px solid var(--tf-neutral-border);
  font-size: 12.5px;
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
  border: 1px dashed var(--tf-neutral-border-strong);
  border-radius: 12px;
  background: var(--tf-neutral-surface);
}

.pbc-list--placeholder {
  opacity: 0.6;
  pointer-events: none;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
