<template>
  <q-page class="bw-page theme-shop">
    <div class="bw-page__stack">
      <!-- 1. Hero Welcome & Search Section -->
      <q-card flat class="hero-card q-pa-md q-pa-sm-lg q-pa-md-xl text-white relative-position overflow-hidden">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-md-7 z-index-1">
            <div class="text-overline text-blue-2 text-weight-bold tracking-wider">{{ tenantName }}</div>
            <h1 class="text-h4 text-sm-h3 text-weight-bold q-my-xs q-my-sm-sm leading-tight">
              {{ $t('customer_dashboard.welcome', { name: customerName }) }}
            </h1>
            <p class="text-body2 text-sm-subtitle1 text-blue-1 q-mb-md q-mb-sm-lg opacity-90">
              {{ $t('customer_dashboard.welcome_sub') }}
            </p>
            
            <!-- Global Product Search Bar -->
            <div class="search-bar-wrap full-width">
              <q-input
                v-model="searchQuery"
                outlined
                dense
                bg-color="white"
                :placeholder="$t('customer_dashboard.search_placeholder')"
                class="search-input soft-input shadow-2"
                @keydown.enter="triggerSearch"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" color="grey-6" />
                </template>
                <template #append>
                  <q-btn
                    color="primary"
                    unelevated
                    no-caps
                    :label="$t('customer_dashboard.search_btn')"
                    class="q-px-md search-btn"
                    @click="triggerSearch"
                  />
                </template>
              </q-input>
            </div>
          </div>
          
          <div class="col-12 col-md-5 z-index-1 text-right gt-sm">
            <q-icon name="ph ph-storefront" size="140px" class="opacity-20 q-mr-lg" />
          </div>
        </div>
        <div class="hero-bg-overlay"></div>
      </q-card>

      <!-- Global Search Results Dialog -->
      <q-dialog v-model="showSearchResultsModal" position="top" transition-show="slide-down" transition-hide="slide-up">
        <q-card style="width: 700px; max-width: 95vw; margin-top: 20px;" class="q-pa-sm q-pa-sm-md shadow-10 rounded-lg">
          <q-card-section class="row items-center justify-between q-pb-none">
            <div>
              <div class="text-h6 text-weight-bold text-grey-9">{{ $t('customer_dashboard.search_results_title') }}</div>
              <div class="text-caption text-grey-6">
                {{ $t('customer_dashboard.search_results_sub', { query: executedSearchQuery }) }}
              </div>
            </div>
            <q-btn flat round dense icon="close" v-close-popup />
          </q-card-section>

          <q-card-section class="q-pt-md">
            <!-- Search Loading State -->
            <div v-if="searching" class="column items-center justify-center q-pa-lg text-grey-7">
              <q-spinner color="primary" size="36px" />
              <div class="q-mt-sm text-subtitle2">{{ $t('customer_dashboard.searching_catalogs') }}</div>
            </div>

            <!-- Empty Search Results State -->
            <div v-else-if="searchResults.length === 0" class="column items-center justify-center q-pa-xl text-center text-grey-6">
              <q-icon name="ph ph-magnifying-glass-minus" size="56px" color="grey-4" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-bold">{{ $t('customer_dashboard.no_products_found') }}</div>
              <div class="text-caption text-grey-5 q-mt-xs">
                {{ $t('customer_dashboard.no_products_sub') }}
              </div>
            </div>

            <!-- Product Search Results List -->
            <div v-else class="q-gutter-y-sm" style="max-height: 60vh; overflow-y: auto;">
              <q-card
                v-for="item in searchResults"
                :key="item.product_id + '-' + (item.global_stock_allocation_id || '')"
                flat
                bordered
                class="q-pa-sm card-hover cursor-pointer"
                @click="goToStorefrontWithProduct(item)"
              >
                <div class="row items-center no-wrap q-col-gutter-sm">
                  <!-- Product Image -->
                  <div class="col-auto">
                    <q-img
                      :src="item.product_image_url || '/placeholder.png'"
                      spinner-color="primary"
                      style="height: 64px; width: 64px; border-radius: 8px;"
                      fit="cover"
                      class="bg-grey-2"
                    />
                  </div>

                  <!-- Product & Shop Info -->
                  <div class="col">
                    <div class="row items-center gap-xs">
                      <q-badge color="blue-1" text-color="blue-8" class="text-weight-bold q-px-xs">
                        <q-icon name="ph ph-storefront" size="12px" class="q-mr-xs" />
                        {{ item.shop_name }}
                      </q-badge>
                      <q-badge v-if="item.product_brand" color="grey-2" text-color="grey-8" class="q-px-xs">
                        {{ item.product_brand }}
                      </q-badge>
                    </div>
                    <div class="text-subtitle2 text-weight-bold text-grey-9 line-clamp-1 q-mt-xs">
                      {{ item.product_name }}
                    </div>
                    <div class="row items-center q-gutter-x-sm text-caption text-grey-6 q-mt-xs">
                      <template v-if="item.see_price">
                        <span v-if="item.unit_price_amount != null" class="text-weight-bold text-primary">
                          <span v-if="item.shop_type === 'dropship'" class="text-caption text-grey-6 block text-weight-medium q-mb-xs" style="line-height: 1;">{{ $t('shop.wholesale_price') }}</span>
                          {{ item.unit_price_currency_symbol || '£' }}{{ Number(item.unit_price_amount).toFixed(2) }}
                        </span>
                        <span v-if="item.shop_type === 'dropship' && item.minimum_sell_price_amount != null" class="text-caption text-secondary text-weight-bold q-ml-sm">
                          {{ $t('customer_dashboard.min_sell', { price: (item.minimum_sell_price_currency_symbol || '£') + Number(item.minimum_sell_price_amount).toFixed(2) }) }}
                        </span>
                      </template>
                      <span v-if="item.available_units != null" class="q-ml-sm">
                        {{ $t('customer_dashboard.stock', { count: item.available_units }) }}
                      </span>
                    </div>
                  </div>

                </div>
              </q-card>
            </div>
          </q-card-section>
        </q-card>
      </q-dialog>

      <!-- Loading State -->
      <div v-if="loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">{{ $t('customer_dashboard.loading_dashboard') }}</div>
      </div>

      <!-- Error State -->
      <q-banner v-else-if="error" class="bg-negative text-white" rounded>
        {{ error }}
      </q-banner>

      <template v-else>
        <!-- 2. Onboarding Stepper Checklist -->
        <q-card flat bordered class="onboarding-card q-pa-md q-pa-sm-lg">
          <div class="row items-center justify-between no-wrap">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center gap-xs">
                <q-icon name="ph ph-compass" color="primary" size="24px" class="q-mr-xs" />
                {{ $t('customer_dashboard.onboarding_title') }}
              </div>
              <div class="text-caption text-grey-6">{{ $t('customer_dashboard.onboarding_sub') }}</div>
            </div>
            <q-btn
              flat
              dense
              round
              color="grey-6"
              :icon="showOnboarding ? 'expand_less' : 'expand_more'"
              @click="showOnboarding = !showOnboarding"
            />
          </div>

          <q-slide-transition>
            <div v-show="showOnboarding" class="q-pt-md">
              <div class="row q-col-gutter-md">
                <!-- Step 1 -->
                <div class="col-12 col-sm-4">
                  <div class="step-item" :class="{ 'step-item--done': true }">
                    <div class="row items-center no-wrap q-gutter-sm">
                      <q-avatar size="36px" color="green-1" text-color="green-7" icon="ph ph-check" />
                      <div class="column">
                        <span class="text-subtitle2 text-weight-bold text-grey-9 leading-none">{{ $t('customer_dashboard.step1_title') }}</span>
                        <span class="text-caption text-grey-6 q-mt-xs">{{ $t('customer_dashboard.step1_sub') }}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Step 2 -->
                <div class="col-12 col-sm-4">
                  <div class="step-item cursor-pointer card-hover" :class="{ 'step-item--done': shops.length > 0 }" @click="goBrowse">
                    <div class="row items-center no-wrap q-gutter-sm">
                      <q-avatar
                        size="36px"
                        :color="shops.length > 0 ? 'green-1' : 'blue-1'"
                        :text-color="shops.length > 0 ? 'green-7' : 'blue-7'"
                        :icon="shops.length > 0 ? 'check' : 'storefront'"
                      />
                      <div class="column">
                        <span class="text-subtitle2 text-weight-bold text-grey-9 leading-none">{{ $t('customer_dashboard.step2_title') }}</span>
                        <span class="text-caption text-grey-6 q-mt-xs">{{ shops.length > 0 ? $t('customer_dashboard.step2_unlocked') : $t('customer_dashboard.step2_view') }}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Step 3 -->
                <div class="col-12 col-sm-4">
                  <div class="step-item cursor-pointer card-hover" :class="{ 'step-item--done': recentOrders.length > 0 }" @click="goBrowse">
                    <div class="row items-center no-wrap q-gutter-sm">
                      <q-avatar
                        size="36px"
                        :color="recentOrders.length > 0 ? 'green-1' : 'purple-1'"
                        :text-color="recentOrders.length > 0 ? 'green-7' : 'purple-7'"
                        :icon="recentOrders.length > 0 ? 'check' : 'shopping_bag'"
                      />
                      <div class="column">
                        <span class="text-subtitle2 text-weight-bold text-grey-9 leading-none">{{ $t('customer_dashboard.step3_title') }}</span>
                        <span class="text-caption text-grey-6 q-mt-xs">{{ recentOrders.length > 0 ? $t('customer_dashboard.step3_placed') : $t('customer_dashboard.step3_start') }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </q-slide-transition>
        </q-card>

        <!-- 3. KPI / Stat Summary Cards -->
        <div v-if="shops.length > 0 || recentOrders.length > 0" class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-card flat bordered class="stat-card q-pa-md">
              <div class="row items-center justify-between no-wrap">
                <div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">{{ $t('customer_dashboard.kpi_active_shops') }}</div>
                  <div class="text-h5 text-weight-bold text-grey-9 q-mt-xs">{{ shops.length }}</div>
                </div>
                <q-avatar color="blue-1" text-color="blue-7" icon="ph ph-storefront" size="44px" />
              </div>
            </q-card>
          </div>

          <div class="col-12 col-sm-4">
            <q-card flat bordered class="stat-card q-pa-md">
              <div class="row items-center justify-between no-wrap">
                <div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">{{ $t('customer_dashboard.kpi_recent_orders') }}</div>
                  <div class="text-h5 text-weight-bold text-grey-9 q-mt-xs">{{ recentOrders.length }}</div>
                </div>
                <q-avatar color="green-1" text-color="green-7" icon="ph ph-tote" size="44px" />
              </div>
            </q-card>
          </div>

          <div class="col-12 col-sm-4">
            <q-card flat bordered class="stat-card q-pa-md">
              <div class="row items-center justify-between no-wrap">
                <div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">{{ $t('customer_dashboard.kpi_active_value') }}</div>
                  <div class="text-h5 text-weight-bold text-primary q-mt-xs">
                    £{{ totalOutlay.toFixed(2) }}
                  </div>
                </div>
                <q-avatar color="indigo-1" text-color="indigo-7" icon="ph ph-receipt" size="44px" />
              </div>
            </q-card>
          </div>
        </div>

        <!-- 4. Wholesale Shops & Categories Grid -->
        <div v-if="shops.length > 0">
          <div class="row items-center justify-between q-mb-sm q-mb-md-md">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shops_title') }}</div>
              <div class="text-caption text-grey-6">{{ $t('customer_dashboard.shops_sub') }}</div>
            </div>
          </div>

          <div class="row q-col-gutter-md">
            <div
              v-for="shop in shops"
              :key="shop.id"
              class="col-12 col-sm-6 col-md-4"
            >
              <q-card flat bordered class="shop-item-card q-pa-md column justify-between">
                <div>
                  <!-- Shop Title -->
                  <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md cursor-pointer" @click="openShop(shop)">
                    {{ shop.name }}
                  </div>

                  <!-- Shop Categories Cards -->
                  <div v-if="getShopCategories(shop).length > 0">
                    <div class="row q-col-gutter-sm">
                      <div
                        v-for="cat in getShopCategories(shop)"
                        :key="cat.name"
                        class="col-6"
                      >
                        <div
                          class="category-mini-card column items-center justify-center text-center q-pa-sm q-pa-sm-md cursor-pointer"
                          @click.stop="openShopCategory(shop)"
                        >
                          <q-avatar size="38px" color="blue-1" text-color="primary" class="q-mb-xs">
                            <q-icon :name="cat.icon || 'ph ph-squares-four'" size="20px" />
                          </q-avatar>
                          <span class="text-caption text-weight-bold text-grey-9 ellipsis full-width q-mt-xs">{{ cat.name }}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </q-card>
            </div>
          </div>
        </div>

        <!-- 5. Operational Workspace (Action Hub & Recent Orders) -->
        <div class="row q-col-gutter-md q-col-gutter-md-lg">
          <!-- Left: Action Hub -->
          <div class="col-12 col-md-6">
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-sm q-mb-md-md">{{ $t('customer_dashboard.shortcuts_title') }}</div>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="goBrowse">
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="blue-1" text-color="blue-7" icon="ph ph-storefront" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_catalogs_title') }}</q-item-label>
                      <q-item-label caption class="text-grey-6">{{ $t('customer_dashboard.shortcut_catalogs_sub') }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>

              <div class="col-12 col-sm-6">
                <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="goOrders">
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="green-1" text-color="green-7" icon="ph ph-receipt" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_orders_title') }}</q-item-label>
                      <q-item-label caption class="text-grey-6">{{ $t('customer_dashboard.shortcut_orders_sub') }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>

              <div class="col-12 col-sm-6">
                <q-card
                  flat
                  bordered
                  class="action-card cursor-pointer card-hover q-pa-md"
                  @click="viewLatestOrder"
                >
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="amber-1" text-color="amber-9" icon="ph ph-clock-counter-clockwise" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_latest_order_title') }}</q-item-label>
                      <q-item-label caption class="text-grey-6">
                        {{ recentOrders.length > 0 ? (recentOrders[0]?.order_no || '#' + recentOrders[0]?.id) : $t('customer_dashboard.shortcut_latest_order_no_orders') }}
                      </q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>

              <div class="col-12 col-sm-6">
                <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="goDocumentation">
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="purple-1" text-color="purple-7" icon="ph ph-question" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_help_title') }}</q-item-label>
                      <q-item-label caption class="text-grey-6">{{ $t('customer_dashboard.shortcut_help_sub') }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>
            </div>
          </div>

          <!-- Right: Recent Activity / Last 3 Orders -->
          <div class="col-12 col-md-6">
            <div class="row items-center justify-between q-mb-sm q-mb-md-md">
              <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('customer_dashboard.recent_activity') }}</span>
              <q-btn
                v-if="recentOrders.length > 0"
                flat
                no-caps
                dense
                color="primary"
                :label="$t('customer_dashboard.view_all_orders')"
                icon-right="chevron_right"
                @click="goOrders"
              />
            </div>

            <div v-if="recentOrders.length === 0" class="empty-orders-block q-pa-lg q-pa-sm-xl text-center border-dashed-1">
              <q-icon name="ph ph-shopping-cart" size="48px" color="grey-3" class="q-mb-sm" />
              <div class="text-subtitle2 text-grey-6">{{ $t('customer_dashboard.no_recent_orders') }}</div>
              <q-btn
                unelevated
                color="primary"
                :label="$t('customer_dashboard.browse_catalog')"
                no-caps
                class="q-mt-md"
                @click="goBrowse"
              />
            </div>

            <q-card v-else flat bordered class="recent-orders-card">
              <q-list separator>
                <q-item
                  v-for="order in recentOrders"
                  :key="order.id"
                  clickable
                  class="q-py-md card-hover"
                  @click="viewOrderDetail(order.id)"
                >
                  <q-item-section>
                    <div class="row items-center justify-between no-wrap q-col-gutter-sm">
                      <div class="column">
                        <span class="text-weight-bold text-grey-9">{{ order.order_no }}</span>
                        <span class="text-caption text-grey-6">{{ order.shop_name }}</span>
                      </div>
                      <div class="column text-right">
                        <span class="text-subtitle2 text-weight-bold text-primary">
                          £{{ Number(order.total_amount || 0).toFixed(2) }}
                        </span>
                        <span class="text-caption text-grey-6">{{ formatDate(order.created_at) }}</span>
                      </div>
                      <div class="q-pl-xs q-pl-sm-sm">
                        <q-badge
                          :color="getStatusColor(order.status)"
                          text-color="white"
                          class="q-py-xs q-px-sm text-weight-bold"
                          style="border-radius: 6px;"
                        >
                          {{ order.status.toUpperCase() }}
                        </q-badge>
                      </div>
                    </div>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-card>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { date } from 'quasar';
import { useQuery } from '@tanstack/vue-query';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderService } from 'src/modules/shop_order/services/shopOrderService';
import { shopCartRepository } from 'src/modules/shop_order/repositories/shopCartRepository';
import { shopCategoryRepository } from 'src/modules/shop_order/repositories/shopCategoryRepository';
import { showSuccessNotification, handleApiFailure } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const router = useRouter();

const tenantName = computed(() => authStore.tenant?.name ?? 'Tenant workspace');
const customerName = computed(() => authStore.member?.name || authStore.user?.fullName || 'Valued Customer');
const tenantBase = computed(() => authStore.tenantSlug ? `/${authStore.tenantSlug}/shop` : '/shop');

// Search query & modal state
const searchQuery = ref('');
const executedSearchQuery = ref('');
const showSearchResultsModal = ref(false);
const searching = ref(false);
const searchResults = ref<any[]>([]);
const addingToCartId = ref<number | null>(null);

// Control visibility of onboarding checklist
const showOnboarding = ref(true);

// 1. Fetch shops customer has access to using TanStack Query
const shopsQuery = useQuery({
  queryKey: computed(() => ['customer-shops-dashboard', authStore.tenantId]),
  queryFn: async () => {
    const res = await shopOrderService.listShopsForCustomer(authStore.tenantId);
    if (!res.success) throw new Error(res.error ?? 'Failed to load shops.');
    return res.data ?? [];
  },
  enabled: computed(() => !!authStore.tenantId),
});

const shops = computed(() => shopsQuery.data.value ?? []);

// Fetch dynamic categories via TanStack Query using shopCategoryRepository to get ID & icons
const categoriesQuery = useQuery({
  queryKey: computed(() => ['customer-shop-categories-dashboard', authStore.tenantId]),
  queryFn: async () => {
    if (!authStore.tenantId) return [];
    return await shopCategoryRepository.listCategories(authStore.tenantId);
  },
  enabled: computed(() => !!authStore.tenantId),
});

const categories = computed(() => categoriesQuery.data.value ?? []);

// 2. Fetch orders from all accessible shops in parallel using TanStack Query
const ordersQuery = useQuery({
  queryKey: computed(() => ['customer-orders-dashboard', shops.value.map(s => s.id)]),
  queryFn: async () => {
    if (shops.value.length === 0) return [];
    
    const ordersPromises = shops.value.map((shop) =>
      shopOrderService.fetchCustomerOrders(shop.id, { limit: 5 }),
    );
    const ordersResults = await Promise.all(ordersPromises);

    const allOrders: any[] = [];
    ordersResults.forEach((res, index) => {
      if (res.success && res.data) {
        const shop = shops.value[index];
        res.data.forEach((order) => {
          allOrders.push({
            ...order,
            shop_name: shop?.name || 'Shop',
            shop_slug: shop?.slug || '',
          });
        });
      }
    });

    // Sort by created_at desc, falling back to ID desc for latest order
    allOrders.sort(
      (a, b) =>
        (new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime()) ||
        ((Number(b.id) || 0) - (Number(a.id) || 0)),
    );
    
    return allOrders.slice(0, 3);
  },
  enabled: computed(() => shops.value.length > 0),
});

const recentOrders = computed(() => ordersQuery.data.value ?? []);

const loading = computed(() => shopsQuery.isLoading.value || ordersQuery.isLoading.value || categoriesQuery.isLoading.value);
const error = computed(() => (shopsQuery.error.value as Error | null)?.message || (ordersQuery.error.value as Error | null)?.message || (categoriesQuery.error.value as Error | null)?.message || null);

const totalOutlay = computed(() => {
  return recentOrders.value.reduce((acc, order) => acc + Number(order.total_amount || 0), 0);
});

onMounted(() => {
  // If the customer has placed orders previously, auto-collapse onboarding checklist
  if (recentOrders.value.length > 0) {
    showOnboarding.value = false;
  }
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
    // Search strictly across customer-accessible shops (filtered by customer group & assigned vendors)
    const accessibleShops = shops.value;
    if (accessibleShops.length === 0) {
      searching.value = false;
      return;
    }

    const searchPromises = accessibleShops.map((shop) =>
      shopOrderService.browseShopCatalog(shop.slug, {
        search: queryText,
        limit: 10,
      }),
    );

    const responses = await Promise.all(searchPromises);

    const mergedProducts: any[] = [];
    responses.forEach((res, idx) => {
      if (res.success && res.data?.data) {
        const shop = accessibleShops[idx];
        const permissions = res.data.meta?.permissions;
        res.data.data.forEach((prod: any) => {
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

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const quickAddToCart = async (item: any) => {
  addingToCartId.value = item.product_id;
  try {
    await shopCartRepository.addToCart(
      item.shop_id,
      item.product_id,
      item.global_stock_allocation_id || null,
      item.minimum_order_quantity || 1,
    );
    showSuccessNotification(`Added ${item.product_name} to ${item.shop_name} cart.`);
  } finally {
    addingToCartId.value = null;
  }
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const goToStorefrontWithSearch = () => {
  showSearchResultsModal.value = false;
  const activeShopSlug = searchResults.value[0]?.shop_slug || shops.value[0]?.slug || localStorage.getItem('last_visited_shop_slug');
  if (activeShopSlug) {
    void router.push({ path: `${tenantBase.value}/browse/${activeShopSlug}`, query: { q: executedSearchQuery.value } });
  } else {
    void router.push({ path: `${tenantBase.value}/browse`, query: { q: executedSearchQuery.value } });
  }
};

const goToStorefrontWithProduct = (item: any) => {
  showSearchResultsModal.value = false;
  if (item && item.shop_slug) {
    void router.push({ 
      path: `${tenantBase.value}/browse/${item.shop_slug}`, 
      query: { q: item.product_name } 
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

const getShopCategories = (shopOrId: any) => {
  const shop = typeof shopOrId === 'object' ? shopOrId : shops.value.find((s) => s.id === shopOrId);
  if (!shop) return [];
  if (shop.categories && Array.isArray(shop.categories) && shop.categories.length > 0) {
    return shop.categories;
  }
  const categoryIds = shop.category_ids;
  if (!categoryIds || !Array.isArray(categoryIds) || categoryIds.length === 0) {
    return [];
  }
  return categories.value.filter((cat: any) => categoryIds.includes(Number(cat.id)));
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const formatShopType = (type: string) => {
  switch (type) {
    case 'vendor_catalog':
      return 'Vendor Catalog';
    case 'dropship':
      return 'Dropship';
    case 'fixed_price':
      return 'Fixed Price';
    default:
      return type || 'Wholesale';
  }
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const filterByCategory = (categoryName: string) => {
  const activeShopSlug = shops.value[0]?.slug || localStorage.getItem('last_visited_shop_slug');
  if (activeShopSlug) {
    void router.push({ path: `${tenantBase.value}/browse/${activeShopSlug}`, query: { category: categoryName } });
  } else {
    void router.push({ path: `${tenantBase.value}/browse`, query: { category: categoryName } });
  }
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

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY');
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<style scoped>
.hero-card {
  background: linear-gradient(135deg, var(--q-primary) 0%, #1565c0 100%);
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
}

.hero-bg-overlay {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  background-image: radial-gradient(circle at 80% 20%, rgba(255, 255, 255, 0.15) 0%, transparent 50%);
  pointer-events: none;
}

.search-bar-wrap {
  max-width: 540px;
  width: 100%;
}

.search-input :deep(.q-field__control) {
  border-radius: 30px !important;
  padding-right: 0px !important;
}

.search-btn {
  border-radius: 0 30px 30px 0;
  height: 40px;
}

.onboarding-card {
  border-radius: 14px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
}

.step-item {
  background: var(--bw-theme-base, #f9f9f9);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
  border-radius: 10px;
  padding: 12px;
  transition: all 0.25s ease;
}

.step-item--done {
  border-color: #2e7d32;
  background: #f1f8e9;
}

.stat-card {
  border-radius: 10px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
}

.shop-item-card {
  border-radius: 14px;
  background: var(--bw-theme-surface, #ffffff);
  min-height: 160px;
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease;
}

.category-mini-card {
  border-radius: 12px;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  background: var(--bw-theme-surface, #f8fafc);
  transition: all 0.2s ease;
}

.category-mini-card:hover {
  background: #f1f5f9;
  border-color: var(--q-primary);
  transform: translateY(-1px);
}

.border-top-soft {
  border-top: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.06));
}

.action-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
}

.recent-orders-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
  overflow: hidden;
}

.empty-orders-block {
  border: 2px dashed var(--bw-theme-border, #e0e0e0);
  border-radius: 12px;
  background: var(--bw-theme-surface, rgba(0, 0, 0, 0.01));
}

.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease, border-color 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow, 0 4px 12px rgba(0, 0, 0, 0.05));
  border-color: var(--q-primary);
}

.border-dashed-1 {
  border-style: dashed !important;
}

.z-index-1 {
  position: relative;
  z-index: 1;
}

.opacity-90 {
  opacity: 0.9;
}

.opacity-20 {
  opacity: 0.2;
}

.tracking-wider {
  letter-spacing: 0.05em;
}

.leading-none {
  line-height: 1;
}

.leading-tight {
  line-height: 1.25;
}

.gap-xs {
  gap: 4px;
}
</style>
