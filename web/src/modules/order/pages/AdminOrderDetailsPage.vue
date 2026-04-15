<template>
  <q-page class="q-pa-md">
    <div class="text-h5">Order Details</div>

    <div class="q-mt-md q-mb-md" style="max-width: 280px">
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
  'ordered',
  'placed',
]

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
      orderStore.selected.conversion_rate =
        value == null || value === '' ? null : Number(value)
    }
  },
})

const cargoRate = computed({
  get: () => orderStore.selected?.cargo_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.cargo_rate =
        value == null || value === '' ? null : Number(value)
    }
  },
})

const profitRate = computed({
  get: () => orderStore.selected?.profit_rate ?? null,
  set: (value) => {
    if (orderStore.selected) {
      orderStore.selected.profit_rate =
        value == null || value === '' ? null : Number(value)
    }
  },
})

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

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      cargo_rate: orderStore.selected.cargo_rate ?? null,
      conversion_rate: orderStore.selected.conversion_rate ?? null,
      profit_rate: orderStore.selected.profit_rate ?? null,
    },
  })
}
</script>
