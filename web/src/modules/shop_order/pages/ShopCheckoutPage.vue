<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">
                {{ $t('shop.title') }} &amp; {{ $t('navigation.orders') }}
              </div>
              <h1 class="text-h5 q-my-none">{{ $t('shop.checkout') }}</h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                {{ $t('shop.checkout_subtitle') }}
              </p>
            </div>
          </div>
        </div>
      </section>

      <div class="row q-col-gutter-lg">
        <!-- Delivery and Billing details (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <div class="column q-gutter-md">
            <!-- Shipping Information -->
            <q-card
              v-if="shopType === 'dropship' || (shopType === 'fixed_price' && allowDelivery)"
              flat
              bordered
              class="form-card"
            >
              <q-card-section
                class="q-px-md q-py-sm border-bottom row items-center justify-between"
              >
                <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                  <q-icon name="local_shipping" size="18px" class="q-mr-xs text-primary" />
                  {{ $t('shop.shipping_info') }}
                </div>
                <!-- Toggle checkbox only for fixed_price -->
                <q-checkbox
                  v-if="shopType === 'fixed_price'"
                  v-model="requestDelivery"
                  :label="$t('shop.request_delivery')"
                  dense
                />
              </q-card-section>

              <q-card-section v-if="requestDelivery" class="q-gutter-md">
                <div class="row q-col-gutter-md">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model="recipientName"
                      outlined
                      dense
                      :label="$t('shop.recipient_name') + ' *'"
                    />
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model="recipientPhone"
                      outlined
                      dense
                      :label="$t('shop.recipient_phone') + ' *'"
                    />
                  </div>
                </div>
                <q-input
                  v-model="shippingAddress"
                  outlined
                  dense
                  type="textarea"
                  :label="$t('shop.shipping_address') + ' *'"
                  rows="3"
                />

                <!-- Payment Mode and Delivery Instructions for Dropship -->
                <template v-if="shopType === 'dropship'">
                  <q-separator class="q-my-md" />
                  
                  <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">
                    {{ $t('shop.payment_mode') }}
                  </div>
                  <div class="q-gutter-sm q-mb-md">
                    <q-radio
                      v-model="isPrepaid"
                      :val="false"
                      :label="$t('shop.payment_mode_cod')"
                      color="primary"
                    />
                    <q-radio
                      v-model="isPrepaid"
                      :val="true"
                      :label="$t('shop.payment_mode_prepaid')"
                      color="primary"
                    />
                  </div>

                  <q-input
                    v-model="deliveryInstructions"
                    outlined
                    dense
                    type="textarea"
                    :label="$t('shop.delivery_instructions')"
                    rows="2"
                    class="q-mt-md"
                  />
                </template>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Checkout Summary (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <q-card flat bordered class="summary-card sticky-card">
            <q-card-section class="q-px-md q-py-sm border-bottom">
              <div class="text-subtitle2 text-weight-bold text-grey-9">
                {{ $t('shop.items_summary') }}
              </div>
            </q-card-section>

            <q-list class="item-list-compact" separator>
              <q-item v-for="item in cartStore.items" :key="item.id" class="q-py-sm">
                <q-item-section avatar>
                  <q-avatar size="36px" rounded class="bg-grey-2">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="image" size="18px" color="grey-4" />
                  </q-avatar>
                </q-item-section>
                <q-item-section>
                  <div class="text-caption text-weight-bold text-grey-9 item-name">
                    {{ item.name }}
                  </div>
                  <div class="text-caption text-grey-6">
                    {{ $t('shop.qty') }}: {{ item.quantity }}
                  </div>
                </q-item-section>
                <q-item-section side v-if="cartStore.cart?.see_price_snapshot || cartStore.cart?.shop_type === 'dropship'">
                  <template v-if="cartStore.cart?.shop_type === 'dropship'">
                    <div class="text-caption text-grey-6 text-right" style="font-size: 10px;">
                      {{ $t('shop.cost_label') }} {{ formatBuyerItemTotal(item) }}
                    </div>
                    <div class="text-caption text-weight-bold text-primary text-right">
                      {{ $t('shop.pay_label') }} {{ formatItemTotal(item) }}
                    </div>
                  </template>
                  <template v-else>
                    <div class="text-caption text-weight-bold text-grey-9">
                      {{ formatItemTotal(item) }}
                    </div>
                  </template>
                </q-item-section>
              </q-item>
            </q-list>

            <q-separator />

            <q-card-section class="q-py-md">
              <template v-if="cartStore.cart?.shop_type === 'dropship'">
                <!-- Items Subtotal -->
                <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                  <span>{{ $t('shop.items_subtotal') }}</span>
                  <span class="text-weight-medium text-grey-9">
                    {{ formatAmount(cartStore.cartTotal) }}
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
                  
                  <div v-if="!isPrepaid" class="row justify-between text-caption text-grey-7 q-mb-xs">
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
                    {{ formatAmount(cartStore.buyerCartTotal + deliveryCharge + printCharge + packingCharge) }}
                  </span>
                </div>

                <!-- Profit -->
                <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                  <span>{{ $t('shop.estimated_profit') }}</span>
                  <span class="text-weight-bold text-positive">
                    {{ formatAmount(estimatedProfit) }}
                  </span>
                </div>
                
                <q-separator class="q-my-sm" />
              </template>

              <div class="row justify-between items-baseline q-mb-lg">
                <span class="text-subtitle1 text-weight-bold text-grey-9">{{
                  cartStore.cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
                }}</span>
                <span
                  v-if="cartStore.cart?.see_price_snapshot || cartStore.cart?.shop_type === 'dropship'"
                  class="text-h6 text-weight-bold text-primary"
                >
                  {{ cartStore.cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
                </span>
                <span v-else class="text-subtitle1 text-grey-5 italic">
                  {{ $t('shop.prices_hidden') }}
                </span>
              </div>

              <!-- PLACE ORDER -->
              <q-btn
                color="primary"
                unelevated
                no-caps
                :label="$t('shop.place_order')"
                class="full-width pill-btn text-weight-bold q-py-sm"
                :loading="orderStore.saving"
                :disabled="
                  requestDelivery &&
                  (!recipientName.trim() || !recipientPhone.trim() || !shippingAddress.trim())
                "
                @click="submitOrder"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useShopCartStore } from '../stores/shopCartStore';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';

import { showErrorNotification } from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const cartStore = useShopCartStore();
const orderStore = useShopOrderStore();
const storefrontStore = useShopStorefrontStore();
const currencyStore = useThriftCurrencyStore();

const recipientName = ref('');
const recipientPhone = ref('');
const shippingAddress = ref('');
const requestDelivery = ref(false);

const isPrepaid = ref(false);
const deliveryInstructions = ref('');

const shopType = computed(() => cartStore.cart?.shop_type);
const allowDelivery = computed(() => cartStore.cart?.allow_delivery);

const shopId = computed(() => {
  return route.query.shopId ? Number(route.query.shopId) : null;
});

// Retrieve default charge parameters from cartStore.cart
const defaultCodChargePct = computed(() => Number(cartStore.cart?.default_cod_charge_pct || 0));
const defaultDeliveryCharge = computed(() => Number(cartStore.cart?.default_delivery_charge_amount || 0));
const defaultPrintCharge = computed(() => Number(cartStore.cart?.default_print_charge_amount || 0));
const defaultPackingCharge = computed(() => Number(cartStore.cart?.default_packing_charge_amount || 0));

// Computed charges
const deliveryCharge = computed(() => (shopType.value === 'dropship' ? defaultDeliveryCharge.value : 0));
const printCharge = computed(() => (shopType.value === 'dropship' ? defaultPrintCharge.value : 0));
const packingCharge = computed(() => (shopType.value === 'dropship' ? defaultPackingCharge.value : 0));

const codCharge = computed(() => {
  if (shopType.value !== 'dropship' || isPrepaid.value) return 0;
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

const estimatedProfit = computed(() => {
  const buyerCost = cartStore.buyerCartTotal
    + deliveryCharge.value
    + printCharge.value
    + packingCharge.value
    + (deductCodFromMargin.value ? codCharge.value : 0);
  return recipientGrandTotal.value - buyerCost;
});

const currencySymbol = computed(() => {
  const shop = storefrontStore.shopDetails;
  if (shop?.sell_currency_id) {
    const curr = currencyStore.currencyById(shop.sell_currency_id);
    if (curr?.symbol) return curr.symbol;
  }
  return '£';
});

// Watch for cart changes to initialize requestDelivery
watch(
  () => cartStore.cart,
  (cart) => {
    if (cart) {
      if (cart.shop_type === 'dropship') {
        requestDelivery.value = true;
      } else {
        requestDelivery.value = false;
      }
    }
  },
  { immediate: true },
);

onMounted(async () => {
  await currencyStore.loadCurrencies();
  if (!cartStore.cart && shopId.value) {
    await cartStore.fetchCart(shopId.value);
  }
  if (!storefrontStore.shopDetails) {
    const lastSlug = localStorage.getItem('last_visited_shop_slug');
    if (lastSlug) {
      await storefrontStore.fetchCatalog(lastSlug, { limit: 1, offset: 0 });
    }
  }
});

const goBack = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/cart`);
};

const submitOrder = async () => {
  if (!cartStore.cart?.id) return;

  if (shopType.value === 'dropship') {
    for (const item of cartStore.items) {
      const minPrice = item.unit_minimum_sell_price_amount || 0;
      const sellPrice = item.customer_sell_price_amount ?? 0;
      if (sellPrice < minPrice) {
        showErrorNotification(
          t('shop.price_below_min', {
            name: item.name,
            amount: `${currencySymbol.value}${minPrice.toFixed(2)}`,
          }),
        );
        return;
      }
    }
  }

  const name = requestDelivery.value ? recipientName.value.trim() : '';
  const phone = requestDelivery.value ? recipientPhone.value.trim() : '';
  const address = requestDelivery.value ? shippingAddress.value.trim() : '';

  const res = await orderStore.submitOrder(
    cartStore.cart.id,
    name,
    phone,
    address,
    null,
    isPrepaid.value,
    deliveryInstructions.value,
    codCharge.value,
    deliveryCharge.value,
    printCharge.value,
    packingCharge.value,
    0
  );
  if (res.success && res.data) {
    cartStore.clearCart();
    const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
    void router.push(`${tenantSlug}/shop/orders/${res.data.order_id}`);
  }
};

// Formatting helpers
const formatAmount = (val: number) => {
  return `${currencySymbol.value}${val.toFixed(2)}`;
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

const formatBuyerItemTotal = (item: any) => {
  const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
  const total = price * item.quantity;
  return `${currencySymbol.value}${total.toFixed(2)}`;
};

const formatCartTotal = () => {
  return `${currencySymbol.value}${cartStore.cartTotal.toFixed(2)}`;
};
</script>

<script lang="ts">
export default {
  name: 'ShopCheckoutPage',
};
</script>

<style scoped>
.form-card,
.summary-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.item-list-compact {
  max-height: 250px;
  overflow-y: auto;
}

.item-name {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.sticky-card {
  position: sticky;
  top: 24px;
}

.font-semibold {
  font-weight: 500;
}

.italic {
  font-style: italic;
}
</style>
