<template>
  <q-page class="q-pa-md">
    <div class="text-h5 q-mb-md">Order</div>

    <q-banner v-if="!orderStore.items.length && !orderStore.loading" class="bg-grey-2 text-grey-8">
      No orders found.
    </q-banner>

    <div v-else class="order-grid">
      <q-card
        v-for="order in orderStore.items"
        :key="order.id"
        class="order-card"
        flat
        bordered
        clickable
        :style="{
          borderLeft: `6px solid ${order.accent_color || '#1976d2'}`,
        }"
        @click="goToOrder(order.id)"
      >
        <q-card-section>
          <div class="row items-center justify-between q-gutter-sm">
            <div class="text-subtitle1 text-weight-medium">{{ order.name }}</div>
            <q-chip dense square>{{ order.status }}</q-chip>
          </div>

          <div class="text-caption text-grey-7 q-mt-xs">
            Order #{{ order.id }} | Store: {{ order.store_id ?? '-' }}
          </div>
          <div class="text-caption text-grey-7">
            Can See Price: {{ order.can_see_price ? 'Yes' : 'No' }}
          </div>
        </q-card-section>
      </q-card>
    </div>

    <div v-if="orderStore.total_pages > 1" class="row justify-center q-mt-md">
      <q-pagination
        :model-value="page"
        :max="orderStore.total_pages"
        :max-pages="8"
        boundary-numbers
        direction-links
        @update:model-value="onPageChange"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useOrderStore } from '../stores/orderStore'

const authStore = useAuthStore()
const orderStore = useOrderStore()
const router = useRouter()
const page = ref(1)

const loadOrders = async (nextPage = 1) => {
  await orderStore.fetchOrders({
    customer_group_id: authStore.customerGroupId ?? null,
    page: nextPage,
    page_size: 20,
  })
}

const onPageChange = async (nextPage: number) => {
  page.value = nextPage
  await loadOrders(nextPage)
}

const goToOrder = async (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/shop/orders/${id}`)
}

onMounted(async () => {
  await loadOrders(1)
})
</script>

<style scoped>
.order-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}

.order-card {
  border-radius: 10px;
}
</style>
