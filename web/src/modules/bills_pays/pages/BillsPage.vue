<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden invoice-list-stack">
      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search bill no, profile, or ID…"
        :filter-count="0"
        @update:search="onSearchTextUpdate"
      >
        <template #pills>
          <div class="row items-center q-gutter-x-xs quick-filter-toggle">
            <button
              v-for="tab in filterTabs"
              :key="tab.value"
              type="button"
              class="quick-filter-pill"
              :class="{ 'quick-filter-pill--active': statusPill === tab.value }"
              @click="setStatusPill(tab.value)"
            >
              <span>{{ tab.label }}</span>
            </button>
          </div>
        </template>
        <template #trailing>
          <q-btn
            flat
            dense
            no-caps
            icon="ph ph-palette"
            label="Brands"
            class="text-slate-600"
            @click="goBrands"
          />
          <q-btn
            unelevated
            dense
            no-caps
            color="primary"
            icon="ph ph-plus"
            label="New bill"
            @click="goCompose"
          />
        </template>
      </ProcurementOpsListToolbar>

      <div v-if="listQuery.isError.value" class="bw-status-banner bg-negative text-white q-pa-sm rounded-borders">
        {{ listErrorMessage }}
      </div>

      <div
        v-if="listQuery.isPending.value && !listQuery.data.value?.data.length"
        class="invoice-list-card col"
      >
        <div class="invoice-list-scroll">
          <div v-for="n in 8" :key="n" class="invoice-list-item invoice-list-item--skeleton">
            <q-skeleton type="text" width="60%" />
          </div>
        </div>
      </div>

      <div
        v-else-if="!rows.length && !debouncedSearch && statusPill === 'all'"
        class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
      >
        <q-icon name="ph ph-receipt" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800">No bills yet</div>
        <div class="text-caption text-grey-6 q-mt-xs">Issued bills from trade, retail, and dropship appear here.</div>
      </div>

      <div
        v-else-if="!rows.length"
        class="column items-center justify-center text-grey-7 q-py-xl col invoice-list-card"
      >
        <q-icon name="ph ph-magnifying-glass" size="36px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium">No bills match</div>
      </div>

      <div v-else class="invoice-list-card col">
        <div class="invoice-list-scroll">
          <BillListRow v-for="row in rows" :key="row.id" :row="row" @open="openBill" />
          <div v-if="hasMore" class="row justify-center q-py-sm">
            <q-btn
              flat
              dense
              no-caps
              :loading="listQuery.isFetching.value"
              class="load-more-btn text-weight-medium q-px-md"
              label="Load more"
              icon="ph ph-arrow-down"
              @click="loadMore"
            />
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
import BillListRow from '../components/BillListRow.vue';
import { useBillsListQuery } from '../composables/useBillsListQuery';
import type { GlobalInvoiceRow } from 'src/modules/sales_invoice/types';

type StatusPill = 'all' | 'due' | 'partial' | 'paid' | 'voided';

const PAGE_SIZE = 25;

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const searchText = ref('');
const debouncedSearch = ref('');
const statusPill = ref<StatusPill>('all');
const page = ref(1);
const accumulatedRows = ref<GlobalInvoiceRow[]>([]);

let searchTimer: ReturnType<typeof setTimeout> | null = null;

const filterTabs: { label: string; value: StatusPill }[] = [
  { label: 'All', value: 'all' },
  { label: 'Due', value: 'due' },
  { label: 'Partial', value: 'partial' },
  { label: 'Paid', value: 'paid' },
  { label: 'Voided', value: 'voided' },
];

const tenantScope = computed(() => {
  const tenant = authStore.selectedTenant;
  if (!tenant?.id) return { parentTenantId: null as number | null, issuedByTenantId: null as number | null };
  if (tenant.parent_id) {
    return { parentTenantId: tenant.parent_id, issuedByTenantId: tenant.id };
  }
  return { parentTenantId: tenant.id, issuedByTenantId: null };
});

const listParams = computed(() => {
  const base = {
    ...tenantScope.value,
    page: page.value,
    pageSize: PAGE_SIZE,
    search: debouncedSearch.value || undefined,
  };
  switch (statusPill.value) {
    case 'due':
      return { ...base, invoiceStatus: 'issued', paymentStatus: 'due' };
    case 'partial':
      return { ...base, paymentStatus: 'partially_paid' };
    case 'paid':
      return { ...base, quickFilter: 'paid' as const };
    case 'voided':
      return { ...base, invoiceStatus: 'voided' };
    default:
      return base;
  }
});

const listQuery = useBillsListQuery(listParams);

const rows = computed(() => accumulatedRows.value);
const total = computed(() => listQuery.data.value?.total ?? 0);
const hasMore = computed(() => accumulatedRows.value.length < total.value);

const listErrorMessage = computed(() => {
  const err = listQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load bills.';
});

watch(
  () => listQuery.data.value,
  (payload) => {
    if (!payload) return;
    if (page.value === 1) {
      accumulatedRows.value = payload.data;
    } else {
      const existingIds = new Set(accumulatedRows.value.map((r) => r.id));
      const next = payload.data.filter((r) => !existingIds.has(r.id));
      accumulatedRows.value = [...accumulatedRows.value, ...next];
    }
  },
);

watch([statusPill, debouncedSearch], () => {
  page.value = 1;
  accumulatedRows.value = [];
});

const onSearchTextUpdate = (value: string) => {
  searchText.value = value;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = value.trim();
  }, 300);
};

const setStatusPill = (value: StatusPill) => {
  statusPill.value = value;
};

const loadMore = () => {
  if (!hasMore.value || listQuery.isFetching.value) return;
  page.value += 1;
};

const tenantSlugParam = () =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;

const goCompose = () => {
  router.push({
    name: 'app-bill-compose-page',
    params: tenantSlugParam() ? { tenantSlug: tenantSlugParam() } : {},
  });
};

const goBrands = () => {
  router.push({
    name: 'app-bill-brands-page',
    params: tenantSlugParam() ? { tenantSlug: tenantSlugParam() } : {},
  });
};

const openBill = (row: GlobalInvoiceRow) => {
  const tenantSlug = tenantSlugParam();
  const isDraft =
    row.invoice_status === 'draft' || row.invoice_status === 'proforma_generated';
  if (isDraft) {
    router.push({
      name: 'app-bill-compose-page',
      params: tenantSlug ? { tenantSlug } : {},
      query: { id: String(row.id) },
    });
    return;
  }
  router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(row.id),
    },
  });
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';

.page-fixed-layout {
  height: calc(100vh - 55px);
}

.quick-filter-pill {
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  background: var(--bw-neutral-surface, #fff);
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 500;
  color: #64748b;
  cursor: pointer;
}

.quick-filter-pill--active {
  background: #0d6b5c;
  border-color: #0d6b5c;
  color: #fff;
}
</style>
