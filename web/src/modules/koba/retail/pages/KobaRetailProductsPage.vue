<template>
  <q-page class="flex flex-col items-center p-4">
    <h1 class="text-2xl font-bold mb-4">Koba Retail Products</h1>
    <div class="w-full">
      <q-row gutter="md">
        <q-col
          v-for="item in store.items"
          :key="item.id"
          cols="12"
          sm="4"
          md="3"
          lg="1"
        >
          <ProductCard
            :product="item"
            show-price
            price-field="price_gbp"
            price-symbol="£"
          />
        </q-col>
      </q-row>
    </div>
    <q-pagination
      v-model="store.meta.currentPage"
      :max="store.totalPages"
      color="primary"
      @update:model-value="store.fetchProducts"
      class="my-4"
    />
  </q-page>
</template>

<script setup lang="ts">
import { useKobaRetailStore } from 'src/modules/koba/retail/stores/kobaRetailStore'
import ProductCard from 'src/modules/koba/retail/components/ProductCard.vue'

const store = useKobaRetailStore()
store.fetchProducts(store.meta.currentPage)
</script>

<style scoped>
</style>
