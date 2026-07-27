<template>
  <q-page class="q-pa-md bw-page theme-shop">
    <div class="q-gutter-y-md">
      <!-- Global Search Results Dialog -->
      <CustomerSearchResultsModal
        v-model="showSearchResultsModal"
        :executed-search-query="executedSearchQuery"
        :searching="searching"
        :search-results="searchResults"
        @select-product="goToStorefrontWithProduct"
      />

      <!-- Skeleton Loading State -->
      <CustomerDashboardSkeleton v-if="loading" />

      <!-- Error State -->
      <q-banner v-else-if="error" class="bg-negative text-white" rounded>
        {{ error }}
      </q-banner>

      <template v-else>
        <!-- 1. Hero Welcome & Search Section -->
        <CustomerDashboardHero
          v-model:searchQuery="searchQuery"
          :tenant-name="tenantName"
          :customer-name="customerName"
          @search="triggerSearch"
        />

        <!-- 3. KPI / Stat Summary Cards -->
        <CustomerDashboardStatCards
          v-if="shops.length > 0 || recentOrders.length > 0"
          :active-shops-count="shops.length"
          :recent-orders-count="recentOrders.length"
          :total-outlay="totalOutlay"
          :currency-symbol="defaultCurrencySymbol"
        />

        <!-- 4. Wholesale Shops & Categories Grid -->
        <CustomerDashboardShopsGrid
          v-if="shops.length > 0"
          :shops="shops"
          :categories="categories"
          @open-shop="openShop"
          @open-shop-category="openShopCategory"
        />

        <!-- 5. Operational Workspace (Action Hub & Recent Orders) -->
        <div class="row q-col-gutter-md q-col-gutter-md-lg">
          <!-- Left: Action Hub -->
          <div class="col-12 col-md-6">
            <CustomerDashboardActionHub
              :latest-order-label="latestOrderLabel"
              @go-browse="goBrowse"
              @go-orders="goOrders"
              @view-latest-order="viewLatestOrder"
              @go-documentation="goDocumentation"
            />
          </div>

          <!-- Right: Recent Activity / Last 3 Orders -->
          <div class="col-12 col-md-6">
            <CustomerDashboardRecentOrders
              :recent-orders="recentOrders"
              :get-currency-symbol="getCurrencySymbol"
              @go-orders="goOrders"
              @go-browse="goBrowse"
              @view-order-detail="viewOrderDetail"
            />
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderRepository } from 'src/modules/shop_order/repositories/shopOrderRepository';
import { useCustomerShopsQuery } from 'src/modules/shop_order/composables/useShopQuery';
import { useShopCategoryListQuery } from 'src/modules/shop_order/composables/useShopCategoryQuery';
import {
  useCustomerDashboardOrdersQuery,
  useShopCurrenciesMapQuery,
} from 'src/modules/shop_order/composables/useCustomerOrdersQuery';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { handleApiFailure } from 'src/utils/appFeedback';

import CustomerDashboardHero from '../components/CustomerDashboardHero.vue';
import CustomerSearchResultsModal from '../components/CustomerSearchResultsModal.vue';
import CustomerDashboardStatCards from '../components/CustomerDashboardStatCards.vue';
import CustomerDashboardShopsGrid from '../components/CustomerDashboardShopsGrid.vue';
import CustomerDashboardActionHub from '../components/CustomerDashboardActionHub.vue';
import CustomerDashboardRecentOrders from '../components/CustomerDashboardRecentOrders.vue';
import CustomerDashboardSkeleton from '../components/CustomerDashboardSkeleton.vue';

const authStore = useAuthStore();
const router = useRouter();

const tenantName = computed(() => authStore.tenant?.name ?? 'Tenant workspace');
const customerName = computed(() => authStore.member?.name || authStore.user?.fullName || 'Valued Customer');
const tenantBase = computed(() => (authStore.tenantSlug ? `/${authStore.tenantSlug}/shop` : '/shop'));
const tenantId = computed(() => authStore.tenantId ?? null);
const categoryParams = computed(() => ({ tenantId: authStore.tenantId ?? 0 }));

// Search query & modal state
const searchQuery = ref('');
const executedSearchQuery = ref('');
const showSearchResultsModal = ref(false);
const searching = ref(false);
const searchResults = ref<any[]>([]);

// 1. Fetch shops customer has access to using TanStack Query
const shopsQuery = useCustomerShopsQuery(tenantId);
const shops = computed(() => shopsQuery.data.value ?? []);

// Fetch dynamic categories via TanStack Query using shopCategoryRepository
const categoriesQuery = useShopCategoryListQuery(categoryParams);
const categories = computed(() => categoriesQuery.data.value ?? []);

// 2. Fetch orders from all accessible shops in parallel using TanStack Query
const ordersQuery = useCustomerDashboardOrdersQuery(shops);
const recentOrders = computed(() => ordersQuery.data.value ?? []);

const uniqueShopIds = computed<number[]>(() => {
  const ids = recentOrders.value.map((o: { shop_id?: number }) => o.shop_id).filter(Boolean) as number[];
  return [...new Set(ids)];
});

const { data: shopCurrenciesData } = useShopCurrenciesMapQuery(uniqueShopIds);
const shopCurrenciesMap = computed(() => shopCurrenciesData.value ?? {});

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value ?? []);

const getCurrencySymbol = (order?: { shop_id?: number }) => {
  const shopId = order?.shop_id;
  if (shopId && shopCurrenciesMap.value[shopId]) {
    const currId = shopCurrenciesMap.value[shopId];
    const curr = currencies.value.find((c) => c.id === currId);
    if (curr?.symbol) return curr.symbol;
  }
  return '৳';
};

const defaultCurrencySymbol = computed(() => {
  if (recentOrders.value.length > 0) {
    return getCurrencySymbol(recentOrders.value[0]);
  }
  return '৳';
});

const loading = computed(
  () => shopsQuery.isLoading.value || ordersQuery.isLoading.value || categoriesQuery.isLoading.value,
);
const error = computed(
  () =>
    (shopsQuery.error.value as Error | null)?.message ||
    (ordersQuery.error.value as Error | null)?.message ||
    (categoriesQuery.error.value as Error | null)?.message ||
    null,
);

const totalOutlay = computed(() => {
  return recentOrders.value.reduce((acc, order) => acc + Number(order.total_amount || 0), 0);
});

const latestOrderLabel = computed(() => {
  if (recentOrders.value.length > 0) {
    return recentOrders.value[0]?.order_no || `#${recentOrders.value[0]?.id}`;
  }
  return 'No recent orders';
});

const goBrowse = () => {
  void router.push({ path: `${tenantBase.value}/browse` });
};

const triggerSearch = async () => {
  const queryText = searchQuery.value.trim();
  if (!queryText) return;

  executedSearchQuery.value = queryText;
  showSearchResultsModal.value = true;
  searching.value = true;
  searchResults.value = [];

  try {
    const accessibleShops = shops.value;
    if (accessibleShops.length === 0) {
      searching.value = false;
      return;
    }

    const searchPromises = accessibleShops.map((shop) =>
      shopOrderRepository.browseShopCatalog(shop.slug, {
        search: queryText,
        limit: 10,
      }),
    );

    const responses = await Promise.all(searchPromises);

    const mergedProducts: any[] = [];
    responses.forEach((res, idx) => {
      if (res?.data) {
        const shop = accessibleShops[idx];
        const permissions = res.meta?.permissions;
        res.data.forEach((prod: any) => {
          mergedProducts.push({
            ...prod,
            shop_id: shop?.id,
            shop_name: shop?.name || 'Shop',
            shop_slug: shop?.slug || '',
            shop_type: shop?.shop_type || 'fixed_price',
            see_price: permissions?.see_price ?? true,
            can_add_to_cart: permissions?.can_add_to_cart ?? true,
          });
        });
      }
    });

    searchResults.value = mergedProducts;
  } catch (err: any) {
    handleApiFailure(err, err?.message || 'Search failed');
  } finally {
    searching.value = false;
  }
};

const goToStorefrontWithProduct = (item: any) => {
  showSearchResultsModal.value = false;
  if (item && item.shop_slug) {
    void router.push({
      path: `${tenantBase.value}/browse/${item.shop_slug}`,
      query: { q: item.product_name },
    });
  }
};

const openShop = (shop: any) => {
  if (!shop?.slug) return;
  localStorage.setItem('last_visited_shop_id', String(shop.id));
  localStorage.setItem('last_visited_shop_slug', shop.slug);
  void router.push({ path: `${tenantBase.value}/browse/${shop.slug}` });
};

const openShopCategory = (shop: any) => {
  if (!shop?.slug) return;
  localStorage.setItem('last_visited_shop_id', String(shop.id));
  localStorage.setItem('last_visited_shop_slug', shop.slug);
  void router.push({ path: `${tenantBase.value}/browse/${shop.slug}` });
};

const goOrders = () => {
  void router.push(`${tenantBase.value}/orders`);
};

const viewOrderDetail = (orderId: number) => {
  void router.push(`${tenantBase.value}/orders/${orderId}`);
};

const viewLatestOrder = () => {
  if (recentOrders.value.length > 0 && recentOrders.value[0]?.id) {
    viewOrderDetail(recentOrders.value[0].id);
  } else {
    goOrders();
  }
};

const goDocumentation = () => {
  void router.push(`${authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''}/app/docs`);
};
</script>
