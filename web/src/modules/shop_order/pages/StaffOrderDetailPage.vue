<template>
  <q-page class="bw-page">
    <div class="bw-page__stack" v-if="orderStore.loading">
      <div class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">Loading order details...</div>
      </div>
    </div>

    <div class="bw-page__stack" v-else-if="orderStore.currentOrder">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">Staff Order Desk</div>
              <h1 class="text-h5 text-weight-bold q-my-none">Order Management</h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Manage and negotiate Order
                <span class="text-weight-bold">{{ orderStore.currentOrder.order_no }}</span>
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-badge
            :color="getStatusColor(orderStore.currentOrder.status)"
            text-color="white"
            class="status-badge text-weight-bold q-py-xs q-px-md text-subtitle2"
          >
            {{ orderStore.currentOrder.status.toUpperCase() }}
          </q-badge>
        </div>
      </section>

      <!-- Main Columns -->
      <div class="row q-col-gutter-lg">
        <!-- Items & Actions Panel (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
              <div class="text-subtitle1 text-weight-bold text-grey-9">Order Lines</div>
              <div
                class="text-caption text-grey-6"
                v-if="orderStore.currentOrder.is_negotiable_snapshot"
              >
                Negotiation Round: {{ orderStore.currentOrder.negotiate_round }}
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
                  <div class="text-caption text-grey-6">Quantity: {{ item.quantity }}</div>
                  <div
                    class="text-caption text-amber-9 text-weight-bold"
                    v-if="item.customer_offer_amount"
                  >
                    Customer Offer: £{{ Number(item.customer_offer_amount).toFixed(2) }}
                  </div>
                </q-item-section>

                <q-item-section side class="column items-end justify-center">
                  <!-- Pricing display -->
                  <div class="column text-right">
                    <span class="text-caption text-grey-6">Catalog Sell Price</span>
                    <span class="text-body2 text-weight-bold text-grey-8">
                      £{{
                        (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2)
                      }}
                    </span>
                  </div>

                  <!-- Offer editing if in editable negotiation/price status -->
                  <div v-if="canAction" class="q-mt-sm row items-center q-gutter-x-sm">
                    <span class="text-caption text-grey-7">Staff Price:</span>
                    <q-input
                      v-model.number="item.staff_offer_amount"
                      type="number"
                      outlined
                      dense
                      class="counter-input"
                      prefix="£"
                      style="width: 100px"
                    />
                  </div>
                  <div
                    v-else-if="item.final_price_amount"
                    class="q-mt-xs text-weight-bold text-primary"
                  >
                    Final Price: £{{ Number(item.final_price_amount).toFixed(2) }}
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>

          <!-- Action Buttons Panel -->
          <div class="q-mt-md row items-center justify-between">
            <div>
              <q-btn
                v-if="orderStore.currentOrder.status !== 'fulfilled'"
                outline
                color="negative"
                no-caps
                icon="delete"
                label="Delete Order"
                class="pill-btn text-weight-bold q-px-lg q-py-sm"
                :loading="orderStore.saving"
                @click="confirmDeleteOrder"
              />
            </div>

            <div class="row q-gutter-md justify-end">
              <div v-if="canAction" class="row q-gutter-md justify-end">
                <q-btn
                  outline
                  color="primary"
                  no-caps
                  label="Save Price / Send Counter"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="submitStaffPricing"
                />
                <q-btn
                  color="green-7"
                  unelevated
                  no-caps
                  label="Confirm Order"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="confirmOrder"
                />
              </div>

              <div v-if="canFulfill" class="row q-gutter-md justify-end">
                <q-btn
                  v-if="orderStore.currentOrder.shop_type_snapshot === 'vendor_catalog'"
                  color="indigo-7"
                  unelevated
                  no-caps
                  label="Place for Procurement"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="placeForProcurement"
                />
                <q-btn
                  v-else
                  color="teal-7"
                  unelevated
                  no-caps
                  label="Fulfill to Invoice"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="fulfillToInvoice"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <div class="column q-gutter-md">
            <!-- Summary Card -->
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <div class="text-subtitle1 text-weight-bold text-grey-9">Order Context</div>
              </q-card-section>

              <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
                <div class="row justify-between">
                  <span class="text-grey-6">Order No:</span>
                  <span class="text-weight-bold text-grey-8">{{
                    orderStore.currentOrder.order_no
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">Date:</span>
                  <span class="text-grey-8">{{
                    formatDate(orderStore.currentOrder.created_at)
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">Shop Type:</span>
                  <span class="text-grey-8 text-capitalize">{{
                    orderStore.currentOrder.shop_type_snapshot
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">Order Mode:</span>
                  <span class="text-grey-8 text-capitalize">{{
                    orderStore.currentOrder.order_mode_snapshot
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">Negotiable:</span>
                  <span class="text-grey-8">{{
                    orderStore.currentOrder.is_negotiable_snapshot ? 'Yes' : 'No'
                  }}</span>
                </div>
                <div class="row justify-between" v-if="orderStore.currentOrder.global_invoice_id">
                  <span class="text-grey-6">Invoice:</span>
                  <router-link
                    :to="{
                      name: 'app-global-invoice-details-page',
                      params: {
                        tenantSlug: route.params.tenantSlug || '',
                        id: orderStore.currentOrder.global_invoice_id,
                      },
                    }"
                    class="text-weight-bold text-primary"
                  >
                    View Invoice
                  </router-link>
                </div>
                <div class="row justify-between" v-if="orderStore.currentOrder.status === 'placed'">
                  <span class="text-grey-6">Procurement:</span>
                  <span class="text-weight-bold text-indigo-7">Placed (Shipment Pull)</span>
                </div>

                <q-separator class="q-my-sm" />

                <div class="row justify-between items-baseline">
                  <span class="text-subtitle1 text-weight-bold text-grey-9">Current Value</span>
                  <span class="text-h6 text-weight-bold text-primary">
                    £{{ orderTotal.toFixed(2) }}
                  </span>
                </div>
              </q-card-section>
            </q-card>

            <!-- Customer Info -->
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <div class="text-subtitle1 text-weight-bold text-grey-9">
                  Recipient &amp; Delivery
                </div>
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
                <div class="q-mt-md text-caption text-grey-5">
                  Ordered by: {{ orderStore.currentOrder.created_by_email }}
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
import { date, useQuasar } from 'quasar';

const route = useRoute();
const router = useRouter();
const orderStore = useShopOrderStore();
const $q = useQuasar();

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

const canAction = computed(() => {
  const o = orderStore.currentOrder;
  return o && (o.status === 'submitted' || o.status === 'negotiating' || o.status === 'priced');
});

const canFulfill = computed(() => {
  const o = orderStore.currentOrder;
  return o && o.status === 'confirmed';
});

const placeForProcurement = async () => {
  if (orderId.value) {
    const res = await orderStore.placeOrderForProcurement(orderId.value);
    if (res.success) {
      const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
      if (detailsRes.success && detailsRes.data) {
        orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
      }
    }
  }
};

const fulfillToInvoice = async () => {
  if (orderId.value) {
    const res = await orderStore.fulfillOrderToInvoice(orderId.value);
    if (res.success) {
      const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
      if (detailsRes.success && detailsRes.data) {
        orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
      }
    }
  }
};

const confirmDeleteOrder = () => {
  $q.dialog({
    title: 'Confirm Deletion',
    message: 'Are you sure you want to delete this order? This action is permanent and cannot be undone.',
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: 'Cancel',
      flat: true,
    }
  }).onOk(() => {
    void (async () => {
      if (orderId.value) {
        const res = await orderStore.deleteShopOrder(orderId.value);
        if (res.success) {
          void router.push({
            name: 'app-shop-orders-page',
            params: { tenantSlug: route.params.tenantSlug },
          });
        }
      }
    })();
  });
};

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

const submitStaffPricing = async () => {
  const payload = orderItems.value.map((item) => ({
    id: item.id,
    staff_offer_amount: Number(item.staff_offer_amount || 0),
    staff_offer_currency_id:
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id,
  }));

  const o = orderStore.currentOrder;
  let res;
  if (o?.status === 'submitted') {
    res = await orderStore.priceOrder(orderId.value, payload);
  } else {
    res = await orderStore.sendStaffCounter(orderId.value, payload);
  }

  if (res.success) {
    const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
    if (detailsRes.success && detailsRes.data) {
      orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
    }
  }
};

const confirmOrder = async () => {
  const res = await orderStore.confirmOrder(orderId.value);
  if (res.success) {
    const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
    if (detailsRes.success && detailsRes.data) {
      orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
    }
  }
};

const goBack = () => {
  const slug = route.params.tenantSlug;
  const tenantSlug = typeof slug === 'string' && slug ? `/${slug}` : '';
  void router.push(`${tenantSlug}/app/shop/orders`);
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
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<script lang="ts">
export default {
  name: 'StaffOrderDetailPage',
};
</script>

<style scoped>
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

.counter-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
