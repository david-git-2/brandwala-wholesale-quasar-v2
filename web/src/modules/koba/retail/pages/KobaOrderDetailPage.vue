<template>
  <q-page class="bw-page q-pa-md">
    <!-- Header -->
    <div class="detail-header q-mb-md">
      <div class="row items-center justify-between no-wrap w-full">
        <div class="row items-center q-gutter-sm">
          <q-btn flat round icon="arrow_back" color="grey-8" :to="{ name: ordersRouteName }" />
          <div>
            <div class="text-h5 text-weight-bold text-grey-9">Order details #{{ orderId }}</div>
            <div class="text-caption text-grey-7">Placed on {{ formatDate(order?.created_at) }}</div>
          </div>
        </div>
        <div v-if="order">
          <q-chip :color="statusColor" text-color="white" square class="text-uppercase text-weight-bold q-px-md q-py-sm">
            {{ order.status }}
          </q-chip>
        </div>
      </div>
    </div>

    <!-- Loading Indicator -->
    <div v-if="loading && !order" class="flex flex-center q-pa-xl">
      <q-spinner color="primary" size="3em" />
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-negative text-center q-pa-md empty-state-card">
      <q-icon name="error_outline" size="48px" color="negative" class="q-mb-sm" />
      <div class="text-h6">{{ error }}</div>
      <q-btn label="Back to Orders" color="primary" flat :to="{ name: ordersRouteName }" class="q-mt-sm" />
    </div>

    <div v-else-if="order" class="row q-col-gutter-md">
      <!-- Left Column: Shipping & Items -->
      <div class="col-12 col-md-8">
        <!-- Shipping Card -->
        <q-card flat class="detail-card q-mb-md">
          <q-card-section class="q-pb-none">
            <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center">
              <q-icon name="local_shipping" color="primary" size="20px" class="q-mr-xs" />
              Shipping Information
            </div>
          </q-card-section>
          
          <q-card-section>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">Recipient Name</div>
                  <div class="info-val text-weight-medium">{{ order.shipping_name || '—' }}</div>
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">Phone Number</div>
                  <div class="info-val text-weight-medium">{{ order.shipping_phone || '—' }}</div>
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">District / Thana</div>
                  <div class="info-val text-weight-medium">{{ order.shipping_district || '—' }} / {{ order.shipping_thana || '—' }}</div>
                </div>
              </div>
              <div class="col-12 col-sm-6">
                <div class="info-item">
                  <div class="info-lbl">Full Address</div>
                  <div class="info-val text-weight-medium">{{ order.shipping_address || '—' }}</div>
                </div>
              </div>
              <div class="col-12" v-if="order.free_delivery">
                <q-chip outline color="primary" icon="check_circle" dense>Free Delivery Requested</q-chip>
              </div>
            </div>
          </q-card-section>
        </q-card>

        <!-- Items Card -->
        <q-card flat class="detail-card">
          <q-card-section class="q-pb-none">
            <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center">
              <q-icon name="shopping_bag" color="primary" size="20px" class="q-mr-xs" />
              Order Items ({{ items.length }} variant{{ items.length === 1 ? '' : 's' }})
            </div>
          </q-card-section>

          <q-card-section class="q-pa-none q-mt-sm">
            <q-list separator class="item-list-container">
              <q-item v-for="item in items" :key="item.id" class="q-py-md">
                <q-item-section avatar>
                  <q-avatar square size="64px" class="bg-grey-2 item-avatar-frame">
                    <img v-if="item.image_url" :src="toDirectGoogleImageUrl(item.image_url)" referrerpolicy="no-referrer" />
                    <q-icon v-else name="image_not_supported" color="grey-5" />
                  </q-avatar>
                </q-item-section>

                <q-item-section>
                  <div class="text-caption text-primary text-uppercase text-weight-bold" v-if="item.brand">{{ item.brand }}</div>
                  <div class="text-subtitle2 text-weight-bold text-grey-9 item-name">{{ item.name }}</div>
                  <div class="text-caption text-grey-6">
                    Quantity: <span class="text-weight-bold text-grey-8">{{ item.quantity }}</span> (Case Size: {{ item.case_size }})
                  </div>
                  <div class="text-caption text-positive text-weight-medium q-mt-xs" v-if="item.commission">
                    Commission: ৳{{ Number(Math.max(0, (item.commission || 0) - gatewayChargeFlat)).toFixed(2) }} / unit
                  </div>
                </q-item-section>

                <q-item-section side class="text-right">
                  <div class="text-subtitle1 text-primary text-weight-bold">
                    ৳{{ Number((item.custom_price_gbp || item.unit_price_gbp || 0) * item.quantity).toFixed(2) }}
                  </div>
                  <div class="text-caption text-grey-6">৳{{ Number(item.custom_price_gbp || item.unit_price_gbp || 0).toFixed(2) }} each</div>
                  <div v-if="item.custom_price_gbp && item.custom_price_gbp > (item.unit_price_gbp || 0)" class="text-caption text-grey-5 text-strike">
                    Orig: ৳{{ Number(item.unit_price_gbp || 0).toFixed(2) }}
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card-section>
        </q-card>
      </div>

      <!-- Right Column: Order Summary & Commission Accounting -->
      <div class="col-12 col-md-4">
        <!-- Summary Card -->
        <q-card flat class="detail-card q-pa-md q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md row items-center">
            <q-icon name="summarize" color="primary" size="20px" class="q-mr-xs" />
            Order Summary
          </div>

          <div class="row justify-between q-py-xs text-grey-8">
            <div>Total units</div>
            <div class="text-weight-bold">{{ totalQuantity }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Subtotal</div>
            <div class="text-weight-bold">৳{{ Number(order.subtotal_gbp || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Delivery</div>
            <div class="text-weight-bold">৳{{ deliveryCharge.toFixed(2) }}</div>
          </div>
          
          <q-separator class="q-my-sm" />
          
          <div class="row justify-between q-py-xs text-h6 text-weight-bold text-grey-9">
            <div>Total Value</div>
            <div class="text-primary">৳{{ finalTotal.toFixed(2) }}</div>
          </div>

          <div v-if="order.note" class="q-mt-md">
            <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Order Note</div>
            <div class="note-box q-pa-sm q-mt-xs text-body2 text-grey-8">
              {{ order.note }}
            </div>
          </div>
        </q-card>

        <!-- Commission Card -->
        <q-card flat class="detail-card q-pa-md">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md row items-center">
            <q-icon name="payments" color="primary" size="20px" class="q-mr-xs" />
            Earnings & Fees
          </div>

          <div class="row justify-between q-py-xs text-grey-8">
            <div>Products Commission</div>
            <div class="text-weight-bold text-positive">৳{{ productsCommissionDisplay.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.extra_profit_user || order.extra_profit_company">
            <div>Extra Profit Share (You 90% | Company 10%)</div>
            <div class="text-weight-bold text-positive">+৳{{ Number(order.extra_profit_user || 0).toFixed(2) }} | +৳{{ Number(order.extra_profit_company || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.delivery_adjustment">
            <div>Delivery Adjustment</div>
            <div class="text-weight-bold text-positive">+৳{{ Number(order.delivery_adjustment || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.cod_charge">
            <div>COD Charge (1.00%)</div>
            <div class="text-weight-bold text-negative">-৳{{ Number(order.cod_charge || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.packing_charge">
            <div>Packing Charge</div>
            <div class="text-weight-bold text-negative">-৳{{ Number(order.packing_charge || 0).toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="order.invoice_charge">
            <div>Invoice Charge</div>
            <div class="text-weight-bold text-negative">-৳{{ Number(order.invoice_charge || 0).toFixed(2) }}</div>
          </div>
          
          <q-separator class="q-my-sm" />

          <div class="row justify-between q-py-sm text-subtitle1 text-weight-bold text-positive q-mt-sm bg-positive-soft q-px-sm rounded-borders">
            <div class="row items-center">
              <q-icon name="monetization_on" class="q-mr-xs" size="20px" />
              Net Earnings
            </div>
            <div>৳{{ netOrderCommission.toFixed(2) }}</div>
          </div>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { date } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaOrderStore } from 'src/modules/koba/retail/stores/kobaOrderStore'
import { useKobaSettingsStore } from 'src/modules/koba/retail/stores/kobaSettingsStore'

const route = useRoute()
const authStore = useAuthStore()
const orderStore = useKobaOrderStore()
const settingsStore = useKobaSettingsStore()

const orderId = computed(() => Number(route.params.id))
const loading = ref(true)
const error = ref<string | null>(null)

const order = computed(() => orderStore.orderDetail?.order || null)
const items = computed(() => orderStore.orderDetail?.items || [])

const ordersRouteName = computed(() => {
  return authStore.scope === 'shop' ? 'shop-koba-retail-orders-page' : 'app-koba-retail-orders-page'
})

const gatewayChargeFlat = computed(() => settingsStore.settings?.gateway_charge_flat ?? 20)

onMounted(async () => {
  loading.value = true
  try {
    await Promise.all([
      orderStore.fetchOrderDetails(orderId.value),
      settingsStore.fetchSettings()
    ])
  } catch (err: any) {
    error.value = err?.message || 'Failed to load order details'
  } finally {
    loading.value = false
  }
})

const totalQuantity = computed(() => {
  return items.value.reduce((sum, item) => sum + (item.quantity || 0), 0)
})

// Since database total_commission is already pre-deducted at checkout,
// we just add it to any extra profit splits.
const productsCommissionDisplay = computed(() => {
  if (!order.value) return 0
  return Number(order.value.total_commission || 0) + Number(order.value.extra_profit_user || 0)
})

const deliveryCharge = computed(() => {
  if (!order.value || order.value.free_delivery || !order.value.shipping_district) return 0
  const rates = settingsStore.settings?.delivery_rates || { "default": 110, "Dhaka": 100 }
  return rates[order.value.shipping_district] ?? rates['default'] ?? 110
})

const finalTotal = computed(() => {
  if (!order.value) return 0
  return Number(order.value.subtotal_gbp || 0) + deliveryCharge.value
})

const netOrderCommission = computed(() => {
  if (!order.value) return 0
  if (order.value.net_order_commission) {
    return Number(order.value.net_order_commission)
  }
  return productsCommissionDisplay.value + 
         Number(order.value.delivery_adjustment || 0) - 
         Number(order.value.cod_charge || 0) - 
         Number(order.value.packing_charge || 0) - 
         Number(order.value.invoice_charge || 0)
})

const statusColor = computed(() => {
  if (!order.value) return 'grey'
  switch (order.value.status) {
    case 'pending': return 'amber-8'
    case 'confirmed': return 'blue-7'
    case 'processing': return 'indigo-7'
    case 'shipped': return 'deep-purple-7'
    case 'delivered': return 'positive'
    case 'cancelled': return 'negative'
    default: return 'grey'
  }
})

function formatDate(isoString: string | undefined) {
  if (!isoString) return '—'
  return date.formatDate(new Date(isoString), 'YYYY-MM-DD HH:mm')
}

function toDirectGoogleImageUrl(url: string | null) {
  if (!url) return ''
  const m1 = url.match(/[?&]id=([^&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  const fileId = m1?.[1] || m2?.[1]
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}
</script>

<style scoped>
.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(6px);
}

.detail-card {
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  background: rgba(255, 255, 255, 0.95);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.01);
}

.empty-state-card {
  border-radius: 16px;
  border: 1px dashed rgba(0, 0, 0, 0.12);
  background: #fdfdfd;
  padding: 40px;
}

.info-item {
  display: flex;
  flex-direction: column;
}

.info-lbl {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.info-val {
  font-size: 14px;
  color: #1e293b;
}

.item-avatar-frame {
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.item-list-container :deep(.q-item) {
  border-bottom: 1px solid rgba(0, 0, 0, 0.04);
}

.item-list-container :deep(.q-item):last-child {
  border-bottom: none;
}

.note-box {
  background: #f8fafc;
  border: 1px solid rgba(0, 0, 0, 0.03);
  border-radius: 8px;
  white-space: pre-line;
}

.bg-positive-soft {
  background-color: rgba(46, 204, 113, 0.1);
}

.rounded-borders {
  border-radius: 8px;
}

.w-full {
  width: 100%;
}
</style>
