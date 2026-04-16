<template>
  <q-page class="q-pa-md">
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
import { useRoute } from 'vue-router';
import CustomerOrderTable from '../components/CustomerOrderTable.vue';
import { formatStatus } from 'src/composables/useFormatStatus';
import CustomerOrderCard from '../components/CustomerOrderCard.vue';




const orderStore = useOrderStore()
const route = useRoute()


onMounted(() => {
  void orderStore.fetchOrderById({ id: Number(route.params.id) })
})
</script>
