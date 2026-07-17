<template>
  <div class="network-stock-search">
    <div v-if="showSearchControls" class="row q-col-gutter-sm items-center q-mb-md">
      <div class="col-12 col-sm-3">
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
      <div class="col-12 col-sm-4">
        <q-select
          v-model="selectedShipmentId"
          :options="shipmentOptions"
          outlined
          dense
          emit-value
          map-options
          option-label="label"
          option-value="value"
          label="Filter Shipment"
          class="soft-input"
          clearable
          :loading="loadingShipments"
          @update:model-value="onCriteriaChange"
        />
      </div>
      <div class="col-12 col-sm-5">
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
            <q-spinner v-if="loading || resolvingCosts" size="20px" color="primary" />
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
                Cost: BDT {{ formatGroupCost(group) }}
              </span>
            </q-item-label>
            <q-item-label caption class="text-grey-7 row q-gutter-x-md">
              <span v-if="group.product_code">Code: {{ group.product_code }}</span>
              <span v-if="group.barcode">Barcode: {{ group.barcode }}</span>
              <span v-if="getShipmentNames(group)" class="text-primary text-weight-bold">
                Shipment: {{ getShipmentNames(group) }}
              </span>
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
import { supabase } from 'src/boot/supabase';

import { createShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import { globalRepository } from 'src/modules/global/repositories/globalRepository';
import type {
  GlobalStockSearchField,
  StockNetworkMode,
  StockNetworkRow,
} from 'src/modules/global/types';
import {
  groupStockNetworkRows,
  pickableContext,
  type StockNetworkProductGroup,
} from 'src/modules/global/utils/mapStockNetworkRow';
import { resolveGlobalStockUnitCost } from 'src/modules/global/utils/resolveGlobalStockUnitCost';
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

const searchField = ref<GlobalStockSearchField>('all');
const searchQuery = ref(props.initialSearch);
const selectedShipmentId = ref<number | null>(null);
const shipments = ref<Array<{ id: number; name: string; tenant_shipment_id: number | null }>>([]);
const loadingShipments = ref(false);

const shipmentOptions = computed(() => {
  const opts = shipments.value.map((s) => ({
    label: `${s.tenant_shipment_id ? '#' + s.tenant_shipment_id + ' - ' : ''}${s.name}`,
    value: s.id,
  }));
  return [{ label: 'All Shipments', value: null }, ...opts];
});

const loadShipments = async () => {
  if (!props.contextTenantId) return;
  loadingShipments.value = true;
  try {
    const { data: parentTenantId, error: resolveError } = await supabase.rpc(
      'resolve_parent_tenant_id',
      { p_tenant_id: props.contextTenantId },
    );
    if (resolveError) throw resolveError;

    const targetTenantId = parentTenantId || props.contextTenantId;

    const { data, error } = await supabase
      .from('global_shipments')
      .select('id, name, tenant_shipment_id')
      .eq('parent_tenant_id', targetTenantId)
      .eq('status', 'Ready Stock')
      .order('id', { ascending: false });
    if (error) throw error;
    shipments.value = data || [];
  } catch (err) {
    console.error('Failed to load shipments for filter:', err);
  } finally {
    loadingShipments.value = false;
  }
};

const results = ref<StockNetworkRow[]>([]);
const loading = ref(false);
const resolvingCosts = ref(false);
const costingCache = createShipmentItemsCostingCache();

const searchFieldOptions = [
  { label: 'All Fields', value: 'all' as const },
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
    case 'name':
      return 'Search by product name...';
    default:
      return 'Search stock...';
  }
});

const getShipmentNames = (group: StockNetworkProductGroup) => {
  const names = group.contexts
    .map((ctx) => ctx.shipment_name)
    .filter((name): name is string => typeof name === 'string' && name.trim() !== '');
  const uniqueNames = Array.from(new Set(names));
  return uniqueNames.join(', ');
};

const groupedResults = computed(() => groupStockNetworkRows(results.value));

const formatGroupCost = (group: StockNetworkProductGroup) => {
  const ctx = pickableContext(group);
  const cost = ctx?.resolvedUnitCost ?? group.resolvedUnitCost;
  if (cost == null) return resolvingCosts.value ? '…' : '—';
  return formatCost(cost);
};

let debounceTimer: ReturnType<typeof setTimeout> | null = null;

const resolveResultCosts = async (rows: StockNetworkRow[]) => {
  if (!rows.length) {
    results.value = [];
    return;
  }

  resolvingCosts.value = true;
  try {
    await costingCache.prefetchShipmentItems(rows.map((row) => row.shipment_id));
    const resolved = await Promise.all(
      rows.map(async (row) => ({
        ...row,
        resolvedUnitCost: await resolveGlobalStockUnitCost(row, costingCache),
      })),
    );
    results.value = resolved;
  } catch {
    results.value = rows;
  } finally {
    resolvingCosts.value = false;
  }
};

const runSearch = async () => {
  if (!props.contextTenantId) {
    results.value = [];
    return;
  }

  const query = searchQuery.value?.trim() || '';
  if (!query && !selectedShipmentId.value) {
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
      shipment_id: selectedShipmentId.value,
      page_size: 50,
      skip_count: true,
    });
    const rows =
      props.mode === 'invoice' ? result.data.filter((row) => row.is_pickable) : result.data;
    await resolveResultCosts(rows);
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
  void runSearch();
};

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
    void loadShipments();
    if (searchQuery.value?.trim() || selectedShipmentId.value) {
      void runSearch();
    }
  },
  { immediate: true },
);

defineExpose({ refresh: runSearch, costingCache });
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
