<template>
  <div>
    <h2 class="shop-home-section__title q-my-none q-mb-sm">
      {{ $t('customer_dashboard.recent_orders_title') }}
    </h2>

    <CustomerOrdersList
      :orders="displayOrders"
      :empty-label="$t('customer_dashboard.no_recent_orders')"
      :show-pricing-badge="false"
      @select="goToOrderDetails"
    />

    <div class="row justify-center q-mt-sm">
      <q-btn
        unelevated
        no-caps
        dense
        class="recent-orders-cta"
        :label="$t('customer_dashboard.view_all_orders')"
        :to="ordersListRoute"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { getLastShopTypePath } from 'src/modules/shop_order/utils/catalogShop';
import CustomerOrdersList, {
  type CustomerOrderListRow,
} from 'src/modules/shop_order/components/CustomerOrdersList.vue';
import type { CustomerDashboardRecentOrder } from '../types/customerDashboard';

const props = defineProps<{
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

const displayOrders = computed(() => props.recentOrders.slice(0, 5));

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

<style scoped>
.recent-orders-cta {
  border-radius: var(--tf-radius-sm) !important;
  background: var(--tf-shop-blue) !important;
  color: var(--tf-shop-paper) !important;
  font-weight: 600;
  padding: 0.45rem 1rem;
}
</style>
