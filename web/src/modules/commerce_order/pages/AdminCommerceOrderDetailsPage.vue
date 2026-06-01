<template>
  <q-page class="q-pa-md commerce-order-details-page">
    <!-- Loading State -->
    <PageInitialLoader v-if="loading" />

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
            <!-- Linked Invoices -->
            <template v-if="order.invoice_ids && order.invoice_ids.length">
              <q-btn
                v-for="invId in order.invoice_ids"
                :key="invId"
                color="primary"
                outline
                icon="receipt"
                :label="`Invoice #${invId}`"
                no-caps
                unelevated
                class="pill-btn slim-btn"
                @click="goToInvoice(invId)"
              />
            </template>
            <q-btn
              color="secondary"
              icon="description"
              label="Generate Invoice"
              no-caps
              unelevated
              class="pill-btn slim-btn"
              :disable="order.status === 'cancelled'"
              :loading="creatingInvoice"
              @click="onGenerateInvoice"
            />
            <q-btn
              color="negative"
              icon="delete"
              outline
              label="Delete Order"
              no-caps
              unelevated
              class="pill-btn slim-btn"
              @click="onDeleteOrder"
            />
            <q-chip
              square
              dense
              clickable
              :style="statusChipStyle(order.status)"
              class="status-chip text-weight-bold"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(order.status) }"></span>
              {{ order.status.toUpperCase() }}
              <q-menu auto-close>
                <q-list dense style="min-width: 120px">
                  <q-item
                    v-for="opt in statusOptions"
                    :key="opt"
                    clickable
                    v-close-popup
                    @click="onStatusMenuSelect(order.id, opt)"
                  >
                    <q-item-section>{{ opt.toUpperCase() }}</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
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
              <q-checkbox
                v-model="chargesForm.is_delivery_charge_inclusive"
                label="Delivery Charge Inclusive"
                dense
                class="text-grey-8 q-mb-sm"
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
                <div class="text-body1 text-weight-medium text-grey-9">
                  ৳{{ Number(order.delivery_charge || 0).toFixed(2) }}
                  <span class="text-caption text-weight-bold" :class="order.is_delivery_charge_inclusive ? 'text-green-7' : 'text-grey-7'">
                    ({{ order.is_delivery_charge_inclusive ? 'Inclusive' : 'Exclusive' }})
                  </span>
                </div>
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
              <q-item-label caption class="text-body2 text-grey-7">
                Inventory:
                <template v-if="getItemInventoryId(item)">
                  #{{ getItemInventoryId(item) }} - {{ getItemInventoryName(item) || 'Assigned' }}
                </template>
                <template v-else>
                  Not assigned
                </template>
              </q-item-label>
            </q-item-section>

            <q-item-section side class="text-right">
              <div class="text-body1 text-weight-bold text-primary">Recipient Price: ৳{{ Number(item.recipient_price_bdt).toFixed(2) }}</div>
              <div class="text-caption text-grey-7">Cost BDT: ৳{{ Number(item.cost_bdt).toFixed(2) }} | Sell Price: ৳{{ Number(item.sell_price_bdt).toFixed(2) }}</div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </div>


  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, reactive } from 'vue'
import { useQuasar } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceOrderService } from '../services/commerceOrderService'
import { supabase } from 'src/boot/supabase'
import type { CommerceOrder, CommerceOrderItem, CommerceOrderStatus } from '../types'
import { showSuccessNotification, showWarningDialog, handleApiFailure } from 'src/utils/appFeedback'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const $q = useQuasar()

// State
const loading = ref(true)
const error = ref<string | null>(null)
const order = ref<CommerceOrder | null>(null)
const items = ref<CommerceOrderItem[]>([])
const creatingInvoice = ref(false)

const editChargesMode = ref(false)
const savingCharges = ref(false)
const chargesForm = reactive({
  delivery_charge: 0,
  wrapping_charge: 0,
  cod: 0,
  shipment_payment: 0,
  is_delivery_charge_inclusive: true,
})

const statusOptions: CommerceOrderStatus[] = ['placed', 'reviewing', 'shipping', 'delivered', 'cancelled']

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
    } else {
      error.value = res.error || 'Failed to load order details.'
    }
  } finally {
    loading.value = false
  }
}

const backToOrders = () => {
  const tenantSlugParam = route.params.tenantSlug
  const tenantSlug = Array.isArray(tenantSlugParam) ? tenantSlugParam[0] : tenantSlugParam
  const tenantPrefix = tenantSlug ? `/${tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/orders`)
}

const goToInvoice = (invoiceId: number) => {
  const tenantSlugParam = route.params.tenantSlug
  const tenantSlug = Array.isArray(tenantSlugParam) ? tenantSlugParam[0] : tenantSlugParam
  const tenantPrefix = tenantSlug ? `/${tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/invoices/${invoiceId}`)
}

const onStatusMenuSelect = async (orderId: number, nextStatus: CommerceOrderStatus) => {
  loading.value = true
  try {
    const res = await commerceOrderService.updateCommerceOrderStatus(orderId, nextStatus)
    if (res.success) {
      showSuccessNotification('Order status updated successfully.')
      await loadOrderDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update order status.')
    }
  } finally {
    loading.value = false
  }
}

const startEditCharges = () => {
  if (!order.value) return
  chargesForm.delivery_charge = Number(order.value.delivery_charge) || 0
  chargesForm.wrapping_charge = Number(order.value.wrapping_charge) || 0
  chargesForm.cod = Number(order.value.cod) || 0
  chargesForm.shipment_payment = Number(order.value.shipment_payment) || 0
  chargesForm.is_delivery_charge_inclusive = !!order.value.is_delivery_charge_inclusive
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
      is_delivery_charge_inclusive: chargesForm.is_delivery_charge_inclusive,
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

const onDeleteOrder = () => {
  if (!order.value) return
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete Commerce Order #${order.value.id}? This will also delete any linked items and invoices.`,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: 'Cancel',
      color: 'grey-7',
      flat: true,
    }
  }).onOk(() => {
    void (async () => {
      loading.value = true
      try {
        const res = await commerceOrderService.deleteCommerceOrder(order.value!.id)
        if (res.success) {
          showSuccessNotification('Order deleted successfully.')
          backToOrders()
        } else {
          showWarningDialog(res.error || 'Failed to delete order.')
        }
      } finally {
        loading.value = false
      }
    })()
  })
}

const onGenerateInvoice = async () => {
  if (!order.value || !authStore.tenantId) return
  creatingInvoice.value = true
  try {
    let defaultDelivery = 0
    let defaultWrapping = 0
    let defaultCodPercent = 0

    if (authStore.tenantId) {
      const settingsRes = await commerceOrderService.getCommerceOrderSettings(authStore.tenantId)
      if (settingsRes.success && settingsRes.data) {
        defaultDelivery = Number(settingsRes.data.default_delivery_charge) || 0
        defaultWrapping = Number(settingsRes.data.default_wrapping_charge) || 0
        defaultCodPercent = Number(settingsRes.data.default_cod_percent) || 0
      }
    }

    const subtotal = items.value.reduce((sum, item) => sum + (Number(item.quantity) * Number(item.recipient_price_bdt)), 0)

    const isInclusive = !!order.value.is_delivery_charge_inclusive
    const deliveryCharge = Number(order.value.delivery_charge) || defaultDelivery
    const wrappingCharge = Number(order.value.wrapping_charge) || defaultWrapping
    const codCharge = Number(order.value.cod) || Number(((defaultCodPercent / 100) * subtotal).toFixed(2))
    
    // Calculate invoice total amount: exclude delivery charge if inclusive
    const totalAmount = subtotal + (isInclusive ? 0 : deliveryCharge) + wrappingCharge + codCharge

    const { data, error: err } = await supabase.rpc('create_commerce_invoice', {
      p_tenant_id: authStore.tenantId,
      p_order_id: order.value.id,
      p_delivery_charge: isInclusive ? 0 : deliveryCharge,
      p_wrapping_charge: wrappingCharge,
      p_cod: codCharge,
      p_total_amount: totalAmount,
      p_amount_paid: 0,
      p_delivered_by: '',
    })

    if (err) throw err

    showSuccessNotification(`Commerce Invoice #${data} generated successfully.`)
    
    // Redirect to the commerce invoice details page
    const tenantSlugParam = route.params.tenantSlug
    const tenantSlug = Array.isArray(tenantSlugParam) ? tenantSlugParam[0] : tenantSlugParam
    const tenantPrefix = tenantSlug ? `/${tenantSlug}` : ''
    void router.push(`${tenantPrefix}/app/commerce-shop/invoices/${data}`)
  } catch (err) {
    console.error(err)
    handleApiFailure({ success: false, error: err instanceof Error ? err.message : String(err) }, 'Failed to generate invoice.')
  } finally {
    creatingInvoice.value = false
  }
}

const statusChipStyle = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed':
      return {
        backgroundColor: '#c8d8f8',
        color: '#27487a',
        border: '1px solid #a9c4f3',
        boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
      }
    case 'reviewing':
      return {
        backgroundColor: '#efd399',
        color: '#6a4a14',
        border: '1px solid #d8b672',
        boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
      }
    case 'shipping':
      return {
        backgroundColor: '#ecd9fc',
        color: '#5b1f9c',
        border: '1px solid #d9b8fa',
        boxShadow: '0 1px 2px rgba(91, 31, 156, 0.18)',
      }
    case 'delivered':
      return {
        backgroundColor: '#c3e8d2',
        color: '#1f5d3c',
        border: '1px solid #9fd4b7',
        boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
      }
    case 'cancelled':
      return {
        backgroundColor: '#f2c7d0',
        color: '#6f2b3a',
        border: '1px solid #e3a6b3',
        boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
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

const statusDotColor = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed': return '#3f67b3'
    case 'reviewing': return '#9a6a24'
    case 'shipping': return '#7b1fa2'
    case 'delivered': return '#2f8b5d'
    case 'cancelled': return '#a64c62'
    default: return '#66758c'
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

const getItemInventoryId = (item: CommerceOrderItem) =>
  (item as CommerceOrderItem & { inventory_item_id?: number | null }).inventory_item_id ?? null

const getItemInventoryName = (item: CommerceOrderItem) =>
  (item as CommerceOrderItem & { inventory_items?: { name?: string | null } | null }).inventory_items?.name ?? null

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
