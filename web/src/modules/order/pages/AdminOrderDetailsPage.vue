<template>
  <q-page class="q-pa-md">
    <div class="text-h5">#{{orderStore.selected?.id}} {{orderStore.selected?.name}} Order Details</div>

    <div class="q-mt-md q-mb-md row justify-end" >
      <q-select
        v-model="selectedStatus"
        outlined
        dense
        label="Order Status"
        :options="statusOptions"
        :loading="orderStore.saving"
        @update:model-value="onStatusChange"
      />
    </div>

    <div class="row q-gutter-sm q-my-sm">
      <q-input
        outlined
        dense
        v-model="conversionRate"
        type="number"
        label="Conversion Rate"
      />
      <q-input
        outlined
        dense
        v-model="cargoRate"
        type="number"
        label="Cargo Rate / KG"
      />
      <q-input
        outlined
        dense
        v-model="profitRate"
        type="number"
        label="Profit Rate"
      />
      <q-btn
        color="primary"
        dense
        no-caps
        label="Save Rates"
        class="q-px-sm"
        :loading="orderStore.saving"
        @click="onSaveRates"
      />

    </div>

    <OrderItemsTable
      :items="orderStore.selected?.order_items ?? []"
      :status="selectedStatus ?? 'customer_submit'"
      :conversion-rate="Number(conversionRate) || 0"
      :cargo-rate="Number(cargoRate) || 0"
      :profit-rate="Number(profitRate) || 0"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useOrderStore } from '../stores/orderStore'
import { useRoute } from 'vue-router'
import OrderItemsTable from '../components/OrderItemsTable.vue'
import type { OrderStatus } from '../types'

const route = useRoute()
const orderStore = useOrderStore()

const selectedStatus = ref<OrderStatus | null>(null)

const statusOptions: OrderStatus[] = [
  'customer_submit',
  'priced',
  'negotiate',
  'final_offered',
  'ordered',
  'placed',
]

const normalizeNumericInput = (value: unknown) => {
  if (value == null) {
    return null
  }

  if (typeof value === 'string' && value.trim() === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

onMounted(async () => {
  await orderStore.fetchOrderById({ id: Number(route.params.id) })
})

watch(
  () => orderStore.selected?.status,
  (status) => {
    selectedStatus.value = status ?? null
  },
  { immediate: true }
)

const conversionRate = computed({
  get: () => orderStore.selected?.conversion_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.conversion_rate = normalizeNumericInput(value)
    }
  },
})

const cargoRate = computed({
  get: () => orderStore.selected?.cargo_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.cargo_rate = normalizeNumericInput(value)
    }
  },
})

const profitRate = computed({
  get: () => orderStore.selected?.profit_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.profit_rate = normalizeNumericInput(value)
    }
  },
})

const conversionRateRef = computed(() => Number(conversionRate.value) || 0)
const cargoRateRef = computed(() => Number(cargoRate.value) || 0)
const profitRateRef = computed(() => Number(profitRate.value) || 0)

const selectedItems = computed(() => orderStore.selected?.order_items ?? [])

const ceil2 = (n: number) => Math.ceil(n * 100) / 100
const ceilInt = (n: number) => Math.ceil(n)
const roundUpTo5 = (n: number) => Math.ceil(n / 5) * 5

const onStatusChange = async (status: OrderStatus | null) => {
  if (!status || !orderStore.selected?.id) return

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      status,
    },
  })
}

const onSaveRates = async () => {
  if (!orderStore.selected?.id) return

  const orderUpdateResult = await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      cargo_rate: orderStore.selected.cargo_rate ?? null,
      conversion_rate: orderStore.selected.conversion_rate ?? null,
      profit_rate: orderStore.selected.profit_rate ?? null,
    },
  })

  if (!orderUpdateResult.success) {
    return
  }

  const conversion = conversionRateRef.value
  const cargo = cargoRateRef.value
  const profit = profitRateRef.value

  const recalculatedPayload = selectedItems.value.map((item) => {
    const productWeight = Number(item.product_weight || 0)
    const packageWeight = Number(item.package_weight || 0)
    const totalWeight = productWeight + packageWeight
    const priceGbp = Number(item.price_gbp || 0)

    const unitLineCostGbp = ceil2((totalWeight / 1000) * cargo + priceGbp)
    const costBdt = ceilInt(unitLineCostGbp * conversion)
    const firstOfferBdt = roundUpTo5((costBdt * profit) / 100 + costBdt)

    return {
      id: item.id,
      cost_gbp: unitLineCostGbp,
      cost_bdt: costBdt,
      first_offer_bdt: firstOfferBdt,
    }
  })

  await orderStore.bulkUpdateOrderItems(recalculatedPayload)
}



</script>
