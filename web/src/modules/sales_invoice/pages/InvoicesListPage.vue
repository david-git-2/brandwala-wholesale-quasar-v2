<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden" :data-test="isParentTenant ? 'invoices-parent-list' : 'invoices-child-list'">
    <!-- Error banner -->
    <q-banner v-if="invoicesQuery.error.value" class="bw-status-banner bg-negative text-white q-mb-xs flex-shrink-0" dense rounded>
      {{ invoicesQuery.error.value }}
    </q-banner>

    <!-- Toolbar: Status & Payment Status Filters, Search, Actions -->
    <q-card flat class="floating-surface shadow-1 q-pa-xs flex-shrink-0 q-mb-xs">
      <div class="row items-center justify-between q-col-gutter-xs">
        <!-- Two Filters: Status and Payment Status -->
        <div class="col-12 col-md-auto row items-center q-gutter-x-xs">
          <q-select
            v-model="invoiceStatusFilter"
            :options="invoiceStatusOptions"
            outlined
            rounded
            dense
            emit-value
            map-options
            options-dense
            style="min-width: 145px"
            class="dense-filter-select"
          >
            <template #prepend>
              <q-icon name="ph ph-flag" size="14px" />
            </template>
          </q-select>

          <q-select
            v-model="statusFilter"
            :options="paymentStatusOptions"
            outlined
            rounded
            dense
            emit-value
            map-options
            options-dense
            style="min-width: 165px"
            class="dense-filter-select"
          >
            <template #prepend>
              <q-icon name="ph ph-credit-card" size="14px" />
            </template>
          </q-select>
        </div>

        <!-- Search & Action Buttons -->
        <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
          <q-input
            v-model="searchText"
            outlined
            rounded
            dense
            clearable
            style="min-width: 220px"
            class="col-grow col-sm-auto dense-search-input"
            placeholder="Search by ID, Customer..."
            @clear="onSearch"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="16px" />
            </template>
          </q-input>

          <q-btn-dropdown
            v-if="!isParentTenant"
            color="primary"
            unelevated
            no-caps
            dense
            class="rounded-sq-btn text-weight-bold q-px-sm"
            label="Create Invoice"
            icon="ph ph-plus"
            data-test="create-invoice-btn"
          >
            <q-list dense style="min-width: 180px">
              <q-item clickable v-close-popup @click="goToCreateWholesale">
                <q-item-section avatar>
                  <q-icon name="ph ph-briefcase" color="purple" size="20px" />
                </q-item-section>
                <q-item-section>Wholesale Invoice</q-item-section>
              </q-item>

              <q-item clickable v-close-popup @click="createRetailDialog = true">
                <q-item-section avatar>
                  <q-icon name="ph ph-tote" color="blue" size="20px" />
                </q-item-section>
                <q-item-section>Retail Invoice</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="createDropshipDialog = true">
                <q-item-section avatar>
                  <q-icon name="ph ph-truck" color="orange" size="20px" />
                </q-item-section>
                <q-item-section>Dropship Invoice</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
        </div>
      </div>
    </q-card>

    <!-- Loading Skeleton Table -->
    <div v-if="invoicesQuery.isLoading.value && !invoicesList.length" class="treasury-table-wrap col">
      <q-markup-table flat bordered class="invoice-table full-height">
        <thead>
          <tr>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="120px" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th class="text-right"><q-skeleton type="text" width="90px" class="q-ml-auto" /></th>
            <th><q-skeleton type="text" width="80px" /></th>
            <th class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 8" :key="n">
            <td>
              <q-skeleton type="text" width="90px" height="16px" class="q-mb-xs" />
              <q-skeleton type="QBadge" width="55px" height="16px" />
            </td>
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
            <td><q-skeleton type="text" width="75px" height="14px" /></td>
            <td class="text-right">
              <q-skeleton type="text" width="70px" height="14px" class="q-ml-auto q-mb-xs" />
              <q-skeleton type="text" width="50px" height="10px" class="q-ml-auto" />
            </td>
            <td>
              <q-skeleton type="QBadge" width="70px" height="20px" class="q-mb-xs" />
              <q-skeleton type="text" width="40px" height="10px" />
            </td>
            <td class="text-right">
              <div class="row justify-end q-gutter-x-xs">
                <q-skeleton type="QBtn" size="sm" width="24px" height="24px" />
              </div>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <!-- Empty State: No data created yet -->
    <div
      v-else-if="!invoicesList.length && !hasActiveFilters"
      class="column items-center justify-center text-center text-grey-6 q-pa-xl floating-surface shadow-1 rounded-borders col"
    >
      <q-icon name="ph ph-file-text" size="48px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No Sales Invoices Found</div>
      <div class="text-caption text-grey-5">
        Invoices will appear here once created for this tenant.
      </div>
    </div>

    <!-- Empty State: No search/filter match -->
    <div
      v-else-if="!invoicesList.length"
      class="column items-center justify-center text-center text-grey-7 q-py-lg floating-surface shadow-1 rounded-borders col"
    >
      <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
      <div class="text-subtitle2 text-weight-medium">No invoices match current filters</div>
      <div class="text-caption text-grey-6 q-mt-xs">Try clearing search or filters to view all invoices.</div>
      <q-btn flat dense no-caps color="primary" label="Reset filters" class="q-mt-sm" @click="onResetFilters" />
    </div>

    <!-- Main Table View -->
    <div v-else class="treasury-table-wrap col">
      <q-card flat class="floating-surface shadow-1 q-pa-none full-height column no-wrap">
        <q-table
          :rows="filteredInvoices"
          :columns="columns"
          row-key="id"
          flat
          class="invoice-table col"
          :table-row-class="invoiceRowClass"
          v-model:pagination="tablePagination"
          :loading="invoicesQuery.isFetching.value"
          :rows-per-page-options="[10, 20, 50]"
          @request="onTableRequest"
          @row-click="(evt, row) => goToDetails(row)"
        >
          <!-- Invoice ID Slot -->
          <template #body-cell-invoice_no="props">
            <q-td :props="props">
              <span class="text-weight-bold text-primary cursor-pointer hover-underline">
                #{{ props.row.invoice_no || props.row.id }}
              </span>
              <div class="row q-gutter-x-xs q-mt-xs">
                <q-chip
                  square
                  dense
                  :color="
                    props.row.invoice_type === 'wholesale'
                      ? 'purple-1'
                      : props.row.invoice_type === 'dropship'
                        ? 'orange-1'
                        : 'blue-1'
                  "
                  :text-color="
                    props.row.invoice_type === 'wholesale'
                      ? 'purple-9'
                      : props.row.invoice_type === 'dropship'
                        ? 'orange-9'
                        : 'blue-9'
                  "
                  class="text-weight-bold text-capitalize q-ma-none text-xxs soft-chip"
                >
                  {{ props.row.invoice_type || 'retail' }}
                </q-chip>
              </div>
            </q-td>
          </template>

          <!-- Customer Info Slot -->
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

          <!-- Sold by (parent books) -->
          <template v-if="isParentTenant" #body-cell-sold_by="props">
            <q-td :props="props">
              <span class="text-caption text-weight-medium">{{ props.row.issued_by_tenant_name || '—' }}</span>
            </q-td>
          </template>

          <!-- Create Date -->
          <template #body-cell-invoice_date="props">
            <q-td :props="props" class="text-weight-medium text-grey-8 text-xs">
              {{ props.row.invoice_date || '—' }}
            </q-td>
          </template>

          <!-- Due Date -->
          <template #body-cell-due_date="props">
            <q-td :props="props" class="text-weight-medium text-grey-8 text-xs">
              {{ props.row.due_date || '—' }}
            </q-td>
          </template>

          <!-- Grand Total & Due Amount -->
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

          <!-- Status Slot -->
          <template #body-cell-status="props">
            <q-td :props="props">
              <div class="column items-start q-gutter-y-xs">
                <!-- Payment Status Badge -->
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
                <!-- Invoice Status Pill -->
                <div class="row items-center q-gutter-x-xs">
                  <q-chip
                    square
                    dense
                    :color="props.row.invoice_status === 'posted' ? 'green-1' : props.row.invoice_status === 'voided' ? 'red-1' : 'amber-1'"
                    :text-color="props.row.invoice_status === 'posted' ? 'green-9' : props.row.invoice_status === 'voided' ? 'red-9' : 'amber-9'"
                    class="text-weight-bold text-uppercase text-xxs q-ma-none soft-chip"
                  >
                    {{ props.row.invoice_status || 'draft' }}
                  </q-chip>
                </div>
              </div>
            </q-td>
          </template>

          <!-- Actions Slot -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right" @click.stop>
              <div class="row justify-end items-center q-gutter-xs">
                <q-btn
                  flat
                  round
                  dense
                  color="grey-7"
                  icon="ph ph-eye"
                  size="sm"
                  @click="goToDetails(props.row)"
                >
                  <q-tooltip>View Invoice</q-tooltip>
                </q-btn>
                <q-btn flat round dense color="grey-7" icon="ph ph-dots-three-vertical" size="sm">
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
                </q-btn>
              </div>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </div>

    <!-- Dialogs -->
    <CreateGlobalInvoiceDialog
      v-model="createWholesaleDialog"
      :parent-tenant-id="effectiveTenantId"
      @created="onInvoiceCreated"
    />
    <CreateRetailInvoiceDialog
      v-model="createRetailDialog"
      :parent-tenant-id="effectiveTenantId"
      @created="onInvoiceCreated"
    />
    <CreateDropshipInvoiceDialog
      v-model="createDropshipDialog"
      :parent-tenant-id="effectiveTenantId"
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

import CreateGlobalInvoiceDialog from '../components/CreateGlobalInvoiceDialog.vue';
import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue';
import CreateDropshipInvoiceDialog from '../components/CreateDropshipInvoiceDialog.vue';
import { invoiceRepository } from '../repositories/invoiceRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import type { GlobalInvoiceCreated, GlobalInvoiceRow } from '../types';
import { useInvoiceWorkspace } from '../composables/useInvoiceWorkspace';

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

const initialSearch = typeof route.query.search === 'string' ? route.query.search : '';
const searchText = ref(initialSearch);
const statusFilter = ref<string | null>(null);
const invoiceStatusFilter = ref<string | null>(null);

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

const pagination = ref({
  page: 1,
  rowsPerPage: 10,
  sortBy: 'id',
  descending: true,
});

const createRetailDialog = ref(route.query.create === 'retail');
const createDropshipDialog = ref(route.query.create === 'dropship');

const goToCreateWholesale = () => {
  void router.push({
    name: 'app-global-invoices-create-wholesale',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
  });
};

watch(
  () => route.query.create,
  (val) => {
    if (val === 'wholesale') goToCreateWholesale();
    if (val === 'retail') createRetailDialog.value = true;
    if (val === 'dropship') createDropshipDialog.value = true;
  },
);

const invoiceStatusOptions = [
  { label: 'All Statuses', value: null },
  { label: 'Draft', value: 'draft' },
  { label: 'Posted', value: 'posted' },
  { label: 'Voided', value: 'voided' },
];

const paymentStatusOptions = [
  { label: 'All Payment Status', value: null },
  { label: 'Paid', value: 'paid' },
  { label: 'Due', value: 'due' },
  { label: 'Partial', value: 'partial' },
  { label: 'Draft', value: 'draft' },
];

const columns = computed(() => {
  const cols: { name: string; label: string; align: 'left' | 'right' | 'center'; sortable?: boolean; field: string }[] = [
    { name: 'invoice_no', label: 'Invoice ID', align: 'left', sortable: true, field: 'invoice_no' },
    { name: 'customer', label: 'Customer', align: 'left', sortable: true, field: 'billing_profile_name' },
  ];
  if (isParentTenant.value) {
    cols.push({ name: 'sold_by', label: 'Sold by', align: 'left', field: 'issued_by_tenant_name' });
  }
  cols.push(
    { name: 'invoice_date', label: 'Create Date', align: 'left', sortable: true, field: 'invoice_date' },
    { name: 'due_date', label: 'Due Date', align: 'left', sortable: true, field: 'due_date' },
    { name: 'amount', label: 'Total Amount', align: 'right', sortable: true, field: 'total_amount' },
    { name: 'status', label: 'Status', align: 'left', sortable: true, field: 'payment_status' },
    { name: 'actions', label: '', align: 'right', field: 'id' },
  );
  return cols;
});

const invoiceRowClass = (row: GlobalInvoiceRow) => {
  if (row.invoice_status === 'draft') return 'invoice-row--draft';
  if (row.invoice_status === 'posted') return 'invoice-row--posted';
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
    });
  },
  placeholderData: (prev) => prev,
});

const invoicesList = computed(() => invoicesQuery.data.value?.data ?? []);
const filteredInvoices = computed(() => invoicesList.value);

const hasActiveFilters = computed(() => {
  return Boolean(statusFilter.value || invoiceStatusFilter.value || searchText.value);
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

const onTableRequest = (props: any) => {
  tablePagination.value = props.pagination;
};

// Reset page to 1 when filters change
watch([searchText, statusFilter, invoiceStatusFilter], () => {
  pagination.value.page = 1;
});

const formatAmount = (value: number) => formatAmountBdt(value);

const formatStatusLabel = (status?: string | null) => {
  const value = (status || 'draft').replace(/_/g, ' ');
  return value;
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
    border: `1px solid ${isDark ? 'rgba(245, 158, 11, 0.3)' : '#ffe0b2'}`,
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

const goToDetails = (row: GlobalInvoiceRow) => {
  void router.push({
    name: 'app-global-invoice-details-page',
    params: {
      tenantSlug: authStore.tenantSlug,
      id: row.id,
    },
  });
};

const onInvoiceCreated = (invoice: GlobalInvoiceCreated) => {
  void queryClient.invalidateQueries({ queryKey: salesInvoiceQueryKeys.root });
  goToDetails(invoice);
};

const onSearch = () => {};

const onResetFilters = () => {
  statusFilter.value = null;
  invoiceStatusFilter.value = null;
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
  background: transparent;
}

.treasury-table-wrap :deep(.q-table__middle) {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.6);
}

body.body--dark .floating-surface {
  background: #1c1c1c;
  border-color: #2e2e2e;
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
  border-radius: 999px;
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
  color: #0f172a;
  background: #f8fafc;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 8px 12px;
  border-bottom: 1px solid #e2e8f0;
}

body.body--dark .invoice-table :deep(thead tr th) {
  background: #1c1c1c;
  color: #a1a1aa;
  border-bottom: 1px solid #2e2e2e;
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
  background-color: #f1f5f9 !important;
}

body.body--dark .invoice-table :deep(tbody tr:hover) {
  background-color: #242424 !important;
}

.invoice-table :deep(tbody td) {
  padding: 6px 12px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 12.5px;
}

body.body--dark .invoice-table :deep(tbody td) {
  border-bottom: 1px solid #262626;
  color: #ededed;
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
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.status-badge:hover {
  transform: translateY(-1px);
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
