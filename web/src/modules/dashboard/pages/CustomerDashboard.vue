<template>
  <q-page class="tf-page theme-shop shop-home-page">
    <div class="shop-home-page__inner q-gutter-y-md">
      <CustomerDashboardSkeleton v-if="dashboardQuery.isLoading.value" />

      <q-banner v-else-if="dashboardError" class="tf-status-banner bg-negative text-white" rounded>
        {{ dashboardError }}
      </q-banner>

      <template v-else>
        <CustomerDashboardQuickAction @start="startNewOrder" />

        <CustomerDashboardTopSection
          :total-products="totalProducts"
          :total-brands="totalBrands"
          :total-orders-placed="orderGlanceTotal"
          :shops="shops"
          :shop-stats="shopStats"
          @open-shop="openShop"
        />

        <CustomerDashboardCategories
          v-if="shops.length > 0 && categories.length > 0"
          :categories="categories"
        />

        <CustomerDashboardOrdersPanel
          v-if="shops.length > 0"
          :segments="orderSegments"
          :recent-orders="recentOrders"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import {
  getLastVisitedShopId,
  rememberCatalogShop,
  resolveCatalogShop,
  shopCatalogEntryPath,
  shopCatalogPath,
} from 'src/modules/shop_order/utils/catalogShop';
import { useCustomerDashboardQuery } from '../composables/useCustomerDashboardQuery';
import { useCustomerShopPortalStatsQuery } from '../composables/useCustomerShopPortalStatsQuery';
import { buildShopPortalStats } from '../utils/shopPortalStats';

import CustomerDashboardQuickAction from '../components/CustomerDashboardQuickAction.vue';
import CustomerDashboardTopSection from '../components/CustomerDashboardTopSection.vue';
import CustomerDashboardCategories from '../components/CustomerDashboardCategories.vue';
import CustomerDashboardOrdersPanel from '../components/CustomerDashboardOrdersPanel.vue';
import CustomerDashboardSkeleton from '../components/CustomerDashboardSkeleton.vue';

const authStore = useAuthStore();
const router = useRouter();

const tenantBase = computed(() => (authStore.tenantSlug ? `/${authStore.tenantSlug}/shop` : '/shop'));
const tenantId = computed(() => authStore.tenantId ?? null);

const lastVisitedShopId = ref<string | null>(null);

watch(
  tenantId,
  (id) => {
    lastVisitedShopId.value = getLastVisitedShopId(id);
  },
  { immediate: true },
);

const dashboardQuery = useCustomerDashboardQuery(tenantId);
const portalStatsQuery = useCustomerShopPortalStatsQuery(tenantId);

const dashboard = computed(() => dashboardQuery.data.value);
const dashboardError = computed(() => (dashboardQuery.error.value as Error | null)?.message || null);

const shops = computed(() => dashboard.value?.shops ?? []);
const categories = computed(() => dashboard.value?.categories ?? []);
const orderSegments = computed(() => dashboard.value?.order_glance.segments ?? null);
const orderGlanceTotal = computed(() => orderSegments.value?.total ?? 0);
const recentOrders = computed(() => dashboard.value?.recent_orders ?? []);
const totalProducts = computed(() => dashboard.value?.catalog_glance.total_products ?? 0);
const totalBrands = computed(() => dashboard.value?.catalog_glance.total_brands ?? 0);

const shopStats = computed(() =>
  buildShopPortalStats(
    shops.value,
    dashboard.value?.active_carts ?? [],
    portalStatsQuery.data.value ?? [],
  ),
);

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

const startNewOrder = () => {
  const shop = resolveCatalogShop(tenantId.value, shops.value);
  if (shop?.slug) {
    rememberShop(shop);
    void router.push(shopCatalogPath(authStore.tenantSlug, shop.slug));
    return;
  }
  void router.push(shopCatalogEntryPath(authStore.tenantSlug));
};

</script>
