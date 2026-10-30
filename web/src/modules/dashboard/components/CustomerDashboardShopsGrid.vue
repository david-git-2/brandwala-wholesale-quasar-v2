<template>
  <div>
    <h2 class="shop-home-section__title q-my-none q-mb-md">
      {{ $t('customer_dashboard.shops_title') }}
    </h2>

    <div class="row q-col-gutter-md">
      <div v-for="(shop, index) in shops" :key="shop.id" class="col-12 col-sm-6 col-md-3">
        <q-card
          flat
          bordered
          class="shop-ds-tile q-pa-lg cursor-pointer"
          :class="tileAccent(index)"
          role="button"
          tabindex="0"
          data-test="shop-card"
          @click="$emit('open-shop', shop)"
          @keydown.enter.prevent="$emit('open-shop', shop)"
        >
          <q-icon name="ph ph-storefront" class="shop-ds-tile__icon" aria-hidden="true" />
          <div class="shop-ds-tile__name text-weight-bold">{{ shop.name }}</div>
          <p v-if="shop.description?.trim()" class="shop-ds-tile__desc q-mt-sm q-mb-none">
            {{ shop.description.trim() }}
          </p>
          <div v-else-if="categoryCount(shop) > 0" class="shop-ds-tile__metric q-mt-sm">
            {{ $t('customer_dashboard.shop_category_count', { count: categoryCount(shop) }) }}
          </div>
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

const TILE_ACCENTS = [
  'shop-ds-tile--accent-blue',
  'shop-ds-tile--accent-sky',
  'shop-ds-tile--accent-mint',
  'shop-ds-tile--accent-primary',
] as const;

const tileAccent = (index: number) => TILE_ACCENTS[index % TILE_ACCENTS.length];

const categoryCount = (shop: CustomerAccessibleShop) =>
  shop.categories?.length ?? shop.category_ids?.length ?? 0;
</script>

<style scoped>
.shop-ds-tile__name {
  font-size: 1.125rem;
  line-height: 1.25;
}

.shop-ds-tile__desc {
  font-size: 0.8125rem;
  line-height: 1.45;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.shop-ds-tile__metric {
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.02em;
}
</style>
