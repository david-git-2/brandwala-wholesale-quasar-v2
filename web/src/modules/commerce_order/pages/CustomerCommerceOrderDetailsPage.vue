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
              <div class="text-h6 text-weight-bold text-primary">Order #{{ order.id }} Details</div>
              <div class="text-caption text-grey-8">Placed on {{ formatDate(order.order_placement_date) }}</div>
            </div>
          </div>
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
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.delivery_charge || 0).toFixed(2) }}</div>
              </div>
              <div class="col-6">
                <div class="text-subtitle2 text-grey-7">COD</div>
                <div class="text-body1 text-weight-medium text-grey-9">৳{{ Number(order.cod || 0).toFixed(2) }}</div>
              </div>
              <div class="col-12">
                <div class="text-subtitle2 text-grey-7">Grand Total</div>
                <div class="text-h5 text-weight-bold text-primary">৳{{ Number(order.shipment_payment || 0).toFixed(2) }}</div>
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
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { commerceOrderService } from '../services/commerceOrderService'
import type { CommerceOrder, CommerceOrderItem, CommerceOrderStatus } from '../types'

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
  const tenantSlug = route.params.tenantSlug
  const tenantPrefix = tenantSlug ? `/${tenantSlug}` : ''
  void router.push(`${tenantPrefix}/shop/commerce-shop/orders`)
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
</style>
