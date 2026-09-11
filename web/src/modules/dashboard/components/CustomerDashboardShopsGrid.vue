<template>
  <div>
    <h2 class="shop-home-section__title q-my-none q-mb-md">
      {{ $t('customer_dashboard.shops_title') }}
    </h2>

    <div class="row q-col-gutter-md">
      <div v-for="(shop, index) in shops" :key="shop.id" class="col-12 col-sm-6 col-md-3">
        <q-card
          flat
          class="shop-ds-tile q-pa-md cursor-pointer"
          :class="tileTone(index)"
          role="button"
          tabindex="0"
          data-test="shop-card"
          @click="$emit('open-shop', shop)"
          @keydown.enter.prevent="$emit('open-shop', shop)"
        >
          <div class="text-h5 text-weight-bold">{{ shop.name }}</div>
          <p v-if="shop.description?.trim()" class="shop-ds-tile__desc q-mt-sm q-mb-none">
            {{ shop.description.trim() }}
          </p>
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

const TILE_TONES = ['shop-ds-tile--charcoal', 'shop-ds-tile--plum', 'shop-ds-tile--mauve', 'shop-ds-tile--clay'] as const;

const tileTone = (index: number) => TILE_TONES[index % TILE_TONES.length];
</script>

<style scoped>
.shop-ds-tile {
  color: #f9fffb;
}

.shop-ds-tile__desc {
  font-size: 0.8125rem;
  line-height: 1.45;
  color: rgba(249, 255, 251, 0.82);
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
