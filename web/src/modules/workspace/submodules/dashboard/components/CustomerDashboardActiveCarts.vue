<template>
  <section
    v-if="carts.length > 0"
    class="shop-home-active-carts"
    aria-label="Active carts"
  >
    <div class="shop-home-section-header q-mb-sm">
      <h2 class="shop-home-section-header__title q-my-none">
        {{ $t('customer_dashboard.active_carts_title') }}
      </h2>
      <span class="shop-home-section-header__sub">
        {{ $t('customer_dashboard.active_carts_sub') }}
      </span>
    </div>

    <div class="row q-col-gutter-sm">
      <div
        v-for="cart in carts"
        :key="cart.cart_id"
        class="col-12 col-sm-6 col-md-4"
      >
        <q-card
          flat
          class="shop-home-card shop-home-cart-card q-pa-md"
          data-test="active-cart-card"
        >
          <div class="row items-center no-wrap q-gutter-sm">
            <q-avatar size="38px" class="shop-home-shop-avatar">
              <img
                v-if="cart.shop_logo_url"
                :src="cart.shop_logo_url"
                :alt="cart.shop_name"
              />
              <q-icon v-else name="ph ph-shopping-cart-simple" size="18px" />
            </q-avatar>
            <div class="col min-w-0">
              <div class="shop-home-shop-card__name ellipsis">{{ cart.shop_name }}</div>
              <span class="shop-home-type-pill">
                {{ $t(customerShopTypeI18nKey(cart.shop_type)) }}
              </span>
            </div>
          </div>

          <div class="shop-home-cart-card__meta q-mt-sm">
            <span>{{ itemCountLabel(cart.item_count) }}</span>
            <span
              v-if="cart.can_see_sell_price && cart.cart_total != null"
              class="shop-home-cart-card__total"
            >
              {{ formatCartTotal(cart) }}
            </span>
          </div>

          <div class="shop-home-shop-card__actions">
            <button
              type="button"
              class="shop-home-shop-card__btn shop-home-shop-card__btn--primary"
              data-test="active-cart-resume-btn"
              @click="$emit('resume-cart', cart)"
            >
              {{ $t('customer_dashboard.resume_cart_action') }}
            </button>
          </div>
        </q-card>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { ActiveCartItem } from 'src/modules/shop_order/repositories/shopCartRepository';
import { customerShopTypeI18nKey } from 'src/modules/shop_order/utils/catalogShop';

defineProps<{
  carts: ActiveCartItem[];
}>();

defineEmits<{
  (e: 'resume-cart', cart: ActiveCartItem): void;
}>();

const { t } = useI18n();

const itemCountLabel = (count: number) =>
  count === 1
    ? t('customer_dashboard.cart_item_one')
    : t('customer_dashboard.cart_items', { count });

const formatCartTotal = (cart: ActiveCartItem) => {
  const symbol = cart.currency_symbol ? `${cart.currency_symbol} ` : '';
  return `${symbol}${Number(cart.cart_total ?? 0).toLocaleString()}`;
};
</script>
