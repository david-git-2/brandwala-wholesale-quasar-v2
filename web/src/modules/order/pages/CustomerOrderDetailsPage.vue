<template>
  <q-page class="q-pa-md customer-order-details-page">
    <!-- SKELETON LOADER -->
    <div v-if="orderStore.loading" class="customer-order-details-wrap">
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

      <div v-if="$q.screen.lt.sm" class="q-gutter-sm">
        <q-card v-for="n in 3" :key="`card-sk-${n}`" flat bordered>
          <q-card-section>
            <q-skeleton type="text" width="40%" />
            <q-skeleton type="text" width="70%" class="q-mt-xs" />
          </q-card-section>
        </q-card>
      </div>
      <q-card v-else flat bordered>
        <q-markup-table flat>
          <thead>
            <tr>
              <th v-for="n in 5" :key="`th-${n}`"><q-skeleton type="text" /></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="n in 4" :key="`tr-${n}`">
              <td v-for="c in 5" :key="`td-${c}`"><q-skeleton type="text" /></td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </div>

    <div v-else class="customer-order-details-wrap">
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
    </div>
  </q-page>
</template>
<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useOrderStore } from '../stores/orderStore';
import { useRoute } from 'vue-router';
import CustomerOrderTable from '../components/CustomerOrderTable.vue';
import { formatStatus } from 'src/composables/useFormatStatus';
import CustomerOrderCard from '../components/CustomerOrderCard.vue';
import { useStoreStore } from 'src/modules/store/stores/storeStore';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
const storeStore = useStoreStore()
const authStore = useAuthStore()



const orderStore = useOrderStore()
const route = useRoute()
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
  tenant_id: authStore.tenantId ?? null,
  item_fields: itemFields,
  order_fields: ['accent_color', 'can_see_price', 'customer_group_id', 'id', 'name','negotiate','status','store_id']
})})

</script>
<style scoped>
.customer-order-details-page {
  background: transparent;
}

.customer-order-details-wrap {
  width: min(1200px, 100%);
  margin: 0 auto;
}
</style>
