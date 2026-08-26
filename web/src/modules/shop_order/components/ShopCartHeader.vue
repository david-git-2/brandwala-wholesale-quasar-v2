<template>
  <section class="cart-page-header row items-center justify-between no-wrap q-col-gutter-sm">
    <div class="col min-width-0">
      <div class="row items-center q-gutter-x-sm no-wrap">
        <h1 class="cart-page-header__title text-subtitle1 text-weight-bold q-my-none ellipsis">
          <template v-if="showCartPicker">{{ $t('shop.cart_select_title') }}</template>
          <template v-else>{{ $t('shop.cart_title') }}</template>
        </h1>
        <q-chip
          v-if="!showCartPicker && itemCount > 0"
          dense
          size="sm"
          class="cart-page-header__count"
          color="primary"
          text-color="white"
        >
          {{ itemCount }}
        </q-chip>
      </div>
      <div
        v-if="!showCartPicker && currentShopCartInfo"
        class="cart-page-header__meta text-caption text-grey-6 ellipsis q-mt-xs"
      >
        {{ currentShopCartInfo.shop_name }}
        <span v-if="itemCount > 0"> · {{ itemCount }} {{ $t('shop.items').toLowerCase() }}</span>
      </div>
    </div>

    <div v-if="!showCartPicker && activeCarts.length > 1" class="col-auto">
      <q-btn-dropdown
        dense
        flat
        no-caps
        color="grey-8"
        class="cart-page-header__shop-switch"
        :label="currentShopCartInfo ? currentShopCartInfo.shop_name : $t('shop.switch_shop')"
        icon="ph ph-storefront"
      >
        <q-list dense class="cart-page-header__shop-list">
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
              <q-avatar size="28px" rounded class="bg-grey-2">
                <q-img v-if="c.shop_logo_url" :src="c.shop_logo_url" />
                <q-icon v-else name="ph ph-storefront" size="16px" color="grey-6" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ c.shop_name }}</q-item-label>
              <q-item-label caption>
                {{ c.item_count }} {{ $t('shop.items').toLowerCase() }}
                <template v-if="c.can_see_sell_price && c.cart_total !== null">
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
  (e: 'select-shop-cart', shopId: number): void;
}>();
</script>

<style scoped>
.cart-page-header {
  min-height: 40px;
}

.cart-page-header__title {
  color: var(--bw-theme-ink, #1f2937);
  line-height: 1.25;
}

.cart-page-header__count {
  min-height: 22px;
  font-size: 11px;
  font-weight: 700;
  padding: 0 8px;
}

.cart-page-header__meta {
  line-height: 1.2;
}

.cart-page-header__shop-switch {
  max-width: 180px;
  border-radius: 8px;
  font-size: 13px;
}

.cart-page-header__shop-switch :deep(.q-btn__content) {
  max-width: 100%;
}

.cart-page-header__shop-switch :deep(.block) {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cart-page-header__shop-list {
  min-width: 240px;
}
</style>
