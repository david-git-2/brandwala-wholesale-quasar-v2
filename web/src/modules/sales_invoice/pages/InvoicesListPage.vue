<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden" :data-test="isParentTenant ? 'invoices-parent-list' : 'invoices-child-list'">
    <div class="invoice-list-stack column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner v-if="invoicesQuery.error.value" class="bw-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ invoicesQuery.error.value }}
      </q-banner>

      <q-card flat bordered class="q-pa-xs flex-shrink-0 list-toolbar-card">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="col-12 col-md-auto">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <button
                v-for="tab in channelTabs"
                :key="tab.value"
                type="button"
                class="quick-filter-pill"
                :class="{ 'quick-filter-pill--active': channelFilter === tab.value }"
                :data-test="`invoice-channel-${tab.value}`"
                @click="channelFilter = tab.value"
              >
                <span>{{ tab.label }}</span>
              </button>
            </div>
          </div>

          <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
            <q-select
              v-model="invoiceStatusFilter"
              :options="invoiceStatusOptions"
              outlined
              dense
              emit-value
              map-options
              options-dense
              style="min-width: 132px"
              class="dense-filter-select"
              data-test="invoice-status-filter"
            >
              <template #prepend>
                <q-icon name="ph ph-flag" size="14px" />
              </template>
            </q-select>

            <q-select
              v-model="statusFilter"
              :options="paymentStatusOptions"
              outlined
              dense
              emit-value
              map-options
              options-dense
              style="min-width: 150px"
              class="dense-filter-select"
              data-test="invoice-payment-filter"
            >
              <template #prepend>
                <q-icon name="ph ph-credit-card" size="14px" />
              </template>
            </q-select>

            <q-input
              v-model="searchText"
              outlined
              dense
              debounce="300"
              clearable
              style="min-width: 220px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search by ID, customer..."
              data-test="invoice-search"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" class="text-slate-400" />
              </template>
            </q-input>

            <q-btn-dropdown
              color="primary"
              unelevated
              no-caps
              dense
              class="rounded-sq-btn text-weight-bold q-px-sm"
              label="Create Invoice"
              icon="ph ph-plus"
              data-test="create-invoice-btn"
            >
            <q-list dense style="min-width: 220px">
              <q-item clickable v-close-popup data-test="create-wholesale-invoice" @click="goToCreateWholesale">
                <q-item-section avatar>
                  <q-icon name="ph ph-briefcase" color="purple" size="20px" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>Trade bill</q-item-label>
                  <q-item-label caption>Buyer on account</q-item-label>
                </q-item-section>
              </q-item>

              <q-item clickable v-close-popup data-test="create-retail-invoice" @click="goToCreateRetail">
                <q-item-section avatar>
                  <q-icon name="ph ph-tote" color="blue" size="20px" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>Retail</q-item-label>
                  <q-item-label caption>Customer on account</q-item-label>
                </q-item-section>
              </q-item>

              <q-item clickable v-close-popup data-test="create-walkin-invoice" @click="openCreateRetail('direct')">
                <q-item-section avatar>
                  <q-icon name="ph ph-lightning" color="positive" size="20px" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>Walk-in Direct</q-item-label>
                  <q-item-label caption>Counter sale, no profile</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
          </div>
        </div>
      </q-card>

      <div v-if="invoicesQuery.isLoading.value && !invoicesList.length" class="invoice-list-card col">
        <div class="invoice-list-scroll">
          <div v-for="n in 8" :key="n" class="invoice-list-item invoice-list-item--skeleton">
            <div class="invoice-info">
              <q-skeleton type="text" width="220px" height="18px" class="q-mb-xs" />
              <q-skeleton type="text" width="320px" height="13px" />
            </div>
            <div class="invoice-aside">
              <q-skeleton type="QBadge" width="75px" height="22px" class="rounded-borders" />
              <q-skeleton type="QBtn" size="xs" width="16px" height="16px" />
            </div>
          </div>
        </div>
      </div>

      <div
        v-else-if="!invoicesList.length && !hasActiveFilters"
        class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block col"
      >
        <q-icon name="ph ph-file-text" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-2xs">No invoices yet</div>
        <div class="text-caption text-grey-6 q-mb-md">
          Create a trade, retail, or walk-in invoice to get started.
        </div>
        <q-btn-dropdown
          color="primary"
          unelevated
          no-caps
          dense
          class="rounded-sq-btn text-weight-bold q-px-md"
          label="Create invoice"
          icon="ph ph-plus"
        >
          <q-list dense style="min-width: 220px">
            <q-item clickable v-close-popup @click="goToCreateWholesale">
              <q-item-section>Trade bill</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="goToCreateRetail">
              <q-item-section>Retail</q-item-section>
            </q-item>
            <q-item clickable v-close-popup @click="openCreateRetail('direct')">
              <q-item-section>Walk-in direct</q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
      </div>

      <div
        v-else-if="!invoicesList.length"
        class="column items-center justify-center text-center text-grey-7 q-py-xl col invoice-list-card"
      >
        <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
        <div class="text-subtitle2 text-weight-medium text-slate-800">No invoices found</div>
        <div class="text-caption text-grey-6 q-mt-xs">Try a different search or clear your filters.</div>
        <q-btn flat dense no-caps color="primary" label="Reset filters" class="q-mt-sm" @click="onResetFilters" />
      </div>

      <div v-else class="invoice-list-card col">
        <div class="invoice-list-scroll">
          <InvoiceListRow
            v-for="row in invoicesList"
            :key="row.id"
            :row="row"
            :show-sold-by="isParentTenant"
            @open="goToDetails"
          />

          <div v-if="hasMore" class="row justify-center q-py-sm">
            <q-btn
              flat
              dense
              no-caps
              :loading="loadingMore"
              class="load-more-btn text-weight-medium text-slate-700 q-px-md"
              label="Load more"
              icon="ph ph-arrow-down"
              @click="loadMoreInvoices"
            />
          </div>
        </div>
      </div>
    </div>

    <CreateRetailInvoiceDialog
      v-model="createRetailDialog"
      :parent-tenant-id="effectiveTenantId"
      :initial-mode="retailInitialMode"
      @created="onInvoiceCreated"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';

import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue';
import InvoiceListRow from '../components/InvoiceListRow.vue';
import { invoiceRepository } from '../repositories/invoiceRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import type { GlobalInvoiceCreated, GlobalInvoiceRow } from '../types';
import { useInvoiceWorkspace } from '../composables/useInvoiceWorkspace';

type InvoiceChannel = 'all' | 'wholesale' | 'retail' | 'walkin' | 'dropship';

const authStore = useAuthStore();
const tenantStore = useTenantStore();
const { isParentTenant } = useInvoiceWorkspace();
const router = useRouter();
const route = useRoute();
const queryClient = useQueryClient();

const effectiveTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.id;
});

const parseChannel = (raw: unknown): InvoiceChannel => {
  if (raw === 'wholesale' || raw === 'retail' || raw === 'dropship' || raw === 'walkin') return raw;
  if (raw === 'direct') return 'walkin';
  return 'all';
};

const initialSearch = typeof route.query.search === 'string' ? route.query.search : '';
const initialBillingProfileId =
  typeof route.query.billing_profile_id === 'string' && route.query.billing_profile_id
    ? Number(route.query.billing_profile_id)
    : null;
const initialQuickFilter =
  route.query.quick_filter === 'unpaid' || route.query.quick_filter === 'paid'
    ? (route.query.quick_filter as 'unpaid' | 'paid')
    : null;
const searchText = ref(initialSearch);
const statusFilter = ref<string | null>(
  typeof route.query.payment_status === 'string' ? route.query.payment_status : null,
);
const invoiceStatusFilter = ref<string | null>(
  typeof route.query.invoice_status === 'string' ? route.query.invoice_status : null,
);
const billingProfileFilter = ref<number | null>(
  initialBillingProfileId && Number.isFinite(initialBillingProfileId) ? initialBillingProfileId : null,
);
const quickFilter = ref<'all' | 'paid' | 'unpaid'>(initialQuickFilter ?? 'all');
const channelFilter = ref<InvoiceChannel>(parseChannel(route.query.type));

watch(
  () => route.query.search,
  (newSearch) => {
    if (typeof newSearch === 'string') {
      searchText.value = newSearch;
    } else if (newSearch === undefined) {
      searchText.value = '';
    }
  },
);

watch(
  () => route.query.type,
  (type) => {
    channelFilter.value = parseChannel(type);
  },
);

const PAGE_SIZE = 20;

const loadedPage = ref(1);
const appendedInvoices = ref<GlobalInvoiceRow[]>([]);
const loadingMore = ref(false);

const createRetailDialog = ref(route.query.create === 'walkin' || route.query.create === 'direct');
const retailInitialMode = ref<'account' | 'direct'>('direct');

const goToCreateWholesale = () => {
  void router.push({
    name: 'app-global-invoices-create-wholesale',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
  });
};

const goToCreateRetail = () => {
  void router.push({
    name: 'app-global-invoices-create-wholesale',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
    query: { type: 'retail' },
  });
};

const openCreateRetail = (mode: 'account' | 'direct') => {
  if (mode === 'account') {
    goToCreateRetail();
    return;
  }
  retailInitialMode.value = 'direct';
  createRetailDialog.value = true;
};

watch(
  () => route.query.create,
  (val) => {
    if (val === 'wholesale') goToCreateWholesale();
    if (val === 'retail') goToCreateRetail();
    if (val === 'walkin' || val === 'direct') openCreateRetail('direct');
  },
);

const channelTabs: { label: string; value: InvoiceChannel }[] = [
  { label: 'All', value: 'all' },
  { label: 'Trade', value: 'wholesale' },
  { label: 'Retail', value: 'retail' },
  { label: 'Walk-in', value: 'walkin' },
  { label: 'Dropship', value: 'dropship' },
];

const invoiceStatusOptions = [
  { label: 'All Statuses', value: null },
  { label: 'Draft', value: 'draft' },
  { label: 'Issued', value: 'issued' },
  { label: 'Voided', value: 'voided' },
];

const paymentStatusOptions = [
  { label: 'All Payments', value: null },
  { label: 'Paid', value: 'paid' },
  { label: 'Due', value: 'due' },
  { label: 'Partial', value: 'partial' },
  { label: 'Draft', value: 'draft' },
];

const listInvoiceType = computed(() => {
  if (channelFilter.value === 'wholesale' || channelFilter.value === 'dropship') {
    return channelFilter.value;
  }
  return null;
});

const listRetailBillingMode = computed(() => {
  if (channelFilter.value === 'walkin') return 'direct' as const;
  if (channelFilter.value === 'retail') return 'account' as const;
  return null;
});

const listQueryFilters = computed(() => ({
  search: searchText.value,
  paymentStatus: statusFilter.value,
  invoiceStatus: invoiceStatusFilter.value,
  invoiceType: listInvoiceType.value,
  retailBillingMode: listRetailBillingMode.value,
  billingProfileId: billingProfileFilter.value,
  quickFilter: quickFilter.value,
}));

const invoicesQuery = useQuery({
  queryKey: computed(() =>
    salesInvoiceQueryKeys.list(effectiveTenantId.value, {
      page: 1,
      pageSize: PAGE_SIZE,
      ...listQueryFilters.value,
    }),
  ),
  enabled: computed(() => !!effectiveTenantId.value),
  queryFn: async () => {
    const tenantId = effectiveTenantId.value;
    if (!tenantId) return { data: [], total: 0 };
    return invoiceRepository.listGlobalInvoices({
      ...(isParentTenant.value
        ? { parentTenantId: tenantId }
        : { issuedByTenantId: tenantId }),
      page: 1,
      pageSize: PAGE_SIZE,
      ...listQueryFilters.value,
    });
  },
  placeholderData: (prev) => prev,
});

const invoicesList = computed(() => [
  ...(invoicesQuery.data.value?.data ?? []),
  ...appendedInvoices.value,
]);

const listTotal = computed(() => invoicesQuery.data.value?.total ?? 0);

const hasMore = computed(() => invoicesList.value.length < listTotal.value);

const hasActiveFilters = computed(() => {
  return Boolean(
    statusFilter.value ||
      invoiceStatusFilter.value ||
      searchText.value ||
      channelFilter.value !== 'all',
  );
});

watch([searchText, statusFilter, invoiceStatusFilter, billingProfileFilter, quickFilter, channelFilter], () => {
  loadedPage.value = 1;
  appendedInvoices.value = [];
});

const loadMoreInvoices = async () => {
  if (loadingMore.value || !hasMore.value || !effectiveTenantId.value) return;
  loadingMore.value = true;
  try {
    const nextPage = loadedPage.value + 1;
    const result = await invoiceRepository.listGlobalInvoices({
      ...(isParentTenant.value
        ? { parentTenantId: effectiveTenantId.value }
        : { issuedByTenantId: effectiveTenantId.value }),
      page: nextPage,
      pageSize: PAGE_SIZE,
      ...listQueryFilters.value,
    });
    appendedInvoices.value = [...appendedInvoices.value, ...result.data];
    loadedPage.value = nextPage;
  } finally {
    loadingMore.value = false;
  }
};

const goToDetails = (row: GlobalInvoiceRow | GlobalInvoiceCreated) => {
  const isComposerDraft =
    (row.invoice_type === 'wholesale' ||
      (row.invoice_type === 'retail' && row.retail_billing_mode !== 'direct')) &&
    (row.invoice_status === 'draft' || row.invoice_status === 'proforma_generated');
  if (isComposerDraft) {
    void router.push({
      name: 'app-global-invoices-create-wholesale',
      params: {
        tenantSlug: authStore.tenantSlug || '',
      },
      query: {
        id: String(row.id),
        ...(row.invoice_type === 'retail' ? { type: 'retail' } : {}),
      },
    });
  } else {
    void router.push({
      name: 'app-global-invoice-details-page',
      params: {
        tenantSlug: authStore.tenantSlug,
        id: row.id,
      },
    });
  }
};

const onInvoiceCreated = (invoice: GlobalInvoiceCreated) => {
  void queryClient.invalidateQueries({ queryKey: salesInvoiceQueryKeys.root });
  goToDetails(invoice);
};

const onResetFilters = () => {
  statusFilter.value = null;
  invoiceStatusFilter.value = null;
  channelFilter.value = 'all';
  searchText.value = '';
};
</script>

<style scoped lang="scss">
@import '../styles/invoice-list.scss';

.page-fixed-layout {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
  background: var(--bw-neutral-canvas, #f8fafc);
}

.list-toolbar-card {
  background: var(--bw-neutral-surface, #ffffff);
  border-radius: var(--bw-radius-sm, 8px);
  border: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.quick-filter-toggle {
  display: flex;
  align-items: center;
  background: #f1f5f9;
  border-radius: var(--bw-radius-sm, 8px);
  padding: 2px;
  gap: 2px;
}

.quick-filter-pill {
  border: none;
  background: transparent;
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 500;
  color: #64748b;
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  transition: all 0.15s ease;
}

.quick-filter-pill:hover {
  color: #0f172a;
}

.quick-filter-pill--active {
  background: var(--bw-neutral-surface, #ffffff);
  color: #0f172a;
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

.dense-filter-select :deep(.q-field__control) {
  height: 34px;
  min-height: 34px;
  border-radius: 8px;
  padding: 0 8px;
}

.dense-filter-select :deep(.q-field__marginal) {
  height: 34px;
}

.dense-filter-select :deep(.q-field__native) {
  padding-top: 0;
  padding-bottom: 0;
  font-size: 12px;
  font-weight: 600;
}

.dense-search-input :deep(.q-field__control) {
  height: 34px;
  min-height: 34px;
  border-radius: 8px;
  padding: 0 12px;
}

.dense-search-input :deep(.q-field__marginal) {
  height: 34px;
}

.dense-search-input :deep(.q-field__native) {
  font-size: 12px;
}

.rounded-sq-btn {
  border-radius: 8px;
  height: 34px;
}

.line-clamp-1 {
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
}

.text-xxs {
  font-size: 9.5px;
  line-height: 1.1;
}

.text-xs {
  font-size: 11.5px;
}

.text-slate-400 {
  color: #94a3b8;
}

.text-slate-800 {
  color: #1e293b;
}
</style>
