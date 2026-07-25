<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Standard Page Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="ph ph-arrow-left" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">Shop Cart</div>
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
            class="pill-btn"
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
                @click="selectShopCart(c.shop_id)"
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

      <!-- Loading State -->
      <div v-if="isCartsLoading || isCartLoading" class="text-center q-pa-xl">
        <q-spinner size="40px" color="primary" class="q-mb-md" />
        <div class="text-grey-7">{{ $t('shop.loading_cart') }}</div>
      </div>

      <!-- Cart List Error State -->
      <q-card v-else-if="isCartsError" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-grey-8 text-weight-bold q-mb-xs">
            Couldn't load your carts
          </div>
          <div class="text-grey-6 q-mb-md">
            Something went wrong while loading your shop carts. Please try again.
          </div>
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            label="Retry"
            @click="() => refetchActiveCarts()"
          />
        </q-card-section>
      </q-card>

      <!-- Multiple Carts Picker View -->
      <div v-else-if="showCartPicker" class="q-py-md">
        <div class="text-subtitle1 text-grey-7 q-mb-md">
          You have active items in multiple shop carts. Choose a store to view its cart and proceed to checkout:
        </div>
        <div class="row q-col-gutter-md">
          <div v-for="c in activeCarts" :key="c.cart_id" class="col-xs-12 col-sm-6 col-md-4">
            <q-card
              flat
              bordered
              class="items-card cursor-pointer border-all active-cart-card"
              @click="selectShopCart(c.shop_id)"
            >
              <q-card-section class="row items-center q-gutter-x-md">
                <q-avatar size="52px" rounded class="bg-grey-2 border-all">
                  <q-img v-if="c.shop_logo_url" :src="c.shop_logo_url" />
                  <q-icon v-else name="ph ph-storefront" color="primary" size="28px" />
                </q-avatar>
                <div class="col">
                  <div class="text-subtitle1 text-weight-bold text-grey-9">{{ c.shop_name }}</div>
                  <div class="text-caption text-grey-6">
                    {{ c.item_count }} {{ c.item_count === 1 ? 'item' : 'items' }}
                    <template v-if="c.see_price && c.cart_total !== null">
                      ·
                      <span class="text-weight-bold text-grey-9">{{ formatActiveCartTotal(c) }}</span>
                    </template>
                  </div>
                </div>
              </q-card-section>
              <q-card-actions align="right" class="bg-grey-1 q-px-md">
                <q-btn flat color="primary" no-caps label="View Cart & Checkout" icon-right="ph ph-arrow-right" />
              </q-card-actions>
            </q-card>
          </div>
        </div>
      </div>

      <!-- Empty State -->
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
            :label="$t('shop.continue_shopping')"
            class="pill-btn"
            @click="goBack"
          />
        </q-card-section>
      </q-card>

      <!-- Cart Content Grid -->
      <div v-else class="row q-col-gutter-lg">
        <!-- Cart Items List (8 cols on desktop) -->
        <div class="col-xs-12 col-md-8">
          <q-card flat bordered class="items-card">
            <q-card-section class="q-px-md q-py-sm border-bottom row items-center justify-between">
              <div class="text-subtitle2 text-weight-bold text-grey-9">
                {{ $t('shop.items') }} ({{ itemCount }})
              </div>
              <div v-if="currentShopCartInfo" class="text-caption text-grey-6">
                Store: <span class="text-weight-bold text-primary">{{ currentShopCartInfo.shop_name }}</span>
              </div>
            </q-card-section>

            <q-list separator>
              <q-item v-for="item in items" :key="item.id" class="q-py-md items-row">
                <!-- Product Image -->
                <q-item-section avatar class="item-img-section">
                  <q-avatar size="64px" rounded class="bg-grey-2 border-all">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="ph ph-image" color="grey-4" size="32px" />
                  </q-avatar>
                </q-item-section>

                <!-- Product Details -->
                <q-item-section class="item-details-section">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 item-name">
                    {{ item.name }}
                  </div>
                  <div
                    class="text-caption text-grey-6 q-mt-xs"
                    v-if="item.global_stock_allocation_id"
                  >
                    {{ $t('shop.listing_id') }}: {{ item.global_stock_allocation_id }}
                  </div>
                  <!-- Dropship Selling Price Input -->
                  <div v-if="cart?.shop_type === 'dropship'" class="q-mt-sm" style="max-width: 210px">
                    <q-input
                      :model-value="item.customer_sell_price_amount"
                      type="number"
                      :label="$t('shop.your_selling_price')"
                      outlined
                      dense
                      :prefix="currencySymbol"
                      :min="item.unit_minimum_sell_price_amount || 0"
                      :disable="!permissions?.can_set_dropship_price"
                      @change="(val: string | number | null) => updateSellingPrice(item, Number(val))"
                    >
                      <template #hint v-if="item.unit_minimum_sell_price_amount">
                        {{ $t('shop.min_price_hint', { amount: `${currencySymbol}${item.unit_minimum_sell_price_amount}` }) }}
                      </template>
                    </q-input>
                  </div>
                </q-item-section>

                <!-- Quantity Adjuster -->
                <q-item-section class="col-auto item-qty-section">
                  <div class="column items-center q-gutter-y-xs">
                    <div class="row items-center no-wrap quantity-controls">
                      <q-btn
                        flat
                        round
                        dense
                        size="sm"
                        icon="ph ph-minus"
                        color="grey-7"
                        :disabled="isSaving"
                        @click="adjustItemQtyLocal(item, -(cart?.shop_type === 'dropship' ? 1 : (item.minimum_quantity || 1)))"
                      />
                      <div class="quantity-value text-weight-bold text-center text-grey-8">
                        {{ getItemQty(item) }}
                      </div>
                      <q-btn
                        flat
                        round
                        dense
                        size="sm"
                        icon="ph ph-plus"
                        color="grey-7"
                        :disabled="isSaving"
                        @click="adjustItemQtyLocal(item, cart?.shop_type === 'dropship' ? 1 : (item.minimum_quantity || 1))"
                      />
                    </div>
                    <q-btn
                      v-if="editedQuantities[item.id] !== undefined && editedQuantities[item.id] !== item.quantity"
                      color="primary"
                      size="xs"
                      unelevated
                      no-caps
                      class="pill-btn q-px-sm"
                      :label="$t('shop.save_qty')"
                      :loading="isSaving"
                      @click="saveItemQty(item)"
                    />
                  </div>
                </q-item-section>

                <!-- Price and Subtotal -->
                <q-item-section
                  v-if="cart?.see_price_snapshot || cart?.shop_type === 'dropship'"
                  side
                  class="text-right subtotal-section item-price-section"
                >
                  <template v-if="cart?.shop_type === 'dropship'">
                    <div class="q-mb-xs">
                      <span class="text-caption text-grey-6 block" style="font-size: 10px; margin-bottom: 2px;">{{ $t('shop.your_cost') }}</span>
                      <div class="text-subtitle2 text-weight-bold text-grey-9" style="line-height: 1.2">
                        {{ formatBuyerItemTotal(item) }}
                      </div>
                      <div class="text-caption text-grey-6" style="font-size: 10px; line-height: 1">
                        {{ formatBuyerUnitPrice(item) }} {{ $t('shop.each') }}
                      </div>
                    </div>
                    <div class="q-mt-xs">
                      <span class="text-caption text-grey-6 block" style="font-size: 10px; margin-bottom: 2px;">{{ $t('shop.recipient_pay') }}</span>
                      <div class="text-subtitle2 text-weight-bold text-primary" style="line-height: 1.2">
                        {{ formatItemTotal(item) }}
                      </div>
                      <div class="text-caption text-grey-6" style="font-size: 10px; line-height: 1">
                        {{ formatUnitPrice(item) }} {{ $t('shop.each') }}
                      </div>
                    </div>
                  </template>
                  <template v-else>
                    <div class="text-subtitle2 text-weight-bold text-grey-9">
                      {{ formatItemTotal(item) }}
                    </div>
                    <div class="text-caption text-grey-6">
                      {{ formatUnitPrice(item) }} {{ $t('shop.each') }}
                    </div>
                  </template>
                </q-item-section>

                <!-- Delete Action -->
                <q-item-section side class="item-delete-section">
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-trash"
                    color="negative"
                    :disabled="isSaving"
                    @click="removeItem(item)"
                  >
                    <q-tooltip>{{ $t('shop.remove_item') }}</q-tooltip>
                  </q-btn>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>
        </div>

        <!-- Checkout Summary (4 cols on desktop) -->
        <div class="col-xs-12 col-md-4">
          <q-card flat bordered class="summary-card sticky-card">
            <q-card-section class="q-px-md q-py-sm border-bottom">
              <div class="text-subtitle2 text-weight-bold text-grey-9">
                {{ $t('shop.order_summary') }}
              </div>
            </q-card-section>

            <q-card-section class="q-py-md">
              <template v-if="cart?.see_price_snapshot || cart?.shop_type === 'dropship'">
                <template v-if="cart?.shop_type === 'dropship'">
                  <!-- Recipient Subtotal -->
                  <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                    <span>{{ $t('shop.items_subtotal') }}</span>
                    <span class="text-weight-medium text-grey-9">
                      {{ formatCartTotal() }}
                    </span>
                  </div>
                  
                  <!-- Charges Section -->
                  <div class="column q-mt-sm q-mb-sm bg-grey-1 q-pa-sm rounded-borders" style="border: 1px solid rgba(0,0,0,0.05); border-radius: 8px;">
                    <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">
                      {{ $t('shop.dropship_charges') }}
                    </div>
                    
                    <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                      <span>{{ $t('shop.delivery_charge') }}</span>
                      <span>{{ formatAmount(0) }}</span>
                    </div>
                    
                    <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                      <span>{{ $t('shop.cod_fee') }}</span>
                      <span>{{ formatAmount(0) }}</span>
                    </div>
                    
                    <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                      <span>
                        {{ $t('shop.print_charge') }}
                        <span class="text-grey-5">({{ deductPrintFromMargin ? 'deducted' : 'customer pays' }})</span>
                      </span>
                      <span>{{ formatAmount(printCharge) }}</span>
                    </div>
                    
                    <div class="row justify-between text-caption text-grey-7">
                      <span>
                        {{ $t('shop.packing_charge') }}
                        <span class="text-grey-5">({{ deductPackingFromMargin ? 'deducted' : 'customer pays' }})</span>
                      </span>
                      <span>{{ formatAmount(packingCharge) }}</span>
                    </div>

                    <div class="delivery-notice-banner q-pa-sm q-mt-sm rounded-borders bg-amber-1 border-amber text-grey-10 shadow-1 flex flex-column gap-xs">
                      <div class="flex items-center text-weight-bold text-caption text-amber-10">
                        <q-icon name="ph ph-truck text-weight-bold" size="16px" class="q-mr-xs text-amber-9" />
                        <span>Courier &amp; Delivery Notice</span>
                      </div>
                      <div class="text-caption text-grey-9">
                        {{ $t('shop.courier_charges_may_vary') }}
                      </div>
                      <div class="column gap-xs q-mt-xs text-caption">
                        <div class="flex items-center justify-between bg-white q-pa-xs rounded-borders">
                          <span class="text-grey-8">Estimated delivery:</span>
                          <strong class="text-primary text-weight-bold">{{ $t('shop.courier_delivery_estimate', { min: formatAmount(courierEstimate.deliveryMin), max: formatAmount(courierEstimate.deliveryMax) }) }}</strong>
                        </div>
                        <div v-if="codEstimateSummary" class="flex items-center justify-between bg-white q-pa-xs rounded-borders">
                          <span class="text-grey-8">Estimated COD fee:</span>
                          <strong class="text-indigo-9 text-weight-bold">{{ $t('shop.courier_cod_estimate', { summary: codEstimateSummary }) }}</strong>
                        </div>
                      </div>
                    </div>
                  </div>

                   <!-- Buyer Cost -->
                   <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                     <span>{{ $t('shop.your_cost_buyer') }}</span>
                     <span class="text-weight-medium text-grey-9">
                       {{ formatAmount(buyerTotal) }}
                     </span>
                   </div>
                   
                   <!-- Profit -->
                   <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                     <span>{{ $t('shop.estimated_profit') }}</span>
                     <span class="text-weight-medium text-positive text-weight-bold">
                       {{ formatAmount(estimatedProfit) }}
                     </span>
                   </div>
                 </template>
                 <template v-else>
                   <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                     <span
                       >{{ $t('shop.subtotal') }} ({{ itemCount }}
                       {{ $t('shop.items').toLowerCase() }})</span
                     >
                     <span class="text-weight-medium">
                       {{ formatCartTotal() }}
                     </span>
                   </div>
                 </template>

                 <q-separator class="q-my-md" />

                 <div class="row justify-between items-baseline q-mb-lg">
                   <span class="text-subtitle1 text-weight-bold text-grey-9">{{
                     cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
                   }}</span>
                   <span class="text-h6 text-weight-bold text-primary">
                     {{ cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
                   </span>
                 </div>
              </template>

              <q-btn
                color="primary"
                unelevated
                no-caps
                class="pill-btn full-width"
                label="Proceed to Checkout"
                :loading="isSaving || placingOrder"
                @click="handleButtonClick"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useActiveShopCartsQuery } from '../composables/useActiveShopCartsQuery';
import { useShopCartQuery } from '../composables/useShopCartQuery';
import { useShopCartMutations } from '../composables/useShopCartMutations';
import type { ActiveCartItem } from '../repositories/shopCartRepository';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { fetchCourierChargeEstimate } from '../services/courierChargeEstimate';
import { useQueryClient } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();
const authStore = useAuthStore();
const orderStore = useShopOrderStore();

const {
  data: activeCartsData,
  isLoading: isCartsLoading,
  isError: isCartsError,
  refetch: refetchActiveCarts,
} = useActiveShopCartsQuery();
const activeCarts = computed(() => activeCartsData.value ?? []);

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);

const selectedShopId = ref<number | null>(null);

watch(
  [() => route.query.shopId, activeCarts, isCartsLoading],
  ([qShopId, carts, loading]) => {
    if (qShopId) {
      selectedShopId.value = Number(qShopId);
    } else if (loading) {
      // Wait for active carts list before deciding — do not bind last_visited_shop_id.
      selectedShopId.value = null;
    } else if (carts.length > 0) {
      selectedShopId.value = null;
    } else {
      // List settled and empty → empty state (no last-visited auto-load).
      selectedShopId.value = null;
    }
  },
  { immediate: true },
);

const showCartPicker = computed(() => {
  return !route.query.shopId && activeCarts.value.length > 0 && !selectedShopId.value;
});

const currentShopCartInfo = computed(() => {
  return activeCarts.value.find((c) => c.shop_id === selectedShopId.value) ?? null;
});

const selectShopCart = (sId: number) => {
  selectedShopId.value = sId;
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.replace({
    path: `${tenantSlug}/shop/cart`,
    query: { shopId: sId },
  });
};

const {
  cart,
  items,
  itemCount,
  cartTotal,
  buyerCartTotal,
  recipientGrandTotal,
  estimatedProfit,
  permissions,
  isLoading: isCartLoading,
} = useShopCartQuery(selectedShopId);

const { updateQtyMutation, removeItemMutation, updatePriceMutation } = useShopCartMutations();

const isSaving = computed(
  () =>
    updateQtyMutation.isPending.value ||
    removeItemMutation.isPending.value ||
    updatePriceMutation.isPending.value,
);

const placingOrder = ref(false);

const storefrontStore = useShopStorefrontStore();

const currencySymbol = computed(() => {
  if (currentShopCartInfo.value?.currency_symbol) {
    return currentShopCartInfo.value.currency_symbol;
  }
  const shop = storefrontStore.shopDetails;
  if (shop?.sell_currency_id) {
    const curr = currencies.value.find((c) => c.id === shop.sell_currency_id);
    if (curr?.symbol) return curr.symbol;
  }
  return '£';
});

const formatActiveCartTotal = (activeCart: ActiveCartItem) => {
  const currency = activeCart.currency_symbol || activeCart.currency_code || '';
  return `${currency}${Number(activeCart.cart_total).toFixed(2)}`;
};

const goBack = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';

  // From a selected shop cart → cart list / picker
  if (route.query.shopId || selectedShopId.value) {
    selectedShopId.value = null;
    void router.replace({ path: `${tenantSlug}/shop/cart`, query: {} });
    return;
  }

  // From cart list → storefront
  const lastSlug = localStorage.getItem('last_visited_shop_slug');
  if (lastSlug) {
    void router.push(`${tenantSlug}/shop/browse/${lastSlug}`);
  } else {
    void router.push(`${tenantSlug}/shop/browse`);
  }
};

const goToCheckout = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push({
    path: `${tenantSlug}/shop/checkout`,
    query: { shopId: selectedShopId.value },
  });
};

const handleButtonClick = async () => {
  if (cart.value?.shop_type === 'vendor_catalog') {
    placingOrder.value = true;
    try {
      const res = await orderStore.submitOrder(
        cart.value.id,
        '', // recipientName
        '', // recipientPhone
        '', // shippingAddress
        null, // billingProfileId
      );
      if (res.success) {
        if (selectedShopId.value) {
          void queryClient.invalidateQueries({
            queryKey: shopOrderQueryKeys.cart(authStore.tenantId ?? 0, selectedShopId.value),
          });
        }
        void queryClient.invalidateQueries({
          queryKey: shopOrderQueryKeys.activeCarts(authStore.tenantId ?? 0),
        });
        const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
        void router.push(`${tenantSlug}/shop/orders`);
      }
    } finally {
      placingOrder.value = false;
    }
  } else {
    goToCheckout();
  }
};

const editedQuantities = ref<Record<number, number>>({});

const getItemQty = (item: any) => {
  return editedQuantities.value[item.id] !== undefined
    ? editedQuantities.value[item.id]
    : item.quantity;
};

const adjustItemQtyLocal = (item: any, delta: number) => {
  const currentVal = getItemQty(item);
  let newVal = currentVal + delta;
  if (newVal < 1) newVal = 1;

  if (newVal === item.quantity) {
    delete editedQuantities.value[item.id];
  } else {
    editedQuantities.value[item.id] = newVal;
  }
};

const saveItemQty = async (item: any) => {
  const targetQty = editedQuantities.value[item.id];
  if (targetQty === undefined || !selectedShopId.value) return;
  await updateQtyMutation.mutateAsync({
    cartItemId: item.id,
    quantity: targetQty,
    shopId: selectedShopId.value,
  });
  delete editedQuantities.value[item.id];
};

const removeItem = async (item: any) => {
  if (!selectedShopId.value) return;
  delete editedQuantities.value[item.id];
  await removeItemMutation.mutateAsync({
    cartItemId: item.id,
    shopId: selectedShopId.value,
  });
};

const updateSellingPrice = async (item: any, newPrice: number) => {
  if (isNaN(newPrice) || newPrice < 0 || !selectedShopId.value) return;
  await updatePriceMutation.mutateAsync({
    cartItemId: item.id,
    price: newPrice,
    shopId: selectedShopId.value,
  });
};

// Formatting helpers
const formatUnitPrice = (item: any) => {
  const price =
    item.customer_sell_price_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0;
  return `${currencySymbol.value}${Number(price).toFixed(2)}`;
};

const formatItemTotal = (item: any) => {
  const price =
    item.customer_sell_price_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0;
  const total = price * item.quantity;
  return `${currencySymbol.value}${total.toFixed(2)}`;
};

const formatBuyerUnitPrice = (item: any) => {
  const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
  return `${currencySymbol.value}${Number(price).toFixed(2)}`;
};

const formatBuyerItemTotal = (item: any) => {
  const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
  const total = price * item.quantity;
  return `${currencySymbol.value}${total.toFixed(2)}`;
};

const defaultPrintCharge = computed(() => Number(cart.value?.default_print_charge_amount || 0));
const defaultPackingCharge = computed(() => Number(cart.value?.default_packing_charge_amount || 0));

const printCharge = computed(() => (cart.value?.shop_type === 'dropship' ? defaultPrintCharge.value : 0));
const packingCharge = computed(() => (cart.value?.shop_type === 'dropship' ? defaultPackingCharge.value : 0));

const deductPrintFromMargin = computed(() => !!cart.value?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!cart.value?.deduct_packing_from_margin);

const buyerTotal = computed(() => {
  return buyerCartTotal.value
    + printCharge.value
    + packingCharge.value;
});

const courierEstimate = ref({
  deliveryMin: 60,
  deliveryMax: 130,
  codPercentMin: 1 as number | null,
  codPercentMax: 1 as number | null,
  codFlatMin: null as number | null,
  codFlatMax: null as number | null,
});

const codEstimateSummary = computed(() => {
  const e = courierEstimate.value;
  const parts: string[] = [];
  if (e.codPercentMin != null && e.codPercentMax != null) {
    parts.push(
      e.codPercentMin === e.codPercentMax
        ? `~${e.codPercentMin}%`
        : `~${e.codPercentMin}–${e.codPercentMax}%`
    );
  }
  if (e.codFlatMin != null && e.codFlatMax != null) {
    parts.push(
      e.codFlatMin === e.codFlatMax
        ? formatAmount(e.codFlatMin)
        : `${formatAmount(e.codFlatMin)}–${formatAmount(e.codFlatMax)}`
    );
  }
  return parts.join(' / ') || '~1%';
});

const formatAmount = (val: any) => {
  const num = typeof val === 'number' ? val : (val?.value ?? 0);
  return `${currencySymbol.value}${num.toFixed(2)}`;
};

const formatCartTotal = () => {
  return `${currencySymbol.value}${cartTotal.value.toFixed(2)}`;
};

watch(
  () => cart.value?.shop_type,
  async (type) => {
    if (type === 'dropship') {
      courierEstimate.value = await fetchCourierChargeEstimate();
    }
  },
);
</script>

<script lang="ts">
export default {
  name: 'ShopCartPage',
};
</script>

<style scoped>
.items-card,
.summary-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.active-cart-card {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.active-cart-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(34, 56, 101, 0.08);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.border-all {
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.items-row {
  transition: background-color 0.2s ease;
}

.items-row:hover {
  background-color: #fafbfd;
}

.item-name {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

.quantity-controls {
  background: rgba(34, 56, 101, 0.03);
  border-radius: 20px;
  padding: 2px 6px;
}

.quantity-value {
  min-width: 32px;
  font-size: 14px;
}

.subtotal-section {
  min-width: 110px;
}

.sticky-card {
  position: sticky;
  top: 24px;
}

.text-success {
  color: #21ba45;
}

.italic {
  font-style: italic;
}

/* Mobile Responsiveness styling */
@media (max-width: 599px) {
  .bw-page,
  :deep(.bw-page) {
    padding: 4px !important;
  }

  .items-card,
  .summary-card {
    border-radius: 8px;
  }

  .items-row {
    display: grid !important;
    grid-template-columns: 64px 1fr;
    grid-template-areas:
      'img details'
      'qty price';
    gap: 12px;
    padding: 12px 8px !important;
    position: relative;
  }

  .item-img-section {
    grid-area: img;
  }

  .item-details-section {
    grid-area: details;
    padding-right: 36px; /* leave room for absolute delete button */
  }

  .item-qty-section {
    grid-area: qty;
    justify-self: start;
    min-width: unset;
  }

  .item-price-section {
    grid-area: price;
    justify-self: end;
    min-width: unset;
    text-align: right;
  }

  .item-delete-section {
    position: absolute;
    top: 8px;
    right: 4px;
    margin: 0;
  }
}
</style>
