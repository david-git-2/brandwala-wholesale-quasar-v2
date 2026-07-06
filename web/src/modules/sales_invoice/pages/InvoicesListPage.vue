<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-black">Sales Invoices</div>
            <div class="text-caption text-grey-8">Wholesale, retail, and dropship desk invoices across sister concerns</div>
          </div>
          <div class="col-auto row q-gutter-sm">
            <q-btn color="primary" icon="add" label="Wholesale" no-caps unelevated class="pill-btn slim-btn shadow-1" @click="createWholesaleDialog = true" />
            <q-btn color="secondary" icon="add" label="Retail" no-caps unelevated outline class="pill-btn slim-btn" @click="createRetailDialog = true" />
            <q-btn color="accent" icon="add" label="Dropship" no-caps unelevated outline class="pill-btn slim-btn" @click="createDropshipDialog = true" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
      <div class="row items-center q-gutter-sm toolbar-left">
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
          class="soft-input toolbar-search"
          label="Search Invoices"
          @clear="onSearchChange"
          @keyup.enter="onSearchChange"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="filterDrawerOpen = true">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
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
      <div class="text-caption text-grey-5">Invoices will appear here once created for this parent company.</div>
    </div>

    <div v-else-if="!filteredInvoices.length" class="text-center text-grey-7 q-py-xl">
      No invoices match current search or filters.
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="row in filteredInvoices" :key="row.id" class="col-12 col-sm-6 col-lg-4">
        <q-card
          flat
          class="full-height cursor-pointer floating-surface shadow-1 card-hover"
          @click="goToDetails(row)"
        >
          <q-card-section class="q-pb-xs">
            <div class="row items-start justify-between no-wrap">
              <div>
                <div class="text-subtitle1 text-weight-bold text-black">{{ row.invoice_no }}</div>
                <div class="text-caption text-grey-7">Invoice #{{ row.id }}</div>
              </div>
              <div class="row items-center q-gutter-x-xs no-wrap">
                <q-chip
                  square
                  dense
                  :color="row.invoice_type === 'wholesale' ? 'purple-2' : 'blue-2'"
                  :text-color="row.invoice_type === 'wholesale' ? 'purple-10' : 'blue-10'"
                  class="text-weight-bold text-capitalize q-ma-none"
                >
                  {{ row.invoice_type || 'retail' }}
                </q-chip>
                <q-chip
                  square
                  dense
                  :style="statusChipStyle(row.payment_status)"
                  class="status-chip text-weight-bold q-ma-none"
                >
                  <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(row.payment_status) }" />
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
                <div class="text-body2 text-black text-weight-medium">{{ row.invoice_date || '—' }}</div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-8 text-weight-medium">Grand Total</div>
                <div class="text-subtitle1 text-weight-bolder text-primary">{{ formatAmount(row.total_amount) }}</div>
              </div>
            </div>
            <div class="row justify-between items-center q-mt-sm">
              <div v-if="row.billing_profile_name">
                <div class="text-caption text-grey-8 text-weight-medium">Billing Profile</div>
                <div class="text-body2 text-weight-medium ellipsis">{{ row.billing_profile_name }}</div>
              </div>
            </div>
            <div class="row justify-between items-center q-mt-sm">
              <div>
                <div class="text-caption text-grey-8 text-weight-medium">Paid</div>
                <div class="text-body2 text-weight-medium">{{ formatAmount(row.paid_amount) }}</div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-8 text-weight-medium">Due</div>
                <div class="text-body2 text-weight-bold" :class="row.due_amount > 0 ? 'text-negative' : 'text-positive'">
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
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" class="text-black text-weight-bold" @click="onResetFilters" />
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
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { formatAmountBdt } from 'src/utils/currency'

import CreateGlobalInvoiceDialog from '../components/CreateGlobalInvoiceDialog.vue'
import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue'
import CreateDropshipInvoiceDialog from '../components/CreateDropshipInvoiceDialog.vue'
import { useInvoiceStore } from '../stores/invoiceStore'
import type { GlobalInvoiceCreated, GlobalInvoiceRow } from '../types'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const router = useRouter()
const invoiceStore = useInvoiceStore()

const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null
  if (!current) return authStore.tenantId
  return current.parent_id ?? current.id
})

const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)
const searchText = ref('')
const statusFilter = ref<string | null>(null)
const invoiceTypeFilter = ref<string | null>(null)
const createWholesaleDialog = ref(false)
const createRetailDialog = ref(false)
const createDropshipDialog = ref(false)

const statusFilterOptions = [
  { label: 'Paid', value: 'paid' },
  { label: 'Due', value: 'due' },
  { label: 'Partial', value: 'partial' },
  { label: 'Draft', value: 'draft' },
]

const activeFilterCount = computed(() => {
  let count = 0
  if (statusFilter.value) count += 1
  if (invoiceTypeFilter.value) count += 1
  return count
})

const filteredInvoices = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  const status = statusFilter.value
  const type = invoiceTypeFilter.value

  return invoiceStore.rows.filter((row) => {
    const matchesSearch =
      !search ||
      String(row.id).includes(search) ||
      (row.invoice_no || '').toLowerCase().includes(search)

    const matchesStatus = !status || row.payment_status === status
    const matchesType = !type || row.invoice_type === type
    return matchesSearch && matchesStatus && matchesType
  })
})

const formatAmount = (value: number) => formatAmountBdt(value)

const formatStatusLabel = (status: string) => {
  const value = (status || 'draft').replace(/_/g, ' ')
  return value
}

const statusChipStyle = (status?: string | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'paid') {
    return { backgroundColor: '#c3e8d2', color: '#1f5d3c', border: '1px solid #9fd4b7' }
  }
  if (value === 'due' || value === 'overdue') {
    return { backgroundColor: '#f2c7d0', color: '#6f2b3a', border: '1px solid #e3a6b3' }
  }
  if (value === 'partial' || value === 'partially_paid') {
    return { backgroundColor: '#e8eaf6', color: '#283593', border: '1px solid #c5cae9' }
  }
  return { backgroundColor: '#efd399', color: '#6a4a14', border: '1px solid #d8b672' }
}

const statusDotColor = (status?: string | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'paid') return '#2f8b5d'
  if (value === 'due' || value === 'overdue') return '#a64c62'
  if (value === 'partial' || value === 'partially_paid') return '#3f51b5'
  return '#9a6a24'
}

const goToDetails = (row: GlobalInvoiceRow) => {
  void router.push({
    name: 'app-global-invoice-details-page',
    params: {
      tenantSlug: authStore.tenantSlug,
      id: row.id,
    },
  })
}

const onInvoiceCreated = (invoice: GlobalInvoiceCreated) => {
  goToDetails(invoice)
}

const onSearchChange = () => {}
const onCloseSearch = () => {
  showSearchInput.value = false
  searchText.value = ''
}
const onResetFilters = () => {
  statusFilter.value = null
  invoiceTypeFilter.value = null
}

const load = async () => {
  const parentId = effectiveParentTenantId.value
  if (!parentId) return
  await invoiceStore.fetchInvoices(parentId)
}

onMounted(() => {
  void load()
})
</script>

<style scoped>
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
</style>
