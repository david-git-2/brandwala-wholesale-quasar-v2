<template>
  <q-page class="q-pa-md shop-commerce-page">
    <div class="q-gutter-y-md">
      <ShopCartHeader
        :show-cart-picker="showCartPicker"
        :item-count="displayItemCount"
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
            :quantity="getItemQty(item)"
            :price="getPurchaseUnitAmount(item)"
            :currency-symbol="currencySymbol"
            :min-qty="item.minimum_quantity"
            :disable-qty="isUpdatingQty"
            :show-save-qty="hasUnsavedQty(item)"
            :is-saving="isUpdatingQty"
            @update:quantity="(qty) => adjustItemQtyLocal(item.id, qty, item.quantity)"
            @save-quantity="() => saveItemQty(item.id)"
          />
        </div>

        <q-btn
          color="primary"
          unelevated
          no-caps
          class="full-width pill-btn q-py-sm"
          icon-right="ph ph-arrow-right"
          :label="$t('shop.dropship_cart_proceed')"
          :disable="isUpdatingQty || hasUnsavedEdits"
          @click="goToReview"
        >
          <q-tooltip v-if="hasUnsavedEdits">
            {{ $t('shop.cart_save_edits_first') }}
          </q-tooltip>
        </q-btn>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import type { ActiveCartItem } from '../repositories/shopCartRepository';
import type { DropshipCartItem } from '../repositories/dropshipCartRepository';
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
  currencySymbol,
  getPurchaseUnitAmount,
  isLoading: isCartLoading,
  isError: isCartError,
  refetch: refetchCart,
} = useDropshipShopCartQuery(selectedShopId);

const { updateQtyMutation } = useShopCartMutations();
const isUpdatingQty = computed(() => updateQtyMutation.isPending.value);
const editedQuantities = ref<Record<number, number>>({});

const getItemQty = (item: DropshipCartItem) =>
  editedQuantities.value[item.id] !== undefined
    ? editedQuantities.value[item.id]
    : item.quantity;

const hasUnsavedQty = (item: DropshipCartItem) =>
  editedQuantities.value[item.id] !== undefined &&
  editedQuantities.value[item.id] !== item.quantity;

const hasUnsavedEdits = computed(() =>
  items.value.some((item) => hasUnsavedQty(item)),
);

const displayItemCount = computed(() =>
  items.value.reduce((sum, item) => sum + getItemQty(item), 0),
);

const displayPurchaseSubtotal = computed(() =>
  items.value.reduce(
    (sum, item) => sum + getPurchaseUnitAmount(item) * getItemQty(item),
    0,
  ),
);

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
    item_count: displayItemCount.value,
    cart_total: displayPurchaseSubtotal.value,
    updated_at: cart.value?.updated_at ?? base?.updated_at ?? new Date().toISOString(),
  };
});

const adjustItemQtyLocal = (itemId: number, quantity: number, savedQuantity: number) => {
  if (quantity === savedQuantity) {
    delete editedQuantities.value[itemId];
    return;
  }
  editedQuantities.value[itemId] = quantity;
};

const saveItemQty = async (itemId: number) => {
  const targetQty = editedQuantities.value[itemId];
  if (targetQty === undefined || !selectedShopId.value) return;

  await updateQtyMutation.mutateAsync({
    cartItemId: itemId,
    quantity: targetQty,
    shopId: selectedShopId.value,
  });
  delete editedQuantities.value[itemId];
};

const goToReview = () => {
  if (!selectedShopId.value || hasUnsavedEdits.value) return;
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
