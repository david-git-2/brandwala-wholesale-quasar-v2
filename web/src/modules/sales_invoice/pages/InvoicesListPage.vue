<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden" :data-test="isParentTenant ? 'invoices-parent-list' : 'invoices-child-list'">
    <q-banner v-if="invoicesQuery.error.value" class="bw-status-banner bg-negative text-white q-mb-xs flex-shrink-0" dense rounded>
      {{ invoicesQuery.error.value }}
    </q-banner>

    <q-card flat bordered class="q-pa-xs flex-shrink-0 q-mb-xs">
      <div class="row items-center justify-between q-col-gutter-xs">
        <div class="col-12 col-md-auto row items-center q-gutter-x-xs">
          <div class="row items-center q-gutter-x-xs quick-filter-toggle">
            <q-btn
              v-for="tab in channelTabs"
              :key="tab.value"
              dense
              unelevated
              no-caps
              :color="channelFilter === tab.value ? 'primary' : 'transparent'"
              :text-color="channelFilter === tab.value ? 'white' : 'grey-8'"
              class="quick-filter-btn text-xs"
              :data-test="`invoice-channel-${tab.value}`"
              @click="channelFilter = tab.value"
            >
              {{ tab.label }}
            </q-btn>
          </div>

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
        </div>

        <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
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
              <q-icon name="ph ph-magnifying-glass" size="16px" />
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
                  <q-item-label>Wholesale</q-item-label>
                  <q-item-label caption>B2B credit sale</q-item-label>
                </q-item-section>
              </q-item>

              <q-item clickable v-close-popup data-test="create-retail-invoice" @click="openCreateRetail('account')">
                <q-item-section avatar>
                  <q-icon name="ph ph-tote" color="blue" size="20px" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>Retail</q-item-label>
                  <q-item-label caption>Linked customer profile</q-item-label>
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

    <div v-if="invoicesQuery.isLoading.value && !invoicesList.length" class="treasury-table-wrap col">
      <q-markup-table flat bordered class="invoice-table full-height">
        <thead>
          <tr>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="70px" /></th>
            <th><q-skeleton type="text" width="120px" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th class="text-right"><q-skeleton type="text" width="90px" class="q-ml-auto" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 8" :key="n">
            <td>
              <q-skeleton type="text" width="90px" height="16px" />
            </td>
            <td><q-skeleton type="QBadge" width="70px" height="18px" /></td>
            <td>
              <div class="row items-center no-wrap">
                <q-skeleton type="QAvatar" size="28px" class="q-mr-sm" />
                <div class="col">
                  <q-skeleton type="text" width="70%" height="14px" />
                  <q-skeleton type="text" width="50%" height="10px" />
                </div>
              </div>
            </td>
            <td><q-skeleton type="text" width="75px" height="14px" /></td>
            <td class="text-right">
              <q-skeleton type="text" width="70px" height="14px" class="q-ml-auto q-mb-xs" />
              <q-skeleton type="text" width="50px" height="10px" class="q-ml-auto" />
            </td>
            <td><q-skeleton type="QBadge" width="70px" height="20px" /></td>
            <td class="text-right">
              <q-skeleton type="QBtn" size="sm" width="24px" height="24px" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <div
      v-else-if="!invoicesList.length && !hasActiveFilters"
      class="column items-center justify-center text-center text-grey-6 q-pa-xl col"
    >
      <q-icon name="ph ph-file-text" size="48px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No invoices yet</div>
      <div class="text-caption text-grey-5 q-mb-sm">
        Create a wholesale, retail, or walk-in invoice to get started.
      </div>
    </div>

    <div
      v-else-if="!invoicesList.length"
      class="column items-center justify-center text-center text-grey-7 q-py-lg col"
    >
      <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
      <div class="text-subtitle2 text-weight-medium">No invoices match current filters</div>
      <div class="text-caption text-grey-6 q-mt-xs">Clear search or filters to view all invoices.</div>
      <q-btn flat dense no-caps color="primary" label="Reset filters" class="q-mt-sm" @click="onResetFilters" />
    </div>

    <div v-else class="treasury-table-wrap col">
      <q-table
        :rows="filteredInvoices"
        :columns="columns"
        row-key="id"
        flat
        bordered
        class="invoice-table col"
        :table-row-class="invoiceRowClass"
        v-model:pagination="tablePagination"
        :loading="invoicesQuery.isFetching.value"
        :rows-per-page-options="[10, 20, 50]"
        @request="onTableRequest"
        @row-click="(_evt, row) => goToDetails(row)"
      >
        <template #body-cell-invoice_no="props">
          <q-td :props="props">
            <span class="text-weight-bold text-primary cursor-pointer hover-underline">
              #{{ props.row.invoice_no || props.row.id }}
            </span>
          </q-td>
        </template>

        <template #body-cell-type="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="invoiceChannelTone(props.row).color"
              :text-color="invoiceChannelTone(props.row).textColor"
              class="text-weight-bold q-ma-none text-xxs soft-chip"
            >
              {{ invoiceChannelLabel(props.row) }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-customer="props">
          <q-td :props="props">
            <div class="row items-center no-wrap">
              <q-avatar
                square
                size="28px"
                :color="$q.dark.isActive ? 'grey-9' : 'grey-3'"
                :text-color="$q.dark.isActive ? 'grey-3' : 'grey-9'"
                class="q-mr-sm text-weight-bold text-xxs avatar-soft-sq"
              >
                {{ getInitials(props.row.billing_profile_name || props.row.recipient_name) }}
              </q-avatar>
              <div class="min-width-0">
                <div class="text-weight-bold text-grey-9 text-xs line-clamp-1">
                  {{ props.row.billing_profile_name || props.row.recipient_name || 'No Customer' }}
                </div>
                <div class="text-caption text-grey-6 text-xxs line-clamp-1">
                  {{ props.row.billing_profile_email || '—' }}
                </div>
              </div>
            </div>
          </q-td>
        </template>

        <template v-if="isParentTenant" #body-cell-sold_by="props">
          <q-td :props="props">
            <span class="text-caption text-weight-medium">{{ props.row.issued_by_tenant_name || '—' }}</span>
          </q-td>
        </template>

        <template #body-cell-invoice_date="props">
          <q-td :props="props" class="text-weight-medium text-grey-8 text-xs">
            {{ props.row.invoice_date || '—' }}
            <div v-if="props.row.due_date" class="text-caption text-grey-6 text-xxs">
              Due {{ props.row.due_date }}
            </div>
          </q-td>
        </template>

        <template #body-cell-amount="props">
          <q-td :props="props" class="text-right">
            <div class="text-weight-bold text-grey-9 text-xs">
              {{ formatAmount(props.row.total_amount) }}
            </div>
            <div
              v-if="props.row.due_amount > 0"
              class="text-caption text-negative text-weight-bold text-xxs"
            >
              Due: {{ formatAmount(props.row.due_amount) }}
            </div>
            <div v-else class="text-caption text-positive text-weight-bold text-xxs">
              Fully Paid
            </div>
          </q-td>
        </template>

        <template #body-cell-status="props">
          <q-td :props="props">
            <div class="column items-start q-gutter-y-xs">
              <q-chip
                square
                dense
                :color="props.row.invoice_status === 'issued' ? 'green-1' : props.row.invoice_status === 'voided' ? 'red-1' : 'amber-1'"
                :text-color="props.row.invoice_status === 'issued' ? 'green-9' : props.row.invoice_status === 'voided' ? 'red-9' : 'amber-9'"
                class="text-weight-bold text-uppercase text-xxs q-ma-none soft-chip"
              >
                {{ props.row.invoice_status || 'draft' }}
              </q-chip>
              <div
                class="status-badge row inline items-center no-wrap"
                :style="paymentStatusBadgeStyle(props.row.payment_status)"
              >
                <q-icon
                  :name="getPaymentStatusIcon(props.row.payment_status)"
                  size="12px"
                  class="q-mr-xs"
                />
                <span class="text-weight-bolder text-uppercase text-xxs" style="letter-spacing: 0.04em">
                  {{ formatStatusLabel(props.row.payment_status) }}
                </span>
              </div>
            </div>
          </q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right" @click.stop>
            <q-btn
              flat
              dense
              color="grey-7"
              icon="ph ph-dots-three-vertical"
              size="sm"
              aria-label="Invoice actions"
            >
              <q-menu auto-close>
                <q-list dense style="min-width: 130px">
                  <q-item clickable @click="goToDetails(props.row)">
                    <q-item-section avatar style="min-width: 24px">
                      <q-icon name="ph ph-eye" size="16px" />
                    </q-item-section>
                    <q-item-section>View Details</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
              <q-tooltip>Actions</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
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
import { useQuasar } from 'quasar';
import { useQuery, useQueryClient } from '@tanstack/vue-query';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { formatAmountBdt } from 'src/utils/currency';

import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue';
import { invoiceRepository } from '../repositories/invoiceRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import type { GlobalInvoiceCreated, GlobalInvoiceRow } from '../types';
import { useInvoiceWorkspace } from '../composables/useInvoiceWorkspace';

type InvoiceChannel = 'all' | 'wholesale' | 'retail' | 'walkin' | 'dropship';

const $q = useQuasar();
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

const pagination = ref({
  page: 1,
  rowsPerPage: 10,
  sortBy: 'id',
  descending: true,
});

const createRetailDialog = ref(route.query.create === 'retail' || route.query.create === 'walkin' || route.query.create === 'direct');
const retailInitialMode = ref<'account' | 'direct'>(
  route.query.create === 'walkin' || route.query.create === 'direct' ? 'direct' : 'account',
);

const goToCreateWholesale = () => {
  void router.push({
    name: 'app-global-invoices-create-wholesale',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
  });
};

const openCreateRetail = (mode: 'account' | 'direct') => {
  retailInitialMode.value = mode;
  createRetailDialog.value = true;
};

watch(
  () => route.query.create,
  (val) => {
    if (val === 'wholesale') goToCreateWholesale();
    if (val === 'retail') openCreateRetail('account');
    if (val === 'walkin' || val === 'direct') openCreateRetail('direct');
  },
);

const channelTabs: { label: string; value: InvoiceChannel }[] = [
  { label: 'All', value: 'all' },
  { label: 'Wholesale', value: 'wholesale' },
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

const columns = computed(() => {
  const cols: { name: string; label: string; align: 'left' | 'right' | 'center'; sortable?: boolean; field: string }[] = [
    { name: 'invoice_no', label: 'Invoice', align: 'left', sortable: true, field: 'invoice_no' },
    { name: 'type', label: 'Type', align: 'left', field: 'invoice_type' },
    { name: 'customer', label: 'Customer', align: 'left', sortable: true, field: 'billing_profile_name' },
  ];
  if (isParentTenant.value) {
    cols.push({ name: 'sold_by', label: 'Sold by', align: 'left', field: 'issued_by_tenant_name' });
  }
  cols.push(
    { name: 'invoice_date', label: 'Date', align: 'left', sortable: true, field: 'invoice_date' },
    { name: 'amount', label: 'Total', align: 'right', sortable: true, field: 'total_amount' },
    { name: 'status', label: 'Status', align: 'left', sortable: true, field: 'payment_status' },
    { name: 'actions', label: '', align: 'right', field: 'id' },
  );
  return cols;
});

const invoiceChannelLabel = (row: GlobalInvoiceRow) => {
  if (row.invoice_type === 'wholesale') return 'Wholesale';
  if (row.invoice_type === 'dropship') return 'Dropship';
  if (row.retail_billing_mode === 'direct') return 'Walk-in';
  return 'Retail';
};

const invoiceChannelTone = (row: GlobalInvoiceRow) => {
  if (row.invoice_type === 'wholesale') return { color: 'purple-1', textColor: 'purple-9' };
  if (row.invoice_type === 'dropship') return { color: 'orange-1', textColor: 'orange-9' };
  if (row.retail_billing_mode === 'direct') return { color: 'green-1', textColor: 'positive' };
  return { color: 'blue-1', textColor: 'blue-9' };
};

const invoiceRowClass = (row: GlobalInvoiceRow) => {
  if (row.invoice_status === 'draft') return 'invoice-row--draft';
  if (row.invoice_status === 'issued') return 'invoice-row--posted';
  if (row.invoice_status === 'voided') return 'invoice-row--voided';
  return '';
};

const invoicesQuery = useQuery({
  queryKey: computed(() =>
    salesInvoiceQueryKeys.list(effectiveTenantId.value, {
      page: pagination.value.page,
      pageSize: pagination.value.rowsPerPage,
      search: searchText.value,
      paymentStatus: statusFilter.value,
      invoiceStatus: invoiceStatusFilter.value,
      invoiceType: listInvoiceType.value,
      retailBillingMode: listRetailBillingMode.value,
      billingProfileId: billingProfileFilter.value,
      quickFilter: quickFilter.value,
    })
  ),
  enabled: computed(() => !!effectiveTenantId.value),
  queryFn: async () => {
    const tenantId = effectiveTenantId.value;
    if (!tenantId) return { data: [], total: 0 };
    return invoiceRepository.listGlobalInvoices({
      ...(isParentTenant.value
        ? { parentTenantId: tenantId }
        : { issuedByTenantId: tenantId }),
      page: pagination.value.page,
      pageSize: pagination.value.rowsPerPage,
      search: searchText.value,
      paymentStatus: statusFilter.value,
      invoiceStatus: invoiceStatusFilter.value,
      invoiceType: listInvoiceType.value,
      retailBillingMode: listRetailBillingMode.value,
      billingProfileId: billingProfileFilter.value,
      quickFilter: quickFilter.value,
    });
  },
  placeholderData: (prev) => prev,
});

const invoicesList = computed(() => invoicesQuery.data.value?.data ?? []);
const filteredInvoices = computed(() => invoicesList.value);

const hasActiveFilters = computed(() => {
  return Boolean(
    statusFilter.value ||
      invoiceStatusFilter.value ||
      searchText.value ||
      channelFilter.value !== 'all',
  );
});

const tablePagination = computed({
  get: () => ({
    page: pagination.value.page,
    rowsPerPage: pagination.value.rowsPerPage,
    rowsNumber: invoicesQuery.data.value?.total ?? 0,
    sortBy: pagination.value.sortBy,
    descending: pagination.value.descending,
  }),
  set: (val) => {
    pagination.value.page = val.page;
    pagination.value.rowsPerPage = val.rowsPerPage;
    pagination.value.sortBy = val.sortBy;
    pagination.value.descending = val.descending;
  },
});

const onTableRequest = (props: { pagination: typeof tablePagination.value }) => {
  tablePagination.value = props.pagination;
};

watch([searchText, statusFilter, invoiceStatusFilter, billingProfileFilter, quickFilter, channelFilter], () => {
  pagination.value.page = 1;
});

const formatAmount = (value: number) => formatAmountBdt(value);

const formatStatusLabel = (status?: string | null) => {
  return (status || 'draft').replace(/_/g, ' ');
};

const getPaymentStatusIcon = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') return 'ph ph-check-circle';
  if (value === 'due' || value === 'overdue') return 'ph ph-warning-circle';
  if (value === 'partial' || value === 'partially_paid') return 'ph ph-hourglass-medium';
  return 'ph ph-file-text';
};

const paymentStatusBadgeStyle = (status?: string | null) => {
  const isDark = $q.dark.isActive;
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') {
    return {
      backgroundColor: isDark ? 'rgba(34, 197, 94, 0.15)' : '#e8f5e9',
      color: isDark ? '#4ade80' : '#2e7d32',
      border: `1px solid ${isDark ? 'rgba(34, 197, 94, 0.3)' : '#c8e6c9'}`,
    };
  }
  if (value === 'due' || value === 'overdue') {
    return {
      backgroundColor: isDark ? 'rgba(239, 68, 68, 0.15)' : '#ffebee',
      color: isDark ? '#f87171' : '#c62828',
      border: `1px solid ${isDark ? 'rgba(239, 68, 68, 0.3)' : '#ffcdd2'}`,
    };
  }
  if (value === 'partial' || value === 'partially_paid') {
    return {
      backgroundColor: isDark ? 'rgba(59, 130, 246, 0.15)' : '#e3f2fd',
      color: isDark ? '#60a5fa' : '#1565c0',
      border: `1px solid ${isDark ? 'rgba(59, 130, 246, 0.3)' : '#bbdefb'}`,
    };
  }
  return {
    backgroundColor: isDark ? 'rgba(245, 158, 11, 0.15)' : '#fff3e0',
    color: isDark ? '#fbbf24' : '#ef6c00',
    border: `1px solid ${isDark ? 'rgba(245, 158, 11, 0.15)' : '#ffe0b2'}`,
  };
};

const getInitials = (name?: string | null) => {
  if (!name) return 'U';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'U';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'U';
};

const goToDetails = (row: GlobalInvoiceRow | GlobalInvoiceCreated) => {
  if (row.invoice_type === 'wholesale') {
    void router.push({
      name: 'app-global-invoices-create-wholesale',
      params: {
        tenantSlug: authStore.tenantSlug || '',
      },
      query: {
        id: String(row.id),
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

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.treasury-table-wrap :deep(.q-table__card),
.treasury-table-wrap :deep(.q-table__container) {
  display: flex;
  flex-direction: column;
  height: 100%;
  box-shadow: none;
}

.treasury-table-wrap :deep(.q-table__middle) {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.quick-filter-toggle {
  background: color-mix(in srgb, var(--bw-theme-ink) 4%, transparent);
  border-radius: 8px;
  padding: 2px;
}

.quick-filter-toggle :deep(.q-btn) {
  border-radius: 6px;
  font-weight: 600;
  padding: 2px 10px;
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

.invoice-table {
  border-radius: 8px;
  overflow: hidden;
}

.invoice-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  font-weight: 700;
  color: var(--bw-neutral-chrome, #64748b);
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 8px 12px;
  border-bottom: 1px solid var(--bw-theme-border);
}

.invoice-table :deep(tbody tr.invoice-row--draft td) {
  background: #fffdf5;
  box-shadow: inset 3px 0 0 #f59e0b;
}

body.body--dark .invoice-table :deep(tbody tr.invoice-row--draft td) {
  background: rgba(245, 158, 11, 0.08);
  box-shadow: inset 3px 0 0 #f59e0b;
}

.invoice-table :deep(tbody tr.invoice-row--posted td) {
  background: #f6fcf8;
  box-shadow: inset 3px 0 0 #22c55e;
}

body.body--dark .invoice-table :deep(tbody tr.invoice-row--posted td) {
  background: rgba(34, 197, 94, 0.08);
  box-shadow: inset 3px 0 0 #22c55e;
}

.invoice-table :deep(tbody tr.invoice-row--voided td) {
  background: #fef7f7;
  box-shadow: inset 3px 0 0 #ef4444;
}

body.body--dark .invoice-table :deep(tbody tr.invoice-row--voided td) {
  background: rgba(239, 68, 68, 0.08);
  box-shadow: inset 3px 0 0 #ef4444;
}

.invoice-table :deep(tbody tr) {
  transition: background-color 0.15s ease;
}

.invoice-table :deep(tbody tr:hover) {
  background-color: color-mix(in srgb, var(--bw-theme-ink) 4%, var(--bw-theme-surface)) !important;
}

.invoice-table :deep(tbody td) {
  padding: 6px 12px;
  border-bottom: 1px solid var(--bw-theme-border);
  font-size: 12.5px;
}

.hover-underline:hover {
  text-decoration: underline;
}

.status-badge {
  border-radius: 6px;
  padding: 2px 7px;
  display: inline-flex;
  align-items: center;
  font-weight: 700;
}

.soft-chip {
  border-radius: 6px !important;
}

.avatar-soft-sq {
  border-radius: 6px;
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
</style>
