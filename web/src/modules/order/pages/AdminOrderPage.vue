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

    <PageInitialLoader v-if="orderStore.loading" />

    <q-banner v-else-if="!orderStore.items.length" class="bg-grey-2 text-grey-8">
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
            <q-chip dense square>{{ formatStatus(order.status) }}</q-chip>
            <q-btn
              v-if="authStore.matchedRole === 'admin'"
              dense
              flat
              round
              icon="more_vert"
              :loading="orderStore.saving"
              @click.stop
            >
              <q-menu auto-close>
                <q-list dense style="min-width: 120px">
                  <q-item clickable v-ripple @click="onAskDelete(order.id)">
                    <q-item-section class="text-negative">Delete</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </div>

          <div class="row items-center justify-start q-gutter-sm">
            <div class="text-subtitle1 text-weight-medium">#{{ order.id }} {{ order.name }}</div>
          </div>
          <div class="text-caption text-grey-7 q-mt-xs">
            Customer Group: {{ order.customer_group_name || 'N/A' }}
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

    <q-dialog v-model="confirmDeleteOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Order</q-card-section>
        <q-card-section>
          Are you sure you want to delete this order? This will remove all order items too.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Delete"
            :loading="orderStore.saving"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { formatStatus } from 'src/composables/useFormatStatus'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useOrderStore } from '../stores/orderStore'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const authStore = useAuthStore()
const orderStore = useOrderStore()
const storeStore = useStoreStore()
const router = useRouter()
const page = ref(1)
const confirmDeleteOpen = ref(false)
const pendingDeleteOrderId = ref<number | null>(null)

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
    store_id: storeStore.selectedStore?.id ?? null,
    page: nextPage,
    page_size: 20,
  })
}

onMounted(async () => {
  const tenantId = authStore.tenantId
  if (tenantId) {
    await storeStore.fetchStoresAdmin(tenantId)
    if (!storeStore.selectedStore || !storeStore.items.some((item) => item.id === storeStore.selectedStore?.id)) {
      storeStore.setSelectedStore(storeStore.items[0] ?? null)
    }
  }
  await loadOrders(1)
})

const deleteOrder = async (id: number) => {
  await orderStore.deleteOrder({ id })
  await loadOrders(page.value)
}

const onAskDelete = (id: number) => {
  pendingDeleteOrderId.value = id
  confirmDeleteOpen.value = true
}

const onConfirmDelete = async () => {
  if (!pendingDeleteOrderId.value) {
    return
  }

  await deleteOrder(pendingDeleteOrderId.value)
  pendingDeleteOrderId.value = null
  confirmDeleteOpen.value = false
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
  await router.push(`${tenantPrefix}/app/orders/${id}`)
}
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
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.order-card {
  border-radius: 10px;
}

@media (max-width: 700px) {
  .order-grid {
    grid-template-columns: 1fr;
  }
}
</style>
