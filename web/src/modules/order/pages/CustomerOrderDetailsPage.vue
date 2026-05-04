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
    <q-card flat bordered class="q-mt-sm q-mb-md bg-white">
      <q-card-section class="row q-col-gutter-md">
        <div class="col">
          <div class="text-caption text-grey-8">Total Quantity</div>
          <div class="text-subtitle1 text-weight-bold">{{ summary.totalQuantity }}</div>
        </div>
        <div class="col">
          <div class="text-caption text-grey-8">Total Cost BDT</div>
          <div class="text-subtitle1 text-weight-bold">{{ formatFixed2(summary.totalCostBdt) }}</div>
        </div>
        <div v-if="canSeeGbp" class="col">
          <div class="text-caption text-grey-8">Total Cost GBP</div>
          <div class="text-subtitle1 text-weight-bold">{{ formatFixed2(summary.totalCostGbp) }}</div>
        </div>
      </q-card-section>
    </q-card>
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
import { computed, onMounted } from 'vue';
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
const canSeeGbp = computed(
  () => Boolean(storeStore.selectedStore?.see_price) || Boolean(orderStore.selected?.can_see_price),
)

const summary = computed(() => {
  const items = orderStore.selected?.order_items ?? []

  return items.reduce(
    (acc, item) => {
      const quantity = Number(item.ordered_quantity ?? 0)
      const bdtUnit = Number(item.final_offer_bdt ?? item.customer_offer_bdt ?? item.first_offer_bdt ?? 0)
      const gbpUnit = Number(item.price_gbp ?? 0)

      acc.totalQuantity += quantity
      acc.totalCostBdt += quantity * bdtUnit
      acc.totalCostGbp += quantity * gbpUnit
      return acc
    },
    { totalQuantity: 0, totalCostBdt: 0, totalCostGbp: 0 },
  )
})

const formatFixed2 = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)


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
