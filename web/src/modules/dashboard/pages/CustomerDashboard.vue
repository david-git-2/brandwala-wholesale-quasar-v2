<template>
  <q-page class="q-pa-md theme-shop">
    <div class="q-gutter-y-md">
      <!-- 1. Hero Welcome & Search Section -->
      <q-card flat class="hero-card q-pa-xl text-white relative-position overflow-hidden">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-md-7 z-index-1">
            <div class="text-overline text-blue-2 text-weight-bold tracking-wider">{{ tenantName }}</div>
            <h1 class="text-h3 text-weight-bold q-my-sm leading-tight">Welcome, {{ customerName }}</h1>
            <p class="text-subtitle1 text-blue-1 q-mb-lg opacity-90">
              Discover premium products, manage your bulk orders, and track your shipments in one unified workspace.
            </p>
            
            <!-- Global Product Search Bar -->
            <div class="search-bar-wrap">
              <q-input
                v-model="searchQuery"
                outlined
                dense
                bg-color="white"
                placeholder="Search products, brands, or categories..."
                class="search-input soft-input shadow-2"
                @keydown.enter="triggerSearch"
              >
                <template #prepend>
                  <q-icon name="search" color="grey-6" />
                </template>
                <template #append>
                  <q-btn
                    color="primary"
                    unelevated
                    no-caps
                    label="Search"
                    class="q-px-md search-btn"
                    @click="triggerSearch"
                  />
                </template>
              </q-input>
            </div>
          </div>
          
          <div class="col-12 col-md-5 z-index-1 text-right gt-sm">
            <q-icon name="storefront" size="140px" class="opacity-20 q-mr-lg" />
          </div>
        </div>
        <div class="hero-bg-overlay"></div>
      </q-card>

      <!-- Loading State -->
      <div v-if="loading" class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">Loading your dashboard...</div>
      </div>

      <!-- Error State -->
      <q-banner v-else-if="error" class="bg-negative text-white" rounded>
        {{ error }}
      </q-banner>

      <template v-else>
        <!-- 2. Onboarding Stepper Checklist (Visible to all, but collapsed for returning users) -->
        <q-card flat bordered class="onboarding-card q-pa-lg">
          <div class="row items-center justify-between q-mb-md">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center gap-xs">
                <q-icon name="explore" color="primary" size="24px" class="q-mr-xs" />
                Get Started with Brandwala Shop
              </div>
              <div class="text-caption text-grey-6">Complete these quick steps to start sourcing inventory.</div>
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
              <div class="row q-col-gutter-lg">
                <!-- Step 1 -->
                <div class="col-12 col-sm-4">
                  <div class="step-item" :class="{ 'step-item--done': true }">
                    <div class="row items-center no-wrap q-gutter-sm">
                      <q-avatar size="36px" color="green-1" text-color="green-7" icon="check" />
                      <div class="column">
                        <span class="text-subtitle2 text-weight-bold text-grey-9 leading-none">1. Account Active</span>
                        <span class="text-caption text-grey-5">Workspace ready</span>
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
                        <span class="text-subtitle2 text-weight-bold text-grey-9 leading-none">2. Explore Wholesale Shops</span>
                        <span class="text-caption text-grey-5">{{ shops.length > 0 ? 'Shops unlocked' : 'View wholesale catalog' }}</span>
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
                        <span class="text-subtitle2 text-weight-bold text-grey-9 leading-none">3. Place First Order</span>
                        <span class="text-caption text-grey-5">{{ recentOrders.length > 0 ? 'First order placed' : 'Start your first bulk order' }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </q-slide-transition>
        </q-card>

        <!-- 3. KPI / Stat Summary Cards (Only show for active/returning users with shops/orders) -->
        <div v-if="shops.length > 0 || recentOrders.length > 0" class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-card flat bordered class="stat-card q-pa-md">
              <div class="row items-center justify-between no-wrap">
                <div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Active Shops</div>
                  <div class="text-h5 text-weight-bold text-grey-9 q-mt-xs">{{ shops.length }}</div>
                </div>
                <q-avatar color="blue-1" text-color="blue-7" icon="storefront" size="48px" />
              </div>
            </q-card>
          </div>

          <div class="col-12 col-sm-4">
            <q-card flat bordered class="stat-card q-pa-md">
              <div class="row items-center justify-between no-wrap">
                <div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Recent Orders</div>
                  <div class="text-h5 text-weight-bold text-grey-9 q-mt-xs">{{ recentOrders.length }}</div>
                </div>
                <q-avatar color="green-1" text-color="green-7" icon="shopping_bag" size="48px" />
              </div>
            </q-card>
          </div>

          <div class="col-12 col-sm-4">
            <q-card flat bordered class="stat-card q-pa-md">
              <div class="row items-center justify-between no-wrap">
                <div>
                  <div class="text-caption text-grey-6 text-uppercase text-weight-bold">Active Value</div>
                  <div class="text-h5 text-weight-bold text-primary q-mt-xs">
                    £{{ totalOutlay.toFixed(2) }}
                  </div>
                </div>
                <q-avatar color="indigo-1" text-color="indigo-7" icon="receipt_long" size="48px" />
              </div>
            </q-card>
          </div>
        </div>

        <!-- 4. Category Sourcing Grid -->
        <div v-if="categories.length > 0">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Browse Wholesale Categories</div>
          <div class="row q-col-gutter-md">
            <div
              v-for="category in categories"
              :key="category.name"
              class="col-6 col-sm-4 col-md-2"
            >
              <q-card
                flat
                bordered
                class="category-card cursor-pointer card-hover text-center q-pa-md"
                @click="filterByCategory(category.name)"
              >
                <q-avatar
                  size="48px"
                  :color="category.bgColor"
                  :text-color="category.color"
                  :icon="category.icon"
                  class="q-mb-sm"
                />
                <div class="text-subtitle2 text-weight-bold text-grey-9">{{ category.name }}</div>
              </q-card>
            </div>
          </div>
        </div>

        <!-- 5. Operational Workspace (Action Hub & Recent Orders) -->
        <div class="row q-col-gutter-lg">
          <!-- Left: Action Hub -->
          <div class="col-12 col-md-6">
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Quick Navigation & Shortcuts</div>
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="goBrowse">
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="blue-1" text-color="blue-7" icon="storefront" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">Shop Catalogs</q-item-label>
                      <q-item-label caption class="text-grey-6">Browse inventory & prices</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>

              <div class="col-12 col-sm-6">
                <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="goOrders">
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="green-1" text-color="green-7" icon="receipt_long" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">My Orders</q-item-label>
                      <q-item-label caption class="text-grey-6">Track deliveries & status</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>

              <div class="col-12 col-sm-6">
                <q-card
                  flat
                  bordered
                  class="action-card cursor-pointer card-hover q-pa-md"
                  @click="recentOrders.length > 0 && recentOrders[0]?.id ? viewOrderDetail(recentOrders[0].id) : goBrowse()"
                >
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="amber-1" text-color="amber-9" icon="history" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">Latest Order</q-item-label>
                      <q-item-label caption class="text-grey-6">
                        {{ recentOrders.length > 0 ? recentOrders[0]?.order_no : 'No active orders' }}
                      </q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>

              <div class="col-12 col-sm-6">
                <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="goDocumentation">
                  <q-item class="q-pa-none">
                    <q-item-section avatar>
                      <q-avatar color="purple-1" text-color="purple-7" icon="help_outline" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">Help & Tutorials</q-item-label>
                      <q-item-label caption class="text-grey-6">Customer guides & FAQs</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-card>
              </div>
            </div>
          </div>

          <!-- Right: Recent Activity / Last 3 Orders -->
          <div class="col-12 col-md-6">
            <div class="row items-center justify-between q-mb-md">
              <span class="text-subtitle1 text-weight-bold text-grey-9">Recent Activity</span>
              <q-btn
                v-if="recentOrders.length > 0"
                flat
                no-caps
                dense
                color="primary"
                label="View All Orders"
                icon-right="chevron_right"
                @click="goOrders"
              />
            </div>

            <div v-if="recentOrders.length === 0" class="empty-orders-block q-pa-xl text-center border-dashed-1">
              <q-icon name="shopping_cart" size="48px" color="grey-3" class="q-mb-sm" />
              <div class="text-subtitle2 text-grey-6">No recent orders found</div>
              <q-btn
                unelevated
                color="primary"
                label="Browse Wholesale Catalog"
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
                        <span class="text-caption text-grey-5">{{ order.shop_name }}</span>
                      </div>
                      <div class="column text-right">
                        <span class="text-subtitle2 text-weight-bold text-primary">
                          £{{ Number(order.total_amount || 0).toFixed(2) }}
                        </span>
                        <span class="text-caption text-grey-5">{{ formatDate(order.created_at) }}</span>
                      </div>
                      <div class="q-pl-sm">
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

const authStore = useAuthStore();
const router = useRouter();

const tenantName = computed(() => authStore.tenant?.name ?? 'Tenant workspace');
const customerName = computed(() => authStore.member?.name || authStore.user?.fullName || 'Valued Customer');
const tenantBase = computed(() => authStore.tenantSlug ? `/${authStore.tenantSlug}/shop` : '/shop');

// Search query reference
const searchQuery = ref('');

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

// Fetch dynamic categories via TanStack Query
const categoriesQuery = useQuery({
  queryKey: computed(() => ['customer-shop-categories-dashboard', authStore.tenantId]),
  queryFn: async () => {
    const res = await shopOrderService.listCustomerShopCategories(authStore.tenantId!);
    if (!res.success) throw new Error(res.error);
    return res.data ?? [];
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

    // Sort by created_at desc
    allOrders.sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
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
  const activeShopSlug = shops.value[0]?.slug || localStorage.getItem('last_visited_shop_slug');
  if (activeShopSlug) {
    void router.push({ path: `${tenantBase.value}/browse/${activeShopSlug}` });
  } else {
    void router.push({ path: `${tenantBase.value}/browse` });
  }
};

const triggerSearch = () => {
  if (!searchQuery.value.trim()) return;
  const activeShopSlug = shops.value[0]?.slug || localStorage.getItem('last_visited_shop_slug');
  if (activeShopSlug) {
    void router.push({ path: `${tenantBase.value}/browse/${activeShopSlug}`, query: { q: searchQuery.value } });
  } else {
    void router.push({ path: `${tenantBase.value}/browse`, query: { q: searchQuery.value } });
  }
};

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

.category-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
  min-height: 120px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
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
