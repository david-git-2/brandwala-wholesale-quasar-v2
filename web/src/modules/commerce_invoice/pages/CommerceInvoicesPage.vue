<template>
  <q-page class="q-pa-md">
    <!-- Hero Header Card -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-black">Shop Invoices</div>
            <div class="text-caption text-grey-8">Order-generated wholesale and retail invoices from the B2B shop</div>
            <div class="text-caption text-grey-8">Manage commerce invoices, orders, and customer payments</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              icon="add"
              label="Create Invoice"
              no-caps
              unelevated
              class="pill-btn slim-btn shadow-1"
              @click="openCreateDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Toolbar Filters & Search -->
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

    <!-- Loading State -->
    <PageInitialLoader v-if="loading" />

    <!-- Empty State -->
    <div v-else-if="!invoices.length" class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block floating-surface shadow-1">
      <q-icon name="description" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No Commerce Invoices Found</div>
      <div class="text-caption text-grey-5">Commerce invoices will appear here once generated from orders or created manually.</div>
    </div>

    <div v-else-if="!filteredInvoices.length" class="text-center text-grey-7 q-py-xl">
      No invoices match current search or filters.
    </div>

    <!-- Card List Layout -->
    <div v-else class="row q-col-gutter-md">
      <div v-for="row in filteredInvoices" :key="row.id" class="col-12 col-sm-6 col-lg-4">
        <q-card
          flat
          class="full-height cursor-pointer floating-surface shadow-1 card-hover"
          :style="invoiceCardStyle(row)"
          @click="goToDetails(row)"
        >
          <q-card-section class="q-pb-xs">
            <div class="row items-start justify-between no-wrap">
              <div>
                <div class="text-subtitle1 text-weight-bold text-black">Invoice #{{ row.id }}</div>
                <div class="text-caption text-grey-7">Order Ref: {{ row.order_id ? '#' + row.order_id : 'Direct Invoice' }}</div>
              </div>
              <div class="row items-center q-gutter-x-xs no-wrap">
                <!-- Type Chip -->
                <q-chip
                  square
                  dense
                  :color="row.invoice_type === 'wholesale' ? 'purple-2' : 'blue-2'"
                  :text-color="row.invoice_type === 'wholesale' ? 'purple-10' : 'blue-10'"
                  class="text-weight-bold text-capitalize q-ma-none"
                >
                  {{ row.invoice_type || 'retail' }}
                </q-chip>

                <!-- Status Chip -->
                <q-chip
                  square
                  dense
                  :style="statusChipStyle(row.status)"
                  class="status-chip text-weight-bold q-ma-none"
                >
                  <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(row.status) }"></span>
                  {{ formatStatusLabel(row.status).toUpperCase() }}
                </q-chip>

                <q-btn flat round dense icon="more_vert" @click.stop>
                  <q-menu auto-close>
                    <q-list dense style="min-width: 140px">
                      <q-item clickable :disable="row.is_customer_group_paid" @click="openPaymentDialog(row)">
                        <q-item-section>Record Payment</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </div>
            </div>
          </q-card-section>
          <q-separator class="separator-light" />
          <q-card-section class="q-gutter-y-xs q-pt-sm">
            <div class="row justify-between items-center">
              <div class="col">
                <div class="text-caption text-grey-8 text-weight-medium">Billing Profile</div>
                <div class="text-body2 text-black text-weight-medium ellipsis" style="max-width: 180px;">
                  {{ getBillingProfileName(row.billing_profile_id) }}
                </div>
              </div>
              <div class="col-auto text-right">
                <div class="text-caption text-grey-8 text-weight-medium">Paid Status</div>
                <q-chip
                  square
                  dense
                  :color="row.is_customer_group_paid ? 'green-2' : 'red-2'"
                  :text-color="row.is_customer_group_paid ? 'green-10' : 'red-10'"
                  class="text-weight-bold q-ma-none"
                >
                  {{ row.is_customer_group_paid ? 'PAID' : 'UNPAID' }}
                </q-chip>
              </div>
            </div>

            <div class="row justify-between items-center q-mt-sm">
              <div>
                <div class="text-caption text-grey-8 text-weight-medium">Invoice Date</div>
                <div class="text-body2 text-black text-weight-medium">{{ row.invoice_date || '-' }}</div>
              </div>
              <div class="text-right">
                <div class="text-caption text-grey-8 text-weight-medium">Grand Total</div>
                <div class="text-subtitle1 text-weight-bolder text-primary">৳{{ formatAmount(row.total_amount) }}</div>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Filter Drawer -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="statusFilter"
        :options="statusFilterOptions"
        label="Invoice Status"
        outlined
        dense
        clearable
        emit-value
        map-options
        class="soft-input q-mb-sm"
        @update:model-value="onSearchChange"
      >
        <template #selected-item="scope">
          <span class="text-black text-weight-medium">{{ scope.opt.label }}</span>
        </template>
      </q-select>

      <q-select
        v-model="billingProfileFilter"
        :options="billingProfileOptions"
        label="Billing Profile"
        outlined
        dense
        clearable
        emit-value
        map-options
        class="soft-input q-mb-sm"
        @update:model-value="onSearchChange"
      >
        <template #selected-item="scope">
          <span class="text-black text-weight-medium">{{ scope.opt.label }}</span>
        </template>
      </q-select>

      <q-select
        v-model="invoiceTypeFilter"
        :options="[
          { label: 'Retail', value: 'retail' },
          { label: 'Wholesale', value: 'wholesale' }
        ]"
        label="Invoice Type"
        outlined
        dense
        clearable
        emit-value
        map-options
        class="soft-input q-mb-sm"
        @update:model-value="onSearchChange"
      >
        <template #selected-item="scope">
          <span class="text-black text-weight-medium">{{ scope.opt.label }}</span>
        </template>
      </q-select>

      <!-- Start Date Filter -->
      <q-input
        v-model="startDateFilter"
        label="Start Date"
        outlined
        dense
        clearable
        mask="####-##-##"
        class="soft-input q-mb-sm"
        @update:model-value="onSearchChange"
      >
        <template v-slot:append>
          <q-icon name="event" class="cursor-pointer">
            <q-popup-proxy cover transition-show="scale" transition-hide="scale">
              <q-date v-model="startDateFilter" mask="YYYY-MM-DD" @update:model-value="onSearchChange" />
            </q-popup-proxy>
          </q-icon>
        </template>
      </q-input>

      <!-- End Date Filter -->
      <q-input
        v-model="endDateFilter"
        label="End Date"
        outlined
        dense
        clearable
        mask="####-##-##"
        class="soft-input q-mb-md"
        @update:model-value="onSearchChange"
      >
        <template v-slot:append>
          <q-icon name="event" class="cursor-pointer">
            <q-popup-proxy cover transition-show="scale" transition-hide="scale">
              <q-date v-model="endDateFilter" mask="YYYY-MM-DD" @update:model-value="onSearchChange" />
            </q-popup-proxy>
          </q-icon>
        </template>
      </q-input>

      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" class="text-black text-weight-bold" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <!-- Record Payment Dialog -->
    <q-dialog v-model="paymentDialog">
      <q-card style="width: 400px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-sm">
        <q-card-section class="row items-center justify-between q-py-sm">
          <div class="text-h6 text-weight-bold text-black">Record Payment</div>
          <q-btn flat round icon="close" v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section class="q-pa-md" v-if="selectedInvoice">
          <q-form @submit="submitPayment" class="q-gutter-y-md">
            <div class="text-subtitle2 text-grey-8 q-mb-xs">
              Invoice #{{ selectedInvoice.id }} | Total: ৳{{ formatAmount(selectedInvoice.total_amount) }}
            </div>
            <div class="text-subtitle2 text-red-7 q-mb-sm">
              Outstanding Due: ৳{{ formatAmount(selectedInvoice.amount_due) }}
            </div>
            <q-input
              v-model.number="paymentAmount"
              type="number"
              step="0.01"
              label="Payment Amount (BDT) *"
              outlined
              dense
              class="soft-input"
              autofocus
              :rules="[
                val => val > 0 || 'Must be > 0',
                val => val <= Number(selectedInvoice?.amount_due) || 'Cannot exceed amount due'
              ]"
            />

            <div class="row justify-end q-mt-lg">
              <q-btn label="Cancel" flat color="grey-7" v-close-popup class="q-mr-sm" />
              <q-btn label="Record" type="submit" color="primary" class="pill-btn slim-btn" unelevated :loading="submittingPayment" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Create Invoice Dialog -->
    <q-dialog v-model="createDialog">
      <q-card style="min-width: 420px; max-width: 95vw" class="floating-surface shadow-2 q-pa-sm">
        <q-card-section class="text-h6 text-weight-bold text-black">Create Commerce Invoice</q-card-section>

        <q-card-section>
          <q-form @submit="submitCreateInvoice" class="q-gutter-y-md">
            <div class="row items-center justify-between q-mb-sm border-all q-pa-sm rounded-borders bg-grey-1" style="border: 1px solid rgba(34, 56, 101, 0.08);">
              <span class="text-subtitle2 text-grey-8 text-weight-bold">Invoice Type:</span>
              <q-btn-toggle
                v-model="createForm.invoice_type"
                toggle-color="primary"
                flat
                dense
                unelevated
                :options="[
                  { label: 'Retail', value: 'retail' },
                  { label: 'Wholesale', value: 'wholesale' }
                ]"
              />
            </div>

            <q-select
              v-model="createForm.billing_profile_id"
              :options="billingProfileOptions"
              label="Billing Profile *"
              outlined
              dense
              emit-value
              map-options
              class="soft-input"
              :rules="[val => !!val || 'Billing Profile is required']"
            />

            <q-input
              v-model="createForm.invoice_date"
              label="Invoice Date *"
              outlined
              dense
              readonly
              class="soft-input"
              :rules="[val => !!val || 'Invoice Date is required']"
            >
              <template #append>
                <q-icon name="event" class="cursor-pointer">
                  <q-popup-proxy ref="createDateProxy" cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="createForm.invoice_date" mask="YYYY-MM-DD" @update:model-value="() => createDateProxy?.hide()">
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>

            <q-input
              v-model="createForm.recipient_name"
              label="Recipient Name *"
              outlined
              dense
              class="soft-input"
              :rules="[val => !!val || 'Recipient Name is required']"
            />
            
            <template v-if="createForm.invoice_type === 'retail'">
              <q-input
                v-model="createForm.recipient_phone"
                label="Recipient Phone *"
                outlined
                dense
                class="soft-input"
                :rules="[val => !!val || 'Recipient Phone is required']"
              />
              <q-input
                v-model="createForm.shipping_address"
                label="Shipping Address *"
                outlined
                dense
                class="soft-input"
                :rules="[val => !!val || 'Shipping Address is required']"
              />
              <q-input
                v-model.number="createForm.delivery_charge"
                type="number"
                label="Delivery Charge"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
              <q-input
                v-model.number="createForm.wrapping_charge"
                type="number"
                label="Wrapping Charge"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
              <q-input
                v-model.number="createForm.cod"
                type="number"
                label="COD Charge"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
            </template>

            <div class="row justify-end q-mt-lg">
              <q-btn flat no-caps label="Cancel" class="text-black text-weight-bold q-mr-sm" v-close-popup />
              <q-btn
                color="primary"
                class="pill-btn slim-btn"
                no-caps
                label="Create"
                type="submit"
                :loading="creatingInvoice"
              />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, reactive, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import type { QPopupProxy } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceInvoiceService } from '../services/commerceInvoiceService'
import { useCommerceBillingProfileStore } from '../stores/commerceBillingProfileStore'
import { commerceOrderService } from 'src/modules/commerce_order/services/commerceOrderService'
import type { CommerceInvoice } from '../types'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'

const authStore = useAuthStore()
const router = useRouter()
const commerceBillingProfileStore = useCommerceBillingProfileStore()

// State
const loading = ref(true)
const invoices = ref<CommerceInvoice[]>([])
const paymentDialog = ref(false)
const selectedInvoice = ref<CommerceInvoice | null>(null)
const paymentAmount = ref(0)
const submittingPayment = ref(false)

// Create Invoice Dialog
const createDialog = ref(false)
const creatingInvoice = ref(false)
const createDateProxy = ref<QPopupProxy | null>(null)
const createForm = reactive({
  billing_profile_id: null as number | null,
  invoice_type: 'retail' as 'retail' | 'wholesale',
  invoice_date: '',
  recipient_name: '',
  recipient_phone: '',
  shipping_address: '',
  delivery_charge: 0,
  wrapping_charge: 0,
  cod: 0,
})

// Search & Filter State
const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)
const searchText = ref('')
const statusFilter = ref<string | null>(null)
const billingProfileFilter = ref<number | null>(null)
const invoiceTypeFilter = ref<string | null>(null)
const startDateFilter = ref<string | null>(null)
const endDateFilter = ref<string | null>(null)

const statusFilterOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'Invoicing', value: 'invoicing' },
  { label: 'Issued', value: 'issued' },
  { label: 'Partially Paid', value: 'partially_paid' },
  { label: 'Paid', value: 'paid' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Cancelled', value: 'cancelled' },
]

const billingProfileOptions = computed(() => {
  return commerceBillingProfileStore.items.map(bp => ({
    label: bp.name,
    value: bp.id
  }))
})

const activeFilterCount = computed(() => {
  let count = 0
  if (statusFilter.value) count += 1
  if (billingProfileFilter.value) count += 1
  if (invoiceTypeFilter.value) count += 1
  if (startDateFilter.value) count += 1
  if (endDateFilter.value) count += 1
  return count
})

watch(() => createForm.billing_profile_id, (bpId) => {
  if (!bpId) return
  const bp = commerceBillingProfileStore.items.find(p => p.id === bpId)
  if (bp) {
    createForm.recipient_name = bp.name || ''
    createForm.recipient_phone = bp.phone || ''
    createForm.shipping_address = bp.address || ''
  }
})

const loadInvoices = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const [res] = await Promise.all([
      commerceInvoiceService.listCommerceInvoices(authStore.tenantId),
      commerceBillingProfileStore.fetchCommerceBillingProfiles({
        tenant_id: authStore.tenantId,
        page: 1,
        page_size: 100,
        sortBy: 'name',
        sortOrder: 'asc',
      })
    ])
    if (res.success && res.data) {
      invoices.value = res.data
    } else {
      invoices.value = []
    }
  } finally {
    loading.value = false
  }
}

const getBillingProfileName = (id: number | null) => {
  if (!id) return 'Others'
  const bp = commerceBillingProfileStore.items.find(p => p.id === id)
  return bp ? bp.name : 'Others'
}

const invoiceCardStyle = (invoice: CommerceInvoice) => {
  const bp = commerceBillingProfileStore.items.find(p => p.id === invoice.billing_profile_id)
  const color = bp?.color
  if (color) {
    return {
      borderLeft: `6px solid ${color}`,
    }
  }
  return {}
}

const goToDetails = (row: CommerceInvoice) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/invoices/${row.id}`)
}

const formatAmount = (val: number | string | null) => {
  return Number(val || 0).toFixed(2)
}

const filteredInvoices = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  const status = statusFilter.value
  const bp = billingProfileFilter.value
  const type = invoiceTypeFilter.value
  const start = startDateFilter.value
  const end = endDateFilter.value

  return invoices.value.filter((row) => {
    const bpName = getBillingProfileName(row.billing_profile_id).toLowerCase()
    const matchesSearch =
      !search ||
      String(row.id).includes(search) ||
      (row.order_id ? String(row.order_id).includes(search) : false) ||
      bpName.includes(search) ||
      (row.delivered_by || '').toLowerCase().includes(search)

    const matchesStatus = !status || row.status === status
    const matchesBp = !bp || row.billing_profile_id === bp
    const matchesType = !type || row.invoice_type === type
    const matchesStart = !start || (row.invoice_date && row.invoice_date.replace(/\//g, '-') >= start.replace(/\//g, '-'))
    const matchesEnd = !end || (row.invoice_date && row.invoice_date.replace(/\//g, '-') <= end.replace(/\//g, '-'))

    return matchesSearch && matchesStatus && matchesBp && matchesType && matchesStart && matchesEnd
  })
})

const onSearchChange = () => {}
const onCloseSearch = () => {
  showSearchInput.value = false
  searchText.value = ''
}
const onResetFilters = () => {
  statusFilter.value = null
  billingProfileFilter.value = null
  invoiceTypeFilter.value = null
  startDateFilter.value = null
  endDateFilter.value = null
}

const openPaymentDialog = (invoice: CommerceInvoice) => {
  selectedInvoice.value = invoice
  paymentAmount.value = Number(invoice.amount_due) || 0
  paymentDialog.value = true
}

const submitPayment = async () => {
  if (!selectedInvoice.value) return
  submittingPayment.value = true
  try {
    const res = await commerceInvoiceService.updateInvoicePayment(selectedInvoice.value.id, paymentAmount.value)
    if (res.success) {
      showSuccessNotification('Payment recorded successfully.')
      paymentDialog.value = false
      await loadInvoices()
    } else {
      showWarningDialog(res.error || 'Failed to record payment.')
    }
  } finally {
    submittingPayment.value = false
  }
}

const openCreateDialog = async () => {
  if (!authStore.tenantId) return
  createForm.billing_profile_id = null
  createForm.invoice_type = 'retail'
  createForm.invoice_date = new Date().toISOString().slice(0, 10)
  createForm.recipient_name = ''
  createForm.recipient_phone = ''
  createForm.shipping_address = ''
  createForm.delivery_charge = 0
  createForm.wrapping_charge = 0
  createForm.cod = 0

  loading.value = true
  try {
    const [, settingsRes] = await Promise.all([
      commerceBillingProfileStore.fetchCommerceBillingProfiles({
        tenant_id: authStore.tenantId,
        page: 1,
        page_size: 100,
        sortBy: 'name',
        sortOrder: 'asc',
      }),
      commerceOrderService.getCommerceOrderSettings(authStore.tenantId)
    ])

    if (settingsRes.success && settingsRes.data) {
      createForm.delivery_charge = Number(settingsRes.data.default_delivery_charge) || 0
      createForm.wrapping_charge = Number(settingsRes.data.default_wrapping_charge) || 0
    }
    createDialog.value = true
  } finally {
    loading.value = false
  }
}

const submitCreateInvoice = async () => {
  if (!authStore.tenantId || !createForm.billing_profile_id) return
  creatingInvoice.value = true
  try {
    const isWholesale = createForm.invoice_type === 'wholesale'
    const res = await commerceInvoiceService.createManualInvoice({
      tenant_id: authStore.tenantId,
      billing_profile_id: createForm.billing_profile_id,
      invoice_type: createForm.invoice_type,
      recipient_name: createForm.recipient_name,
      recipient_phone: isWholesale ? null : createForm.recipient_phone,
      shipping_address: isWholesale ? null : createForm.shipping_address,
      delivery_charge: isWholesale ? 0 : createForm.delivery_charge,
      wrapping_charge: isWholesale ? 0 : createForm.wrapping_charge,
      cod: isWholesale ? 0 : createForm.cod,
      invoice_date: createForm.invoice_date,
    })

    if (res.success && res.data) {
      showSuccessNotification('Manual commerce invoice created successfully.')
      createDialog.value = false
      
      const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
      void router.push(`${tenantPrefix}/app/commerce-shop/invoices/${res.data.id}`)
    } else {
      showWarningDialog(res.error || 'Failed to create manual invoice.')
    }
  } finally {
    creatingInvoice.value = false
  }
}

const formatStatusLabel = (status: string) => {
  const value = status || 'draft'
  if (value === 'handed_to_customer') return 'handed to customer'
  if (value === 'partially_paid') return 'partially paid'
  return value
}

const statusChipStyle = (status?: string | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'draft') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
      boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
    }
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#e1bee7',
      color: '#4a148c',
      border: '1px solid #ce93d8',
      boxShadow: '0 1px 2px rgba(74, 20, 140, 0.18)',
    }
  }
  if (value === 'issued') {
    return {
      backgroundColor: '#d7e7f6',
      color: '#1a4562',
      border: '1px solid #9ebfdc',
      boxShadow: '0 1px 2px rgba(26, 69, 98, 0.18)',
    }
  }
  if (value === 'partially_paid') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
      boxShadow: '0 1px 2px rgba(40, 53, 147, 0.18)',
    }
  }
  if (value === 'paid') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
      boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
    }
  }
  if (value === 'overdue') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
      boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f5f5f5',
      color: '#616161',
      border: '1px solid #e0e0e0',
      boxShadow: '0 1px 2px rgba(97, 97, 97, 0.18)',
    }
  }
  // legacy fallback
  if (value === 'ready') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
      boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
    }
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
    boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  }
}

const statusDotColor = (status?: string | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'draft') return '#9a6a24'
  if (value === 'invoicing') return '#8e24aa'
  if (value === 'issued') return '#2f6e92'
  if (value === 'partially_paid') return '#3f51b5'
  if (value === 'paid') return '#2f8b5d'
  if (value === 'overdue') return '#a64c62'
  if (value === 'cancelled') return '#757575'
  if (value === 'ready') return '#3f67b3'
  return '#66758c'
}

onMounted(() => {
  void loadInvoices()
})
</script>

<style scoped>
.empty-state-block {
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 14px;
  backdrop-filter: blur(6px);
  text-align: center;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 8px !important;
}

.slim-btn {
  min-height: 36px;
  padding-left: 16px;
  padding-right: 16px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  color: #2c3e50 !important;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}

.separator-light {
  background: rgba(34, 56, 101, 0.08);
}

.card-hover {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.12) !important;
}
</style>
