<template>
  <q-page class="q-pa-md customer-orders-page">
    <div class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Customer Portal</div>
          <h1 class="text-h5 text-weight-bold q-my-none">My Orders</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Track status, view items, and negotiate pricing for your active storefront orders.
          </p>
        </div>
      </section>

      <!-- Content -->
      <div v-if="orderStore.loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">Loading orders...</div>
      </div>

      <div
        v-else-if="orderStore.orders.length === 0"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="receipt_long" size="80px" color="grey-4" class="q-mb-md" />
        <div class="text-h6 text-grey-6">No Orders Placed Yet</div>
        <p class="text-body2 text-grey-5 q-mt-sm q-mb-md">
          Browse the catalog, add items to your cart, and place an order to get started. p
        </p>
        <q-btn
          color="primary"
          no-caps
          label="Go Browse Catalog"
          class="pill-btn"
          @click="goToStorefront"
        />
      </div>

      <div v-else class="column q-gutter-md">
        <q-card flat bordered class="order-table-card">
          <q-list separator>
            <q-item v-for="order in orderStore.orders" :key="order.id" class="q-py-md">
              <q-item-section>
                <div class="row items-center justify-between q-col-gutter-sm">
                  <!-- Order Identifier -->
                  <div class="col-xs-12 col-sm-4 column">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{
                      order.order_no
                    }}</span>
                    <span class="text-caption text-grey-6">
                      Placed on: {{ formatDate(order.created_at) }}
                    </span>
                  </div>

                  <!-- Details (Qty & Total) -->
                  <div class="col-xs-12 col-sm-4 row items-center q-gutter-x-lg">
                    <div class="column">
                      <span class="text-caption text-grey-6">Items Count</span>
                      <span class="text-body2 text-weight-bold text-grey-8"
                        >{{ order.item_count }} items</span
                      >
                    </div>
                    <div class="column">
                      <span class="text-caption text-grey-6">Total Amount</span>
                      <span class="text-body2 text-weight-bold text-primary">
                        £{{ Number(order.total_amount || 0).toFixed(2) }}
                      </span>
                    </div>
                  </div>

                  <!-- Status & Action -->
                  <div class="col-xs-12 col-sm-4 row items-center justify-end q-gutter-x-md">
                    <q-badge
                      :color="getStatusColor(order.status)"
                      text-color="white"
                      class="status-badge text-weight-bold q-py-xs q-px-sm"
                    >
                      {{ order.status.toUpperCase() }}
                    </q-badge>
                    <q-btn
                      outline
                      color="primary"
                      no-caps
                      dense
                      label="View Details"
                      class="q-px-md pill-btn"
                      @click="goToOrderDetails(order.id)"
                    />
                  </div>
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { date } from 'quasar';

const route = useRoute();
const router = useRouter();
const orderStore = useShopOrderStore();
const storefrontStore = useShopStorefrontStore();

const getShopId = (): number => {
  return storefrontStore.shopDetails?.id ?? Number(localStorage.getItem('last_visited_shop_id'));
};

onMounted(async () => {
  const shopId = getShopId();
  if (shopId) {
    await orderStore.fetchCustomerOrders(shopId);
  }
});

const goToStorefront = () => {
  const slug = storefrontStore.shopDetails?.slug ?? localStorage.getItem('last_visited_shop_slug');
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  if (slug) {
    void router.push(`${tenantSlug}/shop/browse/${slug}`);
  } else {
    void router.push(`${tenantSlug}/shop/browse`);
  }
};

const goToOrderDetails = (orderId: number) => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/orders/${orderId}`);
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
  name: 'CustomerOrdersPage',
};
</script>

<style scoped>
.customer-orders-page {
  max-width: 1000px;
  margin: 0 auto;
}

.order-table-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.pill-btn {
  border-radius: 30px;
}

.status-badge {
  border-radius: 8px;
}

.empty-state {
  min-height: 400px;
}
</style>
