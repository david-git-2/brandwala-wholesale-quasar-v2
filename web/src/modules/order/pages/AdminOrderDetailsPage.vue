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

    <OrderItemsTable
      :items="orderStore.selected?.order_items ?? []"
      :status="selectedStatus ?? 'customer_submit'"
    />
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useOrderStore } from '../stores/orderStore';
import { useRoute } from 'vue-router';
import OrderItemsTable from '../components/OrderItemsTable.vue';
import type { OrderStatus } from '../types';

const route = useRoute();

const orderStore = useOrderStore();
const selectedStatus = ref<OrderStatus | null>(null)

const statusOptions: OrderStatus[] = [
  'customer_submit',
  'priced',
  'negotiate',
  'ordered',
  'placed',
]

onMounted(() => {
  void orderStore.fetchOrderById({ id: Number(route.params.id) });
});

watch(
  () => orderStore.selected?.status,
  (status) => {
    selectedStatus.value = status ?? null
  },
  { immediate: true },
)

const onStatusChange = async (status: OrderStatus | null) => {
  if (!status || !orderStore.selected?.id) {
    return
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      status,
    },
  })
}
</script>
