<template>
  <div class="shop-cart-tabs-wrap">
    <q-tabs
      :model-value="selectedShopId"
      dense
      no-caps
      align="left"
      class="shop-cart-tabs"
      active-color="primary"
      indicator-color="primary"
      outside-arrows
      mobile-arrows
      data-test="shop-cart-tabs"
      @update:model-value="onSelect"
    >
      <q-tab
        v-for="cart in carts"
        :key="cart.shop_id"
        :name="cart.shop_id"
        :ripple="false"
        class="shop-cart-tabs__tab"
        :data-test="`shop-cart-tab-${cart.shop_id}`"
      >
        <div class="row items-center no-wrap q-gutter-x-xs">
          <q-avatar v-if="cart.shop_logo_url" size="22px" rounded class="shop-cart-tabs__avatar">
            <q-img :src="cart.shop_logo_url" :alt="cart.shop_name" />
          </q-avatar>
          <q-icon
            v-else
            name="ph ph-storefront"
            size="16px"
            class="shop-cart-tabs__icon"
          />
          <span class="ellipsis shop-cart-tabs__label">{{ cart.shop_name }}</span>
          <q-badge
            v-if="cart.item_count > 0"
            color="primary"
            text-color="white"
            rounded
            class="shop-cart-tabs__badge"
            :label="String(cart.item_count)"
          />
        </div>
      </q-tab>
    </q-tabs>
  </div>
</template>

<script setup lang="ts">
import type { ActiveCartItem } from '../repositories/shopCartRepository';

defineProps<{
  carts: ActiveCartItem[];
  selectedShopId: number | null;
}>();

const emit = defineEmits<{
  (e: 'select-shop-cart', shopId: number): void;
}>();

const onSelect = (shopId: number | string | null) => {
  const parsed = Number(shopId);
  if (!Number.isFinite(parsed) || parsed <= 0) return;
  emit('select-shop-cart', parsed);
};
</script>

<style scoped>
.shop-cart-tabs-wrap {
  border: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08));
  border-radius: 10px;
  background: var(--bw-theme-surface, #ffffff);
  overflow: hidden;
}

.shop-cart-tabs {
  min-height: 44px;
}

.shop-cart-tabs__tab {
  min-height: 44px;
  padding: 0 12px;
  max-width: 200px;
}

.shop-cart-tabs__label {
  font-size: 13px;
  font-weight: 600;
  max-width: 120px;
}

.shop-cart-tabs__icon {
  color: var(--bw-theme-muted, #6b7280);
  flex-shrink: 0;
}

.shop-cart-tabs__avatar {
  flex-shrink: 0;
}

.shop-cart-tabs__badge {
  min-height: 18px;
  padding: 0 6px;
  font-size: 10px;
  font-weight: 700;
}
</style>
