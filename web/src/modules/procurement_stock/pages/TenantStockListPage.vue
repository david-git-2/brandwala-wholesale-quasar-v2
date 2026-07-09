<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Tenant Stock"
        subtitle="Your allocated stock slices ready for invoicing and sales"
      />

      <q-banner
        v-if="allocationStore.error"
        class="bw-status-banner bg-negative text-white q-mb-md"
      >
        {{ allocationStore.error }}
      </q-banner>

      <!-- Search & Filters Toolbar -->
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          filled
          dense
          clearable
          class="col-grow"
          placeholder="Search by product name, code, barcode, or sister concern..."
          @keyup.enter="onSearch"
          @clear="onSearch"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" @click="openFilterDrawer">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>

      <!-- Filter Sidebar -->
      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <div class="q-gutter-y-md q-pa-sm">
          <!-- Only show Child Tenant filter if caller is in parent context -->
          <q-select
            v-if="isParentContext"
            v-model="draftChildTenantFilter"
            :options="childTenantOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Sister Concern (Child Tenant)"
          />

          <q-select
            v-model="draftStockTypeFilter"
            :options="stockTypeOptions"
            filled
            dense
            clearable
            emit-value
            map-options
            label="Stock Type"
          />

          <div class="row justify-end q-gutter-x-sm q-mt-md">
            <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
            <q-btn
              unelevated
              no-caps
              label="Apply Filters"
              color="primary"
              @click="onApplyDrawerFilters"
            />
          </div>
        </div>
      </FilterSidebar>

      <PageInitialLoader v-if="allocationStore.loading && !allocationStore.rows.length" />

      <!-- Allocations Table -->
      <q-card v-else flat bordered class="q-pa-none">
        <q-table
          flat
          :rows="allocationStore.rows"
          :columns="columns"
          row-key="id"
          :loading="allocationStore.loading"
          v-model:pagination="pagination"
          :rows-per-page-options="[10, 20, 50]"
          @request="onTableRequest"
        >
          <template #body-cell-image="props">
            <q-td :props="props">
              <q-avatar rounded size="42px" class="bg-grey-2">
                <img
                  :src="props.row.image_url || 'https://placehold.co/56x56?text=No+Image'"
                  alt="Product Image"
                  style="object-fit: contain"
                />
              </q-avatar>
            </q-td>
          </template>

          <template #body-cell-product="props">
            <q-td :props="props">
              <div class="text-weight-bold text-grey-9">{{ props.row.item_name }}</div>
              <div class="text-caption text-grey-6 row q-gutter-x-sm">
                <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
              </div>
            </q-td>
          </template>

          <template #body-cell-quantity="props">
            <q-td :props="props" class="text-weight-bold text-primary">
              {{ props.row.quantity }} pcs
            </q-td>
          </template>

          <template #body-cell-unit_cost="props">
            <q-td :props="props" class="text-right text-secondary">
              ৳{{ formatCost(getUnitCost(props.row)) }}
            </q-td>
          </template>

          <template #body-cell-total_cost="props">
            <q-td :props="props" class="text-right text-weight-bold text-secondary">
              ৳{{ formatCost(getUnitCost(props.row) * props.row.quantity) }}
            </q-td>
          </template>

          <template #no-data>
            <div class="full-width text-center text-grey-7 q-py-lg">
              <q-icon name="inventory_2" size="48px" class="q-mb-sm text-grey-4" />
              <div>No Tenant Stock Allocations Found.</div>
            </div>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useTenantStockStore } from '../stores/tenantStockStore';
import { useGlobalStockTypeStore } from '../stores/globalStockTypeStore';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { createShipmentItemsCostingCache } from 'src/modules/global/composables/useShipmentItemsCostingCache';
import {
  isGlobalStockCostingInput,
  resolveGlobalStockUnitCostSync,
} from 'src/modules/global/utils/resolveGlobalStockUnitCost';
import type { GlobalStockAllocation } from '../repositories/globalStockAllocationRepository';

const authStore = useAuthStore();
const tenantStore = useTenantStore();
const allocationStore = useTenantStockStore();
const stockTypeStore = useGlobalStockTypeStore();
const costingCache = createShipmentItemsCostingCache();

// Filter State
const searchText = ref('');
const filterDrawerOpen = ref(false);
const childTenantFilter = ref<number | null>(null);
const stockTypeFilter = ref<number | null>(null);

const draftChildTenantFilter = ref<number | null>(null);
const draftStockTypeFilter = ref<number | null>(null);

const childTenants = ref<{ id: number; name: string }[]>([]);

const columns: QTableColumn[] = [
  {
    name: 'child_tenant',
    label: 'Sister Concern',
    field: 'child_tenant_name',
    align: 'left',
    sortable: false,
  },
  { name: 'image', label: 'Image', field: 'image_url', align: 'left', sortable: false },
  { name: 'product', label: 'Product Details', field: 'item_name', align: 'left', sortable: false },
  { name: 'shipment', label: 'Shipment', field: 'shipment_name', align: 'left', sortable: false },
  {
    name: 'stock_type',
    label: 'Stock Type',
    field: 'stock_type_description',
    align: 'left',
    sortable: false,
  },
  {
    name: 'unit_cost',
    label: 'Unit Cost (Est. BDT)',
    field: 'id',
    align: 'right',
    sortable: false,
  },
  {
    name: 'total_cost',
    label: 'Total Value (Est. BDT)',
    field: 'id',
    align: 'right',
    sortable: false,
  },
  {
    name: 'quantity',
    label: 'Allocated Quantity',
    field: 'quantity',
    align: 'right',
    sortable: false,
  },
];

// Computed properties for Context Verification
const contextTenantId = computed(() => tenantStore.selectedTenantId ?? authStore.tenantId ?? null);
const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.parent_id ?? current.id;
});
const isParentContext = computed(() => {
  return (
    contextTenantId.value !== null &&
    effectiveParentTenantId.value !== null &&
    contextTenantId.value === effectiveParentTenantId.value
  );
});

const pagination = computed({
  get: () => ({
    page: allocationStore.page,
    rowsPerPage: allocationStore.pageSize,
    rowsNumber: allocationStore.total,
  }),
  set: (val) => {
    allocationStore.page = val.page;
    allocationStore.pageSize = val.rowsPerPage;
  },
});

const activeFilterCount = computed(() => {
  let count = 0;
  if (childTenantFilter.value !== null) count++;
  if (stockTypeFilter.value !== null) count++;
  return count;
});

const stockTypeOptions = computed(() => {
  return stockTypeStore.items.map((t) => ({ label: t.description, value: t.id }));
});

const childTenantOptions = computed(() => {
  return childTenants.value.map((t) => ({ label: t.name, value: t.id }));
});

const getUnitCost = (row: GlobalStockAllocation): number => {
  if (!isGlobalStockCostingInput(row)) return 0;
  return resolveGlobalStockUnitCostSync(row, costingCache.getSync(row.shipment_id));
};

const formatCost = (val: number): string => {
  return val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

const loadAllocations = async () => {
  if (!authStore.tenantId) return;
  await allocationStore.fetchAllocations(authStore.tenantId, {
    page: allocationStore.page,
    pageSize: allocationStore.pageSize,
    search: searchText.value.trim() || null,
    childTenantId: isParentContext.value ? childTenantFilter.value : null,
    stockTypeId: stockTypeFilter.value,
  });
  await costingCache.prefetchShipmentItems(
    allocationStore.rows.map((row) => row.shipment_id),
  );
};

const onTableRequest = async (props: any) => {
  allocationStore.page = props.pagination.page;
  allocationStore.pageSize = props.pagination.rowsPerPage;
  await loadAllocations();
};

const onSearch = () => {
  allocationStore.page = 1;
  void loadAllocations();
};

// Filter Actions
const openFilterDrawer = () => {
  draftChildTenantFilter.value = childTenantFilter.value;
  draftStockTypeFilter.value = stockTypeFilter.value;
  filterDrawerOpen.value = true;
};

const onApplyDrawerFilters = () => {
  childTenantFilter.value = draftChildTenantFilter.value;
  stockTypeFilter.value = draftStockTypeFilter.value;
  filterDrawerOpen.value = false;
  allocationStore.page = 1;
  void loadAllocations();
};

const onResetFilters = () => {
  draftChildTenantFilter.value = null;
  draftStockTypeFilter.value = null;
  childTenantFilter.value = null;
  stockTypeFilter.value = null;
  filterDrawerOpen.value = false;
  allocationStore.page = 1;
  void loadAllocations();
};

const loadChildren = async () => {
  if (!authStore.tenantId) return;
  try {
    const { data, error: err } = await supabase
      .from('tenants')
      .select('id, name')
      .eq('parent_id', authStore.tenantId);
    if (err) throw err;
    childTenants.value = data || [];
  } catch (err: any) {
    console.error('Failed to load child concerns', err);
  }
};

onMounted(async () => {
  if (authStore.tenantId) {
    await stockTypeStore.fetchStockTypes(authStore.tenantId);
    if (isParentContext.value) {
      await loadChildren();
    }
  }
  void loadAllocations();
});

watch(
  () => [contextTenantId.value, isParentContext.value] as const,
  async ([newTenantId, parentCtx]) => {
    if (newTenantId) {
      await stockTypeStore.fetchStockTypes(newTenantId);
      if (parentCtx) {
        await loadChildren();
      } else {
        childTenants.value = [];
      }
      allocationStore.page = 1;
      void loadAllocations();
    }
  },
);
</script>
