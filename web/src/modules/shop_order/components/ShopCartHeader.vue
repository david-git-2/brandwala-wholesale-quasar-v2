<template>
  <section class="column q-gutter-y-sm">
    <div class="row items-center justify-between no-wrap q-col-gutter-sm">
      <div class="col min-width-0">
        <div class="row items-center q-gutter-x-sm no-wrap">
          <h1 class="text-subtitle1 text-weight-bold q-my-none ellipsis">
            <template v-if="showCartPicker">{{ $t('shop.cart_select_title') }}</template>
            <template v-else-if="shopName">
              {{ $t('shop.cart_title') }} · {{ shopName }}
            </template>
            <template v-else>{{ $t('shop.cart_title') }}</template>
          </h1>
          <q-chip
            v-if="!showCartPicker && itemCount > 0"
            dense
            size="sm"
            color="primary"
            text-color="white"
          >
            {{ itemCount }}
          </q-chip>
        </div>
      </div>

      <div
        v-if="nonEmptyCarts.length > 1"
        class="col-auto text-caption tf-text-muted"
        data-test="cart-total-across-shops"
      >
        {{
          $t('shop.cart_across_shops', {
            total: totalItemsAcrossShops,
            shops: nonEmptyCarts.length,
          })
        }}
      </div>
    </div>

    <div
      v-if="nonEmptyCarts.length > 1"
      class="shop-cart-switcher"
      role="tablist"
      aria-label="Active shop carts"
      data-test="cart-shop-switcher"
    >
      <button
        v-for="c in nonEmptyCarts"
        :key="c.shop_id"
        type="button"
        role="tab"
        :aria-selected="c.shop_id === selectedShopId"
        class="shop-cart-switcher__pill"
        :class="{ 'shop-cart-switcher__pill--active': c.shop_id === selectedShopId }"
        :data-test="`cart-shop-tab-${c.shop_id}`"
        @click="$emit('select-shop', c.shop_id)"
      >
        <span class="ellipsis">{{ c.shop_name }}</span>
        <span class="shop-cart-switcher__count">{{ c.item_count }}</span>
      </button>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ActiveCartItem } from '../repositories/shopCartRepository';

const props = withDefaults(
  defineProps<{
    showCartPicker: boolean;
    itemCount: number;
    shopName?: string | null;
    activeCarts?: ActiveCartItem[];
    selectedShopId?: number | null;
  }>(),
  {
    shopName: null,
    activeCarts: () => [],
    selectedShopId: null,
  },
);

defineEmits<{
  (e: 'select-shop', shopId: number): void;
}>();

const nonEmptyCarts = computed(() =>
  (props.activeCarts ?? []).filter((c) => Number(c.item_count) > 0),
);

const totalItemsAcrossShops = computed(() =>
  nonEmptyCarts.value.reduce((sum, c) => sum + Number(c.item_count), 0),
);
</script>

<style scoped>
.shop-cart-switcher {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.shop-cart-switcher__pill {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  max-width: 100%;
  padding: 0.35rem 0.75rem;
  border-radius: 999px;
  border: 1px solid var(--tf-theme-border, rgb(15 23 42 / 0.12));
  background: var(--tf-theme-surface, #fff);
  color: var(--tf-theme-ink, #111827);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    border-color var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    background var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    color var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.shop-cart-switcher__pill:hover,
.shop-cart-switcher__pill:focus-visible {
  border-color: color-mix(in srgb, var(--tf-theme-primary) 50%, transparent);
}

.shop-cart-switcher__pill--active {
  border-color: var(--tf-theme-primary);
  background: color-mix(in srgb, var(--tf-theme-primary) 12%, transparent);
  color: var(--tf-theme-primary);
}

.shop-cart-switcher__count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.35rem;
  padding: 0.05rem 0.4rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  background: color-mix(in srgb, var(--tf-theme-ink, #111827) 8%, transparent);
}

.shop-cart-switcher__pill--active .shop-cart-switcher__count {
  background: var(--tf-theme-primary);
  color: var(--tf-theme-on-primary, #fff);
}
</style>
