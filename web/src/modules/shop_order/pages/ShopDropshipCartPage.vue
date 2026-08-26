<template>
  <q-page class="q-pa-md shop-commerce-page">
    <div class="q-gutter-y-md">
      <ShopCartHeader
        :show-cart-picker="showCartPicker"
        :item-count="itemCount"
        :active-carts="activeCarts"
        :current-shop-cart-info="headerCartInfo"
        :selected-shop-id="selectedShopId"
        :format-active-cart-total="formatActiveCartTotal"
        @select-shop-cart="selectShopCart"
      />

      <ShopCartSkeleton v-if="isCartsLoading || isCartLoading" />

      <q-card v-else-if="isCartError" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-grey-8 text-weight-bold q-mb-xs">
            {{ $t('shop.cart_load_error') }}
          </div>
          <div class="text-grey-6 q-mb-md">
            {{ $t('shop.cart_load_error_desc') }}
          </div>
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            :label="$t('shop.cart_retry')"
            @click="() => refetchCart()"
          />
        </q-card-section>
      </q-card>

      <ShopCartPickerView
        v-else-if="showCartPicker"
        :active-carts="activeCarts"
        :format-active-cart-total="formatActiveCartTotal"
        @select-shop-cart="selectShopCart"
      />

      <q-card v-else-if="items.length === 0" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-shopping-cart" size="64px" color="grey-4" class="q-mb-md" />
          <div class="text-h6 text-grey-7 text-weight-bold">{{ $t('shop.cart_empty') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm q-mb-md">
            {{ $t('shop.cart_empty_desc') }}
          </p>
          <q-btn
            color="primary"
            no-caps
            unelevated
            :label="$t('shop.continue_shopping')"
            @click="goBack"
          />
        </q-card-section>
      </q-card>

      <template v-else>
        <div class="column q-gutter-y-sm dropship-cart-list">
          <ShopDropshipCartItemCard
            v-for="item in items"
            :key="item.id"
            :name="item.name"
            :image-url="item.image_url"
            :quantity="item.quantity"
            :price="getPurchaseUnitAmount(item)"
            :currency-symbol="currencySymbol"
            :min-qty="item.minimum_quantity"
            :disable-qty="updateQtyMutation.isPending"
            @update:quantity="(qty) => updateItemQuantity(item.id, qty)"
          />
        </div>

        <q-btn
          color="primary"
          unelevated
          no-caps
          class="full-width pill-btn q-py-sm"
          icon-right="ph ph-arrow-right"
          :label="$t('shop.dropship_cart_proceed')"
          :disable="updateQtyMutation.isPending"
          @click="goToReview"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import type { ActiveCartItem } from '../repositories/shopCartRepository';
import { useActiveShopCartsQuery } from '../composables/useActiveShopCartsQuery';
import { useShopCartSelection } from '../composables/useShopCartSelection';
import { useDropshipShopCartQuery } from '../composables/useDropshipShopCartQuery';
import { useShopCartMutations } from '../composables/useShopCartMutations';
import { shopDropshipReviewPath } from '../utils/catalogShop';
import ShopCartHeader from '../components/ShopCartHeader.vue';
import ShopCartPickerView from '../components/ShopCartPickerView.vue';
import ShopCartSkeleton from '../components/ShopCartSkeleton.vue';
import ShopDropshipCartItemCard from '../components/ShopDropshipCartItemCard.vue';

const route = useRoute();
const router = useRouter();

const {
  data: activeCartsData,
  isLoading: isCartsLoading,
} = useActiveShopCartsQuery();
const activeCarts = computed(() => activeCartsData.value ?? []);

const {
  selectedShopId,
  showCartPicker,
  currentShopCartInfo,
  selectShopCart,
  formatActiveCartTotal,
  goBack,
} = useShopCartSelection(activeCarts, isCartsLoading);

const {
  cart,
  items,
  itemCount,
  purchaseSubtotal,
  currencySymbol,
  getPurchaseUnitAmount,
  isLoading: isCartLoading,
  isError: isCartError,
  refetch: refetchCart,
} = useDropshipShopCartQuery(selectedShopId);

const { updateQtyMutation } = useShopCartMutations();

const headerCartInfo = computed<ActiveCartItem | null>(() => {
  if (!selectedShopId.value) return currentShopCartInfo.value;

  const base = currentShopCartInfo.value;
  return {
    cart_id: cart.value?.id ?? base?.cart_id ?? 0,
    shop_id: selectedShopId.value,
    shop_name: cart.value?.shop_name ?? base?.shop_name ?? '',
    shop_slug: cart.value?.shop_slug ?? base?.shop_slug ?? '',
    shop_logo_url: base?.shop_logo_url ?? null,
    shop_type: 'dropship',
    can_see_buy_price: true,
    can_see_sell_price: true,
    currency_id: cart.value?.currency?.id ?? base?.currency_id ?? null,
    currency_code: cart.value?.currency?.code ?? base?.currency_code ?? null,
    currency_symbol: currencySymbol.value || base?.currency_symbol || null,
    item_count: itemCount.value,
    cart_total: purchaseSubtotal.value,
    updated_at: cart.value?.updated_at ?? base?.updated_at ?? new Date().toISOString(),
  };
});

const updateItemQuantity = async (itemId: number, quantity: number) => {
  if (!selectedShopId.value) return;
  const item = items.value.find((row) => row.id === itemId);
  if (!item || item.quantity === quantity) return;

  await updateQtyMutation.mutateAsync({
    cartItemId: itemId,
    quantity,
    shopId: selectedShopId.value,
  });
};

const goToReview = () => {
  if (!selectedShopId.value) return;
  void router.push(
    shopDropshipReviewPath(
      route.params.tenantSlug ? String(route.params.tenantSlug) : null,
      selectedShopId.value,
    ),
  );
};
</script>

<script lang="ts">
export default {
  name: 'ShopDropshipCartPage',
};
</script>
