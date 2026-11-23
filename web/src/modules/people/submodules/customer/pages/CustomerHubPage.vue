<template>
  <q-page class="customer-hub-page page-fixed-layout q-pa-md">
    <CustomerGroupListPanel fill-height />
  </q-page>
</template>

<script setup lang="ts">
import CustomerGroupListPanel from '../components/CustomerGroupListPanel.vue';
</script>

<style scoped>
.customer-hub-page {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
</style>
