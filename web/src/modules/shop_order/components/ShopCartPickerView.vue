<template>
  <div class="q-py-md">
    <div class="text-subtitle1 text-grey-7 q-mb-md">
      {{ $t('shop.cart_select_desc') }}
    </div>
    <div class="row q-col-gutter-md">
      <div v-for="c in activeCarts" :key="c.cart_id" class="col-xs-12 col-sm-6 col-md-4">
        <q-card
          flat
          bordered
          class="items-card cursor-pointer border-all active-cart-card"
          @click="$emit('select-shop-cart', c.shop_id)"
        >
          <q-card-section class="row items-center q-gutter-x-md">
            <q-avatar size="52px" rounded class="bg-grey-2 border-all">
              <q-img v-if="c.shop_logo_url" :src="c.shop_logo_url" />
              <q-icon v-else name="ph ph-storefront" color="primary" size="28px" />
            </q-avatar>
            <div class="col">
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ c.shop_name }}</div>
              <div class="text-caption text-grey-6">
                {{ c.item_count }} {{ c.item_count === 1 ? $t('shop.items').toLowerCase() : $t('shop.items').toLowerCase() }}
                <template v-if="c.can_see_sell_price && c.cart_total !== null">
                  ·
                  <span class="text-weight-bold text-grey-9">{{ formatActiveCartTotal(c) }}</span>
                </template>
              </div>
            </div>
          </q-card-section>
          <q-card-actions align="right" class="bg-grey-1 q-px-md">
            <q-btn
              flat
              color="primary"
              no-caps
              :label="$t('shop.cart_view_checkout')"
              icon-right="ph ph-arrow-right"
            />
          </q-card-actions>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { ActiveCartItem } from '../repositories/shopCartRepository';

defineProps<{
  activeCarts: ActiveCartItem[];
  formatActiveCartTotal: (cart: ActiveCartItem) => string;
}>();

defineEmits<{
  (e: 'select-shop-cart', shopId: number): void;
}>();
</script>

<style scoped>
.items-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-all {
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.active-cart-card {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.active-cart-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(34, 56, 101, 0.08);
}
</style>
