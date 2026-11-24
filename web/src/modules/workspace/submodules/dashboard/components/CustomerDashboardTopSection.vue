<template>
  <section class="shop-home-top" aria-label="Catalog overview">
    <div class="shop-home-kpi-row row q-col-gutter-md">
      <div class="col-12 col-sm-4">
        <q-card
          flat
          class="shop-home-card shop-home-kpi shop-home-kpi--interactive q-pa-md cursor-pointer"
          role="button"
          tabindex="0"
          data-test="kpi-total-products"
          @click="$emit('browse-catalog')"
          @keydown.enter.prevent="$emit('browse-catalog')"
        >
          <div class="shop-home-kpi__inner">
            <div class="min-w-0">
              <div class="shop-home-kpi__label row items-center no-wrap q-gutter-xs">
                <span class="ellipsis">{{ $t('customer_dashboard.total_products') }}</span>
                <q-icon name="ph ph-arrow-up-right" size="13px" aria-hidden="true" />
              </div>
              <div class="shop-home-kpi__value">{{ formatCount(totalProducts) }}</div>
            </div>
            <div class="shop-home-kpi__badge shop-home-kpi__badge--primary" aria-hidden="true">
              <q-icon name="ph ph-package" size="20px" />
            </div>
          </div>
        </q-card>
      </div>

      <div class="col-12 col-sm-4">
        <q-card flat class="shop-home-card shop-home-kpi q-pa-md">
          <div class="shop-home-kpi__inner">
            <div class="min-w-0">
              <div class="shop-home-kpi__label ellipsis">{{ $t('customer_dashboard.total_brands') }}</div>
              <div class="shop-home-kpi__value">{{ formatCount(totalBrands) }}</div>
            </div>
            <div class="shop-home-kpi__badge" aria-hidden="true">
              <q-icon name="ph ph-tag" size="20px" />
            </div>
          </div>
        </q-card>
      </div>

      <div class="col-12 col-sm-4">
        <q-card
          flat
          class="shop-home-card shop-home-kpi shop-home-kpi--interactive q-pa-md cursor-pointer"
          role="button"
          tabindex="0"
          data-test="kpi-total-orders"
          @click="$emit('view-orders')"
          @keydown.enter.prevent="$emit('view-orders')"
        >
          <div class="shop-home-kpi__inner">
            <div class="min-w-0">
              <div class="shop-home-kpi__label row items-center no-wrap q-gutter-xs">
                <span class="ellipsis">{{ $t('customer_dashboard.total_orders_placed') }}</span>
                <q-icon name="ph ph-arrow-up-right" size="13px" aria-hidden="true" />
              </div>
              <div class="shop-home-kpi__value">{{ formatCount(totalOrdersPlaced) }}</div>
            </div>
            <div class="shop-home-kpi__badge shop-home-kpi__badge--accent" aria-hidden="true">
              <q-icon name="ph ph-receipt" size="20px" />
            </div>
          </div>
        </q-card>
      </div>
    </div>

    <div class="row q-col-gutter-md q-mt-sm items-start">
      <div class="col-12 col-lg-7">
        <div id="shop-directory" class="shop-home-section-header q-mb-sm">
          <h2 class="shop-home-section-header__title q-my-none">
            {{ $t('customer_dashboard.shops_title') }}
          </h2>
          <span class="shop-home-section-header__sub">
            {{ $t('customer_dashboard.shops_sub') }}
          </span>
        </div>

        <div v-if="shops.length > 0" class="column q-gutter-y-sm">
          <q-card
            v-for="shop in shops"
            :key="shop.id"
            flat
            class="shop-home-card shop-home-shop-card q-pa-md cursor-pointer"
            role="button"
            tabindex="0"
            data-test="shop-card"
            @click="$emit('open-shop', shop)"
            @keydown.enter.prevent="$emit('open-shop', shop)"
          >
            <div class="shop-home-shop-card__top">
              <div class="row items-center no-wrap q-gutter-sm min-w-0">
                <q-avatar size="42px" rounded class="shop-home-shop-avatar">
                  <span class="shop-home-shop-avatar__initials">{{ shopInitials(shop.name) }}</span>
                </q-avatar>
                <div class="min-w-0">
                  <div class="row items-center no-wrap q-gutter-xs">
                    <div class="shop-home-shop-card__name ellipsis">{{ shop.name }}</div>
                    <span class="shop-home-type-pill">
                      {{ $t(customerShopTypeI18nKey(shop.shop_type)) }}
                    </span>
                  </div>
                  <div class="shop-home-shop-card__context">
                    {{ shopSummaryText(shop.id) }}
                  </div>
                </div>
              </div>

              <div class="shop-home-shop-card__actions">
                <button
                  v-if="cartItemsForShop(shop.id) > 0"
                  type="button"
                  class="shop-home-shop-card__btn shop-home-shop-card__btn--cart"
                  data-test="shop-resume-cart-btn"
                  @click.stop="$emit('resume-cart', shop)"
                  @keydown.enter.stop
                  @keydown.space.stop
                >
                  {{ resumeCartLabel(shop.id) }}
                </button>
                <span class="shop-home-shop-card__btn shop-home-shop-card__btn--primary">
                  <span>{{ $t('customer_dashboard.browse_catalog') }}</span>
                  <q-icon name="ph ph-arrow-right" size="14px" class="q-ml-xs" />
                </span>
              </div>
            </div>

            <div
              v-if="cartItemsForShop(shop.id) > 0 || pendingOrdersForShop(shop.id) > 0"
              class="shop-home-shop-card__chips q-mt-sm"
            >
              <button
                v-if="cartItemsForShop(shop.id) > 0"
                type="button"
                class="shop-home-status-chip shop-home-status-chip--cart"
                data-test="shop-chip-cart"
                @click.stop="$emit('resume-cart', shop)"
                @keydown.enter.stop
                @keydown.space.stop
              >
                <q-icon name="ph ph-shopping-cart-simple" size="13px" />
                <span>{{ cartItemsLabel(shop.id) }}</span>
              </button>
              <button
                v-if="pendingOrdersForShop(shop.id) > 0"
                type="button"
                class="shop-home-status-chip"
                data-test="shop-chip-orders"
                @click.stop="$emit('view-shop-orders', shop)"
                @keydown.enter.stop
                @keydown.space.stop
              >
                <q-icon name="ph ph-package" size="13px" />
                <span>{{ pendingOrdersLabel(shop.id) }}</span>
              </button>
            </div>
          </q-card>
        </div>

        <q-card
          v-else
          flat
          class="shop-home-card shop-home-shop-card shop-home-shop-card--empty q-pa-md"
        >
          <div class="shop-home-shop-card__context">{{ $t('customer_dashboard.no_shops_sub') }}</div>
        </q-card>

        <slot name="below-shops" />
      </div>

      <div class="col-12 col-lg-5">
        <slot name="side" />
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import { customerShopTypeI18nKey } from 'src/modules/shop_order/utils/catalogShop';
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
  (e: 'resume-cart', shop: CustomerAccessibleShop): void;
  (e: 'view-shop-orders', shop: CustomerAccessibleShop): void;
  (e: 'browse-catalog'): void;
  (e: 'view-orders'): void;
}>();

const { t } = useI18n();

const shopInitials = (name: string) => {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0]?.[0] ?? ''}${parts[1]?.[0] ?? ''}`.toUpperCase();
  }
  return name.trim().slice(0, 2).toUpperCase() || 'S';
};

const formatCount = (value?: number | null) => {
  if (value == null) return '—';
  return value.toLocaleString();
};

const cartItemsForShop = (shopId: number) => props.shopStats?.[shopId]?.cartItems ?? 0;
const pendingOrdersForShop = (shopId: number) => props.shopStats?.[shopId]?.pendingOrders ?? 0;

const shopSummaryText = (shopId: number) => {
  const pending = pendingOrdersForShop(shopId);
  const cart = cartItemsForShop(shopId);
  if (pending === 0 && cart === 0) {
    return t('customer_dashboard.shop_idle_context');
  }
  return t('customer_dashboard.shop_context_line', { pending, cart });
};

const cartItemsLabel = (shopId: number) => {
  const count = cartItemsForShop(shopId);
  return count === 1
    ? t('customer_dashboard.cart_item_one')
    : t('customer_dashboard.cart_items', { count });
};

const pendingOrdersLabel = (shopId: number) =>
  t('customer_dashboard.pending_orders_chip', { count: pendingOrdersForShop(shopId) });

const resumeCartLabel = (shopId: number) =>
  t('customer_dashboard.resume_cart', { count: cartItemsForShop(shopId) });
</script>
