<template>
  <q-page class="q-pa-md">
    <!-- Loading Skeleton State -->
    <CustomerOrderDetailSkeleton v-if="isLoading" />

    <!-- Error State -->
    <div class="q-gutter-y-md" v-else-if="isError">
      <div class="column items-center justify-center q-pa-xl text-center">
        <q-icon name="ph ph-warning-circle" size="48px" color="negative" class="q-mb-sm" />
        <div class="text-h6 text-grey-8">{{ error?.message || 'Failed to load order details.' }}</div>
        <q-btn flat color="primary" label="Go Back to Orders" class="q-mt-md" @click="goOrders" />
      </div>
    </div>

    <!-- Loaded Content State -->
    <div class="q-gutter-y-md" v-else-if="currentOrder">
      <!-- Header & Status Workflow Component -->
      <CustomerOrderHeader
        :order="currentOrder"
        :status-sequence="statusSequence"
        :terminal-statuses="terminalStatuses"
        :normalized-status="normalizedStatus"
        @back="goOrders"
      />

      <!-- Order Info Cards -->
      <div class="row q-col-gutter-lg">
        <!-- Main details & Negotiation panel (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <CustomerOrderItemsList
            :order-items="orderItems"
            :order="currentOrder"
            :is-negotiation-open="isNegotiationOpen"
            :is-sending-counter="isSendingCounter"
            :currency-symbol="currencySymbol"
            @submit-counter-offer="submitCounterOffer"
          />
        </div>

        <!-- Sidebar (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <div class="column q-gutter-md">
            <!-- Summary Info Card -->
            <CustomerOrderSummaryCard
              :order="currentOrder"
              :currency-symbol="currencySymbol"
              :recipient-subtotal="recipientSubtotal"
              :delivery-charge-val="deliveryChargeVal"
              :cod-charge-val="codChargeVal"
              :print-charge-val="printChargeVal"
              :packing-charge-val="packingChargeVal"
              :discount-val="discountVal"
              :deduct-delivery-from-margin="deductDeliveryFromMargin"
              :deduct-cod-from-margin="deductCodFromMargin"
              :cod-fee-pct-label="codFeePctLabel"
              :recipient-grand-total="recipientGrandTotal"
              :middleman-total-cost="middlemanTotalCost"
              :estimated-profit="estimatedProfit"
              :is-before-pickup="isBeforePickup"
              :order-total="orderTotal"
            />

            <!-- Shipping Info Card -->
            <CustomerOrderShippingCard :order="currentOrder" />
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useShopOrderDetailQuery, useSendCustomerCounterMutation } from '../composables/useShopOrderDetailQuery';
import { supabase } from 'src/boot/supabase';
import type { ShopOrderItem } from '../types';

import CustomerOrderDetailSkeleton from '../components/CustomerOrderDetailSkeleton.vue';
import CustomerOrderHeader from '../components/CustomerOrderHeader.vue';
import CustomerOrderItemsList from '../components/CustomerOrderItemsList.vue';
import CustomerOrderSummaryCard from '../components/CustomerOrderSummaryCard.vue';
import CustomerOrderShippingCard from '../components/CustomerOrderShippingCard.vue';

const route = useRoute();
const router = useRouter();

const orderId = computed(() => Number(route.params.id || 0));

const { data: orderDetailsData, isLoading, isError, error } = useShopOrderDetailQuery(orderId);
const { mutate: sendCustomerCounter, isPending: isSendingCounter } = useSendCustomerCounterMutation();
const { data: currenciesData } = useThriftCurrenciesQuery();

const currencies = computed(() => currenciesData.value ?? []);
const currentOrder = computed(() => orderDetailsData.value?.order || null);

const orderItems = ref<ShopOrderItem[]>([]);
const shopSellCurrencyId = ref<number | null>(null);

watch(
  () => orderDetailsData.value,
  async (newData) => {
    if (newData) {
      orderItems.value = JSON.parse(JSON.stringify(newData.items || []));
      const shopId = newData.order?.shop_id;
      if (shopId) {
        const { data: shopData } = await supabase
          .from('shops')
          .select('sell_currency_id')
          .eq('id', shopId)
          .single();
        if (shopData?.sell_currency_id) {
          shopSellCurrencyId.value = shopData.sell_currency_id;
        }
      }
    }
  },
  { immediate: true },
);

const currencySymbol = computed(() => {
  if (shopSellCurrencyId.value) {
    const curr = currencies.value.find((c) => c.id === shopSellCurrencyId.value);
    if (curr?.symbol) return curr.symbol;
  }
  const firstItem = orderItems.value?.[0];
  const currId =
    firstItem?.unit_sell_price_currency_id ||
    firstItem?.customer_offer_currency_id ||
    firstItem?.unit_list_price_currency_id;
  if (currId) {
    const curr = currencies.value.find((c) => c.id === currId);
    if (curr?.symbol) return curr.symbol;
  }
  return '৳';
});

const isNegotiationOpen = computed(() => {
  const o = currentOrder.value;
  return !!(o && o.is_negotiable_snapshot && (o.status === 'negotiating' || o.status === 'priced'));
});

const getDisplayUnitPrice = (item: any) => {
  return (
    item.final_price_amount ??
    item.staff_offer_amount ??
    item.customer_offer_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0
  );
};

const orderTotal = computed(() => {
  return orderItems.value.reduce((sum, item) => sum + getDisplayUnitPrice(item) * item.quantity, 0);
});

// Dropship calculations
const recipientSubtotal = computed(() => {
  return orderItems.value.reduce((sum, item) => sum + (item.customer_sell_price_amount ?? 0) * item.quantity, 0);
});

const accountingSubtotal = computed(() => {
  return orderItems.value.reduce((sum, item) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return sum + price * item.quantity;
  }, 0);
});

const codChargeVal = computed(() => Number(currentOrder.value?.cod_charge_amount || 0));
const deliveryChargeVal = computed(() => Number(currentOrder.value?.delivery_charge_amount || 0));
const printChargeVal = computed(() => Number(currentOrder.value?.print_charge_amount || 0));
const packingChargeVal = computed(() => Number(currentOrder.value?.packing_charge_amount || 0));
const discountVal = computed(() => Number(currentOrder.value?.discount_amount || 0));
const deductCodFromMargin = computed(() => !!currentOrder.value?.deduct_cod_from_margin);
const deductDeliveryFromMargin = computed(() => !!currentOrder.value?.deduct_delivery_from_margin);

const recipientGrandTotal = computed(() => {
  return recipientSubtotal.value
    + (deductDeliveryFromMargin.value ? 0 : deliveryChargeVal.value)
    + (deductCodFromMargin.value ? 0 : codChargeVal.value)
    - discountVal.value;
});

const middlemanTotalCost = computed(() => {
  return accountingSubtotal.value
    + printChargeVal.value
    + packingChargeVal.value
    + (deductDeliveryFromMargin.value ? deliveryChargeVal.value : 0)
    + (deductCodFromMargin.value ? codChargeVal.value : 0);
});

const estimatedProfit = computed(() => {
  return recipientSubtotal.value - discountVal.value - middlemanTotalCost.value;
});

const codFeePctLabel = computed(() => {
  const sub = recipientSubtotal.value;
  if (!sub) return 0;
  return Number(((codChargeVal.value / sub) * 100).toFixed(1));
});

const submitCounterOffer = () => {
  if (!orderId.value) return;
  const payload = orderItems.value.map((item) => ({
    id: item.id,
    customer_offer_amount: Number(item.customer_offer_amount || 0),
    customer_offer_currency_id: Number(
      item.customer_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id ||
      0
    ),
  }));

  sendCustomerCounter({ orderId: orderId.value, items: payload });
};

const order = computed(() => currentOrder.value || ({} as any));

/** Map legacy/alias statuses onto the display sequence. */
const normalizedStatus = computed(() => {
  const status = String(order.value.status || '');
  if (status === 'pending') return 'submitted';
  if (status === 'approved') return 'confirmed';
  if (status === 'payment_received') return 'delivered';
  return status;
});

const isBeforePickup = computed(() => {
  const current = normalizedStatus.value;
  const postPickupStatuses = ['ready_for_pickup', 'shipped', 'delivered', 'payment_received', 'remitted'];
  return !postPickupStatuses.includes(current);
});

const statusSequence = computed(() => {
  const shopType = order.value.shop_type_snapshot;
  if (shopType === 'dropship') {
    return ['confirmed', 'processing', 'ready_for_pickup', 'shipped', 'delivered'];
  }
  if (shopType === 'vendor_catalog') {
    if (order.value.is_negotiable_snapshot) {
      return ['negotiating', 'priced', 'confirmed', 'placed'];
    }
    return ['submitted', 'confirmed', 'placed'];
  }
  return ['confirmed', 'fulfilled'];
});

const terminalStatuses = computed(() => {
  if (order.value.shop_type_snapshot === 'dropship') {
    return ['returned', 'cancelled'];
  }
  return ['cancelled'];
});

const goOrders = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/orders`);
};
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderDetailPage',
};
</script>
