<template>
  <q-page class="tf-page theme-shop shop-home-page">
    <div class="shop-home-page__inner q-gutter-y-md">
      <CustomerDashboardSkeleton v-if="dashboardQuery.isLoading.value" />

      <q-banner v-else-if="dashboardError" class="tf-status-banner bg-negative text-white" rounded>
        {{ dashboardError }}
      </q-banner>

      <template v-else>
        <CustomerDashboardQuickAction
          :user-name="authStore.user?.fullName ?? authStore.user?.email ?? null"
          :scope-label="heroScopeLabel"
          :shop-count="shops.length"
          :has-active-carts="activeCarts.length > 0"
          :latest-cart-shop-name="latestCart?.shop_name ?? null"
          :needs-you-count="orderSegments?.needs_you ?? 0"
          :payment-needed-count="orderSegments?.payment_needed ?? 0"
          @start="startNewOrder"
          @resume-latest-cart="resumeLatestCart"
          @review-attention="reviewAttentionOrders"
        />

        <CustomerDashboardActiveCarts
          :carts="activeCarts"
          @resume-cart="resumeActiveCart"
        />

        <CustomerDashboardTopSection
          :total-products="totalProducts"
          :total-brands="totalBrands"
          :total-orders-placed="orderGlanceTotal"
          :shops="shops"
          :shop-stats="shopStats"
          @open-shop="openShop"
          @resume-cart="resumeShopCart"
          @view-shop-orders="viewShopOrders"
          @browse-catalog="browseCatalog"
          @view-orders="viewOrders"
        >
          <template #below-shops>
            <CustomerDashboardCategories
              v-if="shops.length > 0 && categories.length > 0"
              class="q-mt-md"
              :categories="categories"
              @select="openCategory"
            />
          </template>

          <template #side>
            <CustomerDashboardOrdersPanel
              v-if="shops.length > 0"
              :segments="orderSegments"
              :recent-orders="recentOrders"
            />
          </template>
        </CustomerDashboardTopSection>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import type { ActiveCartItem } from 'src/modules/shop_order/repositories/shopCartRepository';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import {
  customerShopTypeI18nKey,
  filterShopsByRouteType,
  getLastVisitedShopId,
  rememberCatalogShop,
  resolveCatalogShop,
  resolveCustomerShopTypePath,
  shopCartPath,
  shopCatalogEntryPath,
  shopCatalogPath,
  shopDropshipPlaceOrderPath,
} from 'src/modules/shop_order/utils/catalogShop';
import { shopTypeFromPathSegment, shopTypeToPathSegment } from 'src/modules/shop_order/utils/shopRouteTypes';
import { useCustomerDashboardQuery } from '../composables/useCustomerDashboardQuery';
import { useCustomerShopPortalStatsQuery } from '../composables/useCustomerShopPortalStatsQuery';
import type { CustomerDashboardCategory } from '../types/customerDashboard';
import { buildShopPortalStats } from '../utils/shopPortalStats';

import CustomerDashboardQuickAction from '../components/CustomerDashboardQuickAction.vue';
import CustomerDashboardActiveCarts from '../components/CustomerDashboardActiveCarts.vue';
import CustomerDashboardTopSection from '../components/CustomerDashboardTopSection.vue';
import CustomerDashboardCategories from '../components/CustomerDashboardCategories.vue';
import CustomerDashboardOrdersPanel from '../components/CustomerDashboardOrdersPanel.vue';
import CustomerDashboardSkeleton from '../components/CustomerDashboardSkeleton.vue';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const routeShopTypePath = computed(() =>
  resolveCustomerShopTypePath(route, authStore.tenantId),
);
const routeShopType = computed(() => shopTypeFromPathSegment(routeShopTypePath.value));

const tenantId = computed(() => authStore.tenantId ?? null);

const lastVisitedShopId = ref<string | null>(null);

watch(
  tenantId,
  (id) => {
    lastVisitedShopId.value = getLastVisitedShopId(id);
  },
  { immediate: true },
);

const dashboardQuery = useCustomerDashboardQuery(tenantId, routeShopType);
const portalStatsQuery = useCustomerShopPortalStatsQuery(tenantId, routeShopType);

const dashboard = computed(() => dashboardQuery.data.value);
const dashboardError = computed(() => (dashboardQuery.error.value as Error | null)?.message || null);

const shops = computed(() =>
  filterShopsByRouteType(dashboard.value?.shops ?? [], routeShopTypePath.value),
);
const scopedShopIds = computed(() => new Set(shops.value.map((shop) => shop.id)));
const categories = computed(() => dashboard.value?.categories ?? []);
const orderSegments = computed(() => dashboard.value?.order_glance.segments ?? null);
const orderGlanceTotal = computed(() => orderSegments.value?.total ?? 0);
const recentOrders = computed(() =>
  (dashboard.value?.recent_orders ?? []).filter((order) => scopedShopIds.value.has(order.shop_id)),
);
const activeCarts = computed(() =>
  (dashboard.value?.active_carts ?? []).filter(
    (cart) => cart.item_count > 0 && scopedShopIds.value.has(cart.shop_id),
  ),
);
const latestCart = computed(() => activeCarts.value[0] ?? null);
const totalProducts = computed(() => dashboard.value?.catalog_glance.total_products ?? 0);
const totalBrands = computed(() => dashboard.value?.catalog_glance.total_brands ?? 0);

const heroScopeLabel = computed(() => {
  const typeLabel = routeShopType.value ? t(customerShopTypeI18nKey(routeShopType.value)) : '';
  const countLabel =
    shops.value.length > 0
      ? t('customer_dashboard.accessible_shops_count', shops.value.length)
      : '';
  return [typeLabel, countLabel].filter(Boolean).join(' · ') || null;
});

const shopStats = computed(() =>
  buildShopPortalStats(
    shops.value,
    activeCarts.value,
    (portalStatsQuery.data.value ?? []).filter((order) =>
      scopedShopIds.value.has(order.shop_id),
    ),
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
    return shopCatalogPath(authStore.tenantSlug, shop.slug, query, shop.shop_type);
  }
  return shopCatalogEntryPath(
    authStore.tenantSlug,
    routeShopTypePath.value ?? 'catalog',
  );
};

const scrollToShopDirectory = () => {
  if (typeof document === 'undefined') return;
  const el = document.getElementById('shop-directory');
  el?.scrollIntoView({ behavior: 'smooth', block: 'start' });
};

const openShop = (shop: CustomerAccessibleShop) => {
  if (!shop?.slug) return;
  rememberShop(shop);
  void router.push(browsePath(shop));
};

const routeToCart = (shopId: number, shopType: ActiveCartItem['shop_type']) => {
  if (shopType === 'dropship') {
    void router.push(shopDropshipPlaceOrderPath(authStore.tenantSlug, shopId));
    return;
  }
  void router.push(shopCartPath(authStore.tenantSlug, shopId, shopType));
};

const resumeShopCart = (shop: CustomerAccessibleShop) => {
  if (!shop?.id) return;
  rememberShop(shop);
  routeToCart(shop.id, shop.shop_type);
};

const resumeActiveCart = (cart: ActiveCartItem) => {
  const matchedShop = shops.value.find((s) => s.id === cart.shop_id);
  if (matchedShop) {
    rememberShop(matchedShop);
  }
  routeToCart(cart.shop_id, cart.shop_type);
};

const resumeLatestCart = () => {
  if (!latestCart.value) return;
  resumeActiveCart(latestCart.value);
};

const viewOrders = () => {
  void router.push({
    name: 'shop-orders-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? '',
      shopType: routeShopTypePath.value ?? 'catalog',
    },
  });
};

const reviewAttentionOrders = () => {
  void router.push({
    name: 'shop-orders-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? '',
      shopType: routeShopTypePath.value ?? 'catalog',
    },
    query: { bucket: 'needs_you' },
  });
};

const viewShopOrders = (shop: CustomerAccessibleShop) => {
  const shopType = shopTypeToPathSegment(shop.shop_type) ?? routeShopTypePath.value ?? 'catalog';
  void router.push({
    name: 'shop-orders-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? '',
      shopType,
    },
  });
};

const openCategory = (category: CustomerDashboardCategory) => {
  const shop = resolveCatalogShop(tenantId.value, shops.value, routeShopType.value);
  if (shop?.slug) {
    rememberShop(shop);
    const target = shopCatalogPath(authStore.tenantSlug, shop.slug, null, shop.shop_type);
    void router.push({
      ...target,
      query: { ...target.query, category: category.name },
    });
    return;
  }
  void router.push({
    path: shopCatalogEntryPath(authStore.tenantSlug, routeShopTypePath.value ?? 'catalog'),
    query: { category: category.name },
  });
};

const browseCatalog = () => {
  if (shops.value.length > 1) {
    scrollToShopDirectory();
    return;
  }
  const shop = resolveCatalogShop(tenantId.value, shops.value, routeShopType.value);
  if (shop?.slug) {
    rememberShop(shop);
    void router.push(shopCatalogPath(authStore.tenantSlug, shop.slug, null, shop.shop_type));
    return;
  }
  void router.push(
    shopCatalogEntryPath(authStore.tenantSlug, routeShopTypePath.value ?? 'catalog'),
  );
};

const startNewOrder = () => {
  if (shops.value.length > 1) {
    scrollToShopDirectory();
    return;
  }
  browseCatalog();
};
</script>
