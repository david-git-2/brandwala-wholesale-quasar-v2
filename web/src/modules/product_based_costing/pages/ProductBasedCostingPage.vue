<template>
  <q-page class="q-pa-lg">
    <div>Product Based Costing</div>

    <div v-if="store.loading">loading</div>
    <div v-else-if="store.error">error: {{ store.error }}</div>
    <ul v-else>
      <li v-for="item in store.items" :key="item.id">
        <pre>{{ item }}</pre>
      </li>
    </ul>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'

import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'

const store = useProductBasedCostingStore()

onMounted(() => {
  void store.fetchProductBasedCostingFiles()
})
</script>
