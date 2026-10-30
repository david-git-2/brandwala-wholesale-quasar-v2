<template>
  <section class="shop-home-top" aria-label="Catalog overview">
    <div class="shop-home-kpi-row row q-col-gutter-sm">
      <div class="col-4">
        <q-card flat class="shop-home-card shop-home-kpi q-pa-sm q-px-md">
          <div class="shop-home-kpi__value">{{ formatCountWithPlus(totalProducts) }}</div>
          <div class="shop-home-kpi__label">{{ $t('customer_dashboard.total_products') }}</div>
        </q-card>
      </div>
      <div class="col-4">
        <q-card flat class="shop-home-card shop-home-kpi q-pa-sm q-px-md">
          <div class="shop-home-kpi__value">{{ formatCountWithPlus(totalBrands) }}</div>
          <div class="shop-home-kpi__label">{{ $t('customer_dashboard.total_brands') }}</div>
        </q-card>
      </div>
      <div class="col-4">
        <q-card flat class="shop-home-card shop-home-kpi q-pa-sm q-px-md">
          <div class="shop-home-kpi__value">{{ formatCount(totalOrdersPlaced) }}</div>
          <div class="shop-home-kpi__label">{{ $t('customer_dashboard.total_orders_placed') }}</div>
        </q-card>
      </div>
    </div>

    <div v-if="shops.length > 0" class="shop-home-shops-row row q-col-gutter-sm q-mt-sm">
      <div
        v-for="shop in shops"
        :key="shop.id"
        class="col-12 col-sm-6"
      >
        <q-card
          flat
          class="shop-home-card shop-home-shop-card q-pa-md cursor-pointer"
          role="button"
          tabindex="0"
          data-test="shop-card"
          @click="$emit('open-shop', shop)"
          @keydown.enter.prevent="$emit('open-shop', shop)"
        >
          <div class="shop-home-shop-card__name">{{ shop.name }}</div>
          <div class="shop-home-shop-card__context">{{ shopContext(shop.id) }}</div>
          <span class="shop-home-shop-card__btn">{{ startOrderLabel(shop.name) }}</span>
        </q-card>
      </div>
    </div>

    <q-card
      v-else
      flat
      class="shop-home-card shop-home-shop-card shop-home-shop-card--empty q-pa-md q-mt-sm"
    >
      <div class="shop-home-shop-card__context">{{ $t('customer_dashboard.no_shops_sub') }}</div>
    </q-card>
  </section>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import type { ShopPortalStat } from '../utils/shopPortalStats';

const props = defineProps<{
  totalProducts?: number | null;
  totalBrands?: number | null;
  totalOrdersPlaced?: number | null;
  shops: CustomerAccessibleShop[];
  shopStats?: Record<number, ShopPortalStat>;
}>();

defineEmits<{
  (e: 'open-shop', shop: CustomerAccessibleShop): void;
}>();

const { t } = useI18n();

const formatCount = (value?: number | null) => {
  if (value == null) return '—';
  return value.toLocaleString();
};

const formatCountWithPlus = (value?: number | null) => {
  const formatted = formatCount(value);
  return formatted === '—' ? formatted : `${formatted}+`;
};

const shopContext = (shopId: number) => {
  const stat = props.shopStats?.[shopId] ?? { pendingOrders: 0, cartItems: 0 };
  return t('customer_dashboard.shop_context_line', {
    pending: stat.pendingOrders,
    cart: stat.cartItems,
  });
};

const startOrderLabel = (shopName: string) =>
  t('customer_dashboard.shop_start_order_for', { name: shopName });
</script>
