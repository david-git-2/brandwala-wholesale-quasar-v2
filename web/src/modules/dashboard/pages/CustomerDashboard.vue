<template>
  <q-page class="q-pa-md bw-page theme-shop">
    <div class="q-gutter-y-md">
      <CustomerDashboardSkeleton v-if="shopsQuery.isLoading.value" />

      <q-banner v-else-if="shopsError" class="bw-status-banner bg-negative text-white" rounded>
        {{ shopsError }}
      </q-banner>

      <template v-else>
        <CustomerDashboardHero :customer-name="customerName" />

        <CustomerDashboardStatusStrip
          v-if="shops.length > 0"
          :glance="glance"
          :loading="ordersQuery.isLoading.value"
          @select-bucket="goOrders"
        />

        <div
          v-if="shops.length === 0"
          class="column items-center justify-center q-pa-xl text-center empty-state-block floating-surface"
        >
          <q-icon name="ph ph-storefront" size="56px" color="grey-4" class="q-mb-sm" />
          <div class="text-subtitle1 text-weight-bold">{{ $t('customer_dashboard.no_shops_title') }}</div>
          <p class="text-body2 text-grey-6 q-mb-none">{{ $t('customer_dashboard.no_shops_sub') }}</p>
        </div>

        <CustomerDashboardResumeRow
          v-else
          v-model:searchQuery="searchQuery"
          :continue-shop="continueShop"
          :cart-item-count="resumeCartCount"
          :show-search="true"
          @continue="openContinueShop"
          @search="triggerSearch"
          @go-cart="goCart"
        />

        <CustomerDashboardShopsGrid
          v-if="shops.length > 1"
          :shops="shops"
          :last-visited-shop-id="lastVisitedShopId"
          @open-shop="openShop"
        />

        <CustomerDashboardRecentOrders
          v-if="shops.length > 0"
          :recent-orders="recentOrders"
          :loading="ordersQuery.isLoading.value"
          :error="ordersError"
          @go-orders="goOrders"
          @view-order-detail="viewOrderDetail"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerShopsQuery } from 'src/modules/shop_order/composables/useShopQuery';
import { useCustomerDashboardOrdersQuery } from 'src/modules/shop_order/composables/useCustomerOrdersQuery';
import { useActiveShopCartsQuery } from 'src/modules/shop_order/composables/useActiveShopCartsQuery';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import {
  getLastVisitedShopId,
  rememberCatalogShop,
  resolveCartShopId,
  shopCartPath,
  shopCatalogPath,
} from 'src/modules/shop_order/utils/catalogShop';
import { countOrderGlance, isWaitingStatus, type OrderGlanceBucket } from '../utils/customerDashboardStatus';

import CustomerDashboardHero from '../components/CustomerDashboardHero.vue';
import CustomerDashboardResumeRow from '../components/CustomerDashboardResumeRow.vue';
import CustomerDashboardShopsGrid from '../components/CustomerDashboardShopsGrid.vue';
import CustomerDashboardRecentOrders from '../components/CustomerDashboardRecentOrders.vue';
import CustomerDashboardSkeleton from '../components/CustomerDashboardSkeleton.vue';
import CustomerDashboardStatusStrip from '../components/CustomerDashboardStatusStrip.vue';

const authStore = useAuthStore();
const router = useRouter();

const customerName = computed(
  () => authStore.member?.name || authStore.user?.fullName || 'Valued Customer',
);
const tenantBase = computed(() => (authStore.tenantSlug ? `/${authStore.tenantSlug}/shop` : '/shop'));
const tenantId = computed(() => authStore.tenantId ?? null);

const searchQuery = ref('');
const lastVisitedShopId = ref<string | null>(null);

watch(
  tenantId,
  (id) => {
    lastVisitedShopId.value = getLastVisitedShopId(id);
  },
  { immediate: true },
);

const shopsQuery = useCustomerShopsQuery(tenantId);
const shops = computed(() => shopsQuery.data.value ?? []);
const shopsError = computed(() => (shopsQuery.error.value as Error | null)?.message || null);

const ordersQuery = useCustomerDashboardOrdersQuery();
const glanceOrders = computed(() =>
  (ordersQuery.data.value ?? []).filter((order) => order.status !== 'draft'),
);
const glance = computed(() => countOrderGlance(glanceOrders.value));
const recentOrders = computed(() => {
  const rows = [...glanceOrders.value];
  rows.sort((a, b) => {
    const aWait = isWaitingStatus(a.status) ? 0 : 1;
    const bWait = isWaitingStatus(b.status) ? 0 : 1;
    return aWait - bWait;
  });
  return rows.slice(0, 3);
});
const ordersError = computed(() => (ordersQuery.error.value as Error | null)?.message || null);

const continueShop = computed<CustomerAccessibleShop | null>(() => {
  const lastId = lastVisitedShopId.value;
  if (lastId) {
    const match = shops.value.find((shop) => String(shop.id) === lastId);
    if (match) return match;
  }
  if (shops.value.length === 1) return shops.value[0] ?? null;
  return null;
});

const cartsQuery = useActiveShopCartsQuery();
const resumeCartCount = computed(() => {
  const shopId = continueShop.value?.id;
  if (!shopId) return 0;
  const cart = (cartsQuery.data.value ?? []).find((c) => c.shop_id === shopId);
  return cart?.item_count ?? 0;
});

const searchTargetShop = computed(() => continueShop.value ?? shops.value[0] ?? null);

const rememberShop = (shop: CustomerAccessibleShop) => {
  if (tenantId.value) {
    rememberCatalogShop(tenantId.value, shop);
  }
  lastVisitedShopId.value = String(shop.id);
};

const browsePath = (shop?: CustomerAccessibleShop | null, query?: string) => {
  if (shop?.slug) {
    return shopCatalogPath(authStore.tenantSlug, shop.slug, query);
  }
  return { path: `${tenantBase.value}/browse` };
};

const openShop = (shop: CustomerAccessibleShop) => {
  if (!shop?.slug) return;
  rememberShop(shop);
  void router.push(browsePath(shop));
};

const openContinueShop = () => {
  if (continueShop.value) openShop(continueShop.value);
};

const triggerSearch = () => {
  const queryText = searchQuery.value.trim();
  if (!queryText || !searchTargetShop.value) return;
  rememberShop(searchTargetShop.value);
  void router.push(browsePath(searchTargetShop.value, queryText));
};

const goCart = () => {
  const shopId =
    continueShop.value?.id ??
    resolveCartShopId(tenantId.value, cartsQuery.data.value ?? []);
  void router.push(shopCartPath(authStore.tenantSlug, shopId));
};

const goOrders = (bucket?: OrderGlanceBucket) => {
  void router.push({
    path: `${tenantBase.value}/orders`,
    query: bucket ? { bucket } : {},
  });
};

const viewOrderDetail = (orderId: number) => {
  void router.push(`${tenantBase.value}/orders/${orderId}`);
};
</script>
