<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden invoice-list-stack">
      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search parties…"
        :filter-count="0"
        @update:search="onSearchTextUpdate"
      >
        <template #pills>
          <TfDrawerSectionTabs
            v-model="entityType"
            :tabs="typeSectionTabs"
            aria-label="Cashbook party type"
            @update:model-value="setEntityType"
          />
        </template>
      </ProcurementOpsListToolbar>

      <div v-if="isError" class="tf-status-banner bg-negative text-white q-pa-sm rounded-borders">
        {{ errorMessage }}
      </div>

      <div v-if="isPending && !rows.length" class="invoice-list-card col">
        <div class="invoice-list-scroll">
          <div v-for="n in 6" :key="n" class="invoice-list-item invoice-list-item--skeleton">
            <q-skeleton type="text" width="60%" />
          </div>
        </div>
      </div>

      <div
        v-else-if="!rows.length"
        class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
      >
        <q-icon name="ph ph-wallet" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle2">No parties with cashbook activity</div>
      </div>

      <div v-else class="invoice-list-card col">
        <div class="invoice-list-scroll">
          <CashbookEntityRow v-for="row in rows" :key="`${row.entity_type}-${row.entity_id}`" :row="row" @open="openParty" />
          <div v-if="entityType !== 'tenant' && hasMore" class="row justify-center q-py-sm">
            <q-btn flat dense no-caps class="load-more-btn q-px-md" label="Load more" icon="ph ph-arrow-down" @click="offset += PAGE_SIZE" />
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import CashbookEntityRow from '../components/CashbookEntityRow.vue';
import { useCashbookEntitiesQuery } from '../composables/useCashbookEntitiesQuery';
import type { CashbookEntityRow as EntityRow } from '../repositories/cashbookRepository';

const PAGE_SIZE = 50;

type EntityPill = 'tenant' | 'customer' | 'courier' | 'vendor';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const searchText = ref('');
const debouncedSearch = ref('');
const entityType = ref<EntityPill>('tenant');
const offset = ref(0);
const accumulatedRows = ref<EntityRow[]>([]);

const typeTabs: { label: string; value: EntityPill }[] = [
  { label: 'Us', value: 'tenant' },
  { label: 'Customer', value: 'customer' },
  { label: 'Courier', value: 'courier' },
  { label: 'Vendor', value: 'vendor' },
];

const typeSectionTabs = typeTabs.map((tab) => ({ name: tab.value, label: tab.label }));

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const queryParams = computed(() => ({
  tenantId: operatingTenantId.value,
  booksTenantId: booksTenantId.value,
  entityType: entityType.value,
  search: debouncedSearch.value || undefined,
  offset: offset.value,
  limit: PAGE_SIZE,
}));

const { tenantCashQuery, entitiesQuery } = useCashbookEntitiesQuery(queryParams);

const isPending = computed(() =>
  entityType.value === 'tenant' ? tenantCashQuery.isPending.value : entitiesQuery.isPending.value,
);
const isError = computed(() =>
  entityType.value === 'tenant' ? tenantCashQuery.isError.value : entitiesQuery.isError.value,
);
const errorMessage = computed(() => {
  const err =
    entityType.value === 'tenant' ? tenantCashQuery.error.value : entitiesQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load cashbook.';
});

watch(
  () => (entityType.value === 'tenant' ? tenantCashQuery.data.value : entitiesQuery.data.value),
  (payload) => {
    if (entityType.value === 'tenant') {
      accumulatedRows.value = payload ? [payload as EntityRow] : [];
      return;
    }
    const list = (payload as EntityRow[] | undefined) ?? [];
    if (offset.value === 0) accumulatedRows.value = list;
    else {
      const ids = new Set(accumulatedRows.value.map((r) => r.entity_id));
      accumulatedRows.value = [...accumulatedRows.value, ...list.filter((r) => !ids.has(r.entity_id))];
    }
  },
);

const rows = computed(() => accumulatedRows.value);
const hasMore = computed(
  () => entityType.value !== 'tenant' && (entitiesQuery.data.value?.length ?? 0) >= PAGE_SIZE,
);

watch([entityType, debouncedSearch], () => {
  offset.value = 0;
  accumulatedRows.value = [];
});

let searchTimer: ReturnType<typeof setTimeout> | null = null;
const onSearchTextUpdate = (value: string) => {
  searchText.value = value;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = value.trim();
  }, 300);
};

const setEntityType = (value: string | number) => {
  entityType.value = value as EntityPill;
};

const routeParams = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  return tenantSlug ? { tenantSlug } : {};
};

const openParty = (row: EntityRow) => {
  router.push({
    name: 'app-cashbook-party-page',
    params: {
      ...routeParams(),
      entityType: row.entity_type,
      entityId: String(row.entity_id),
    },
  });
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
.page-fixed-layout {
  height: calc(100vh - 55px);
}
</style>
