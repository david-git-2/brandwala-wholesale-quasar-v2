<template>
  <q-page class="q-pa-md customer-order-detail-page">
    <div class="bw-page__stack" v-if="orderStore.loading">
      <div class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_order_details') }}</div>
      </div>
    </div>

    <div class="bw-page__stack" v-else-if="orderStore.currentOrder">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline text-primary">{{ $t('shop_admin.order_portal') }}</div>
              <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('shop_admin.order_details') }}</h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Details for Order
                <span class="text-weight-bold">{{ orderStore.currentOrder.order_no }}</span>
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto">
          <q-badge
            :color="getStatusColor(orderStore.currentOrder.status)"
            text-color="white"
            class="status-badge text-weight-bold q-py-xs q-px-md text-subtitle2"
          >
            {{ orderStore.currentOrder.status.toUpperCase() }}
          </q-badge>
        </div>
      </section>

      <!-- Order Info Cards -->
      <div class="row q-col-gutter-lg">
        <!-- Main details & Negotiation panel (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.items_in_order') }}</div>
              <div
                class="text-caption text-grey-6"
                v-if="orderStore.currentOrder.is_negotiable_snapshot"
              >
                {{ $t('shop_admin.negotiation_round') }} {{ orderStore.currentOrder.negotiate_round }}
              </div>
            </q-card-section>

            <q-list separator>
              <q-item v-for="item in orderItems" :key="item.id" class="q-py-md q-px-lg">
                <q-item-section avatar>
                  <q-avatar size="50px" rounded class="bg-grey-2">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="image" size="24px" color="grey-4" />
                  </q-avatar>
                </q-item-section>

                <q-item-section>
                  <div class="text-body1 text-weight-bold text-grey-9">{{ item.name }}</div>
                  <div class="text-caption text-grey-6">{{ $t('shop_admin.quantity') }}: {{ item.quantity }}</div>
                </q-item-section>

                <q-item-section side class="column items-end justify-center">
                  <!-- Pricing display -->
                  <template v-if="orderStore.currentOrder.shop_type_snapshot === 'dropship'">
                    <div class="column text-right q-mb-xs">
                      <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.accounting_cost') }}</span>
                      <span class="text-body2 text-weight-medium text-grey-8">
                        £{{ (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                      </span>
                      <span class="text-caption text-grey-6" style="font-size: 10px;">
                        Total Cost: £{{ ((item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0) * item.quantity).toFixed(2) }}
                      </span>
                    </div>
                    <div class="column text-right">
                      <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.recipient_price') }}</span>
                      <span class="text-body2 text-weight-bold text-primary">
                        £{{ (item.customer_sell_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                      </span>
                      <span class="text-caption text-weight-bold text-primary" style="font-size: 11px;">
                        Total Recipient: £{{ ((item.customer_sell_price_amount ?? 0) * item.quantity).toFixed(2) }}
                      </span>
                    </div>
                  </template>
                  <template v-else>
                    <div class="column text-right">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.unit_price') }}</span>
                      <span class="text-body2 text-weight-bold text-grey-8">
                        £{{ getDisplayUnitPrice(item).toFixed(2) }}
                      </span>
                      <span class="text-caption text-grey-6">
                        Total: £{{ (getDisplayUnitPrice(item) * item.quantity).toFixed(2) }}
                      </span>
                    </div>
                  </template>

                  <!-- Offer editing if in negotiation status -->
                  <div v-if="isNegotiationOpen" class="q-mt-sm row items-center q-gutter-x-sm">
                    <span class="text-caption text-grey-7">{{ $t('shop_admin.your_counter') }}</span>
                    <q-input
                      v-model.number="item.customer_offer_amount"
                      type="number"
                      outlined
                      dense
                      class="counter-input"
                      prefix="£"
                      style="width: 100px"
                    />
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>

          <!-- Negotiation submit banner -->
          <q-card
            v-if="isNegotiationOpen"
            flat
            bordered
            class="negotiate-action-card q-mt-md bg-amber-1 border-amber"
          >
            <q-card-section class="row items-center justify-between q-col-gutter-md">
              <div class="col">
                <div class="text-subtitle2 text-weight-bold text-amber-9">
                  Counter Offer Action Required
                </div>
                <div class="text-body2 text-amber-8">
                  Propose counter unit prices for the items above and submit them to staff.
                </div>
              </div>
              <div class="col-auto">
                <q-btn
                  color="amber-9"
                  unelevated
                  no-caps
                  :label="$t('shop_admin.submit_counter_offer')"
                  class="pill-btn text-weight-bold"
                  :loading="orderStore.saving"
                  @click="submitCounterOffer"
                />
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Sidebar (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <div class="column q-gutter-md">
            <!-- Summary Info -->
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_summary') }}</div>
              </q-card-section>

              <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.order_no') }}</span>
                  <span class="text-weight-bold text-grey-8">{{
                    orderStore.currentOrder.order_no
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.date') }}</span>
                  <span class="text-grey-8">{{
                    formatDate(orderStore.currentOrder.created_at)
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.shop_type_label') }}</span>
                  <span class="text-grey-8 text-capitalize">{{
                    orderStore.currentOrder.shop_type_snapshot
                  }}</span>
                </div>
                <div class="row justify-between" v-if="orderStore.currentOrder.shop_type_snapshot === 'dropship'">
                  <span class="text-grey-6">{{ $t('shop_admin.payment_mode') }}</span>
                  <q-badge
                    :color="orderStore.currentOrder.is_prepaid_snapshot ? 'positive' : 'warning'"
                    text-color="white"
                    class="q-py-xs q-px-sm"
                  >
                    {{
                      orderStore.currentOrder.is_prepaid_snapshot
                        ? $t('shop_admin.payment_prepaid')
                        : $t('shop_admin.payment_cod')
                    }}
                  </q-badge>
                </div>
                <div class="row justify-between" v-else>
                  <span class="text-grey-6">{{ $t('shop_admin.order_mode_label') }}</span>
                  <span class="text-grey-8 text-capitalize">{{
                    orderStore.currentOrder.order_mode_snapshot
                  }}</span>
                </div>

                <q-separator class="q-my-sm" />

                <!-- Dropship detailed receipt footer -->
                <template v-if="orderStore.currentOrder.shop_type_snapshot === 'dropship'">
                  <div class="row justify-between text-body2 text-grey-7">
                    <span>{{ $t('shop.items_subtotal') }}</span>
                    <span>£{{ recipientSubtotal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="deliveryChargeVal > 0">
                    <span>{{ $t('shop.delivery_charge') }}</span>
                    <span>£{{ deliveryChargeVal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="codChargeVal > 0">
                    <span>{{ $t('shop.cod_fee', { pct: codFeePctLabel }) }}</span>
                    <span>£{{ codChargeVal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="printChargeVal > 0">
                    <span>{{ $t('shop.print_charge') }}</span>
                    <span>£{{ printChargeVal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="packingChargeVal > 0">
                    <span>{{ $t('shop.packing_charge') }}</span>
                    <span>£{{ packingChargeVal.toFixed(2) }}</span>
                  </div>

                  <div class="row justify-between text-body2 text-negative" v-if="discountVal > 0">
                    <span>{{ $t('shop_admin.discount') }}</span>
                    <span>-£{{ discountVal.toFixed(2) }}</span>
                  </div>

                  <q-separator class="q-my-sm" />

                  <div class="row justify-between items-baseline q-mb-xs">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop.recipient_pay_total') }}</span>
                    <span class="text-h6 text-weight-bold text-primary">
                      £{{ recipientGrandTotal.toFixed(2) }}
                    </span>
                  </div>

                  <div class="row justify-between text-caption text-grey-6">
                    <span>{{ $t('shop_admin.your_cost_accounting') }}</span>
                    <span>£{{ middlemanTotalCost.toFixed(2) }}</span>
                  </div>

                  <div class="row justify-between text-body2 text-weight-bold text-positive q-mt-xs">
                    <span>{{ $t('shop_admin.your_estimated_profit') }}</span>
                    <span>£{{ estimatedProfit.toFixed(2) }}</span>
                  </div>
                </template>
                <template v-else>
                  <div class="row justify-between items-baseline">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.total_amount_label') }}</span>
                    <span class="text-h6 text-weight-bold text-primary">
                      £{{ orderTotal.toFixed(2) }}
                    </span>
                  </div>
                </template>
              </q-card-section>
            </q-card>

            <!-- Shipping Info -->
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.shipping_details') }}</div>
              </q-card-section>

              <q-card-section class="q-px-lg q-py-md text-body2 text-grey-8">
                <div class="text-weight-bold text-grey-9">
                  {{ orderStore.currentOrder.recipient_name }}
                </div>
                <div class="q-mt-xs">{{ orderStore.currentOrder.recipient_phone }}</div>
                <div
                  class="q-mt-sm text-grey-6 bg-grey-1 q-pa-sm rounded-borders"
                  style="white-space: pre-wrap"
                >
                  {{ orderStore.currentOrder.shipping_address }}
                </div>
                
                <div
                  v-if="orderStore.currentOrder.delivery_instructions"
                  class="q-mt-sm q-pa-sm bg-blue-50 text-blue-9 text-caption rounded-borders"
                  style="border: 1px solid #90caf9;"
                >
                  <div class="text-weight-bold">{{ $t('shop_admin.delivery_instructions_notes') }}</div>
                  <div style="white-space: pre-wrap">{{ orderStore.currentOrder.delivery_instructions }}</div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { date } from 'quasar';

const route = useRoute();
const router = useRouter();
const orderStore = useShopOrderStore();

const orderItems = ref<any[]>([]);

const orderId = computed(() => Number(route.params.id));

onMounted(async () => {
  if (orderId.value) {
    const res = await orderStore.fetchOrderDetails(orderId.value);
    if (res.success && res.data) {
      orderItems.value = JSON.parse(JSON.stringify(res.data.items));
    }
  }
});

const isNegotiationOpen = computed(() => {
  const o = orderStore.currentOrder;
  return o && o.is_negotiable_snapshot && (o.status === 'negotiating' || o.status === 'priced');
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

const codChargeVal = computed(() => Number(orderStore.currentOrder?.cod_charge_amount || 0));
const deliveryChargeVal = computed(() => Number(orderStore.currentOrder?.delivery_charge_amount || 0));
const printChargeVal = computed(() => Number(orderStore.currentOrder?.print_charge_amount || 0));
const packingChargeVal = computed(() => Number(orderStore.currentOrder?.packing_charge_amount || 0));
const discountVal = computed(() => Number(orderStore.currentOrder?.discount_amount || 0));
const deductCodFromMargin = computed(() => !!orderStore.currentOrder?.deduct_cod_from_margin);
const deductDeliveryFromMargin = computed(() => !!orderStore.currentOrder?.deduct_delivery_from_margin);
const deductPrintFromMargin = computed(() => !!orderStore.currentOrder?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!orderStore.currentOrder?.deduct_packing_from_margin);

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
    + deliveryChargeVal.value
    + printChargeVal.value
    + packingChargeVal.value
    + (deductCodFromMargin.value ? codChargeVal.value : 0);
});

const estimatedProfit = computed(() => {
  return recipientGrandTotal.value - middlemanTotalCost.value;
});

const codFeePctLabel = computed(() => {
  const sub = recipientSubtotal.value;
  if (!sub) return 0;
  return Number(((codChargeVal.value / sub) * 100).toFixed(1));
});

const submitCounterOffer = async () => {
  const payload = orderItems.value.map((item) => ({
    id: item.id,
    customer_offer_amount: Number(item.customer_offer_amount || 0),
    customer_offer_currency_id:
      item.customer_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id,
  }));

  const res = await orderStore.sendCustomerCounter(orderId.value, payload);
  if (res.success) {
    const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
    if (detailsRes.success && detailsRes.data) {
      orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
    }
  }
};

const goBack = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/orders`);
};

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderDetailPage',
};
</script>

<style scoped>
.customer-order-detail-page {
  max-width: 1200px;
  margin: 0 auto;
}

.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 30px;
}

.status-badge {
  border-radius: 8px;
}

.negotiate-action-card {
  border-radius: 12px;
}

.border-amber {
  border-color: #ffb300 !important;
}

.counter-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
