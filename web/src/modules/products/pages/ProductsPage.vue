<template>
  <q-page class="q-pa-lg">
    <div>Products</div>

    <div v-if="productStore.loading">loading</div>
    <div v-else-if="productStore.error">error: {{ productStore.error }}</div>
    <ul v-else>
      <li v-for="product in productStore.items" :key="product.id">
        <pre>{{ product }}</pre>
      </li>
    </ul>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'

import { useProductStore } from '../stores/productStore'

const productStore = useProductStore()

onMounted(() => {
  void productStore.fetchProducts()
})
</script>
