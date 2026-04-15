<template>
  <div class="row q-gutter-md">
    <q-card
      v-for="item in orderStore.selected?.order_items"
      :key="item.id"
      class="my-card"
    >
      <div class="product-image-wrap">
        <SmartImage :src="item.image_url"  :alt="item.name"
          img-class="product-image"
          fallback-class="product-image-fallback" />
      </div>

      <q-card-section>
        <div class="text-body1 text-weight-medium name-clamp">
          {{ item.name }}
        </div>

        <div class="  q-mt-sm">
          Quantity: {{ item.ordered_quantity }}
        </div>

         <div v-if="orderStore.selected?.status==='customer_submit'" class="  q-mt-sm" >

        </div>
        <div v-else-if="orderStore.selected?.status==='priced'" class="  q-mt-sm" >
          <div>First Offer: {{ item.first_offer_bdt }}</div>

        </div>


          <div v-else-if="orderStore.selected?.status==='negotiate'" class="  q-mt-sm" >
          <div>First Offer: {{ item.first_offer_bdt }} </div>

          <div>Customer Offer: {{ item.customer_offer_bdt }}</div>
        </div>
           <div v-else-if="orderStore.selected?.status==='final_offered'" class="  q-mt-sm" >
          <div>First Offer: {{ item.first_offer_bdt }}</div>
          <div>Customer Offer: {{ item.customer_offer_bdt }}</div>
          <div>Final Offer: {{ item.final_offer_bdt }}</div>

        </div>
         <div v-else class="  q-mt-sm" >
          <div>First Offer: {{ item.first_offer_bdt }}</div>
          <div>Customer Offer: {{ item.customer_offer_bdt }}</div>
          <div>Final Offer: {{ item.final_offer_bdt }}</div>

        </div>



      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue'
import { useOrderStore } from '../stores/orderStore'

const orderStore = useOrderStore()
</script>

<style scoped>
.my-card {
  width: 280px;
  border-radius: 12px;
}

.product-image-wrap {
  width: 100%;
  height: 180px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #fff;
  border-top-left-radius: 12px;
  border-top-right-radius: 12px;
  overflow: hidden;
}

.name-clamp {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4em;
  min-height: 4.2em;
}
:deep(.product-image) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  padding: 8px;
}

:deep(.product-image-fallback) {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #746655;
  background: #f3efe9;
  font-size: 0.95rem;
}
</style>
