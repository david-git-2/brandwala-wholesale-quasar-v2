<template>
  <q-page class="q-pa-md page-container customer-order-detail-page">
    <!-- Loading Skeleton State -->
    <CustomerOrderDetailSkeleton v-if="isLoading" :variant="skeletonVariant" />

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
      <CustomerOrderHeader
        v-if="!isVendorCatalog"
        :order="currentOrder"
        :status-sequence="statusSequence"
        :terminal-statuses="terminalStatuses"
        :normalized-status="normalizedStatus"
      />

      <div v-if="showMerchantWallet" class="row justify-end">
        <q-btn
          outline
          no-caps
          color="primary"
          icon="ph ph-wallet"
          :label="$t('shop_admin.merchant_wallet')"
          :to="{ name: 'shop-merchant-wallet-page' }"
          data-test="dropship-merchant-wallet"
        />
      </div>

      <!-- Catalog Shop Order View -->
      <template v-if="isVendorCatalog">
        <div class="row justify-center">
          <div class="col-12 catalog-order-shell column q-gutter-y-md">
            <CustomerOrderHeader
              :order="currentOrder"
              :status-sequence="statusSequence"
              :terminal-statuses="terminalStatuses"
              :normalized-status="normalizedStatus"
            />

            <div class="row items-center justify-between q-col-gutter-sm">
              <div class="text-subtitle1 text-weight-bold text-grey-9">
                Items in Order ({{ displayOrderItems.length }})
              </div>
              <div
                v-if="showItemDecisionProgress"
                class="text-caption text-weight-bold gt-sm"
                :class="isAllItemsDecided ? 'text-positive' : 'text-amber-9'"
              >
                {{ itemsDecidedCount }} / {{ orderItems.length }} decided
              </div>
            </div>

            <CustomerCatalogOrderItemCard
              v-for="item in displayOrderItems"
              :key="item.id"
              :item="item"
              :order="currentOrder"
              :status="normalizedStatus"
              :is-negotiable="!!currentOrder.is_negotiable_snapshot"
              :currency-symbol="currencySymbol"
              :buy-currency-symbol="buyCurrencySymbol"
              @update:quantity="handleQuantityUpdate"
              @save-quantity="handleSaveQuantity"
              @update:customer-offer="handleCustomerOfferUpdate"
              @save-item-counter="handleSaveItemCounter"
            />

            <CustomerOrderShippingCard
              v-if="currentOrder.recipient_name || currentOrder.shipping_address"
              :order="currentOrder"
            />

            <CustomerOrderStickyActions
              :status="normalizedStatus"
              :is-negotiable="!!currentOrder.is_negotiable_snapshot"
              :total-amount="orderTotal"
              :currency-symbol="currencySymbol"
              :decided-count="itemsDecidedCount"
              :total-items="displayOrderItems.length"
              :negotiate-round="currentOrder.negotiate_round || 1"
              :can-submit-counter="isAllItemsDecided"
              :is-submitting-counter="isSendingCounter"
              :is-confirming="isConfirming"
              @submit-counter="submitCounterOffer"
              @confirm-order="confirmOrder"
            />
          </div>
        </div>
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
  useCustomerShopOrderDetailQuery,
  useSendCustomerCounterMutation,
  useCustomerConfirmOrderMutation,
} from '../composables/useShopOrderDetailQuery';
import { useUpdateCatalogOrderItemMutation } from '../composables/useCatalogOrderMutations';
import type { ShopOrderItem } from '../types';
import { calculateItemFirstOfferPrice } from '../utils/catalogPricingUtils';
import { requestConfirmation } from 'src/utils/appFeedback';
import { useMerchantWalletQuery } from '../composables/useMerchantWalletQuery';
import {
  getCustomerCatalogStatusSequence,
  getCustomerCatalogItemDisplayQuantity,
  isCatalogCustomerFulfillmentPhase,
  isCustomerCatalogItemDecided,
  normalizeCatalogOrderStatus,
} from '../utils/catalogOrderStatus';

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

const skeletonVariant = computed<'catalog' | 'dropship'>(() => {
  const state = history.state as { shopTypeSnapshot?: string } | null;
  return state?.shopTypeSnapshot === 'vendor_catalog' ? 'catalog' : 'dropship';
});

const { data: orderDetailsData, isLoading, isError, error } = useCustomerShopOrderDetailQuery(orderId);
const { mutate: sendCustomerCounter, isPending: isSendingCounter } = useSendCustomerCounterMutation();
const { mutate: confirmCustomerOrder, isPending: isConfirming } = useCustomerConfirmOrderMutation();
const { mutate: updateCatalogOrderItem } = useUpdateCatalogOrderItemMutation();

const currentOrder = computed(() => orderDetailsData.value?.order || null);
const orderItems = ref<ShopOrderItem[]>([]);

const isVendorCatalog = computed(() => currentOrder.value?.shop_type_snapshot === 'vendor_catalog');
const walletEnabled = computed(
  () =>
    currentOrder.value?.shop_type_snapshot === 'dropship' &&
    Boolean(currentOrder.value?.billing_profile_id),
);
const { summary: walletSummary } = useMerchantWalletQuery(walletEnabled);
const showMerchantWallet = computed(() => Boolean(walletSummary.value?.billing_profile_id));

watch(
  () => orderDetailsData.value,
  (newData) => {
    if (newData) {
      orderItems.value = JSON.parse(JSON.stringify(newData.items || []));
    }
  },
  { immediate: true },
);

const displayOrderItems = computed(() => {
  if (!isCatalogCustomerFulfillmentPhase(normalizedStatus.value)) {
    return orderItems.value;
  }
  return orderItems.value.filter(
    (item) => getCustomerCatalogItemDisplayQuantity(item) > 0,
  );
});

const currencySymbol = computed(() => {
  return currentOrder.value?.shop_sell_currency_symbol || '৳';
});

const buyCurrencySymbol = computed(() => {
  return currentOrder.value?.shop_buy_currency_symbol || '£';
});

const isNegotiationOpen = computed(() => {
  const o = currentOrder.value;
  return !!(o && o.is_negotiable_snapshot && normalizeCatalogOrderStatus(o.status) === 'priced');
});

const getDisplayUnitPrice = (item: any) => {
  if (normalizedStatus.value === 'final_offered' || ['confirmed', 'procuring', 'ready_for_shipment', 'delivered'].includes(normalizedStatus.value)) {
    if (item.final_price_amount != null && item.final_price_amount > 0) {
      return Number(item.final_price_amount);
    }
    if (item.final_offer_amount != null && item.final_offer_amount > 0) {
      return Number(item.final_offer_amount);
    }
  }
  if (['priced', 'countered', 'final_offered', 'confirmed', 'procuring', 'ready_for_shipment', 'delivered'].includes(normalizedStatus.value)) {
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
  return orderItems.value.every((item) => isCustomerCatalogItemDecided(item));
});

const itemsDecidedCount = computed(() =>
  orderItems.value.filter((item) => isCustomerCatalogItemDecided(item)).length,
);

const showItemDecisionProgress = computed(
  () =>
    !!currentOrder.value?.is_negotiable_snapshot && normalizedStatus.value === 'priced',
);

const orderTotal = computed(() => {
  if (isVendorCatalog.value) {
    return displayOrderItems.value.reduce((sum, item) => {
      return sum + getDisplayUnitPrice(item) * getCustomerCatalogItemDisplayQuantity(item);
    }, 0);
  }
  return orderItems.value.reduce((sum, item) => {
    return sum + getDisplayUnitPrice(item) * item.quantity;
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

const submitCounterOffer = async () => {
  if (!orderId.value) return;

  const confirmed = await requestConfirmation(
    'Send your response for all items? If you accepted every line, the order will be confirmed. If you countered any line, staff will send a final offer.',
    'Send my response',
    'Send response',
  );

  if (!confirmed) return;

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

const confirmOrder = async () => {
  if (!orderId.value) return;

  const confirmed = await requestConfirmation(
    'Are you sure you want to confirm this order? Once confirmed, the order will proceed to processing and fulfillment.',
    'Confirm Order',
    'Confirm Order',
  );

  if (!confirmed) return;

  confirmCustomerOrder(orderId.value);
};

const handleQuantityUpdate = ({ itemId, quantity }: { itemId: number; quantity: number }) => {
  const item = orderItems.value.find((i) => i.id === itemId);
  if (item) {
    item.quantity = quantity;
  }
};

const handleSaveQuantity = ({ itemId, quantity }: { itemId: number; quantity: number }) => {
  if (!orderId.value) return;
  handleQuantityUpdate({ itemId, quantity });

  const targetItem = orderItems.value.find((i) => i.id === itemId);
  if (!targetItem) return;

  updateCatalogOrderItem({
    orderId: orderId.value,
    itemId,
    productId: targetItem.product_id,
    payload: {
      quantity,
    },
  });
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
  return normalizeCatalogOrderStatus(status);
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
    return getCustomerCatalogStatusSequence(!!order.value.is_negotiable_snapshot);
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

<style scoped>
.customer-order-detail-page {
  padding-bottom: calc(24px + env(safe-area-inset-bottom, 0px));
}

.catalog-order-shell {
  width: 100%;
  max-width: 640px;
  margin: 0 auto;
}

@media (min-width: 600px) {
  .catalog-order-shell {
    max-width: 720px;
  }

  .catalog-order-shell :deep(.catalog-progress-bar) {
    padding: 10px 12px;
  }
}
</style>

