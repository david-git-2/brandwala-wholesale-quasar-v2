<template>
  <q-page class="bw-page theme-shop">
    <div class="q-gutter-y-md">
      <CustomerDashboardSkeleton v-if="dashboardQuery.isLoading.value" />

      <q-banner v-else-if="dashboardError" class="bw-status-banner bg-negative text-white" rounded>
        {{ dashboardError }}
      </q-banner>

      <template v-else>
        <CustomerDashboardHero
          :tenant-name="tenantName"
          :total-products="totalProducts"
          :total-brands="totalBrands"
        />

        <div
          v-if="shops.length === 0"
          class="column items-center justify-center q-pa-xl text-center empty-state-block floating-surface"
        >
          <q-icon name="ph ph-storefront" size="56px" color="grey-4" class="q-mb-sm" />
          <div class="text-subtitle1 text-weight-bold">{{ $t('customer_dashboard.no_shops_title') }}</div>
          <p class="text-body2 text-grey-6 q-mb-none">{{ $t('customer_dashboard.no_shops_sub') }}</p>
        </div>

        <CustomerDashboardShopsGrid
          v-else
          :shops="shops"
          @open-shop="openShop"
        />

        <CustomerDashboardCategories
          v-if="shops.length > 0 && categories.length > 0"
          :categories="categories"
        />

        <section v-if="shops.length > 0" class="shop-home-section q-gutter-y-md">
          <h2 class="shop-home-section__title q-my-none">
            {{ $t('customer_dashboard.glance_title') }}
          </h2>

          <CustomerDashboardStatusStrip :segments="orderSegments" />

          <CustomerDashboardRecentOrders :recent-orders="recentOrders" />
        </section>
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
  shopCatalogPath,
} from 'src/modules/shop_order/utils/catalogShop';
import { useCustomerDashboardQuery } from '../composables/useCustomerDashboardQuery';

import CustomerDashboardHero from '../components/CustomerDashboardHero.vue';
import CustomerDashboardShopsGrid from '../components/CustomerDashboardShopsGrid.vue';
import CustomerDashboardCategories from '../components/CustomerDashboardCategories.vue';
import CustomerDashboardRecentOrders from '../components/CustomerDashboardRecentOrders.vue';
import CustomerDashboardSkeleton from '../components/CustomerDashboardSkeleton.vue';
import CustomerDashboardStatusStrip from '../components/CustomerDashboardStatusStrip.vue';

const authStore = useAuthStore();
const router = useRouter();

const tenantName = computed(
  () => authStore.tenant?.name || authStore.selectedTenant?.name || 'Shop',
);
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
const dashboard = computed(() => dashboardQuery.data.value);
const dashboardError = computed(() => (dashboardQuery.error.value as Error | null)?.message || null);

const shops = computed(() => dashboard.value?.shops ?? []);
const categories = computed(() => dashboard.value?.categories ?? []);
const orderSegments = computed(() => dashboard.value?.order_glance.segments ?? null);
const recentOrders = computed(() => dashboard.value?.recent_orders ?? []);
const totalProducts = computed(() => dashboard.value?.catalog_glance.total_products ?? 0);
const totalBrands = computed(() => dashboard.value?.catalog_glance.total_brands ?? 0);

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

</script>
