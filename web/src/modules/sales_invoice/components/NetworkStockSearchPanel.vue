<template>
  <div class="network-stock-search">
    <div v-if="showSearchControls" class="row q-col-gutter-sm items-center q-mb-md">
      <div class="col-12 col-sm-4">
        <q-select
          v-model="searchField"
          :options="searchFieldOptions"
          outlined
          dense
          emit-value
          map-options
          label="Search By"
          class="soft-input"
          @update:model-value="onCriteriaChange"
        />
      </div>
      <div class="col-12 col-sm-8">
        <q-input
          v-model="searchQuery"
          :placeholder="searchPlaceholder"
          outlined
          dense
          clearable
          autofocus
          class="soft-input search-input"
          @update:model-value="onSearchInput"
        >
          <template #append>
            <q-spinner v-if="loading" size="20px" color="primary" />
          </template>
        </q-input>
      </div>
    </div>

    <div class="scroll-area">
      <q-list v-if="groupedResults.length" separator>
        <q-item
          v-for="group in groupedResults"
          :key="group.key"
          class="search-result-item q-py-sm"
          :clickable="selectable"
          @click="selectable ? onSelectGroup(group) : undefined"
        >
          <q-item-section avatar>
            <q-avatar rounded size="48px" class="bg-grey-2 shadow-1">
              <img
                :src="group.image_url || 'https://placehold.co/48x48?text=No+Image'"
                alt="product image"
                style="object-fit: contain"
              />
            </q-avatar>
          </q-item-section>

          <q-item-section>
            <q-item-label class="text-subtitle2 text-weight-bold row items-center justify-between">
              <span>{{ group.name }}</span>
              <span class="text-caption text-grey-8 text-weight-bold">
                Cost: BDT {{ formatCost(group.cost) }}
              </span>
            </q-item-label>
            <q-item-label caption class="text-grey-7 row q-gutter-x-md">
              <span v-if="group.product_code">Code: {{ group.product_code }}</span>
              <span v-if="group.barcode">Barcode: {{ group.barcode }}</span>
            </q-item-label>

            <div class="row items-center q-gutter-xs q-mt-xs flex-wrap">
              <template
                v-for="ctx in group.contexts"
                :key="`${ctx.global_stock_id}-${ctx.holding_tenant_id}`"
              >
                <q-chip
                  v-if="ctx.excellent_qty > 0 || ctx.allocated_qty > 0 || mode === 'invoice'"
                  dense
                  square
                  :color="ctx.is_own_tenant ? 'green-1' : 'grey-2'"
                  :text-color="ctx.is_own_tenant ? 'green-9' : 'grey-8'"
                  :clickable="selectable && ctx.is_pickable"
                  class="text-overline text-weight-bold"
                  @click.stop="selectable && ctx.is_pickable ? onSelectRow(ctx) : undefined"
                >
                  <span v-if="ctx.is_own_tenant">Own Stock</span>
                  <span v-else>{{ ctx.holding_tenant_name ?? 'Network' }}</span>
                  :
                  {{ ctx.allocated_qty > 0 ? ctx.allocated_qty : ctx.excellent_qty }}
                  <span
                    v-if="
                      mode === 'invoice' &&
                      ctx.is_own_tenant &&
                      ctx.allocated_qty === 0 &&
                      ctx.global_qty > 0
                    "
                    class="q-ml-xs text-orange-9"
                  >
                    (via network)
                  </span>
                </q-chip>
              </template>
            </div>
          </q-item-section>

          <q-item-section v-if="selectable" side>
            <q-btn
              flat
              round
              dense
              icon="add_circle"
              color="primary"
              :disable="!pickableContext(group)"
              @click.stop="onSelectGroup(group)"
            />
          </q-item-section>
        </q-item>
      </q-list>

      <div v-else-if="searchQuery.trim() && !loading" class="text-center q-pa-xl text-grey-6">
        <q-icon name="info" size="36px" class="q-mb-xs" />
        <div>No stock items found matching your search.</div>
      </div>

      <div v-else-if="!loading && mode !== 'invoice'" class="text-center q-pa-xl text-grey-5">
        <q-icon name="manage_search" size="48px" class="q-mb-sm" />
        <div>Search stock across your organization. Your allocations appear first.</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';

import { globalRepository } from 'src/modules/global/repositories/globalRepository';
import type {
  GlobalStockSearchField,
  StockNetworkMode,
  StockNetworkRow,
} from 'src/modules/global/types';
import {
  groupStockNetworkRows,
  type StockNetworkProductGroup,
} from 'src/modules/global/utils/mapStockNetworkRow';
import { formatAmountBdt } from 'src/utils/currency';

const formatCost = (val: number) => formatAmountBdt(val);

const props = withDefaults(
  defineProps<{
    mode: StockNetworkMode;
    contextTenantId: number;
    selectable?: boolean;
    showSearchControls?: boolean;
    initialSearch?: string;
  }>(),
  {
    selectable: false,
    showSearchControls: true,
    initialSearch: '',
  },
);

const emit = defineEmits<{
  (e: 'select', row: StockNetworkRow): void;
  (e: 'view', row: StockNetworkRow): void;
}>();

const searchField = ref<GlobalStockSearchField>('name');
const searchQuery = ref(props.initialSearch);
const results = ref<StockNetworkRow[]>([]);
const loading = ref(false);

const searchFieldOptions = [
  { label: 'Name', value: 'name' as const },
  { label: 'Barcode', value: 'barcode' as const },
  { label: 'Product Code', value: 'product_code' as const },
];

const searchPlaceholder = computed(() => {
  switch (searchField.value) {
    case 'barcode':
      return 'Search by barcode...';
    case 'product_code':
      return 'Search by product code...';
    default:
      return 'Search by product name...';
  }
});

const groupedResults = computed(() => groupStockNetworkRows(results.value));

let debounceTimer: ReturnType<typeof setTimeout> | null = null;

const runSearch = async () => {
  if (!props.contextTenantId) {
    results.value = [];
    return;
  }

  const query = searchQuery.value.trim();
  if (!query) {
    results.value = [];
    return;
  }

  loading.value = true;
  try {
    const result = await globalRepository.searchStockNetwork({
      context_tenant_id: props.contextTenantId,
      mode: props.mode,
      search: query,
      search_field: searchField.value,
      page_size: 50,
      skip_count: true,
    });
    results.value =
      props.mode === 'invoice' ? result.data.filter((row) => row.is_pickable) : result.data;
  } catch {
    results.value = [];
  } finally {
    loading.value = false;
  }
};

const onSearchInput = () => {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    void runSearch();
  }, 350);
};

const onCriteriaChange = () => {
  if (searchQuery.value.trim()) {
    void runSearch();
  }
};

const pickableContext = (group: StockNetworkProductGroup) =>
  group.contexts.find((ctx) => ctx.is_pickable) ?? group.contexts[0] ?? null;

const onSelectRow = (row: StockNetworkRow) => {
  if (!row.is_pickable && props.mode === 'invoice') return;
  emit('select', row);
};

const onSelectGroup = (group: StockNetworkProductGroup) => {
  const row = pickableContext(group);
  if (!row) return;
  onSelectRow(row);
};

watch(
  () => [props.contextTenantId, props.mode] as const,
  () => {
    if (searchQuery.value.trim()) {
      void runSearch();
    }
  },
  { immediate: true },
);

defineExpose({ refresh: runSearch });
</script>

<style scoped>
.scroll-area {
  max-height: 400px;
  overflow-y: auto;
}

.search-result-item {
  border-radius: 8px;
  margin: 4px 8px;
  transition: background 0.15s ease;
}

.search-result-item:hover {
  background: rgba(37, 99, 235, 0.05);
}

.search-input {
  border-radius: 8px;
}
</style>
