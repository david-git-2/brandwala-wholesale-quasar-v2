<template>
  <q-page class="q-pa-md full-width-page">
    <!-- Compact & Sticky Page Toolbar -->
    <div class="bw-page-toolbar">
      <div class="bw-page-toolbar__left">
        <div class="row items-center q-gutter-sm">
          <q-icon name="description" size="20px" color="primary" />
          <div class="bw-page-toolbar__title">Sales Invoices</div>
        </div>

        <div class="row items-center q-gutter-sm">
          <q-btn
            v-if="!showSearchInput"
            flat
            round
            dense
            icon="search"
            aria-label="Show search"
            @click="showSearchInput = true"
          />
          <q-input
            v-else
            v-model="searchText"
            filled
            dense
            clearable
            class="soft-input"
            style="width: min(200px, 45vw)"
            placeholder="Search Invoices"
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
          </q-btn>
        </div>
      </div>

      <div class="bw-page-toolbar__actions">
        <q-btn
          color="primary"
          icon="add"
          label="Wholesale"
          no-caps
          unelevated
          size="sm"
          class="pill-btn slim-btn shadow-1"
          @click="createWholesaleDialog = true"
        />
        <q-btn
          color="secondary"
          icon="add"
          label="Retail"
          no-caps
          unelevated
          size="sm"
          outline
          class="pill-btn slim-btn"
          @click="createRetailDialog = true"
        />
        <q-btn
          color="accent"
          icon="add"
          label="Dropship"
          no-caps
          unelevated
          size="sm"
          outline
          class="pill-btn slim-btn"
          @click="createDropshipDialog = true"
        />
      </div>
    </div>

    <PageInitialLoader v-if="invoiceStore.loading && !invoiceStore.rows.length" />

    <q-banner v-else-if="invoiceStore.error" class="bg-negative text-white q-mb-md" rounded>
      {{ invoiceStore.error }}
    </q-banner>

    <div
      v-else-if="!invoiceStore.rows.length"
      class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block floating-surface shadow-1"
    >
      <q-icon name="description" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No Sales Invoices Found</div>
      <div class="text-caption text-grey-5">
        Invoices will appear here once created for this parent company.
      </div>
    </div>

    <div v-else-if="!filteredInvoices.length" class="text-center text-grey-7 q-py-xl">
      No invoices match current search or filters.
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="row in filteredInvoices" :key="row.id" class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          class="full-height cursor-pointer floating-surface card-hover invoice-card"
          @click="goToDetails(row)"
        >
          <q-card-section class="q-pb-xs">
            <div class="column q-gutter-y-xs">
              <div>
                <div class="text-subtitle1 text-weight-bold text-black">{{ row.invoice_no }}</div>
                <div class="text-caption text-grey-7">
                  Invoice ID: {{ row.id }}-{{ row.invoice_date }}
                </div>
              </div>
              <div class="row items-center q-gutter-xs q-mt-xs">
                <q-chip
                  square
                  dense
                  :color="row.invoice_type === 'wholesale' ? 'purple-2' : row.invoice_type === 'dropship' ? 'orange-2' : 'blue-2'"
                  :text-color="row.invoice_type === 'wholesale' ? 'purple-10' : row.invoice_type === 'dropship' ? 'orange-10' : 'blue-10'"
                  class="text-weight-bold text-capitalize q-ma-none"
                >
                  {{ row.invoice_type || 'retail' }}
                </q-chip>
                <!-- Invoice Status -->
                <q-chip
                  square
                  dense
                  :style="invoiceStatusChipStyle(row.invoice_status)"
                  class="status-chip text-weight-bold q-ma-none"
                >
                  <span
                    class="status-chip-dot"
                    :style="{ backgroundColor: invoiceStatusDotColor(row.invoice_status) }"
                  />
                  {{ formatStatusLabel(row.invoice_status).toUpperCase() }}
                </q-chip>
                <!-- Payment Status -->
                <q-chip
                  square
                  dense
                  :style="paymentStatusChipStyle(row.payment_status)"
                  class="status-chip text-weight-bold q-ma-none"
                >
                  <span
                    class="status-chip-dot"
                    :style="{ backgroundColor: paymentStatusDotColor(row.payment_status) }"
                  />
                  {{ formatStatusLabel(row.payment_status).toUpperCase() }}
                </q-chip>
              </div>
            </div>
          </q-card-section>
          <q-separator />
          <q-card-section class="q-gutter-y-xs q-pt-sm">
            <div class="row justify-between items-center">
              <div>
                <div class="text-caption text-grey-8 text-weight-medium">Invoice Date</div>
                <div class="text-body2 text-black text-weight-medium">
                  {{ row.invoice_date || '—' }}
                </div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-8 text-weight-medium">Grand Total</div>
                <div class="text-subtitle1 text-weight-bolder text-primary">
                  {{ formatAmount(row.total_amount) }}
                </div>
              </div>
            </div>
            <div class="row justify-between items-center q-mt-sm">
              <div v-if="row.billing_profile_name">
                <div class="text-caption text-grey-8 text-weight-medium">Billing Profile</div>
                <div class="text-body2 text-weight-medium ellipsis">
                  {{ row.billing_profile_name }}
                </div>
              </div>
            </div>
            <div class="row justify-between items-center q-mt-sm">
              <div>
                <div class="text-caption text-grey-8 text-weight-medium">Paid</div>
                <div class="text-body2 text-weight-medium">{{ formatAmount(row.paid_amount) }}</div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-8 text-weight-medium">Due</div>
                <div
                  class="text-body2 text-weight-bold"
                  :class="row.due_amount > 0 ? 'text-negative' : 'text-positive'"
                >
                  {{ formatAmount(row.due_amount) }}
                </div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

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
          style="min-height: 40px; border-color: rgba(0, 0, 0, 0.12);"
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
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { formatAmountBdt } from 'src/utils/currency';

import CreateGlobalInvoiceDialog from '../components/CreateGlobalInvoiceDialog.vue';
import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue';
import CreateDropshipInvoiceDialog from '../components/CreateDropshipInvoiceDialog.vue';
import { useInvoiceStore } from '../stores/invoiceStore';
import type { GlobalInvoiceCreated, GlobalInvoiceRow } from '../types';

const authStore = useAuthStore();
const tenantStore = useTenantStore();
const router = useRouter();
const invoiceStore = useInvoiceStore();

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

const activeFilterCount = computed(() => {
  let count = 0;
  if (statusFilter.value) count += 1;
  if (invoiceStatusFilter.value) count += 1;
  if (invoiceTypeFilter.value) count += 1;
  if (selectedDateRange.value) count += 1;
  return count;
});

const filteredInvoices = computed(() => {
  const search = searchText.value.trim().toLowerCase();
  const status = statusFilter.value;
  const invStatus = invoiceStatusFilter.value;
  const type = invoiceTypeFilter.value;

  let fromDate: string | null = null;
  let toDate: string | null = null;
  if (selectedDateRange.value) {
    if (typeof selectedDateRange.value === 'string') {
      const formatted = selectedDateRange.value.replace(/\//g, '-');
      fromDate = formatted;
      toDate = formatted;
    } else if (
      typeof selectedDateRange.value === 'object' &&
      selectedDateRange.value.from &&
      selectedDateRange.value.to
    ) {
      fromDate = selectedDateRange.value.from.replace(/\//g, '-');
      toDate = selectedDateRange.value.to.replace(/\//g, '-');
    }
  }

  return invoiceStore.rows.filter((row) => {
    const matchesSearch =
      !search ||
      String(row.id).includes(search) ||
      (row.invoice_no || '').toLowerCase().includes(search);

    const matchesStatus = !status || row.payment_status === status;
    const matchesInvStatus = !invStatus || row.invoice_status === invStatus;
    const matchesType = !type || row.invoice_type === type;

    let matchesDate = true;
    if (fromDate && toDate) {
      if (row.invoice_date) {
        matchesDate = row.invoice_date >= fromDate && row.invoice_date <= toDate;
      } else {
        matchesDate = false;
      }
    }

    return matchesSearch && matchesStatus && matchesInvStatus && matchesType && matchesDate;
  });
});

const formatAmount = (value: number) => formatAmountBdt(value);

const formatStatusLabel = (status?: string | null) => {
  const value = (status || 'draft').replace(/_/g, ' ');
  return value;
};

const invoiceStatusChipStyle = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  switch (value) {
    case 'draft':
      return {
        backgroundColor: '#fff7ed',
        color: '#c2410c',
        border: '1px solid #ffedd5',
      };
    case 'posted':
      return {
        backgroundColor: '#f0fdf4',
        color: '#166534',
        border: '1px solid #bbf7d0',
      };
    case 'voided':
      return {
        backgroundColor: '#fef2f2',
        color: '#991b1b',
        border: '1px solid #fee2e2',
      };
    default:
      return {
        backgroundColor: '#f9fafb',
        color: '#1f2937',
        border: '1px solid #e5e7eb',
      };
  }
};

const invoiceStatusDotColor = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  switch (value) {
    case 'draft':
      return '#ea580c';
    case 'posted':
      return '#15803d';
    case 'voided':
      return '#dc2626';
    default:
      return '#9ca3af';
  }
};

const paymentStatusChipStyle = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') {
    return { backgroundColor: '#c3e8d2', color: '#1f5d3c', border: '1px solid #9fd4b7' };
  }
  if (value === 'due' || value === 'overdue') {
    return { backgroundColor: '#f2c7d0', color: '#6f2b3a', border: '1px solid #e3a6b3' };
  }
  if (value === 'partial' || value === 'partially_paid') {
    return { backgroundColor: '#e8eaf6', color: '#283593', border: '1px solid #c5cae9' };
  }
  return { backgroundColor: '#efd399', color: '#6a4a14', border: '1px solid #d8b672' };
};

const paymentStatusDotColor = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') return '#2f8b5d';
  if (value === 'due' || value === 'overdue') return '#a64c62';
  if (value === 'partial' || value === 'partially_paid') return '#3f51b5';
  return '#9a6a24';
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
};

const load = async () => {
  const parentId = effectiveParentTenantId.value;
  if (!parentId) return;
  await invoiceStore.fetchInvoices(parentId);
};

onMounted(() => {
  void load();
});
</script>

<style scoped>
.full-width-page {
  max-width: 100% !important;
}
.status-chip {
  border-radius: 6px !important;
  font-size: 11px;
  letter-spacing: 0.02em;
}
.status-chip-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 999px;
  margin-right: 5px;
}
.invoice-card {
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.08) !important;
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s cubic-bezier(0.4, 0, 0.2, 1) !important;
}
.invoice-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 10px 22px rgba(34, 56, 101, 0.14) !important;
}
</style>
