<template>
  <div>
    <div class="text-subtitle1 text-weight-bold q-mb-md">
      {{ $t('customer_dashboard.shops_title') }}
    </div>

    <div class="row q-col-gutter-md">
      <div v-for="shop in shops" :key="shop.id" class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          bordered
          class="shop-item-card q-pa-md cursor-pointer card-hover"
          role="button"
          tabindex="0"
          data-test="shop-card"
          @click="$emit('open-shop', shop)"
          @keydown.enter.prevent="$emit('open-shop', shop)"
        >
          <div class="text-subtitle1 text-weight-bold">{{ shop.name }}</div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';

defineProps<{
  shops: CustomerAccessibleShop[];
}>();

defineEmits<{
  (e: 'open-shop', shop: CustomerAccessibleShop): void;
}>();
</script>

<style scoped>
.shop-item-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
}
</style>
