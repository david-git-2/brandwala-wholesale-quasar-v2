<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Page Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Invoices</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Sales Invoices</h1>
        </div>
        <div class="col-auto">
          <q-btn-dropdown
            color="primary"
            unelevated
            no-caps
            class="pill-btn text-weight-bold"
            label="Create Invoice"
            icon="add"
          >
            <q-list dense style="min-width: 180px">
              <q-item clickable v-close-popup @click="createWholesaleDialog = true">
                <q-item-section avatar>
                  <q-icon name="business" color="purple" size="20px" />
                </q-item-section>
                <q-item-section>Wholesale Invoice</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="createRetailDialog = true">
                <q-item-section avatar>
                  <q-icon name="shopping_bag" color="blue" size="20px" />
                </q-item-section>
                <q-item-section>Retail Invoice</q-item-section>
              </q-item>
              <q-item clickable v-close-popup @click="createDropshipDialog = true">
                <q-item-section avatar>
                  <q-icon name="local_shipping" color="orange" size="20px" />
                </q-item-section>
                <q-item-section>Dropship Invoice</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
        </div>
      </section>

      <!-- Dashboard Statistics Cards -->
      <div class="row q-col-gutter-sm">
        <!-- Total Receivables Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat class="stat-card total-receivables-card text-white full-height card-hover">
            <q-card-section class="q-pa-sm q-pb-none">
              <div class="row justify-between items-center">
                <div class="text-caption text-weight-bold opacity-80">Total Receivables</div>
                <q-avatar size="24px" class="bg-white-20">
                  <q-icon name="account_balance_wallet" size="14px" />
                </q-avatar>
              </div>
              <div class="text-h6 text-weight-bolder q-mt-xs">
                {{ formatAmount(totalDue) }}
              </div>
            </q-card-section>
            <q-card-section class="q-pa-sm q-pt-none">
              <div class="row justify-between items-center text-xxs q-mb-xs opacity-75">
                <span>Paid Rate</span>
                <span class="text-weight-bold">{{ paidPercent }}%</span>
              </div>
              <div class="receivables-progress">
                <div class="receivables-progress-fill" :style="{ width: paidPercent + '%' }" />
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Paid Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card bg-white full-height card-hover">
            <q-card-section class="row no-wrap justify-between items-center q-pa-sm">
              <div>
                <div class="row items-center q-gutter-xs">
                  <q-avatar size="24px" color="green-1" text-color="green">
                    <q-icon name="payments" size="12px" />
                  </q-avatar>
                  <span class="text-caption text-grey-8 text-weight-bold q-ml-xs">Paid</span>
                </div>
                <div class="text-h6 text-weight-bolder text-black q-mt-xs">
                  {{ formatAmount(totalPaid) }}
                </div>
                <div class="text-xxs text-green text-weight-bold q-mt-xs row items-center">
                  <q-icon name="trending_up" size="12px" class="q-mr-xs" />
                  {{ paidPercent }}% collected
                </div>
              </div>
              <!-- Mini SVG Bar Chart -->
              <div class="chart-container self-center">
                <svg width="50" height="30" viewBox="0 0 50 30">
                  <rect x="3" y="10" width="5" height="20" rx="2" fill="#e8f5e9" />
                  <rect x="11" y="6" width="5" height="24" rx="2" fill="#e8f5e9" />
                  <rect x="19" y="15" width="5" height="15" rx="2" fill="#e8f5e9" />
                  <rect x="27" y="3" width="5" height="27" rx="2" fill="#4caf50" />
                  <rect x="35" y="12" width="5" height="18" rx="2" fill="#4caf50" />
                </svg>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Unpaid Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card bg-white full-height card-hover">
            <q-card-section class="row no-wrap justify-between items-center q-pa-sm">
              <div>
                <div class="row items-center q-gutter-xs">
                  <q-avatar size="24px" color="blue-1" text-color="blue">
                    <q-icon name="pending_actions" size="12px" />
                  </q-avatar>
                  <span class="text-caption text-grey-8 text-weight-bold q-ml-xs">Unpaid</span>
                </div>
                <div class="text-h6 text-weight-bolder text-black q-mt-xs">
                  {{ formatAmount(totalDue) }}
                </div>
                <div class="text-xxs text-blue text-weight-bold q-mt-xs row items-center">
                  <q-icon name="trending_flat" size="12px" class="q-mr-xs" />
                  {{ unpaidPercent }}% outstanding
                </div>
              </div>
              <!-- Mini SVG Line Chart -->
              <div class="chart-container self-center">
                <svg width="50" height="30" viewBox="0 0 50 30">
                  <path
                    d="M 3,22 Q 11,8 19,18 T 35,4 T 43,15"
                    fill="none"
                    stroke="#2196f3"
                    stroke-width="1.5"
                    stroke-linecap="round"
                  />
                  <path
                    d="M 3,22 Q 11,8 19,18 T 35,4 T 43,15 L 43,30 L 3,30 Z"
                    fill="rgba(33, 150, 243, 0.08)"
                  />
                </svg>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Overdue Card -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card bg-white full-height card-hover">
            <q-card-section class="row no-wrap justify-between items-center q-pa-sm">
              <div>
                <div class="row items-center q-gutter-xs">
                  <q-avatar size="24px" color="red-1" text-color="red">
                    <q-icon name="error_outline" size="12px" />
                  </q-avatar>
                  <span class="text-caption text-grey-8 text-weight-bold q-ml-xs">Overdue</span>
                </div>
                <div class="text-h6 text-weight-bolder text-black q-mt-xs">
                  {{ formatAmount(totalOverdue) }}
                </div>
                <div class="text-xxs text-red text-weight-bold q-mt-xs row items-center">
                  <q-icon name="trending_down" size="12px" class="q-mr-xs" />
                  {{ overduePercent }}% overdue
                </div>
              </div>
              <!-- Mini SVG Bar Chart -->
              <div class="chart-container self-center">
                <svg width="50" height="30" viewBox="0 0 50 30">
                  <rect x="3" y="18" width="5" height="12" rx="2" fill="#ffebee" />
                  <rect x="11" y="12" width="5" height="18" rx="2" fill="#ffebee" />
                  <rect x="19" y="5" width="5" height="25" rx="2" fill="#f44336" />
                  <rect x="27" y="15" width="5" height="15" rx="2" fill="#ffebee" />
                  <rect x="35" y="8" width="5" height="22" rx="2" fill="#f44336" />
                </svg>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <!-- Filters Toolbar -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <!-- Left side segmented filters -->
          <div class="col-auto row items-center q-gutter-sm">
            <q-btn-toggle
              v-model="quickFilter"
              toggle-color="primary"
              toggle-text-color="white"
              text-color="grey-8"
              flat
              dense
              unelevated
              no-caps
              :options="[
                { label: 'All', value: 'all' },
                { label: 'Paid', value: 'paid' },
                { label: 'Unpaid', value: 'unpaid' },
              ]"
              class="quick-filter-toggle text-weight-bold"
            />
          </div>

          <!-- Right side tools (Search, Filter drawer) -->
          <div class="col-auto row items-center q-gutter-sm">
            <!-- search control -->
            <q-btn
              v-if="!showSearchInput"
              flat
              round
              dense
              icon="search"
              aria-label="Show search"
              @click="showSearchInput = true"
            >
              <q-tooltip>Search Invoices</q-tooltip>
            </q-btn>
            <q-input
              v-else
              v-model="searchText"
              outlined
              dense
              clearable
              class="soft-input"
              style="width: min(250px, 45vw)"
              placeholder="Search by ID, Customer..."
              @clear="onSearchChange"
              @keyup.enter="onSearchChange"
            >
              <template #prepend>
                <q-icon name="search" size="18px" />
              </template>
              <template #append>
                <q-btn
                  flat
                  round
                  dense
                  icon="close"
                  size="18px"
                  aria-label="Hide search"
                  @click="onCloseSearch"
                />
              </template>
            </q-input>

            <q-btn
              flat
              round
              dense
              icon="filter_alt"
              aria-label="Filters"
              @click="filterDrawerOpen = true"
            >
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
              <q-tooltip>More Filters</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <!-- Loaders & States -->
      <PageInitialLoader v-if="invoicesQuery.isLoading.value && !invoicesList.length" />

      <q-banner v-else-if="invoicesQuery.error.value" class="bg-negative text-white q-mb-md" rounded>
        {{ invoicesQuery.error.value }}
      </q-banner>

      <!-- Empty State -->
      <div
        v-else-if="!invoicesList.length && activeFilterCount === 0 && quickFilter === 'all'"
        class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block floating-surface shadow-1"
      >
        <q-icon name="description" size="64px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-medium">No Sales Invoices Found</div>
        <div class="text-caption text-grey-5">
          Invoices will appear here once created for this parent company.
        </div>
      </div>

      <!-- No Matching Filters -->
      <div v-else-if="!invoicesList.length" class="text-center text-grey-7 q-py-xl">
        No invoices match current search or filters.
      </div>

      <!-- Table View -->
      <div v-else class="treasury-table-wrap">
        <q-table
          :rows="filteredInvoices"
          :columns="columns"
          row-key="id"
          flat
          bordered
          class="invoice-table"
          v-model:pagination="tablePagination"
          :loading="invoicesQuery.isFetching.value"
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
                  class="text-weight-bold text-caption text-capitalize q-ma-none text-xxs"
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
                  size="36px"
                  :color="getAvatarStyleAndColor(props.row).color"
                  :style="getAvatarStyleAndColor(props.row).style"
                  text-color="white"
                  class="q-mr-sm text-weight-bold"
                >
                  {{ getInitials(props.row.billing_profile_name || props.row.recipient_name) }}
                </q-avatar>
                <div>
                  <div class="text-weight-bold text-black">
                    {{ props.row.billing_profile_name || props.row.recipient_name || 'No Customer' }}
                  </div>
                  <div class="text-caption text-grey-7 text-xs">
                    {{ props.row.billing_profile_email || 'no-email@brandwala.com' }}
                  </div>
                </div>
              </div>
            </q-td>
          </template>

          <!-- Create Date -->
          <template #body-cell-invoice_date="props">
            <q-td :props="props" class="text-weight-medium text-grey-8">
              {{ props.row.invoice_date || '—' }}
            </q-td>
          </template>

          <!-- Due Date -->
          <template #body-cell-due_date="props">
            <q-td :props="props" class="text-weight-medium text-grey-8">
              {{ props.row.due_date || '—' }}
            </q-td>
          </template>

          <!-- Grand Total & Due Amount -->
          <template #body-cell-amount="props">
            <q-td :props="props" class="text-right">
              <div class="text-weight-bold text-black">
                {{ formatAmount(props.row.total_amount) }}
              </div>
              <div
                v-if="props.row.due_amount > 0"
                class="text-caption text-red text-weight-bold text-xs"
              >
                Due: {{ formatAmount(props.row.due_amount) }}
              </div>
              <div v-else class="text-caption text-green text-weight-bold text-xs">
                Fully Paid
              </div>
            </q-td>
          </template>

          <!-- Combined Status Slot -->
          <template #body-cell-status="props">
            <q-td :props="props">
              <div class="column items-start q-gutter-y-xs">
                <!-- Payment Status Pill -->
                <q-chip
                  square
                  dense
                  :style="paymentStatusChipStyle(props.row.payment_status)"
                  class="status-chip text-weight-bold q-ma-none text-capitalize"
                >
                  <span
                    class="status-chip-dot"
                    :style="{ backgroundColor: paymentStatusDotColor(props.row.payment_status) }"
                  />
                  {{ formatStatusLabel(props.row.payment_status) }}
                </q-chip>
                <!-- Invoice Status -->
                <span class="text-xxs text-weight-bold text-grey-6 text-uppercase q-ml-xs">
                  {{ props.row.invoice_status }}
                </span>
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
                  icon="visibility"
                  size="sm"
                  @click="goToDetails(props.row)"
                >
                  <q-tooltip>View Invoice</q-tooltip>
                </q-btn>
                <q-btn flat round dense color="grey-7" icon="more_vert" size="sm">
                  <q-menu auto-close>
                    <q-list dense style="min-width: 120px">
                      <q-item clickable @click="goToDetails(props.row)">
                        <q-item-section>View Details</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </div>
            </q-td>
          </template>
        </q-table>
      </div>

      <!-- Filters Sidebar -->
      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <q-select
          v-model="invoiceStatusFilter"
          :options="invoiceStatusFilterOptions"
          label="Invoice Status"
          outlined
          dense
          clearable
          emit-value
          map-options
          class="soft-input q-mb-sm"
        />
        <q-select
          v-model="statusFilter"
          :options="statusFilterOptions"
          label="Payment Status"
          outlined
          dense
          clearable
          emit-value
          map-options
          class="soft-input q-mb-sm"
        />
        <q-select
          v-model="invoiceTypeFilter"
          :options="[
            { label: 'Retail', value: 'retail' },
            { label: 'Wholesale', value: 'wholesale' },
            { label: 'Dropship', value: 'dropship' },
          ]"
          label="Invoice Type"
          outlined
          dense
          clearable
          emit-value
          map-options
          class="soft-input q-mb-md"
        />

        <!-- Date Range Filter -->
        <div class="q-mb-md">
          <div class="text-caption text-grey-7 q-mb-xs">Invoice Date Range</div>
          <q-btn
            outline
            no-caps
            class="full-width soft-input text-left justify-start q-px-sm"
            color="primary"
            style="min-height: 40px; border-color: rgba(0, 0, 0, 0.12)"
          >
            <q-icon name="event" class="q-mr-xs" color="primary" />
            <span class="text-caption text-grey-8">{{ dateRangeLabel }}</span>
            <q-popup-proxy cover transition-show="scale" transition-hide="scale">
              <q-date v-model="selectedDateRange" range>
                <div class="row items-center justify-end q-gutter-sm">
                  <q-btn
                    v-close-popup
                    label="Clear"
                    color="negative"
                    flat
                    @click="selectedDateRange = null"
                  />
                  <q-btn v-close-popup label="Close" color="primary" flat />
                </div>
              </q-date>
            </q-popup-proxy>
          </q-btn>
        </div>

        <div class="row q-gutter-sm justify-end">
          <q-btn
            flat
            no-caps
            label="Reset"
            class="text-black text-weight-bold"
            @click="onResetFilters"
          />
        </div>
      </FilterSidebar>
    </div>

    <!-- Dialogs -->
    <CreateGlobalInvoiceDialog
      v-model="createWholesaleDialog"
      :parent-tenant-id="effectiveParentTenantId"
      @created="onInvoiceCreated"
    />
    <CreateRetailInvoiceDialog
      v-model="createRetailDialog"
      :parent-tenant-id="effectiveParentTenantId"
      @created="onInvoiceCreated"
    />
    <CreateDropshipInvoiceDialog
      v-model="createDropshipDialog"
      :parent-tenant-id="effectiveParentTenantId"
      @created="onInvoiceCreated"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import { formatAmountBdt } from 'src/utils/currency';

import CreateGlobalInvoiceDialog from '../components/CreateGlobalInvoiceDialog.vue';
import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue';
import CreateDropshipInvoiceDialog from '../components/CreateDropshipInvoiceDialog.vue';
import { invoiceRepository } from '../repositories/invoiceRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import type { GlobalInvoiceCreated, GlobalInvoiceRow } from '../types';

const authStore = useAuthStore();
const tenantStore = useTenantStore();
const router = useRouter();
const queryClient = useQueryClient();
const customerGroupStore = useCustomerGroupStore();

const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.parent_id ?? current.id;
});

const showSearchInput = ref(false);
const filterDrawerOpen = ref(false);
const searchText = ref('');
const statusFilter = ref<string | null>(null);
const invoiceStatusFilter = ref<string | null>(null);
const invoiceTypeFilter = ref<string | null>(null);
const selectedDateRange = ref<string | { from: string; to: string } | null>(null);
const quickFilter = ref<'all' | 'paid' | 'unpaid'>('all');

const pagination = ref({
  page: 1,
  rowsPerPage: 10,
  sortBy: 'id',
  descending: true,
});

const dateRange = computed(() => {
  let from: string | null = null;
  let to: string | null = null;
  if (selectedDateRange.value) {
    if (typeof selectedDateRange.value === 'string') {
      const formatted = selectedDateRange.value.replace(/\//g, '-');
      from = formatted;
      to = formatted;
    } else if (
      typeof selectedDateRange.value === 'object' &&
      selectedDateRange.value.from &&
      selectedDateRange.value.to
    ) {
      from = selectedDateRange.value.from.replace(/\//g, '-');
      to = selectedDateRange.value.to.replace(/\//g, '-');
    }
  }
  return { from, to };
});

const dateRangeLabel = computed(() => {
  if (!selectedDateRange.value) return 'Any Date';
  if (typeof selectedDateRange.value === 'string') {
    return selectedDateRange.value.replace(/\//g, '-');
  }
  if (
    typeof selectedDateRange.value === 'object' &&
    selectedDateRange.value.from &&
    selectedDateRange.value.to
  ) {
    return `${selectedDateRange.value.from.replace(/\//g, '-')} to ${selectedDateRange.value.to.replace(/\//g, '-')}`;
  }
  return 'Any Date';
});

const createWholesaleDialog = ref(false);
const createRetailDialog = ref(false);
const createDropshipDialog = ref(false);

const statusFilterOptions = [
  { label: 'Paid', value: 'paid' },
  { label: 'Due', value: 'due' },
  { label: 'Partial', value: 'partial' },
  { label: 'Draft', value: 'draft' },
];

const invoiceStatusFilterOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'Posted', value: 'posted' },
  { label: 'Voided', value: 'voided' },
];

const columns: any[] = [
  { name: 'invoice_no', label: 'Invoice ID', align: 'left', sortable: true, field: 'invoice_no' },
  { name: 'customer', label: 'User Info', align: 'left', sortable: true, field: 'billing_profile_name' },
  { name: 'invoice_date', label: 'Create Date', align: 'left', sortable: true, field: 'invoice_date' },
  { name: 'due_date', label: 'Due Date', align: 'left', sortable: true, field: 'due_date' },
  { name: 'amount', label: 'Total Amount', align: 'right', sortable: true, field: 'total_amount' },
  { name: 'status', label: 'Status', align: 'left', sortable: true, field: 'payment_status' },
  { name: 'actions', label: '', align: 'right', field: 'id' },
];

const invoicesQuery = useQuery({
  queryKey: computed(() =>
    salesInvoiceQueryKeys.list(effectiveParentTenantId.value, {
      page: pagination.value.page,
      pageSize: pagination.value.rowsPerPage,
      search: searchText.value,
      paymentStatus: statusFilter.value,
      invoiceStatus: invoiceStatusFilter.value,
      invoiceType: invoiceTypeFilter.value,
      fromDate: dateRange.value.from,
      toDate: dateRange.value.to,
      quickFilter: quickFilter.value,
    })
  ),
  enabled: computed(() => !!effectiveParentTenantId.value),
  queryFn: async () => {
    const parentId = effectiveParentTenantId.value;
    if (!parentId) return { data: [], total: 0 };
    return invoiceRepository.listGlobalInvoices({
      parentTenantId: parentId,
      page: pagination.value.page,
      pageSize: pagination.value.rowsPerPage,
      search: searchText.value,
      paymentStatus: statusFilter.value,
      invoiceStatus: invoiceStatusFilter.value,
      invoiceType: invoiceTypeFilter.value,
      fromDate: dateRange.value.from,
      toDate: dateRange.value.to,
      quickFilter: quickFilter.value,
    });
  },
  placeholderData: (prev) => prev,
});

const invoicesList = computed(() => invoicesQuery.data.value?.data ?? []);
const filteredInvoices = computed(() => invoicesList.value);

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

// Reset page to 1 when any filter changes
watch(
  [searchText, statusFilter, invoiceStatusFilter, invoiceTypeFilter, selectedDateRange, quickFilter],
  () => {
    pagination.value.page = 1;
  }
);

// Computed statistics for dashboard cards
const totalAmount = computed(() =>
  invoicesList.value.reduce((sum, r) => sum + (r.total_amount || 0), 0)
);
const totalPaid = computed(() =>
  invoicesList.value.reduce((sum, r) => sum + (r.paid_amount || 0), 0)
);
const totalDue = computed(() =>
  invoicesList.value.reduce((sum, r) => sum + (r.due_amount || 0), 0)
);
const totalOverdue = computed(() =>
  invoicesList.value
    .filter((r) => r.payment_status === 'overdue' || r.payment_status === 'due')
    .reduce((sum, r) => sum + (r.due_amount || 0), 0)
);

const paidPercent = computed(() =>
  totalAmount.value ? Math.round((totalPaid.value / totalAmount.value) * 100) : 0
);
const unpaidPercent = computed(() =>
  totalAmount.value ? Math.round((totalDue.value / totalAmount.value) * 100) : 0
);
const overduePercent = computed(() =>
  totalAmount.value ? Math.round((totalOverdue.value / totalAmount.value) * 100) : 0
);

const activeFilterCount = computed(() => {
  let count = 0;
  if (statusFilter.value) count += 1;
  if (invoiceStatusFilter.value) count += 1;
  if (invoiceTypeFilter.value) count += 1;
  if (selectedDateRange.value) count += 1;
  return count;
});

const formatAmount = (value: number) => formatAmountBdt(value);

const formatStatusLabel = (status?: string | null) => {
  const value = (status || 'draft').replace(/_/g, ' ');
  return value;
};

const paymentStatusChipStyle = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') {
    return { backgroundColor: '#e8f5e9', color: '#2e7d32', border: '1px solid #c8e6c9' };
  }
  if (value === 'due' || value === 'overdue') {
    return { backgroundColor: '#ffebee', color: '#c62828', border: '1px solid #ffcdd2' };
  }
  if (value === 'partial' || value === 'partially_paid') {
    return { backgroundColor: '#e3f2fd', color: '#1565c0', border: '1px solid #bbdefb' };
  }
  return { backgroundColor: '#fff3e0', color: '#ef6c00', border: '1px solid #ffe0b2' };
};

const paymentStatusDotColor = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') return '#4caf50';
  if (value === 'due' || value === 'overdue') return '#f44336';
  if (value === 'partial' || value === 'partially_paid') return '#2196f3';
  return '#ff9800';
};

const getInitials = (name?: string | null) => {
  if (!name) return 'U';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'U';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'U';
};

const getAvatarColor = (name?: string | null) => {
  if (!name) return 'grey-6';
  const colors = ['purple-5', 'teal-5', 'blue-5', 'orange-5', 'cyan-5', 'indigo-5', 'green-5'];
  let sum = 0;
  for (let i = 0; i < name.length; i++) {
    sum += name.charCodeAt(i);
  }
  return colors[sum % colors.length];
};

const customerGroupColorMap = computed<Record<number, string | null>>(() =>
  customerGroupStore.groups.reduce<Record<number, string | null>>((acc, g) => {
    acc[g.id] = g.accent_color;
    return acc;
  }, {}),
);

const getAvatarStyleAndColor = (row: any) => {
  const profileColor = row.billing_profile_color;
  if (profileColor) {
    if (profileColor.startsWith('#')) {
      return { style: { backgroundColor: profileColor }, color: undefined };
    }
    return { style: {}, color: profileColor };
  }

  const customerGroupId = row.billing_profile_customer_group_id;
  if (customerGroupId) {
    const groupColor = customerGroupColorMap.value[customerGroupId];
    if (groupColor) {
      if (groupColor.startsWith('#')) {
        return { style: { backgroundColor: groupColor }, color: undefined };
      }
      return { style: {}, color: groupColor };
    }
  }

  const name = row.billing_profile_name || row.recipient_name;
  const fallbackColor = getAvatarColor(name) || 'grey-6';
  if (fallbackColor.startsWith('#')) {
    return { style: { backgroundColor: fallbackColor }, color: undefined };
  }
  return { style: {}, color: fallbackColor };
};

const loadCustomerGroups = async () => {
  const parentId = effectiveParentTenantId.value;
  if (parentId) {
    await customerGroupStore.fetchCustomerGroupsByTenant(parentId);
  }
};

onMounted(loadCustomerGroups);

watch(effectiveParentTenantId, (newId) => {
  if (newId) {
    void customerGroupStore.fetchCustomerGroupsByTenant(newId);
  }
});

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

const onSearchChange = () => {};
const onCloseSearch = () => {
  showSearchInput.value = false;
  searchText.value = '';
};
const onResetFilters = () => {
  statusFilter.value = null;
  invoiceStatusFilter.value = null;
  invoiceTypeFilter.value = null;
  selectedDateRange.value = null;
  quickFilter.value = 'all';
};
</script>

<style scoped>
.stat-card {
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.03) !important;
  transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.25s ease;
  overflow: hidden;
  position: relative;
}

.total-receivables-card {
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%) !important;
}

.bg-white-20 {
  background: rgba(255, 255, 255, 0.2);
}

.opacity-80 {
  opacity: 0.8;
}

.opacity-75 {
  opacity: 0.75;
}

.receivables-progress {
  height: 6px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 99px;
  overflow: hidden;
}

.receivables-progress-fill {
  height: 100%;
  background: #ffffff !important;
}

.chart-container {
  height: 40px;
  display: flex;
  align-items: flex-end;
}

.quick-filter-toggle {
  background: rgba(0, 0, 0, 0.03);
  border-radius: 8px;
  padding: 2px;
}

.quick-filter-toggle :deep(.q-btn) {
  border-radius: 6px;
  font-weight: 600;
  padding: 4px 16px;
}

.invoice-table {
  border-radius: 12px;
  background: #ffffff;
  overflow: hidden;
}

.invoice-table :deep(thead tr th) {
  font-weight: 700;
  color: var(--q-primary);
  background: #f8fafc;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 14px 16px;
  border-bottom: 1px solid #f1f5f9;
}

.invoice-table :deep(tbody tr) {
  transition: background-color 0.2s ease;
}

.invoice-table :deep(tbody tr:hover) {
  background-color: #f8fafc !important;
}

.invoice-table :deep(tbody td) {
  padding: 12px 16px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 13px;
}

.hover-underline:hover {
  text-decoration: underline;
}

.status-chip {
  border-radius: 20px !important;
  font-size: 11px;
  padding: 2px 8px;
}

.status-chip-dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 999px;
  margin-right: 6px;
}

.text-xxs {
  font-size: 9px;
  line-height: 1;
}

.text-xs {
  font-size: 11px;
}

.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(34, 56, 101, 0.12) !important;
}
</style>
