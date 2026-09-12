<template>
  <div>
    <h3 class="shop-home-section__subtitle q-my-none q-mb-sm">
      {{ $t('customer_dashboard.recent_orders_title') }}
    </h3>

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
        :to="{ name: 'shop-orders-page' }"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import CustomerOrdersList, {
  type CustomerOrderListRow,
} from 'src/modules/shop_order/components/CustomerOrdersList.vue';
import type { CustomerDashboardRecentOrder } from '../types/customerDashboard';

const props = defineProps<{
  recentOrders: CustomerDashboardRecentOrder[];
}>();

const authStore = useAuthStore();
const router = useRouter();

const displayOrders = computed(() => props.recentOrders.slice(0, 5));

const goToOrderDetails = (order: CustomerOrderListRow) => {
  const tenantSlug = authStore.tenantSlug ? `/${authStore.tenantSlug}` : '';
  void router.push(`${tenantSlug}/shop/orders/${order.id}`);
};
</script>

<style scoped>
.shop-home-section__subtitle {
  text-align: center;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--bw-shop-plum);
}

.recent-orders-cta {
  border-radius: var(--bw-radius-sm) !important;
  background: var(--bw-shop-blue) !important;
  color: var(--bw-shop-paper) !important;
  font-weight: 600;
  padding: 0.45rem 1rem;
}
</style>
