<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">{{ $t('shop_admin.customer_portal') }}</div>
          <h1 class="text-h5 text-weight-bold q-my-none">My Orders</h1>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            unelevated
            no-caps
            icon="ph ph-wallet"
            label="Merchant wallet"
            :to="{ name: 'shop-merchant-wallet-page' }"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
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
                <q-icon name="ph ph-magnifying-glass" />
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

      <!-- Skeleton Loading State -->
      <div v-if="isLoading">
        <q-card flat bordered class="order-table-card">
          <q-list separator class="rounded-borders">
            <q-item v-for="n in 5" :key="n" class="q-py-md q-px-md">
              <q-item-section>
                <div class="row items-center justify-between q-col-gutter-y-sm q-col-gutter-md-none">
                  <div class="col-xs-12 col-sm-5 col-md-4 column justify-center">
                    <q-skeleton type="text" width="140px" height="20px" class="q-mb-xs" />
                    <q-skeleton type="text" width="110px" height="14px" />
                  </div>
                  <div class="col-xs-12 col-sm-7 col-md-5 row items-center justify-between justify-sm-start q-gutter-x-lg-xl">
                    <div class="column">
                      <q-skeleton type="text" width="50px" height="14px" class="q-mb-xs" />
                      <q-skeleton type="text" width="65px" height="18px" />
                    </div>
                    <div class="column">
                      <q-skeleton type="text" width="60px" height="14px" class="q-mb-xs" />
                      <q-skeleton type="text" width="75px" height="18px" />
                    </div>
                  </div>
                  <div class="col-xs-12 col-md-3 row items-center justify-between justify-md-end q-gutter-x-md q-mt-xs q-mt-md-none">
                    <q-skeleton type="QBadge" width="80px" height="22px" />
                    <q-skeleton type="rect" width="50px" height="18px" class="gt-xs rounded-borders" />
                  </div>
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div
        v-else-if="isError"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="ph ph-warning-circle" size="60px" color="negative" class="q-mb-md" />
        <div class="text-h6 text-negative">Failed to load orders</div>
        <p class="text-body2 text-grey-6 q-mt-sm q-mb-md">
          {{ error?.message || 'An error occurred while fetching your orders.' }}
        </p>
      </div>

      <div
        v-else-if="filteredOrders.length === 0"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="ph ph-receipt" size="80px" color="grey-4" class="q-mb-md" />
        <div class="text-h6 text-grey-6">{{ $t('shop_admin.no_orders_yet') }}</div>
        <p class="text-body2 text-grey-5 q-mt-sm q-mb-md">
          {{ $t('shop_admin.no_orders_hint') }}
        </p>
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Browse Wholesale Shops"
          @click="goBrowse"
        />
      </div>

      <div v-else class="column q-gutter-md">
        <q-card flat bordered class="order-table-card">
          <q-list separator class="rounded-borders">
            <q-item
              v-for="order in filteredOrders"
              :key="order.id"
              clickable
              v-ripple
              class="q-py-md q-px-md order-item"
              @click="goToOrderDetails(order.id)"
            >
              <q-item-section>
                <div class="row items-center justify-between q-col-gutter-y-sm q-col-gutter-md-none">
                  <!-- Order Identifier & Date -->
                  <div class="col-xs-12 col-sm-5 col-md-4 column justify-center">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">
                      {{ order.order_no }}
                    </span>
                    <span class="text-caption text-grey-6">
                      {{ $t('shop_admin.placed_on') }} {{ formatDate(order.created_at) }}
                    </span>
                  </div>

                  <!-- Details (Items & Total) -->
                  <div class="col-xs-12 col-sm-7 col-md-5 row items-center justify-between justify-sm-start q-gutter-x-lg-xl">
                    <div class="column">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.items_count') }}</span>
                      <span class="text-body2 text-weight-bold text-grey-8">{{
                        $t('shop_admin.items_count_value', { count: order.item_count })
                      }}</span>
                    </div>
                    <div class="column">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.total_amount') }}</span>
                      <span class="text-body2 text-weight-bold text-primary">
                        {{ getCurrencySymbol(order) }}{{ Number(order.total_amount || 0).toFixed(2) }}
                      </span>
                    </div>
                  </div>

                  <!-- Status Badge & Chevron Action -->
                  <div class="col-xs-12 col-md-3 row items-center justify-between justify-md-end q-gutter-x-md q-mt-xs q-mt-md-none">
                    <q-badge
                      :color="getStatusColor(order.status)"
                      text-color="white"
                      class="status-badge text-weight-bold q-py-xs q-px-sm"
                    >
                      {{ order.status.toUpperCase() }}
                    </q-badge>
                    <div class="row items-center text-grey-6 action-arrow">
                      <span class="text-caption text-weight-medium gt-xs q-mr-xs text-primary label-view">
                        View
                      </span>
                      <q-icon name="ph ph-caret-right" size="18px" />
                    </div>
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
import { ref, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import {
  useCustomerOrdersQuery,
  useShopCurrenciesMapQuery,
} from '../composables/useCustomerOrdersQuery';
import { date } from 'quasar';

const route = useRoute();
const router = useRouter();
const storefrontStore = useShopStorefrontStore();

const currentShopId = computed<number>(
  () => storefrontStore.shopDetails?.id ?? Number(localStorage.getItem('last_visited_shop_id') || 0),
);

const { data: rawOrders, isLoading, isError, error } = useCustomerOrdersQuery(currentShopId);
const orders = computed(() => rawOrders.value ?? []);

const uniqueShopIds = computed<number[]>(() => {
  const ids = orders.value.map((o: { shop_id?: number }) => o.shop_id).filter(Boolean) as number[];
  return [...new Set(ids)];
});

const { data: shopCurrenciesData } = useShopCurrenciesMapQuery(uniqueShopIds);
const shopCurrenciesMap = computed(() => shopCurrenciesData.value ?? {});

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value ?? []);

const getCurrencySymbol = (order: { shop_id?: number }) => {
  const shopId = order.shop_id;
  if (shopId && shopCurrenciesMap.value[shopId]) {
    const currId = shopCurrenciesMap.value[shopId];
    const curr = currencies.value.find((c) => c.id === currId);
    if (curr?.symbol) return curr.symbol;
  }
  return '৳';
};

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
  let list = orders.value;

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    list = list.filter((o: { order_no?: string }) => o.order_no?.toLowerCase().includes(q));
  }

  if (statusFilter.value !== 'all') {
    if (statusFilter.value === 'pending') {
      list = list.filter((o: { status: string }) => o.status === 'pending' || o.status === 'draft');
    } else if (statusFilter.value === 'approved') {
      list = list.filter(
        (o: { status: string }) =>
          o.status === 'approved' || o.status === 'confirmed' || o.status === 'priced',
      );
    } else {
      list = list.filter((o: { status: string }) => o.status === statusFilter.value);
    }
  }

  return list;
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
.order-table-card {
  border-radius: 12px;
  background: #ffffff;
  box-shadow: var(--bw-theme-shadow, 0 2px 8px rgba(0, 0, 0, 0.04));
}

.order-item {
  transition: background-color 0.15s ease;
}

.order-item:hover {
  background-color: rgba(0, 0, 0, 0.015);
}

.order-item:hover .action-arrow {
  color: var(--q-primary) !important;
  transform: translateX(2px);
}

.action-arrow {
  transition: transform 0.15s ease, color 0.15s ease;
}

.status-badge {
  border-radius: 6px;
  letter-spacing: 0.3px;
  font-size: 11px;
}

.empty-state {
  min-height: 400px;
}
</style>
