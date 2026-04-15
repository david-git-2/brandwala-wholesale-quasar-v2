<template>
  <q-page class="q-pa-md">
    <div class="text-h5">Order Details</div>
    <div class="row justify-end"><q-chip class="bg-primary" text-color="white"  :label="formatStatus(orderStore.selected?.status)" /></div>
    <CustomerOrderTable
      :items="orderStore.selected?.order_items || []"
      :status="orderStore.selected?.status ?? 'customer_submit'"
    />
  </q-page>
</template>
<script setup lang="ts">
import { onMounted } from 'vue';
import { useOrderStore } from '../stores/orderStore';
import { useRoute } from 'vue-router';
import CustomerOrderTable from '../components/CustomerOrderTable.vue';
import { formatStatus } from 'src/composables/useFormatStatus';



const orderStore = useOrderStore()
const route = useRoute()


onMounted(() => {
  void orderStore.fetchOrderById({ id: Number(route.params.id) })
})
</script>
