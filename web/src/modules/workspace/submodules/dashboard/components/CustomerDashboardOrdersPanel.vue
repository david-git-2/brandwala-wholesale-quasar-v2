<template>
  <q-card flat class="shop-home-card shop-home-orders-panel q-pa-md">
    <header class="shop-home-orders-panel__header">
      <h2 class="shop-home-orders-panel__title q-my-none">
        {{ $t('customer_dashboard.recent_orders_title') }}
      </h2>
      <router-link
        class="shop-home-orders-panel__link"
        :to="ordersListRoute"
      >
        {{ $t('customer_dashboard.view_all_link') }}
      </router-link>
    </header>

    <CustomerDashboardStatusStrip
      :segments="segments"
      :orders-route="ordersListRoute"
      class="q-mt-md"
    />

    <CustomerOrdersList
      class="q-mt-md"
      layout="dashboard"
      :orders="displayOrders"
      :empty-label="$t('customer_dashboard.no_recent_orders')"
      :show-pricing-badge="false"
      :show-copy-button="false"
      @select="goToOrderDetails"
    />
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { getLastShopTypePath } from 'src/modules/shop_order/utils/catalogShop';
import CustomerOrdersList, {
  type CustomerOrderListRow,
} from 'src/modules/shop_order/components/CustomerOrdersList.vue';
import type { CustomerDashboardRecentOrder, OrderGlanceSegments } from '../types/customerDashboard';
import CustomerDashboardStatusStrip from './CustomerDashboardStatusStrip.vue';

const props = defineProps<{
  segments: OrderGlanceSegments | null;
  recentOrders: CustomerDashboardRecentOrder[];
}>();

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const shopTypeParam = computed(() => {
  if (typeof route.params.shopType === 'string') {
    return route.params.shopType;
  }
  return getLastShopTypePath(authStore.tenantId);
});

const ordersListRoute = computed(() => ({
  name: 'shop-orders-page',
  params: {
    tenantSlug: authStore.tenantSlug ?? '',
    shopType: shopTypeParam.value,
  },
}));

const displayOrders = computed(() =>
  props.recentOrders.slice(0, 5).map((order) => ({
    id: order.id,
    order_no: order.order_no,
    shop_name: order.shop_name,
    shop_id: order.shop_id,
    shop_slug: order.shop_slug,
    status: order.status,
    created_at: order.created_at,
  })),
);

const goToOrderDetails = (order: CustomerOrderListRow) => {
  void router.push({
    name: 'shop-order-detail-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? '',
      shopType: shopTypeParam.value,
      id: String(order.id),
    },
  });
};
</script>
