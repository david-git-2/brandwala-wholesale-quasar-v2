<template>
  <q-page class="q-pa-md">
    <div class="text-h5 q-mb-md text-weight-bold">Orders</div>

    <div v-if="storeOptions.length" class="store-switch q-mb-md">
      <q-btn-toggle
        v-model="selectedStoreId"
        no-caps
        unelevated
        toggle-color="primary"
        :options="storeOptions"
        @update:model-value="onStoreChange"
      />
    </div>

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
          <div class="row items-center justify-end q-gutter-sm">
            <q-chip dense square>{{formatStatus(order.status)}}</q-chip>
          </div>
              <div class="row items-center justify-start q-gutter-sm">
            <div class="text-subtitle1 text-weight-medium">#{{order.id}} {{ order.name }}</div>
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
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useOrderStore } from '../stores/orderStore'
import { formatStatus } from 'src/composables/useFormatStatus'


const authStore = useAuthStore()
const orderStore = useOrderStore()
const storeStore = useStoreStore()
const router = useRouter()
const page = ref(1)

const selectedStoreId = computed<number | null>({
  get: () => storeStore.selectedStore?.id ?? null,
  set: (value) => {
    storeStore.setSelectedStoreById(value)
  },
})

const storeOptions = computed(() =>
  storeStore.items.map((store) => ({
    label: store.name,
    value: store.id,
  })),
)

const loadOrders = async (nextPage = 1) => {
  await orderStore.fetchOrders({
    customer_group_id: authStore.customerGroupId ?? null,
    store_id: storeStore.selectedStore?.id ?? null,
    page: nextPage,
    page_size: 20,
  })
}

const onPageChange = async (nextPage: number) => {
  page.value = nextPage
  await loadOrders(nextPage)
}

const onStoreChange = async () => {
  page.value = 1
  await loadOrders(1)
}

const goToOrder = async (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/shop/orders/${id}`)
}

onMounted(async () => {
  await storeStore.fetchStoresForCustomer()
  if (!storeStore.selectedStore || !storeStore.items.some((item) => item.id === storeStore.selectedStore?.id)) {
    storeStore.setSelectedStore(storeStore.items[0] ?? null)
  }
  await loadOrders(1)
})
</script>

<style scoped>
.store-switch {
  padding: 8px;
  background: #ffffff;
  border: 1px solid #e7e2d8;
  border-radius: 12px;
}

.order-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}

.order-card {
  border-radius: 10px;
}
</style>
