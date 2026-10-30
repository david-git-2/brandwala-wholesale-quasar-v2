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
.recent-orders-cta {
  border-radius: var(--tf-radius-sm) !important;
  background: var(--tf-shop-blue) !important;
  color: var(--tf-shop-paper) !important;
  font-weight: 600;
  padding: 0.45rem 1rem;
}
</style>
