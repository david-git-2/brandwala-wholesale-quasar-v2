<template>
  <q-page class="q-pa-md page-container">
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

      <!-- Catalog Shop Order View (Mobile Card List + Sticky Bottom Actions) -->
      <template v-if="isVendorCatalog">
        <div class="row q-col-gutter-lg">
          <!-- Item Cards List (8 cols on desktop, 12 on mobile) -->
          <div class="col-xs-12 col-md-8">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-subtitle1 text-weight-bold text-grey-9">
                Items in Order ({{ orderItems.length }})
              </div>
              <div v-if="currentOrder.is_negotiable_snapshot" class="text-caption text-amber-9 text-weight-bold">
                Round {{ currentOrder.negotiate_round || 1 }}
              </div>
            </div>

            <!-- Cards loop -->
            <CustomerCatalogOrderItemCard
              v-for="item in orderItems"
              :key="item.id"
              :item="item"
              :order="currentOrder"
              :status="normalizedStatus"
              :is-negotiable="!!currentOrder.is_negotiable_snapshot"
              :currency-symbol="currencySymbol"
              :buy-currency-symbol="buyCurrencySymbol"
              @update:confirmed-qty="handleConfirmedQtyUpdate"
              @update:customer-offer="handleCustomerOfferUpdate"
              @save-item-counter="handleSaveItemCounter"
            />
          </div>

          <!-- Sidebar (Shipping) -->
          <div class="col-xs-12 col-md-4">
            <div class="column q-gutter-md">
              <CustomerOrderShippingCard :order="currentOrder" />
            </div>
          </div>
        </div>

        <!-- Sticky Bottom CTA Action Bar for Mobile/Catalog -->
        <CustomerOrderStickyActions
          :status="normalizedStatus"
          :is-negotiable="!!currentOrder.is_negotiable_snapshot"
          :total-amount="orderTotal"
          :currency-symbol="currencySymbol"
          :can-submit-counter="isAllItemsDecided"
          :is-submitting-counter="isSendingCounter"
          :is-confirming="isConfirming"
          @submit-counter="submitCounterOffer"
          @confirm-order="confirmOrder"
        />
      </template>

      <!-- Dropship / Other Order View (Original layout) -->
      <template v-else>
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
                :deduct-print-from-margin="deductPrintFromMargin"
                :deduct-packing-from-margin="deductPackingFromMargin"
                :cod-fee-pct-label="codFeePctLabel"
                :recipient-grand-total="recipientGrandTotal"
                :middleman-total-cost="middlemanTotalCost"
                :estimated-profit="estimatedProfit"
                :is-before-pickup="isBeforePickup"
                :order-total="orderTotal"
              />

              <CustomerOrderShippingCard :order="currentOrder" />
            </div>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  useShopOrderDetailQuery,
  useSendCustomerCounterMutation,
  useCustomerConfirmOrderMutation,
} from '../composables/useShopOrderDetailQuery';
import { useUpdateCatalogOrderItemMutation } from '../composables/useCatalogOrderMutations';
import type { ShopOrderItem } from '../types';
import { calculateItemFirstOfferPrice } from '../utils/catalogPricingUtils';

import CustomerOrderDetailSkeleton from '../components/CustomerOrderDetailSkeleton.vue';
import CustomerOrderHeader from '../components/CustomerOrderHeader.vue';
import CustomerOrderItemsList from '../components/CustomerOrderItemsList.vue';
import CustomerOrderSummaryCard from '../components/CustomerOrderSummaryCard.vue';
import CustomerOrderShippingCard from '../components/CustomerOrderShippingCard.vue';
import CustomerCatalogOrderItemCard from '../components/CustomerCatalogOrderItemCard.vue';
import CustomerOrderStickyActions from '../components/CustomerOrderStickyActions.vue';

const route = useRoute();
const router = useRouter();

const orderId = computed(() => Number(route.params.id || 0));

const { data: orderDetailsData, isLoading, isError, error } = useShopOrderDetailQuery(orderId);
const { mutate: sendCustomerCounter, isPending: isSendingCounter } = useSendCustomerCounterMutation();
const { mutate: confirmCustomerOrder, isPending: isConfirming } = useCustomerConfirmOrderMutation();
const { mutate: updateCatalogOrderItem } = useUpdateCatalogOrderItemMutation();

const currentOrder = computed(() => orderDetailsData.value?.order || null);
const orderItems = ref<ShopOrderItem[]>([]);

const isVendorCatalog = computed(() => currentOrder.value?.shop_type_snapshot === 'vendor_catalog');

watch(
  () => orderDetailsData.value,
  (newData) => {
    if (newData) {
      orderItems.value = JSON.parse(JSON.stringify(newData.items || []));
    }
  },
  { immediate: true },
);

const currencySymbol = computed(() => {
  return currentOrder.value?.shop_sell_currency_symbol || '৳';
});

const buyCurrencySymbol = computed(() => {
  return currentOrder.value?.shop_buy_currency_symbol || '£';
});

const isNegotiationOpen = computed(() => {
  const o = currentOrder.value;
  return !!(o && o.is_negotiable_snapshot && (o.status === 'negotiating' || o.status === 'priced'));
});

const getDisplayUnitPrice = (item: any) => {
  if (normalizedStatus.value === 'final_offered' || ['confirmed', 'procuring', 'ordered', 'delivered'].includes(normalizedStatus.value)) {
    if (item.final_offer_amount != null && item.final_offer_amount > 0) {
      return Number(item.final_offer_amount);
    }
  }
  if (['priced', 'countered', 'final_offered', 'confirmed', 'procuring', 'ordered', 'delivered'].includes(normalizedStatus.value)) {
    if (item.staff_offer_amount != null && item.staff_offer_amount > 0) {
      return Number(item.staff_offer_amount);
    }
    if (currentOrder.value) {
      const computedOffer = calculateItemFirstOfferPrice(
        item,
        {
          conversion_rate: currentOrder.value.conversion_rate,
          cargo_rate: currentOrder.value.cargo_rate,
          first_offer_rate: currentOrder.value.first_offer_rate ?? currentOrder.value.profit_rate,
          profit_basis: currentOrder.value.profit_basis,
        },
        currentOrder.value.package_weight_kg,
      );
      if (computedOffer > 0) return computedOffer;
    }
  }
  return (
    item.customer_offer_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0
  );
};

const isAllItemsDecided = computed(() => {
  if (orderItems.value.length === 0) return false;
  return orderItems.value.every(
    (item) => item.customer_offer_amount != null && Number(item.customer_offer_amount) > 0,
  );
});

const orderTotal = computed(() => {
  const isFinalOrBeyond = ['final_offered', 'confirmed', 'procuring', 'ordered', 'delivered'].includes(
    normalizedStatus.value,
  );
  return orderItems.value.reduce((sum, item) => {
    const qty = isFinalOrBeyond ? (item.confirmed_quantity ?? item.quantity) : item.quantity;
    return sum + getDisplayUnitPrice(item) * qty;
  }, 0);
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
const deductPrintFromMargin = computed(() => !!currentOrder.value?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!currentOrder.value?.deduct_packing_from_margin);

const recipientGrandTotal = computed(() => {
  return recipientSubtotal.value
    + (deductDeliveryFromMargin.value ? 0 : deliveryChargeVal.value)
    + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
    + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
    + (deductCodFromMargin.value ? 0 : codChargeVal.value)
    - discountVal.value;
});

const middlemanTotalCost = computed(() => {
  return accountingSubtotal.value
    + (deductPrintFromMargin.value ? printChargeVal.value : 0)
    + (deductPackingFromMargin.value ? packingChargeVal.value : 0)
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

const confirmOrder = () => {
  if (!orderId.value) return;
  confirmCustomerOrder(orderId.value);
};

const handleConfirmedQtyUpdate = ({ itemId, confirmedQuantity }: { itemId: number; confirmedQuantity: number }) => {
  const item = orderItems.value.find((i) => i.id === itemId);
  if (item) {
    item.confirmed_quantity = confirmedQuantity;
  }
};

const handleCustomerOfferUpdate = ({ itemId, amount }: { itemId: number; amount: number }) => {
  const item = orderItems.value.find((i) => i.id === itemId);
  if (item) {
    item.customer_offer_amount = amount;
  }
};

const handleSaveItemCounter = ({ itemId, amount }: { itemId: number; amount: number }) => {
  if (!orderId.value) return;
  handleCustomerOfferUpdate({ itemId, amount });

  const targetItem = orderItems.value.find((i) => i.id === itemId);
  if (!targetItem) return;

  const currencyId = Number(
    targetItem.customer_offer_currency_id ||
      targetItem.unit_sell_price_currency_id ||
      targetItem.unit_list_price_currency_id ||
      0,
  );

  updateCatalogOrderItem({
    orderId: orderId.value,
    itemId,
    productId: targetItem.product_id,
    payload: {
      customer_offer_amount: amount,
      customer_offer_currency_id: currencyId > 0 ? currencyId : null,
    },
  });
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
      return ['submitted', 'costing_pending', 'priced', 'countered', 'final_offered', 'confirmed', 'procuring', 'ordered', 'delivered'];
    }
    return ['submitted', 'costing_pending', 'priced', 'final_offered', 'confirmed', 'procuring', 'ordered', 'delivered'];
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

