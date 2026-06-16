<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold text-primary">Commerce Invoices</div>
      <q-btn
        color="primary"
        icon="add"
        label="Create Invoice"
        no-caps
        unelevated
        class="pill-btn slim-btn"
        @click="openCreateDialog"
      />
    </div>

    <!-- Loading State -->
    <PageInitialLoader v-if="loading" />

    <!-- Empty State -->
    <div v-else-if="!invoices.length" class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block">
      <q-icon name="description" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium">No Commerce Invoices Found</div>
      <div class="text-caption text-grey-5">Commerce invoices will appear here once generated from reviewed orders or created manually.</div>
    </div>

    <!-- Invoices Table -->
    <div v-else>
      <q-table
        flat
        bordered
        :rows="invoices"
        :columns="columns"
        row-key="id"
        class="floating-surface shadow-1 rounded-borders invoices-table"
        @row-click="onRowClick"
      >
        <template #body-cell-id="props">
          <q-td :props="props">
            #{{ props.value }}
          </q-td>
        </template>

        <template #body-cell-invoice_type="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="props.value === 'wholesale' ? 'purple-2' : 'blue-2'"
              :text-color="props.value === 'wholesale' ? 'purple-10' : 'blue-10'"
              class="text-weight-bold text-capitalize"
            >
              {{ props.value || 'retail' }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-order_id="props">
          <q-td :props="props">
            #{{ props.value }}
          </q-td>
        </template>

        <template #body-cell-is_customer_group_paid="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="props.value ? 'green' : 'red'"
              text-color="white"
              class="text-weight-bold"
            >
              {{ props.value ? 'PAID' : 'UNPAID' }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-status="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :style="statusChipStyle(props.value)"
              class="status-chip text-weight-bold"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(props.value) }"></span>
              {{ formatStatusLabel(props.value).toUpperCase() }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-created_at="props">
          <q-td :props="props">
            {{ formatDate(props.value) }}
          </q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props" class="q-gutter-xs text-center" @click.stop>
            <q-btn
              flat
              round
              color="primary"
              icon="payment"
              size="sm"
              :disable="props.row.is_customer_group_paid"
              @click="openPaymentDialog(props.row)"
            >
              <q-tooltip>Record Payment</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </div>

    <!-- Record Payment Dialog -->
    <q-dialog v-model="paymentDialog">
      <q-card style="width: 400px; max-width: 90vw;" class="rounded-borders">
        <q-card-section class="bg-primary text-white row items-center justify-between">
          <div class="text-h6">Record Payment for Invoice #{{ selectedInvoice?.id }}</div>
          <q-btn flat round icon="close" v-close-popup color="white" />
        </q-card-section>

        <q-card-section class="q-pa-md" v-if="selectedInvoice">
          <q-form @submit="submitPayment" class="q-gutter-md">
            <div class="text-subtitle2 text-grey-7 q-mb-sm">
              Total Amount: ৳{{ selectedInvoice.total_amount }} | Due: ৳{{ selectedInvoice.amount_due }}
            </div>
            <q-input
              v-model.number="paymentAmount"
              type="number"
              label="Payment Amount (BDT)"
              outlined
              dense
              class="soft-input"
              :rules="[
                val => val > 0 || 'Must be > 0',
                val => val <= Number(selectedInvoice?.amount_due) || 'Cannot exceed amount due'
              ]"
            />

            <div class="row justify-end q-mt-md">
              <q-btn label="Cancel" flat color="grey-7" v-close-popup class="q-mr-sm" />
              <q-btn label="Record Payment" type="submit" color="primary" unelevated :loading="submittingPayment" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Create Invoice Dialog -->
    <q-dialog v-model="createDialog">
      <q-card style="width: 500px; max-width: 90vw;" class="rounded-borders">
        <q-card-section class="bg-primary text-white row items-center justify-between">
          <div class="text-h6">Create Commerce Invoice</div>
          <q-btn flat round icon="close" v-close-popup color="white" />
        </q-card-section>

        <q-card-section class="q-pa-md">
          <q-form @submit="submitCreateInvoice" class="q-gutter-y-md">
            <div class="row items-center justify-between q-mb-sm border-all q-pa-sm rounded-borders bg-grey-1">
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
              <q-btn label="Cancel" flat color="grey-7" v-close-popup class="q-mr-sm" />
              <q-btn label="Create" type="submit" color="primary" unelevated :loading="creatingInvoice" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar'
import { onMounted, ref, reactive, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceInvoiceService } from '../services/commerceInvoiceService'
import { useCommerceBillingProfileStore } from '../stores/commerceBillingProfileStore'
import { commerceOrderService } from 'src/modules/commerce_order/services/commerceOrderService'
import type { CommerceInvoice } from '../types'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

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
const createForm = reactive({
  billing_profile_id: null as number | null,
  invoice_type: 'retail' as 'retail' | 'wholesale',
  recipient_name: '',
  recipient_phone: '',
  shipping_address: '',
  delivery_charge: 0,
  wrapping_charge: 0,
  cod: 0,
})

const billingProfileOptions = computed(() => {
  return commerceBillingProfileStore.items.map(bp => ({
    label: bp.name,
    value: bp.id
  }))
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

const columns: QTableColumn[] = [
  { name: 'id', label: 'Invoice ID', field: 'id', align: 'left', sortable: true },
  { name: 'invoice_type', label: 'Type', field: 'invoice_type', align: 'left', sortable: true },
  { name: 'order_id', label: 'Order ID', field: 'order_id', align: 'left', sortable: true },
  { name: 'total_amount', label: 'Total (BDT)', field: 'total_amount', align: 'left' },
  { name: 'amount_paid', label: 'Paid (BDT)', field: 'amount_paid', align: 'left' },
  { name: 'amount_due', label: 'Due (BDT)', field: 'amount_due', align: 'left' },
  { name: 'is_customer_group_paid', label: 'Payment Status', field: 'is_customer_group_paid', align: 'left', sortable: true },
  { name: 'status', label: 'Invoice Status', field: 'status', align: 'left', sortable: true },
  { name: 'delivered_by', label: 'Delivered By', field: 'delivered_by', align: 'left' },
  { name: 'created_at', label: 'Created Date', field: 'created_at', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center' },
]

const loadInvoices = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const res = await commerceInvoiceService.listCommerceInvoices(authStore.tenantId)
    if (res.success && res.data) {
      invoices.value = res.data
    } else {
      invoices.value = []
    }
  } finally {
    loading.value = false
  }
}

const onRowClick = (_evt: Event, row: CommerceInvoice) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/invoices/${row.id}`)
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
    })

    if (res.success && res.data) {
      showSuccessNotification('Manual commerce invoice created successfully.')
      createDialog.value = false
      
      // Redirect to invoice details
      const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
      void router.push(`${tenantPrefix}/app/commerce-shop/invoices/${res.data.id}`)
    } else {
      showWarningDialog(res.error || 'Failed to create manual invoice.')
    }
  } finally {
    creatingInvoice.value = false
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

const formatStatusLabel = (status: string) => {
  if (status === 'handed_to_customer') return 'handed to customer'
  return status || 'draft'
}

const statusChipStyle = (status: 'draft' | 'ready' | 'handed_to_customer') => {
  switch (status) {
    case 'ready':
      return {
        backgroundColor: '#c8d8f8',
        color: '#27487a',
        border: '1px solid #a9c4f3',
        boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
      }
    case 'handed_to_customer':
      return {
        backgroundColor: '#c3e8d2',
        color: '#1f5d3c',
        border: '1px solid #9fd4b7',
        boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
      }
    default:
      return {
        backgroundColor: '#dbe5f3',
        color: '#3b4b66',
        border: '1px solid #b9c8dd',
        boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
      }
  }
}

const statusDotColor = (status: 'draft' | 'ready' | 'handed_to_customer') => {
  switch (status) {
    case 'ready': return '#3f67b3'
    case 'handed_to_customer': return '#2f8b5d'
    default: return '#66758c'
  }
}

onMounted(() => {
  void loadInvoices()
})
</script>

<style scoped>
.empty-state-block {
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid #e7e2d8;
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

.invoices-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
  font-weight: 600;
  color: #2c3e50;
}

.invoices-table :deep(tr) {
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.invoices-table :deep(tr:hover) {
  background-color: rgba(34, 56, 101, 0.03);
}

.pill-btn {
  border-radius: 999px;
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
</style>
