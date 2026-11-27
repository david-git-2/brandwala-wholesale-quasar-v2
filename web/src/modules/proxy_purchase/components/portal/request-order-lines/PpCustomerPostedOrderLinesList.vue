<template>
  <div class="pp-customer-posted-order-lines column q-gutter-y-xs">
    <PpOrderLineCustomerCard v-for="line in lines" :key="line.id" :line="line" />
  </div>
</template>

<script setup lang="ts">
import PpOrderLineCustomerCard from './PpOrderLineCustomerCard.vue';
import type { PpOrderLine } from '../../../types/ppPurchaseRequest';

defineProps<{
  lines: PpOrderLine[];
}>();
</script>