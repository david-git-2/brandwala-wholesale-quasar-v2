<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Compact Header Design -->
      <q-card flat class="q-mb-sm floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm">
              <div class="row items-center q-gutter-x-sm no-wrap">
                <q-btn flat round dense icon="arrow_back" color="grey-7" @click="goBack" />
                <div>
                  <div class="text-subtitle1 text-weight-bold text-grey-9">
                    {{ $t('shop.cart_title') }}
                  </div>
                  <div class="text-caption text-grey-7">
                    {{ $t('shop.cart_subtitle') }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Loading State -->
      <div v-if="cartStore.loading" class="text-center q-pa-xl">
        <q-spinner size="40px" color="primary" class="q-mb-md" />
        <div class="text-grey-7">{{ $t('shop.loading_cart') }}</div>
      </div>

      <!-- Empty State -->
      <q-card v-else-if="cartStore.items.length === 0" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="shopping_cart" size="64px" color="grey-4" class="q-mb-md" />
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
            <q-card-section class="q-px-md q-py-sm border-bottom">
              <div class="text-subtitle2 text-weight-bold text-grey-9">
                {{ $t('shop.items') }} ({{ cartStore.itemCount }})
              </div>
            </q-card-section>

            <q-list separator>
              <q-item v-for="item in cartStore.items" :key="item.id" class="q-py-md items-row">
                <!-- Product Image -->
                <q-item-section avatar class="item-img-section">
                  <q-avatar size="64px" rounded class="bg-grey-2 border-all">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="image" color="grey-4" size="32px" />
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
                  <div v-if="cartStore.cart?.shop_type === 'dropship'" class="q-mt-sm" style="max-width: 210px">
                    <q-input
                      :model-value="item.customer_sell_price_amount"
                      type="number"
                      :label="$t('shop.your_selling_price')"
                      outlined
                      dense
                      :prefix="currencySymbol"
                      :min="item.unit_minimum_sell_price_amount || 0"
                      :disable="!storefrontStore.permissions?.can_set_dropship_price"
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
                        icon="remove"
                        color="grey-7"
                        :disabled="cartStore.saving"
                        @click="adjustItemQtyLocal(item, -(cartStore.cart?.shop_type === 'dropship' ? 1 : (item.minimum_quantity || 1)))"
                      />
                      <div class="quantity-value text-weight-bold text-center text-grey-8">
                        {{ getItemQty(item) }}
                      </div>
                      <q-btn
                        flat
                        round
                        dense
                        size="sm"
                        icon="add"
                        color="grey-7"
                        :disabled="cartStore.saving"
                        @click="adjustItemQtyLocal(item, cartStore.cart?.shop_type === 'dropship' ? 1 : (item.minimum_quantity || 1))"
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
                      :loading="cartStore.saving"
                      @click="saveItemQty(item)"
                    />
                  </div>
                </q-item-section>

                <!-- Price and Subtotal -->
                <q-item-section
                  v-if="cartStore.cart?.see_price_snapshot || cartStore.cart?.shop_type === 'dropship'"
                  side
                  class="text-right subtotal-section item-price-section"
                >
                  <template v-if="cartStore.cart?.shop_type === 'dropship'">
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
                    icon="delete_outline"
                    color="negative"
                    :disabled="cartStore.saving"
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
              <template v-if="cartStore.cart?.see_price_snapshot || cartStore.cart?.shop_type === 'dropship'">
                <template v-if="cartStore.cart?.shop_type === 'dropship'">
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
                      <span>
                        {{ $t('shop.delivery_charge') }}
                        <span class="text-grey-5">({{ deductDeliveryFromMargin ? 'deducted' : 'customer pays' }})</span>
                      </span>
                      <span>{{ formatAmount(deliveryCharge) }}</span>
                    </div>
                    
                    <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                      <span>
                        {{ $t('shop.cod_fee', { pct: defaultCodChargePct }) }}
                        <span class="text-grey-5">({{ deductCodFromMargin ? 'deducted' : 'customer pays' }})</span>
                      </span>
                      <span>{{ formatAmount(codCharge) }}</span>
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
                       >{{ $t('shop.subtotal') }} ({{ cartStore.itemCount }}
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
                     cartStore.cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
                   }}</span>
                   <span class="text-h6 text-weight-bold text-primary">
                     {{ cartStore.cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
                   </span>
                 </div>
              </template>

              <q-btn
                color="primary"
                unelevated
                no-caps
                :label="
                  cartStore.cart?.shop_type === 'vendor_catalog'
                    ? $t('shop.place_order')
                    : $t('shop.proceed_to_checkout')
                "
                class="full-width pill-btn text-weight-bold q-py-sm"
                :loading="cartStore.saving || placingOrder"
                @click="handleButtonClick"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopCartStore } from '../stores/shopCartStore';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';

const route = useRoute();
const router = useRouter();
const cartStore = useShopCartStore();
const storefrontStore = useShopStorefrontStore();
const orderStore = useShopOrderStore();
const currencyStore = useThriftCurrencyStore();

const placingOrder = ref(false);

const shopId = computed(() => {
  const qShopId = route.query.shopId ? Number(route.query.shopId) : null;
  if (qShopId) return qShopId;

  if (storefrontStore.shopDetails?.id) {
    return storefrontStore.shopDetails.id;
  }

  const storedId = localStorage.getItem('last_visited_shop_id');
  return storedId ? Number(storedId) : null;
});

const currencySymbol = computed(() => {
  const shop = storefrontStore.shopDetails;
  if (shop?.sell_currency_id) {
    const curr = currencyStore.currencyById(shop.sell_currency_id);
    if (curr?.symbol) return curr.symbol;
  }
  return '£';
});

const goBack = () => {
  const lastSlug = localStorage.getItem('last_visited_shop_slug');
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
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
    query: { shopId: shopId.value },
  });
};

const handleButtonClick = async () => {
  if (cartStore.cart?.shop_type === 'vendor_catalog') {
    placingOrder.value = true;
    try {
      const res = await orderStore.submitOrder(
        cartStore.cart.id,
        '', // recipientName
        '', // recipientPhone
        '', // shippingAddress
        null, // billingProfileId
      );
      if (res.success) {
        cartStore.clearCart();
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
  if (targetQty === undefined) return;
  await cartStore.updateQty(item.id, targetQty);
  delete editedQuantities.value[item.id];
};

const removeItem = async (item: any) => {
  delete editedQuantities.value[item.id];
  await cartStore.removeItem(item.id);
};

const updateSellingPrice = async (item: any, newPrice: number) => {
  if (isNaN(newPrice) || newPrice < 0) return;
  await cartStore.updatePrice(item.id, newPrice);
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

const defaultCodChargePct = computed(() => Number(cartStore.cart?.default_cod_charge_pct || 0));
const defaultDeliveryCharge = computed(() => Number(cartStore.cart?.default_delivery_charge_amount || 0));
const defaultPrintCharge = computed(() => Number(cartStore.cart?.default_print_charge_amount || 0));
const defaultPackingCharge = computed(() => Number(cartStore.cart?.default_packing_charge_amount || 0));

const deliveryCharge = computed(() => (cartStore.cart?.shop_type === 'dropship' ? defaultDeliveryCharge.value : 0));
const printCharge = computed(() => (cartStore.cart?.shop_type === 'dropship' ? defaultPrintCharge.value : 0));
const packingCharge = computed(() => (cartStore.cart?.shop_type === 'dropship' ? defaultPackingCharge.value : 0));
const codCharge = computed(() => {
  if (cartStore.cart?.shop_type !== 'dropship') return 0;
  return (cartStore.cartTotal * defaultCodChargePct.value) / 100;
});
const totalCharges = computed(() => {
  return deliveryCharge.value + printCharge.value + packingCharge.value + codCharge.value;
});

const deductCodFromMargin = computed(() => !!cartStore.cart?.deduct_cod_from_margin);
const deductDeliveryFromMargin = computed(() => !!cartStore.cart?.deduct_delivery_from_margin);
const deductPrintFromMargin = computed(() => !!cartStore.cart?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!cartStore.cart?.deduct_packing_from_margin);

const recipientGrandTotal = computed(() => {
  return cartStore.cartTotal
    + (deductDeliveryFromMargin.value ? 0 : deliveryCharge.value)
    + (deductPrintFromMargin.value ? 0 : printCharge.value)
    + (deductPackingFromMargin.value ? 0 : packingCharge.value)
    + (deductCodFromMargin.value ? 0 : codCharge.value);
});

const buyerTotal = computed(() => {
  return cartStore.buyerCartTotal
    + deliveryCharge.value
    + printCharge.value
    + packingCharge.value
    + (deductCodFromMargin.value ? codCharge.value : 0);
});

const estimatedProfit = computed(() => {
  return recipientGrandTotal.value - buyerTotal.value;
});

const formatAmount = (val: number | any) => {
  const num = typeof val === 'number' ? val : (val?.value ?? 0);
  return `${currencySymbol.value}${num.toFixed(2)}`;
};

const formatCartTotal = () => {
  return `${currencySymbol.value}${cartStore.cartTotal.toFixed(2)}`;
};

onMounted(async () => {
  editedQuantities.value = {};
  await currencyStore.loadCurrencies();
  if (shopId.value) {
    await cartStore.fetchCart(shopId.value);
    if (!storefrontStore.permissions || !storefrontStore.shopDetails) {
      const lastSlug = localStorage.getItem('last_visited_shop_slug');
      if (lastSlug) {
        await storefrontStore.fetchCatalog(lastSlug, { limit: 1, offset: 0 });
      }
    }
  }
});
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
