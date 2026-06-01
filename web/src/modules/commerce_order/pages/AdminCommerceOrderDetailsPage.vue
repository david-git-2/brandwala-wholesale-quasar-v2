<template>
  <q-page class="q-pa-md commerce-order-details-page">
    <!-- Loading State -->
    <div v-if="loading" class="customer-order-details-wrap">
      <div class="row items-center justify-between q-mb-sm">
        <q-skeleton type="text" width="280px" height="32px" />
        <q-skeleton type="QChip" width="100px" />
      </div>

      <q-card flat bordered class="q-mt-sm q-mb-md bg-white">
        <q-card-section class="row q-col-gutter-md">
          <div class="col" v-for="n in 3" :key="`summary-col-${n}`">
            <q-skeleton type="text" width="60px" />
            <q-skeleton type="text" width="90px" class="q-mt-xs" />
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block floating-surface shadow-1">
      <q-icon name="error_outline" size="64px" class="q-mb-sm text-red" />
      <div class="text-subtitle1 text-weight-medium text-grey-7">{{ error }}</div>
      <q-btn label="Back to Orders" color="primary" class="pill-btn slim-btn q-mt-md" unelevated @click="backToOrders" />
    </div>

    <!-- Details View -->
    <div v-else-if="order" class="customer-order-details-wrap">
      <!-- Header Hero Card -->
      <q-card flat class="hero-surface floating-surface shadow-1 q-mb-md q-pa-md">
        <div class="row items-center justify-between">
          <div class="row items-center">
            <q-btn flat round icon="arrow_back" color="primary" class="q-mr-sm" @click="backToOrders" />
            <div>
              <div class="text-h6 text-weight-bold text-primary">Commerce Order #{{ order.id }}</div>
              <div class="text-caption text-grey-8">Placed on {{ formatDate(order.order_placement_date) }}</div>
            </div>
          </div>
          <div class="row items-center q-gutter-sm">
            <q-btn
              color="secondary"
              icon="description"
              label="Generate Invoice"
              no-caps
              unelevated
              class="pill-btn slim-btn"
              :disable="order.status === 'cancelled'"
              @click="openInvoiceDialog"
            />
            <q-chip
              square
              dense
              :color="getStatusColor(order.status)"
              text-color="white"
              class="text-weight-bold status-chip"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: getStatusDotColor(order.status) }"></span>
              {{ order.status.toUpperCase() }}
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Main Layout Grid -->
      <div class="row q-col-gutter-md q-mb-md">
        <!-- Recipient Information Card -->
        <div class="col-12 col-md-6">
          <q-card flat class="floating-surface shadow-1 q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">
              <q-icon name="assignment" class="q-mr-xs" /> Recipient Details
            </div>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <div class="text-subtitle2 text-grey-7">Recipient Name</div>
                <div class="text-body1 text-weight-medium text-grey-9">{{ order.recipient_name }}</div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="text-subtitle2 text-grey-7">Recipient Phone</div>
                <div class="text-body1 text-weight-medium text-grey-9">{{ order.recipient_phone }}</div>
              </div>
              <div class="col-12">
                <div class="text-subtitle2 text-grey-7">Shipping Address</div>
                <div class="text-body1 text-grey-9">{{ order.shipping_address }}</div>
              </div>
            </div>
          </q-card>
        </div>

        <!-- Order Status Control Card -->
        <div class="col-12 col-md-6">
          <q-card flat class="floating-surface shadow-1 q-pa-md full-height">
            <div class="row items-center justify-between q-mb-md">
              <div class="text-subtitle1 text-weight-bold text-primary">
                <q-icon name="local_atm" class="q-mr-xs" /> Pricing Details
              </div>
              <q-btn
                v-if="!editChargesMode"
                flat
                dense
                no-caps
                size="sm"
                icon="edit"
                label="Edit Charges"
                color="primary"
                class="pill-btn"
                @click="startEditCharges"
              />
            </div>

            <q-form v-if="editChargesMode" @submit="saveCharges" class="q-gutter-y-sm">
              <q-input
                v-model.number="chargesForm.delivery_charge"
                type="number"
                step="0.01"
                label="Delivery Charge"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
              <q-input
                v-model.number="chargesForm.wrapping_charge"
                type="number"
                step="0.01"
                label="Wrapping Charge"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
              <q-input
                v-model.number="chargesForm.cod"
                type="number"
                step="0.01"
                label="COD"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
              <q-input
                v-model.number="chargesForm.shipment_payment"
                type="number"
                step="0.01"
                label="Grand Total"
                outlined
                dense
                class="soft-input"
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
              <div class="row justify-end q-gutter-x-sm q-mt-md">
                <q-btn label="Cancel" flat color="grey-7" size="sm" class="pill-btn" @click="editChargesMode = false" />
                <q-btn label="Save" type="submit" color="primary" size="sm" class="pill-btn slim-btn" unelevated :loading="savingCharges" />
              </div>
            </q-form>
            
            <div v-else class="row q-col-gutter-md q-mb-md">
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">Delivery Charge</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.delivery_charge || 0).toFixed(2) }}</div>
              </div>
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">Wrapping Charge</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.wrapping_charge || 0).toFixed(2) }}</div>
              </div>
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">COD</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.cod || 0).toFixed(2) }}</div>
              </div>
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">Grand Total</div>
                <div class="text-h6 text-weight-bold text-primary">৳{{ Number(order.shipment_payment || 0).toFixed(2) }}</div>
              </div>
            </div>

            <q-separator class="q-my-sm" />

            <div class="row items-end q-col-gutter-sm q-mt-xs">
              <div class="col-grow">
                <div class="text-caption text-grey-8 q-mb-xs">Update Order Status</div>
                <q-select
                  v-model="newStatus"
                  :options="statusOptions"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
              <div class="col-auto">
                <q-btn
                  color="primary"
                  label="Save Status"
                  no-caps
                  unelevated
                  class="pill-btn slim-btn"
                  :loading="updatingStatus"
                  @click="updateStatus"
                />
              </div>
            </div>
          </q-card>
        </div>
      </div>

      <!-- Order Items List -->
      <div class="text-subtitle1 text-weight-bold text-primary q-mb-sm">
        <q-icon name="shopping_bag" class="q-mr-xs" /> Items ({{ items.length }})
      </div>
      <q-card flat class="floating-surface shadow-1">
        <q-list separator class="rounded-borders">
          <q-item v-for="item in items" :key="item.id" class="q-py-md">
            <q-item-section avatar>
              <q-avatar rounded size="60px" class="bg-grey-2 border-all">
                <img :src="item.image_url || 'https://placehold.co/60x60?text=No+Image'" alt="" />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label class="text-weight-bold text-body1 text-grey-9">Product ID: {{ item.product_id }}</q-item-label>
              <q-item-label caption class="text-body2 text-grey-7">Quantity: {{ item.quantity }}</q-item-label>
            </q-item-section>

            <q-item-section side class="text-right">
              <div class="text-body1 text-weight-bold text-primary">Recipient Price: ৳{{ Number(item.recipient_price_bdt).toFixed(2) }}</div>
              <div class="text-caption text-grey-7">Cost BDT: ৳{{ Number(item.cost_bdt).toFixed(2) }} | Sell Price: ৳{{ Number(item.sell_price_bdt).toFixed(2) }}</div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </div>

    <!-- Create Invoice Dialog -->
    <q-dialog v-model="invoiceDialog">
      <q-card style="width: 500px; max-width: 90vw;" class="rounded-borders">
        <q-card-section class="bg-secondary text-white row items-center justify-between">
          <div class="text-h6">Create Invoice for Order #{{ order?.id }}</div>
          <q-btn flat round icon="close" v-close-popup color="white" />
        </q-card-section>

        <q-card-section class="q-pa-md" v-if="order">
          <q-form @submit="createInvoice" class="q-gutter-md">
            <q-input
              v-model.number="invoiceForm.delivery_charge"
              type="number"
              label="Delivery Charge (BDT)"
              outlined
              dense
              class="soft-input"
              :rules="[val => val >= 0 || 'Must be >= 0']"
            />
            <q-input
              v-model.number="invoiceForm.total_amount"
              type="number"
              label="Total Amount (BDT)"
              outlined
              dense
              class="soft-input"
              :rules="[val => val >= 0 || 'Must be >= 0']"
            />
            <q-input
              v-model.number="invoiceForm.amount_paid"
              type="number"
              label="Amount Paid (BDT)"
              outlined
              dense
              class="soft-input"
              :rules="[val => val >= 0 || 'Must be >= 0']"
            />
            <q-input
              v-model="invoiceForm.delivered_by"
              label="Delivered By (Rider / courier name)"
              outlined
              dense
              class="soft-input"
            />

            <div class="row justify-end q-mt-md">
              <q-btn label="Cancel" flat color="grey-7" v-close-popup class="q-mr-sm" />
              <q-btn label="Generate Invoice" type="submit" color="secondary" unelevated :loading="creatingInvoice" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceOrderService } from '../services/commerceOrderService'
import { supabase } from 'src/boot/supabase'
import type { CommerceOrder, CommerceOrderItem, CommerceOrderStatus } from '../types'
import { showSuccessNotification, showWarningDialog, handleApiFailure } from 'src/utils/appFeedback'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

// State
const loading = ref(true)
const error = ref<string | null>(null)
const order = ref<CommerceOrder | null>(null)
const items = ref<CommerceOrderItem[]>([])
const updatingStatus = ref(false)
const creatingInvoice = ref(false)
const invoiceDialog = ref(false)

const editChargesMode = ref(false)
const savingCharges = ref(false)
const chargesForm = reactive({
  delivery_charge: 0,
  wrapping_charge: 0,
  cod: 0,
  shipment_payment: 0,
})

const newStatus = ref<CommerceOrderStatus>('placed')
const statusOptions: CommerceOrderStatus[] = ['placed', 'reviewing', 'shipping', 'delivered', 'cancelled']

const invoiceForm = reactive({
  delivery_charge: 0,
  total_amount: 0,
  amount_paid: 0,
  delivered_by: '',
})

const loadOrderDetails = async () => {
  const orderId = Number(route.params.id)
  if (Number.isNaN(orderId)) {
    error.value = 'Invalid Order ID.'
    loading.value = false
    return
  }

  loading.value = true
  error.value = null
  try {
    const res = await commerceOrderService.getCommerceOrderDetails(orderId)
    if (res.success && res.data) {
      order.value = res.data.order
      items.value = res.data.items
      newStatus.value = res.data.order.status
    } else {
      error.value = res.error || 'Failed to load order details.'
    }
  } finally {
    loading.value = false
  }
}

const backToOrders = () => {
  const tenantSlug = route.params.tenantSlug
  const tenantPrefix = tenantSlug ? `/${tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/orders`)
}

const updateStatus = async () => {
  if (!order.value) return
  updatingStatus.value = true
  try {
    const res = await commerceOrderService.updateCommerceOrderStatus(order.value.id, newStatus.value)
    if (res.success) {
      showSuccessNotification('Order status updated successfully.')
      await loadOrderDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update order status.')
    }
  } finally {
    updatingStatus.value = false
  }
}

const startEditCharges = () => {
  if (!order.value) return
  chargesForm.delivery_charge = Number(order.value.delivery_charge) || 0
  chargesForm.wrapping_charge = Number(order.value.wrapping_charge) || 0
  chargesForm.cod = Number(order.value.cod) || 0
  chargesForm.shipment_payment = Number(order.value.shipment_payment) || 0
  editChargesMode.value = true
}

const saveCharges = async () => {
  if (!order.value) return
  savingCharges.value = true
  try {
    const res = await commerceOrderService.updateCommerceOrderCharges(order.value.id, {
      delivery_charge: chargesForm.delivery_charge,
      wrapping_charge: chargesForm.wrapping_charge,
      cod: chargesForm.cod,
      shipment_payment: chargesForm.shipment_payment,
    })
    if (res.success) {
      showSuccessNotification('Charges updated successfully.')
      editChargesMode.value = false
      await loadOrderDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update charges.')
    }
  } finally {
    savingCharges.value = false
  }
}

const openInvoiceDialog = () => {
  if (!order.value) return
  invoiceForm.delivery_charge = Number(order.value.delivery_charge) || 0
  invoiceForm.total_amount = Number(order.value.shipment_payment) || 0
  invoiceForm.amount_paid = 0
  invoiceForm.delivered_by = ''
  invoiceDialog.value = true
}

const createInvoice = async () => {
  if (!order.value || !authStore.tenantId) return
  creatingInvoice.value = true
  try {
    const { data, error: err } = await supabase.rpc('create_commerce_invoice', {
      p_tenant_id: authStore.tenantId,
      p_order_id: order.value.id,
      p_delivery_charge: invoiceForm.delivery_charge,
      p_total_amount: invoiceForm.total_amount,
      p_amount_paid: invoiceForm.amount_paid,
      p_delivered_by: invoiceForm.delivered_by,
    })

    if (err) throw err

    showSuccessNotification(`Commerce Invoice #${data} generated successfully.`)
    invoiceDialog.value = false
    await loadOrderDetails()
  } catch (err) {
    console.error(err)
    handleApiFailure({ success: false, error: err instanceof Error ? err.message : String(err) }, 'Failed to generate invoice.')
  } finally {
    creatingInvoice.value = false
  }
}

const getStatusColor = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed': return 'blue-2'
    case 'reviewing': return 'orange-2'
    case 'shipping': return 'purple-2'
    case 'delivered': return 'green-2'
    case 'cancelled': return 'red-2'
    default: return 'grey-2'
  }
}

const getStatusDotColor = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed': return '#1976d2'
    case 'reviewing': return '#f57c00'
    case 'shipping': return '#7b1fa2'
    case 'delivered': return '#388e3c'
    case 'cancelled': return '#d32f2f'
    default: return '#616161'
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

onMounted(() => {
  void loadOrderDetails()
})
</script>

<style scoped>
.commerce-order-details-page {
  background: transparent;
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

.empty-state-block {
  text-align: center;
  background: rgba(255, 255, 255, 0.7);
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

.border-all {
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
