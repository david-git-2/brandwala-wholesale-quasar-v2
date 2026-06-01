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
              <div class="text-h6 text-weight-bold text-primary">Order #{{ order.id }} Details</div>
              <div class="text-caption text-grey-8">Placed on {{ formatDate(order.order_placement_date) }}</div>
            </div>
          </div>
          <q-chip
            square
            dense
            :style="statusChipStyle(order.status)"
            class="text-weight-bold status-chip"
          >
            <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(order.status) }"></span>
            {{ order.status.toUpperCase() }}
          </q-chip>
        </div>
      </q-card>

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

        <!-- Pricing Summary Card -->
        <div class="col-12 col-md-6">
          <q-card flat class="floating-surface shadow-1 q-pa-md full-height">
            <div class="text-subtitle1 text-weight-bold text-primary q-mb-md">
              <q-icon name="local_atm" class="q-mr-xs" /> Pricing Details
            </div>
            <div class="row q-col-gutter-md">
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
                <div class="text-subtitle2 text-grey-7">COD</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.cod || 0).toFixed(2) }}</div>
              </div>
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">Wrapping Charge</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.wrapping_charge || 0).toFixed(2) }}</div>
              </div>
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">Invoice Print Charge</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.invoice_print_charge || 0).toFixed(2) }}</div>
              </div>
              <div class="col-12">
                <q-separator class="q-my-sm" />
                <div class="row justify-between items-center">
                  <div class="text-subtitle2 text-grey-7">Grand Total</div>
                  <div class="text-h5 text-weight-bold text-primary">৳{{ Number(order.shipment_payment || 0).toFixed(2) }}</div>
                </div>
              </div>
              <div class="col-12 q-pt-xs">
                <div class="row justify-between items-center">
                  <div class="text-subtitle2 text-weight-bold text-green-7">Estimated Profit</div>
                  <div class="text-subtitle1 text-weight-bold text-green-7">৳{{ formatPrice(estimatedProfit) }}</div>
                </div>
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
              <div class="text-caption text-grey-7">Sell Price: ৳{{ Number(item.sell_price_bdt).toFixed(2) }}</div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { commerceOrderService } from '../services/commerceOrderService'
import type { CommerceOrder, CommerceOrderItem, CommerceOrderStatus } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const route = useRoute()
const router = useRouter()

// State
const loading = ref(true)
const error = ref<string | null>(null)
const order = ref<CommerceOrder | null>(null)
const items = ref<CommerceOrderItem[]>([])

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
  void router.push(`${tenantPrefix}/shop/commerce-shop/orders`)
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

const estimatedProfit = computed(() => {
  if (!order.value || !items.value) return 0
  let costSubtotal = 0
  items.value.forEach(item => {
    costSubtotal += (item.cost_bdt || 0) * (item.quantity || 0)
  })
  
  const revenue = Number(order.value.shipment_payment || 0)
  const delivery = Number(order.value.delivery_charge || 0)
  const cod = Number(order.value.cod || 0)
  const wrapping = Number(order.value.wrapping_charge || 0)
  const print = Number(order.value.invoice_print_charge || 0)
  const isDeliveryInclusive = Boolean(order.value.is_delivery_charge_inclusive)

  const deliveryCostImpact = isDeliveryInclusive ? delivery : 0
  return revenue - costSubtotal - deliveryCostImpact - cod - wrapping - print
})

const formatPrice = (price: number) => {
  return Number(price || 0).toFixed(2)
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
</style>
