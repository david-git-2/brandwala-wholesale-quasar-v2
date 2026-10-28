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
          <div class="row items-center q-gutter-x-sm no-wrap">
            <TfDrawerSectionTabs
              v-model="arSide"
              :tabs="arSectionTabs"
              ariaLabel="Receivable or payable"
              @update:model-value="setArSide"
            />
            <TfDrawerSectionTabs
              v-model="statusPill"
              :tabs="statusSectionTabs"
              ariaLabel="Bill status"
              @update:model-value="setStatusPill"
            />
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
            v-if="arSide === 'they_owe'"
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

      <div v-if="listQuery.isError.value" class="tf-status-banner bg-negative text-white q-pa-sm rounded-borders">
        {{ listErrorMessage }}
      </div>

      <div
        v-if="listQuery.isPending.value && !rows.length"
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
        v-else-if="!rows.length && statusPill === 'draft'"
        class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
      >
        <q-icon name="ph ph-file-dashed" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800">No draft bills</div>
        <div class="text-caption text-grey-6 q-mt-xs">
          Unissued bills from compose or open shipment costs appear here.
        </div>
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
              :loading="listQuery.isFetchingNextPage.value"
              class="load-more-btn text-weight-medium q-px-md"
              label="Load more"
              icon="ph ph-arrow-down"
              @click="loadMore"
            />
          </div>
          <div
            v-else-if="rows.length"
            class="row justify-center q-py-sm text-caption text-grey-6"
          >
            End of list
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import BillListRow from '../components/BillListRow.vue';
import { useBillsListInfiniteQuery } from '../composables/useBillsListInfiniteQuery';
import type { BillListRow as BillListRowData } from '../types/billList';

type StatusPill = 'all' | 'draft' | 'due' | 'partial' | 'paid' | 'voided';
type ArSide = 'they_owe' | 'we_owe';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const searchText = ref('');
const debouncedSearch = ref('');
const statusPill = ref<StatusPill>('all');
const arSide = ref<ArSide>('they_owe');
let searchTimer: ReturnType<typeof setTimeout> | null = null;

const arTabs: { label: string; value: ArSide }[] = [
  { label: 'They owe', value: 'they_owe' },
  { label: 'We owe', value: 'we_owe' },
];

const filterTabs: { label: string; value: StatusPill }[] = [
  { label: 'All', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'Due', value: 'due' },
  { label: 'Partial', value: 'partial' },
  { label: 'Paid', value: 'paid' },
  { label: 'Voided', value: 'voided' },
];

const arSectionTabs = arTabs.map((tab) => ({ name: tab.value, label: tab.label }));
const statusSectionTabs = filterTabs.map((tab) => ({ name: tab.value, label: tab.label }));

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
    search: debouncedSearch.value || undefined,
    arSide: arSide.value,
  };
  switch (statusPill.value) {
    case 'draft':
      return { ...base, invoiceStatus: 'draft' };
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

const listQuery = useBillsListInfiniteQuery(listParams);

const rows = listQuery.rows;
const hasMore = listQuery.hasMore;

const listErrorMessage = computed(() => {
  const err = listQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load bills.';
});

const setArSide = (value: string | number) => {
  arSide.value = value as ArSide;
};

const onSearchTextUpdate = (value: string | null | undefined) => {
  searchText.value = value ?? '';
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = (value ?? '').trim();
  }, 300);
};

const setStatusPill = (value: string | number) => {
  statusPill.value = value as StatusPill;
};

const loadMore = () => {
  if (!hasMore.value || listQuery.isFetchingNextPage.value) return;
  void listQuery.fetchNextPage();
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

const openBill = (row: BillListRowData) => {
  const tenantSlug = tenantSlugParam();
  const detailRoute = {
    name: 'app-bill-detail-page' as const,
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(row.id),
    },
  };

  // Shipment AP and other payables are not edited on the AR compose desk.
  if (row.invoice_type === 'ap') {
    router.push(detailRoute);
    return;
  }

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
  router.push(detailRoute);
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';

.page-fixed-layout {
  height: calc(100vh - 55px);
}

</style>
