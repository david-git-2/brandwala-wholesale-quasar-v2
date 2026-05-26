<template>
  <q-dialog v-model="isOpen" max-width="700px" width="100%">
    <q-card class="detail-card">
      <q-card-section class="row items-center q-pb-none header-section">
        <div class="text-h6 text-weight-bold">Order Details #{{ order?.id }}</div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-separator class="q-my-sm" />

      <q-card-section v-if="loading" class="row justify-center q-pa-xl">
        <q-spinner color="primary" size="3em" />
      </q-card-section>

      <q-card-section v-else-if="!order" class="q-pa-md text-center text-grey">
        No order details available.
      </q-card-section>

      <q-card-section v-else class="q-pa-md scroll-container">
        <!-- Order Stats Grid -->
        <div class="row q-col-gutter-md q-mb-lg">
          <div class="col-12 col-sm-6">
            <div class="info-block">
              <span class="info-label">Status</span>
              <span class="info-val">
                <q-chip :color="statusColor" text-color="white" dense square class="text-uppercase text-weight-bold">
                  {{ order.status }}
                </q-chip>
              </span>
            </div>
            <div class="info-block q-mt-sm">
              <span class="info-label">Date Placed</span>
              <span class="info-val">{{ formatDate(order.created_at) }}</span>
            </div>
            <div v-if="order.note" class="info-block q-mt-sm">
              <span class="info-label">Note</span>
              <span class="info-val text-grey-8">{{ order.note }}</span>
            </div>
          </div>
          <div class="col-12 col-sm-6">
            <div class="info-block">
              <span class="info-label">Subtotal</span>
              <span class="info-val text-primary text-weight-bold">৳{{ Number(order.subtotal_gbp || 0).toFixed(2) }}</span>
            </div>
            <div class="info-block q-mt-sm">
              <span class="info-label">Total Commission</span>
              <span class="info-val text-positive text-weight-bold">৳{{ Number(order.total_commission || 0).toFixed(2) }}</span>
            </div>
            <div class="info-block q-mt-sm">
              <span class="info-label">Items Count</span>
              <span class="info-val">{{ order.item_count }}</span>
            </div>
          </div>
        </div>

        <q-separator class="q-my-md" />

        <!-- Shipping Info -->
        <div class="shipping-section q-mb-lg">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">Shipping Information</div>
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <div class="text-caption text-grey-6">Name</div>
              <div class="text-body2 font-medium">{{ order.shipping_name || '—' }}</div>
            </div>
            <div class="col-12 col-sm-6">
              <div class="text-caption text-grey-6">Phone</div>
              <div class="text-body2 font-medium">{{ order.shipping_phone || '—' }}</div>
            </div>
            <div class="col-12 col-sm-6 q-mt-sm">
              <div class="text-caption text-grey-6">District / Thana</div>
              <div class="text-body2 font-medium">{{ order.shipping_district || '—' }} / {{ order.shipping_thana || '—' }}</div>
            </div>
            <div class="col-12 col-sm-6 q-mt-sm">
              <div class="text-caption text-grey-6">Address</div>
              <div class="text-body2 font-medium">{{ order.shipping_address || '—' }}</div>
            </div>
            <div class="col-12 q-mt-sm" v-if="order.free_delivery">
              <q-chip outline color="primary" icon="local_shipping" dense>Free Delivery</q-chip>
            </div>
          </div>
        </div>

        <q-separator class="q-my-md" />

        <!-- Order Items -->
        <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">Items</div>
        <q-list class="item-list">
          <q-item v-for="item in items" :key="item.id" class="q-py-md item-row">
            <q-item-section avatar>
              <q-avatar square size="50px" class="bg-grey-2 item-avatar">
                <img v-if="item.image_url" :src="toDirectGoogleImageUrl(item.image_url)" referrerpolicy="no-referrer" />
                <q-icon v-else name="image_not_supported" color="grey-5" />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <div class="text-caption text-grey-6 text-uppercase text-weight-bold" v-if="item.brand">{{ item.brand }}</div>
              <q-item-label class="text-weight-bold text-grey-9 item-name">{{ item.name }}</q-item-label>
              <q-item-label caption>
                Qty: <span class="text-weight-medium text-grey-8">{{ item.quantity }}</span> (Case Size: {{ item.case_size }})
              </q-item-label>
              <q-item-label caption v-if="item.commission">
                Commission: <span class="text-weight-medium text-positive">৳{{ Number(item.commission).toFixed(2) }}</span> / unit
              </q-item-label>
            </q-item-section>

            <q-item-section side class="text-right">
              <div class="text-weight-bold text-primary">৳{{ Number((item.unit_price_gbp || 0) * item.quantity).toFixed(2) }}</div>
              <div class="text-caption text-grey-6">৳{{ Number(item.unit_price_gbp || 0).toFixed(2) }} each</div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { date } from 'quasar'
import type { KobaOrder, KobaOrderItem } from '../repositories/kobaOrderRepository'

const props = defineProps<{
  modelValue: boolean
  order: KobaOrder | null
  items: KobaOrderItem[]
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
}>()

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
})

const statusColor = computed(() => {
  if (!props.order) return 'grey'
  switch (props.order.status) {
    case 'pending': return 'amber-8'
    case 'confirmed': return 'blue-7'
    case 'processing': return 'indigo-7'
    case 'shipped': return 'deep-purple-7'
    case 'delivered': return 'positive'
    case 'cancelled': return 'negative'
    default: return 'grey'
  }
})

function formatDate(isoString: string) {
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
.detail-card {
  border-radius: 16px;
  overflow: hidden;
  max-height: 85vh;
  display: flex;
  flex-direction: column;
}

.header-section {
  background: rgba(248, 250, 252, 0.9);
}

.scroll-container {
  overflow-y: auto;
  flex: 1;
}

.info-block {
  display: flex;
  flex-direction: column;
  background: #f8fafc;
  padding: 8px 12px;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.03);
}

.info-label {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.info-val {
  font-size: 14px;
  font-weight: 500;
  color: #0f172a;
}

.shipping-section {
  background: #fdfdfd;
  border: 1px solid rgba(0, 0, 0, 0.04);
  border-radius: 12px;
  padding: 14px;
}

.font-medium {
  font-weight: 500;
  color: #1e293b;
}

.item-list {
  border-radius: 12px;
  border: 1px solid rgba(0, 0, 0, 0.05);
  background: #ffffff;
  overflow: hidden;
}

.item-row {
  border-bottom: 1px solid rgba(0, 0, 0, 0.04);
  transition: background-color 0.15s ease;
}

.item-row:last-child {
  border-bottom: none;
}

.item-row:hover {
  background-color: #fafbfc;
}

.item-avatar {
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.04);
}

.item-name {
  line-height: 1.3;
}
</style>
