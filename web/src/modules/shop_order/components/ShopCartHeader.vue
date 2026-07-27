<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat round icon="arrow_back" color="grey-7" @click="$emit('go-back')" />
        <div>
          <div class="text-overline text-primary">Shop Cart</div>
          <h1 class="text-h5 text-weight-bold q-my-none">
            <template v-if="showCartPicker">Select a Cart</template>
            <template v-else>Your Cart ({{ itemCount }} items)</template>
          </h1>
        </div>
      </div>
    </div>

    <!-- Shop Switcher dropdown if multiple carts exist -->
    <div v-if="!showCartPicker && activeCarts.length > 1" class="col-auto">
      <q-btn-dropdown
        outline
        color="primary"
        no-caps
        unelevated
        :label="currentShopCartInfo ? currentShopCartInfo.shop_name : 'Switch Shop'"
        icon="ph ph-storefront"
      >
        <q-list>
          <q-item
            v-for="c in activeCarts"
            :key="c.cart_id"
            clickable
            v-close-popup
            :active="c.shop_id === selectedShopId"
            active-class="bg-blue-1 text-primary"
            @click="$emit('select-shop-cart', c.shop_id)"
          >
            <q-item-section avatar>
              <q-avatar size="32px" rounded class="bg-grey-2">
                <q-img v-if="c.shop_logo_url" :src="c.shop_logo_url" />
                <q-icon v-else name="ph ph-storefront" size="18px" color="grey-6" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ c.shop_name }}</q-item-label>
              <q-item-label caption>
                {{ c.item_count }} items
                <template v-if="c.see_price && c.cart_total !== null">
                  · {{ formatActiveCartTotal(c) }}
                </template>
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </q-btn-dropdown>
    </div>
  </section>
</template>

<script setup lang="ts">
import type { ActiveCartItem } from '../repositories/shopCartRepository';

defineProps<{
  showCartPicker: boolean;
  itemCount: number;
  activeCarts: ActiveCartItem[];
  currentShopCartInfo: ActiveCartItem | null;
  selectedShopId: number | null;
  formatActiveCartTotal: (cart: ActiveCartItem) => string;
}>();

defineEmits<{
  (e: 'go-back'): void;
  (e: 'select-shop-cart', shopId: number): void;
}>();
</script>
