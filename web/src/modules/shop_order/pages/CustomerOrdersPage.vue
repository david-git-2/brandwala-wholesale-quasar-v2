<template>
  <q-page class="q-pa-md customer-orders-page">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">{{ $t('shop_admin.customer_portal') }}</div>
          <h1 class="text-h5 text-weight-bold q-my-none">My Orders</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.my_orders_subtitle') }}
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            class="pill-btn"
            label="Browse Wholesale Shops"
            @click="goBrowse"
          />
        </div>
      </section>

      <!-- Toolbar Card -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-xs-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              clearable
              placeholder="Search order no..."
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-xs-12 col-sm-6 col-md-3">
            <q-select
              v-model="statusFilter"
              dense
              outlined
              emit-value
              map-options
              :options="statusOptions"
              label="Filter Status"
            />
          </div>
        </div>
      </q-card>

      <!-- Content -->
      <div v-if="orderStore.loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_orders') }}</div>
      </div>

      <div
        v-else-if="filteredOrders.length === 0"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="receipt_long" size="80px" color="grey-4" class="q-mb-md" />
        <div class="text-h6 text-grey-6">{{ $t('shop_admin.no_orders_yet') }}</div>
        <p class="text-body2 text-grey-5 q-mt-sm q-mb-md">
          {{ $t('shop_admin.no_orders_hint') }}
        </p>
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Browse Wholesale Shops"
          class="pill-btn"
          @click="goBrowse"
        />
      </div>

      <div v-else class="column q-gutter-md">
        <q-card flat bordered class="order-table-card">
          <q-list separator>
            <q-item v-for="order in filteredOrders" :key="order.id" class="q-py-md">
              <q-item-section>
                <div class="row items-center justify-between q-col-gutter-sm">
                  <!-- Order Identifier -->
                  <div class="col-xs-12 col-sm-4 column">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{
                      order.order_no
                    }}</span>
                    <span class="text-caption text-grey-6">
                      {{ $t('shop_admin.placed_on') }} {{ formatDate(order.created_at) }}
                    </span>
                  </div>

                  <!-- Details (Qty & Total) -->
                  <div class="col-xs-12 col-sm-4 row items-center q-gutter-x-lg">
                    <div class="column">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.items_count') }}</span>
                      <span class="text-body2 text-weight-bold text-grey-8">{{
                        $t('shop_admin.items_count_value', { count: order.item_count })
                      }}</span>
                    </div>
                    <div class="column">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.total_amount') }}</span>
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
                      :label="$t('shop_admin.view_details')"
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
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { date } from 'quasar';

const route = useRoute();
const router = useRouter();
const orderStore = useShopOrderStore();
const storefrontStore = useShopStorefrontStore();

const searchQuery = ref('');
const statusFilter = ref('all');

const statusOptions = [
  { label: 'All Statuses', value: 'all' },
  { label: 'Pending / Draft', value: 'pending' },
  { label: 'Submitted', value: 'submitted' },
  { label: 'Negotiating', value: 'negotiating' },
  { label: 'Approved / Confirmed', value: 'approved' },
  { label: 'Shipped', value: 'shipped' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Cancelled', value: 'cancelled' },
];

const filteredOrders = computed(() => {
  let list = orderStore.orders || [];

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    list = list.filter((o: any) => o.order_no?.toLowerCase().includes(q));
  }

  if (statusFilter.value !== 'all') {
    if (statusFilter.value === 'pending') {
      list = list.filter((o: any) => o.status === 'pending' || o.status === 'draft');
    } else if (statusFilter.value === 'approved') {
      list = list.filter((o: any) => o.status === 'approved' || o.status === 'confirmed' || o.status === 'priced');
    } else {
      list = list.filter((o: any) => o.status === statusFilter.value);
    }
  }

  return list;
});

const getShopId = (): number => {
  return storefrontStore.shopDetails?.id ?? Number(localStorage.getItem('last_visited_shop_id'));
};

onMounted(async () => {
  const shopId = getShopId();
  if (shopId) {
    await orderStore.fetchCustomerOrders(shopId);
  }
});

const goBrowse = () => {
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
    case 'pending':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'approved':
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'ready_for_pickup':
      return 'indigo-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'returned':
      return 'deep-orange-8';
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
