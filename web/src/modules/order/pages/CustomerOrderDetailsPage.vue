<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-sm">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Orders"
        @click="onBackToOrders"
      />
    </div>
    <div class="text-h5">#{{orderStore.selected?.id}} {{orderStore.selected?.name}} Order Details</div>
    <div class="row justify-end"><q-chip class="bg-primary" text-color="white"  :label="formatStatus(orderStore.selected?.status)" /></div>
    <div v-if="$q.screen.lt.sm">
      <CustomerOrderCard />
    </div>
    <div v-else>
      <CustomerOrderTable
        :items="orderStore.selected?.order_items || []"
        :status="orderStore.selected?.status ?? 'customer_submit'"
        :negotiate-enabled="orderStore.selected?.negotiate ?? true"
      />
    </div>
  </q-page>
</template>
<script setup lang="ts">
import { onMounted } from 'vue';
import { useOrderStore } from '../stores/orderStore';
import { useRoute, useRouter } from 'vue-router';
import CustomerOrderTable from '../components/CustomerOrderTable.vue';
import { formatStatus } from 'src/composables/useFormatStatus';
import CustomerOrderCard from '../components/CustomerOrderCard.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useStoreStore } from 'src/modules/store/stores/storeStore';
const storeStore = useStoreStore()



const orderStore = useOrderStore()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()


onMounted(() => {
const itemFields = [
  'id',
  'name',
  'quantity',
  'customer_offer_bdt',
  'final_offer_bdt',
  'first_offer_bdt',
  'image_url',
  'minimum_quantity',
  'name',
  'order_id',
  'ordered_quantity',
  ...(storeStore.selectedStore?.see_price ? ['price_gbp'] : [])
]

void orderStore.fetchOrderById({
  id: Number(route.params.id),
  item_fields: itemFields,
  order_fields: ['accent_color', 'can_see_price', 'customer_group_id', 'id', 'name','negotiate','status','store_id']
})})

const onBackToOrders = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/shop/orders`)
}
</script>
