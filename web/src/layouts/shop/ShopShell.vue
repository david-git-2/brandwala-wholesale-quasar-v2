<template>
  <q-layout
    view="hHh lpR fFf"
    class="shop-shell theme-shop"
    :class="{ 'shop-shell--chrome-hidden': chromeHidden }"
    @scroll="onLayoutScroll"
  >
    <q-header class="shop-shell__header">
      <q-toolbar class="shop-shell__toolbar">
        <div class="shop-shell__left">
          <button
            type="button"
            class="shop-shell__tenant-link"
            data-test="shop-header-tenant-link"
            @click="goHome"
          >
            <span class="shop-shell__tenant-text shop-banner-font">{{ tenantName }}</span>
          </button>

          <template v-if="showCatalogShopHeader">
            <span class="shop-shell__context-divider" aria-hidden="true" />
            <div class="shop-shell__shop-switch">
              <CatalogShopHeaderSwitcher
                :shop-name="headerShopName"
                :current-slug="headerShopSlug"
                :shops="headerCustomerShops"
                @switch-shop="onSwitchHeaderShop"
              />
            </div>
          </template>
        </div>

        <nav v-if="!$q.screen.xs" class="shop-shell__nav" aria-label="Shop">
          <q-btn
            flat
            no-caps
            dense
            class="shop-shell__labeled-btn"
            :class="{ 'shop-shell__labeled-btn--segment-active': isHomeNavActive }"
            icon="ph ph-house"
            :label="$t('navigation.dashboard')"
            data-test="shop-header-dashboard-btn"
            @click="goHome"
          />
          <q-btn
            flat
            no-caps
            dense
            class="shop-shell__labeled-btn"
            :class="{ 'shop-shell__labeled-btn--segment-active': isCatalogNavActive }"
            icon="ph ph-storefront"
            :label="$t('navigation.catalog')"
            data-test="shop-header-catalog-btn"
            @click="goToCatalog"
          />
          <q-btn
            flat
            no-caps
            dense
            class="shop-shell__labeled-btn"
            :class="{ 'shop-shell__labeled-btn--segment-active': isOrdersNavActive }"
            icon="ph ph-clipboard-text"
            :label="$t('navigation.orders')"
            data-test="shop-header-orders-btn"
            @click="goToOrders"
          />
        </nav>

        <div class="shop-shell__actions">
          <button
            v-if="showHeaderSearch && $q.screen.gt.sm"
            type="button"
            class="shop-shell__search-trigger"
            aria-label="Search products"
            data-test="shop-header-search-trigger"
            @click="searchOpen = true"
          >
            <q-icon name="ph ph-magnifying-glass" size="16px" class="shop-shell__search-trigger-icon" />
            <span class="shop-shell__search-trigger-text">{{ $t('shop.search_placeholder') }}</span>
          </button>

          <q-btn
            v-else-if="showHeaderSearch"
            flat
            round
            dense
            :ripple="false"
            class="shop-shell__icon-btn"
            aria-label="Search products"
            data-test="shop-header-search-trigger"
            @click="searchOpen = true"
          >
            <q-icon name="ph ph-magnifying-glass" size="20px" />
          </q-btn>

          <NotificationBell v-if="notificationsEnabled" scope="shop" />

          <q-btn
            v-if="canShowCartIcon && !$q.screen.xs"
            flat
            round
            dense
            :ripple="false"
            class="shop-shell__icon-btn"
            aria-label="Cart"
            @click="goToCart"
          >
            <q-icon name="ph ph-shopping-cart" size="20px" />
            <q-badge
              v-if="cartItemCount > 0"
              color="negative"
              floating
              rounded
              class="shop-shell__cart-badge"
              :label="cartItemCount"
            />
            <q-tooltip v-if="cartTooltipText">{{ cartTooltipText }}</q-tooltip>
          </q-btn>

          <UserProfileMenu
            :shop-login-group-count="loginGroups.length"
            @sign-out="openSignOutDialog"
          />
        </div>
      </q-toolbar>
    </q-header>

    <q-footer v-if="$q.screen.xs" class="shop-shell__bottom-nav" data-test="shop-bottom-nav">
      <nav class="shop-shell__bottom-nav-inner" aria-label="Shop navigation">
        <button
          type="button"
          class="shop-shell__bottom-nav-item"
          :class="{ 'shop-shell__bottom-nav-item--active': isHomeNavActive }"
          data-test="shop-bottom-nav-home"
          @click="goHome"
        >
          <span class="shop-shell__bottom-nav-icon">
            <q-icon name="ph ph-house" />
          </span>
          <span class="shop-shell__bottom-nav-label">{{ $t('navigation.dashboard') }}</span>
        </button>
        <button
          type="button"
          class="shop-shell__bottom-nav-item"
          :class="{ 'shop-shell__bottom-nav-item--active': isCatalogNavActive }"
          data-test="shop-bottom-nav-catalog"
          @click="goToCatalog"
        >
          <span class="shop-shell__bottom-nav-icon">
            <q-icon name="ph ph-storefront" />
          </span>
          <span class="shop-shell__bottom-nav-label">{{ $t('navigation.catalog') }}</span>
        </button>
        <button
          type="button"
          class="shop-shell__bottom-nav-item"
          :class="{ 'shop-shell__bottom-nav-item--active': isCartNavActive }"
          data-test="shop-bottom-nav-cart"
          @click="goToCart"
        >
          <span class="shop-shell__bottom-nav-icon">
            <q-icon name="ph ph-shopping-cart" />
            <span v-if="cartItemCount > 0" class="shop-shell__bottom-nav-badge">{{ cartItemCount }}</span>
          </span>
          <span class="shop-shell__bottom-nav-label">{{ $t('navigation.cart') }}</span>
        </button>
        <button
          type="button"
          class="shop-shell__bottom-nav-item"
          :class="{ 'shop-shell__bottom-nav-item--active': isOrdersNavActive }"
          data-test="shop-bottom-nav-orders"
          @click="goToOrders"
        >
          <span class="shop-shell__bottom-nav-icon">
            <q-icon name="ph ph-clipboard-text" />
          </span>
          <span class="shop-shell__bottom-nav-label">{{ $t('navigation.orders') }}</span>
        </button>
      </nav>
    </q-footer>

    <q-page-container
      class="shop-shell__page-container"
      :class="$q.screen.xs ? 'q-pa-xs' : 'q-pa-md'"
    >
      <slot />
    </q-page-container>

    <q-dialog
      v-if="showHeaderSearch"
      v-model="searchOpen"
      position="top"
      class="shop-shell__search-dialog"
    >
      <q-card class="shop-shell__search-card q-pa-md">
        <ShopHeaderProductSearch class="shop-shell__search shop-shell__search--mobile" />
      </q-card>
    </q-dialog>

    <q-dialog v-model="showLogoutDialog" persistent class="shop-shell__signout-dialog">
      <div class="shop-shell__signout-card">
        <div class="shop-shell__signout-identity">
          <div class="shop-shell__signout-avatar">
            <img v-if="userAvatarUrl" :src="userAvatarUrl" referrerpolicy="no-referrer" alt="" />
            <span v-else>{{ userInitials }}</span>
          </div>
          <div>
            <div class="shop-shell__signout-name">{{ userName }}</div>
            <div class="shop-shell__signout-email">{{ userEmail }}</div>
          </div>
        </div>

        <p class="shop-shell__signout-message">
          You’ll be signed out of this workspace. Your data stays safe.
        </p>

        <div class="shop-shell__signout-actions">
          <button class="shop-shell__signout-btn shop-shell__signout-btn--cancel" @click="showLogoutDialog = false">
            Stay signed in
          </button>
          <button class="shop-shell__signout-btn shop-shell__signout-btn--confirm" @click="confirmLogout">
            <q-icon name="ph ph-sign-out" size="1rem" />
            Sign out
          </button>
        </div>
      </div>
    </q-dialog>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import UserProfileMenu from 'src/components/navigation/UserProfileMenu.vue';
import NotificationBell from 'src/modules/workspace/submodules/notifications/components/NotificationBell.vue';
import { NOTIFICATIONS_ENABLED as notificationsEnabled } from 'src/modules/workspace/submodules/notifications/notificationsFeature';
import ShopHeaderProductSearch from 'src/modules/shop_order/components/ShopHeaderProductSearch.vue';
import CatalogShopHeaderSwitcher from 'src/modules/shop_order/components/CatalogShopHeaderSwitcher.vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useActiveShopCartsQuery } from 'src/modules/shop_order/composables/useActiveShopCartsQuery';
import { useShopCustomerShellQuery } from 'src/modules/shop_order/composables/useShopCustomerShellQuery';
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore';
import { clearShopOrderQueryCache } from 'src/query/queryClient';
import {
  filterShopsByRouteType,
  getLastShopTypePath,
  getLastVisitedShopId,
  rememberCatalogShop,
  resolveCartShopId,
  resolveCatalogShop,
  resolveCustomerShopTypePath,
  shopCartPath,
  shopCatalogEntryPath,
  shopCatalogPath,
  shopDropshipPlaceOrderPath,
  shopHomePath,
} from 'src/modules/shop_order/utils/catalogShop';
import { filterActiveCartsByShopTypePath } from 'src/modules/shop_order/utils/shopCartScope';
import { shopTypeFromPathSegment, shopTypeToPathSegment } from 'src/modules/shop_order/utils/shopRouteTypes';

const WORKSPACE_THEME_CLASSES = ['theme-platform', 'theme-app', 'theme-shop', 'theme-investor', 'theme-proxy'];

const props = defineProps<{
  logoutTo: string;
}>();

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const kobaCartStore = useKobaCartStore();
const shellQuery = useShopCustomerShellQuery(
  computed(() => authStore.tenantId ?? null),
  computed(() => authStore.user?.email),
);
const { data: activeCartsData } = useActiveShopCartsQuery();
const activeCarts = computed(() => activeCartsData.value ?? []);
const loginGroups = computed(() => shellQuery.data.value?.login_groups ?? []);

const showLogoutDialog = ref(false);
const searchOpen = ref(false);
const chromeHidden = ref(false);

const CATALOG_ROUTE_NAMES = new Set([
  'shop-catalog-entry-page',
  'shop-storefront-browse-page',
  'shop-storefront-product-detail-page',
]);

const ORDER_ROUTE_NAMES = new Set(['shop-orders-page', 'shop-order-detail-page']);

const CART_ROUTE_NAMES = new Set(['shop-cart-page', 'shop-checkout-page']);

const HEADER_SEARCH_ROUTE_NAMES = new Set([
  'customer-dashboard',
  ...CATALOG_ROUTE_NAMES,
  ...ORDER_ROUTE_NAMES,
  ...CART_ROUTE_NAMES,
]);

const routeName = computed(() => String(route.name ?? ''));

const showHeaderSearch = computed(() => HEADER_SEARCH_ROUTE_NAMES.has(routeName.value));

const isKobaActive = computed(() => !!(route.name && String(route.name).includes('koba')));

const isCatalogNavActive = computed(() => CATALOG_ROUTE_NAMES.has(routeName.value));

const isHomeNavActive = computed(() => routeName.value === 'customer-dashboard');

const isOrdersNavActive = computed(() => ORDER_ROUTE_NAMES.has(routeName.value));

const isCartNavActive = computed(() => {
  if (CART_ROUTE_NAMES.has(routeName.value)) {
    return true;
  }
  if (isKobaActive.value && routeName.value.includes('cart')) {
    return true;
  }
  return false;
});

const isCartRoute = computed(() => CART_ROUTE_NAMES.has(routeName.value));

const activeCartShopId = computed(() =>
  resolveCartShopId(authStore.tenantId, scopedActiveCarts.value ?? [], route.query.shopId),
);

const activeCartInfo = computed(() => {
  const shopId = activeCartShopId.value;
  if (!shopId) return null;
  return (scopedActiveCarts.value ?? []).find((cart) => cart.shop_id === shopId) ?? null;
});

const tenantName = computed(
  () => authStore.tenant?.name || authStore.selectedTenant?.name || 'Shop',
);

const customerShops = computed(() => shellQuery.data.value?.customer_shops ?? []);

const routeShopTypePath = computed(() =>
  resolveCustomerShopTypePath(route, authStore.tenantId),
);

const scopedActiveCarts = computed(() =>
  filterActiveCartsByShopTypePath(activeCarts.value, routeShopTypePath.value),
);

const routeShopType = computed(() => shopTypeFromPathSegment(routeShopTypePath.value));

const headerCustomerShops = computed(() =>
  filterShopsByRouteType(customerShops.value, routeShopTypePath.value),
);

const catalogShopSlug = computed(() => {
  const slug = route.params.shopSlug;
  return typeof slug === 'string' && slug.length > 0 ? slug : '';
});

const cartShopSlug = computed(() => {
  if (activeCartInfo.value?.shop_slug) {
    return activeCartInfo.value.shop_slug;
  }
  const shopId = activeCartShopId.value;
  if (!shopId) return '';
  return headerCustomerShops.value.find((shop) => shop.id === shopId)?.slug ?? '';
});

const cartShopName = computed(() => {
  if (activeCartInfo.value?.shop_name) {
    return activeCartInfo.value.shop_name;
  }
  const shopId = activeCartShopId.value;
  if (!shopId) return cartShopSlug.value;
  return headerCustomerShops.value.find((shop) => shop.id === shopId)?.name ?? cartShopSlug.value;
});

const rememberedShop = computed(() =>
  resolveCatalogShop(authStore.tenantId, headerCustomerShops.value, routeShopType.value),
);

const headerShopSlug = computed(() => {
  if (isCartRoute.value && cartShopSlug.value) {
    return cartShopSlug.value;
  }
  if (catalogShopSlug.value) {
    return catalogShopSlug.value;
  }
  return rememberedShop.value?.slug ?? '';
});

const headerShopName = computed(() => {
  if (isCartRoute.value && cartShopName.value) {
    return cartShopName.value;
  }
  const match = headerCustomerShops.value.find((shop) => shop.slug === headerShopSlug.value);
  return match?.name || headerShopSlug.value;
});

const showCatalogShopHeader = computed(() => {
  if (routeName.value === 'customer-dashboard') return false;
  if (routeName.value === 'shop-order-detail-page') return false;
  if (headerCustomerShops.value.length === 0) return false;
  return Boolean(headerShopSlug.value || rememberedShop.value?.slug);
});

watch(showHeaderSearch, (visible) => {
  if (!visible) {
    searchOpen.value = false;
  }
});

let lastChromeScrollY = 0;

const applyChromeFromScrollY = (y: number) => {
  if (!$q.screen.xs) {
    chromeHidden.value = false;
    lastChromeScrollY = y;
    return;
  }
  if (y <= 16) {
    chromeHidden.value = false;
  } else if (y > lastChromeScrollY + 8) {
    chromeHidden.value = true;
  } else if (y < lastChromeScrollY - 8) {
    chromeHidden.value = false;
  }
  lastChromeScrollY = y;
};

const onLayoutScroll = (info: { direction: string; position: number }) => {
  applyChromeFromScrollY(info.position);
};

const onWindowScroll = () => {
  const container = document.querySelector('.shop-shell .q-page-container');
  const containerY = container instanceof HTMLElement ? container.scrollTop : 0;
  applyChromeFromScrollY(Math.max(window.scrollY, containerY));
};

watch(
  () => route.fullPath,
  () => {
    chromeHidden.value = false;
    searchOpen.value = false;
  },
);

watch(
  () => $q.screen.xs,
  (isXs) => {
    if (!isXs) {
      chromeHidden.value = false;
    }
  },
);

const applyBodyThemeClass = () => {
  if (typeof document === 'undefined') {
    return;
  }
  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
  document.body.classList.add('theme-shop');
};

applyBodyThemeClass();

const userName = computed(
  () => authStore.user?.fullName ?? authStore.user?.email ?? 'Workspace user',
);
const userEmail = computed(() => authStore.user?.email ?? 'No active session');
const userAvatarUrl = computed(() => authStore.user?.avatarUrl ?? null);

const userInitials = computed(() => {
  const source = userName.value?.trim() || userEmail.value?.trim();
  if (!source) return '?';

  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0]?.[0] ?? ''}${parts[1]?.[0] ?? ''}`.toUpperCase();
  }

  return source.slice(0, 2).toUpperCase();
});

const scopedShopCart = computed(() => {
  const carts = scopedActiveCarts.value ?? [];
  if (isCartRoute.value && activeCartShopId.value) {
    return carts.find((c) => c.shop_id === activeCartShopId.value) ?? null;
  }
  if (isCatalogNavActive.value && headerShopSlug.value) {
    return carts.find((c) => c.shop_slug === headerShopSlug.value) ?? null;
  }
  return null;
});

const cartItemCount = computed(() => {
  if (isKobaActive.value) {
    return kobaCartStore.itemCount;
  }
  if (isCartRoute.value || (isCatalogNavActive.value && headerShopSlug.value)) {
    return Number(scopedShopCart.value?.item_count ?? 0);
  }
  return (scopedActiveCarts.value ?? []).reduce((sum, c) => sum + Number(c.item_count), 0);
});

const cartTooltipText = computed(() => {
  if (isKobaActive.value) return '';
  const nonEmpty = (scopedActiveCarts.value ?? []).filter((c) => Number(c.item_count) > 0);
  if (nonEmpty.length <= 1) return '';
  return nonEmpty.map((c) => `${c.shop_name}: ${c.item_count}`).join(' · ');
});

const canShowCartIcon = computed(() => true);

const kobaCartRouteName = computed(() => {
  const name = String(route.name ?? '');
  if (name.includes('retail')) {
    return name.includes('shop') ? 'shop-koba-retail-cart-page' : 'app-koba-retail-cart-page';
  }
  if (name.includes('wholesale') || name.includes('resale')) {
    return name.includes('shop') ? 'shop-koba-wholesale-cart-page' : 'app-koba-wholesale-cart-page';
  }
  return name.includes('shop') ? 'shop-koba-retail-cart-page' : 'app-koba-retail-cart-page';
});

const goHome = () => {
  void router.push(
    shopHomePath(
      authStore.tenantSlug,
      routeShopTypePath.value ?? getLastShopTypePath(authStore.tenantId),
    ),
  );
};

onMounted(() => {
  window.addEventListener('scroll', onWindowScroll, { passive: true });
});

onBeforeUnmount(() => {
  window.removeEventListener('scroll', onWindowScroll);
  if (typeof document === 'undefined') {
    return;
  }
  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
});

const goToCatalog = () => {
  const tenantId = authStore.tenantId;
  const cartSlug = activeCartInfo.value?.shop_slug;
  const cartShopId = activeCartInfo.value?.shop_id;
  if (cartSlug && cartShopId) {
    if (tenantId) {
      rememberCatalogShop(tenantId, { id: cartShopId, slug: cartSlug });
    }
    const cartShop = headerCustomerShops.value.find((row) => row.slug === cartSlug);
    void router.push(
      shopCatalogPath(authStore.tenantSlug, cartSlug, null, cartShop?.shop_type),
    );
    return;
  }

  const shop = resolveCatalogShop(tenantId, headerCustomerShops.value, routeShopType.value);
  if (shop?.slug) {
    if (tenantId) {
      rememberCatalogShop(tenantId, shop);
    }
    void router.push(shopCatalogPath(authStore.tenantSlug, shop.slug, null, shop.shop_type));
    return;
  }
  const entryTypePath = routeShopTypePath.value ?? 'catalog';
  void router.push(shopCatalogEntryPath(authStore.tenantSlug, entryTypePath));
};

const routeToShopCart = (
  shopId: number | null | undefined,
  shopType: ReturnType<typeof shopTypeFromPathSegment> | undefined,
) => {
  if (shopType === 'dropship') {
    return shopDropshipPlaceOrderPath(authStore.tenantSlug, shopId);
  }
  return shopCartPath(authStore.tenantSlug, shopId, shopType);
};

const onSwitchHeaderShop = (shop: { id: number; slug: string; name: string }) => {
  if (!shop.slug) return;
  const shopRow = headerCustomerShops.value.find((row) => row.id === shop.id);
  const targetShopType = shopRow?.shop_type ?? routeShopType.value;
  if (authStore.tenantId) {
    rememberCatalogShop(authStore.tenantId, shop);
  }
  if (isCartRoute.value) {
    if (shop.id === activeCartShopId.value) return;
    void router.push(routeToShopCart(shop.id, targetShopType));
    return;
  }
  if (isOrdersNavActive.value) return;
  if (shop.slug === headerShopSlug.value) return;
  void router.push(shopCatalogPath(authStore.tenantSlug, shop.slug, null, targetShopType));
};

const goToOrders = () => {
  const tenantSlug = authStore.tenantSlug;
  if (!tenantSlug) {
    void router.push('/shop/orders');
    return;
  }
  const shopTypePath =
    routeShopTypePath.value ??
    shopTypeToPathSegment(rememberedShop.value?.shop_type) ??
    'catalog';
  void router.push({
    name: 'shop-orders-page',
    params: { tenantSlug, shopType: shopTypePath },
  });
};

const goToCart = async () => {
  if (isKobaActive.value) {
    const targetRoute = kobaCartRouteName.value;
    if (router.hasRoute(targetRoute)) {
      await router.push({ name: targetRoute });
    } else {
      const fallbackRoute = String(route.name ?? '').includes('shop')
        ? 'shop-koba-retail-cart-page'
        : 'app-koba-retail-cart-page';
      if (router.hasRoute(fallbackRoute)) {
        await router.push({ name: fallbackRoute });
      }
    }
    return;
  }

  const parsedLastId = parseInt(getLastVisitedShopId(authStore.tenantId) ?? '', 10);
  const shopId =
    resolveCartShopId(authStore.tenantId, scopedActiveCarts.value ?? []) ??
    (Number.isNaN(parsedLastId) ? null : parsedLastId);
  const matchedCart = (scopedActiveCarts.value ?? []).find((c) => c.shop_id === shopId);
  const matchedShop = headerCustomerShops.value.find((s) => s.id === shopId);
  const targetShopType =
    matchedCart?.shop_type ??
    matchedShop?.shop_type ??
    rememberedShop.value?.shop_type ??
    routeShopType.value;
  await router.push(routeToShopCart(shopId, targetShopType));
};

watch(
  () => isKobaActive.value,
  (active) => {
    if (active) {
      void kobaCartStore.fetchCart();
    }
  },
);

const openSignOutDialog = () => {
  showLogoutDialog.value = true;
};

const confirmLogout = async () => {
  showLogoutDialog.value = false;

  try {
    await supabase.auth.signOut();
  } catch (error) {
    console.error('[auth] Failed to sign out from Supabase session', error);
  } finally {
    authStore.clearAccess();

    try {
      await router.replace(props.logoutTo);
    } catch (error) {
      console.error('[auth] Failed to redirect after sign out', error);
    }
  }
};

defineExpose({
  openSignOutDialog,
});
</script>

<style scoped>
.shop-shell {
  min-height: 100vh;
  --shop-shell-base: var(--tf-theme-base, #ffffff);
  --shop-shell-surface: var(--tf-theme-surface, #ffffff);
  --shop-shell-border: var(--tf-theme-border, #ebe7e2);
  --shop-shell-ink: var(--tf-theme-ink, #2a2b2a);
  --shop-shell-muted: var(--tf-theme-muted, #5e4955);
  --shop-shell-accent: var(--tf-theme-primary, #2a2b2a);
  --shop-shell-accent-soft: var(--tf-theme-primary-soft, rgb(153 104 136 / 0.16));
  background: var(--shop-shell-base);
  color: var(--shop-shell-ink);
}

.shop-shell__header {
  background: color-mix(in srgb, var(--shop-shell-surface) 90%, var(--color-mix-tint, white) 10%);
  border-bottom: 1px solid var(--shop-shell-border);
}

.shop-shell__toolbar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: center;
  gap: 0.75rem;
  padding: 0.45rem 0.9rem;
  min-height: 54px;
}

.shop-shell__left {
  justify-self: start;
  min-width: 0;
  max-width: 100%;
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 0.55rem;
}

.shop-shell__context-divider {
  width: 1px;
  height: 18px;
  background: var(--tf-neutral-border-strong);
  flex-shrink: 0;
}

.shop-shell__nav {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.15rem;
  padding: 0.2rem;
  border-radius: var(--tf-radius-md, 8px);
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-canvas);
}

.shop-shell__tenant-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  position: static;
  z-index: 2;
  margin: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
  padding: 0.15rem 0.15rem 0.15rem 0;
  flex: 0 1 auto;
  min-width: 0;
  max-width: 9rem;
  color: var(--tf-neutral-ink);
}

.shop-shell__tenant-text {
  min-width: 0;
  font-size: clamp(0.95rem, 2.8vw, 1.125rem);
  line-height: 1.1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.shop-shell__tenant-link:hover,
.shop-shell__tenant-link:focus-visible {
  opacity: 0.78;
  outline: none;
}

.shop-shell__actions {
  display: flex;
  align-items: center;
  justify-self: end;
  justify-content: flex-end;
  gap: 0.4rem;
  min-width: 0;
}

.shop-shell__shop-switch {
  min-width: 0;
  max-width: 12.5rem;
}

.shop-shell__search-trigger {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  height: 34px;
  padding: 0 0.7rem;
  border-radius: var(--tf-radius-md, 8px);
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-canvas);
  color: var(--tf-neutral-muted);
  font-size: 0.8125rem;
  cursor: pointer;
  white-space: nowrap;
  transition: border-color 0.15s ease, background-color 0.15s ease, color 0.15s ease;
}

.shop-shell__search-trigger:hover,
.shop-shell__search-trigger:focus-visible {
  border-color: var(--tf-neutral-border-strong);
  background: var(--tf-neutral-surface);
  color: var(--tf-neutral-ink);
  outline: none;
}

.shop-shell__search-trigger-icon {
  color: var(--tf-neutral-muted);
  flex-shrink: 0;
}

.shop-shell__search-trigger-text {
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 9.5rem;
}

.shop-shell__icon-btn {
  min-width: 38px;
  min-height: 38px;
  color: var(--shop-shell-ink);
}

.shop-shell__icon-btn :deep(.q-icon) {
  color: var(--shop-shell-ink);
}

.shop-shell__labeled-btn {
  min-height: 32px;
  padding: 0.3rem 0.75rem;
  border-radius: var(--tf-radius-sm, 6px);
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  background: transparent !important;
}

.shop-shell__labeled-btn :deep(.q-icon) {
  font-size: 1rem;
  color: var(--tf-neutral-muted);
}

.shop-shell__labeled-btn :deep(.q-btn__content) {
  gap: 0.3rem;
}

.shop-shell__labeled-btn--segment-active {
  background: var(--tf-neutral-surface) !important;
  color: var(--tf-theme-primary) !important;
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.08);
}

.shop-shell__labeled-btn--segment-active :deep(.q-icon) {
  color: var(--tf-theme-primary) !important;
}

.shop-shell__cart-badge {
  top: 2px;
  right: 2px;
  font-size: 0.625rem;
  font-weight: 700;
  min-width: 1.05rem;
  min-height: 1.05rem;
  line-height: 1.05rem;
  padding: 0 0.25rem;
}

@media (max-width: 1023px) {
  .shop-shell__toolbar {
    padding: 0.3rem 0.4rem;
    gap: 0.25rem;
  }

  .shop-shell__labeled-btn {
    min-width: 40px;
    min-height: 34px;
    padding: 0.3rem;
    border-radius: 8px;
  }

  .shop-shell__labeled-btn :deep(.q-btn__label),
  .shop-shell__labeled-btn :deep(.block) {
    display: none;
  }
}

@media (max-width: 599px) {
  .shop-shell {
    --shop-bottom-nav-height: calc(4.75rem + env(safe-area-inset-bottom, 0px));
  }

  .shop-shell__header {
    background: var(--shop-shell-surface);
    border-bottom: 0;
    box-shadow: 0 1px 0 color-mix(in srgb, var(--shop-shell-border) 70%, transparent);
  }

  .shop-shell__toolbar {
    grid-template-columns: minmax(0, 1fr) auto;
    min-height: 56px;
    padding: calc(0.35rem + env(safe-area-inset-top, 0px)) 0.7rem 0.4rem;
    gap: 0.5rem;
  }

  .shop-shell__left {
    gap: 0.35rem;
  }

  .shop-shell__context-divider {
    height: 14px;
  }

  .shop-shell__tenant-link {
    max-width: min(34vw, 8rem);
    justify-content: flex-start;
    padding: 0;
  }

  .shop-shell__tenant-text {
    font-size: 0.9375rem;
    font-weight: 700;
    letter-spacing: -0.02em;
    line-height: 1.2;
  }

  .shop-shell__actions {
    gap: 0.1rem;
  }

  .shop-shell__shop-switch {
    max-width: 8.5rem;
  }

  .shop-shell__shop-switch :deep(.catalog-header-shop__static),
  .shop-shell__shop-switch :deep(.catalog-header-shop__trigger) {
    min-height: 28px;
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.15rem 0.45rem;
  }

  .shop-shell__icon-btn {
    min-width: 36px;
    min-height: 36px;
  }

  .shop-shell__actions :deep(.notification-bell) {
    min-width: 36px;
    min-height: 36px;
  }

  .shop-shell__actions :deep(.user-profile-btn) {
    padding: 0;
    min-height: 36px;
  }

  .shop-shell__header,
  .shop-shell__bottom-nav {
    transition: transform 0.28s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .shop-shell--chrome-hidden .shop-shell__header {
    transform: translateY(-110%);
  }

  .shop-shell--chrome-hidden .shop-shell__bottom-nav {
    transform: translateY(calc(100% + 12px));
  }
}

.shop-shell__search--mobile {
  width: 100%;
  max-width: none;
  min-width: 0;
}

.shop-shell__search--mobile :deep(.shop-header-search-wrap) {
  max-width: none;
}

.shop-shell__page-container {
  background: var(--shop-shell-base);
}

.shop-shell__bottom-nav {
  background: transparent;
  border: 0;
  box-shadow: none;
  color: var(--shop-shell-ink);
}

.shop-shell__bottom-nav :deep(.q-footer) {
  background: transparent;
}

.shop-shell__bottom-nav-inner {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  align-items: stretch;
  gap: 0.15rem;
  margin: 0 10px calc(8px + env(safe-area-inset-bottom, 0px));
  padding: 0.35rem 0.3rem;
  border-radius: 18px;
  background: var(--shop-shell-surface);
  border: 1px solid color-mix(in srgb, var(--shop-shell-border) 70%, transparent);
  box-shadow:
    0 10px 28px rgb(var(--tf-theme-primary-rgb, 51 104 160) / 0.1),
    0 1px 0 color-mix(in srgb, white 70%, transparent);
}

.shop-shell__bottom-nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  min-width: 0;
  min-height: 3.35rem;
  margin: 0;
  padding: 0.15rem 0.2rem;
  border: 0;
  background: transparent;
  color: var(--shop-shell-muted);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.shop-shell__bottom-nav-icon {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.35rem;
  height: 1.85rem;
  border-radius: 999px;
}

.shop-shell__bottom-nav-icon :deep(.q-icon) {
  font-size: 1.35rem;
  color: inherit;
}

.shop-shell__bottom-nav-label {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.6875rem;
  font-weight: 500;
  letter-spacing: 0.01em;
  line-height: 1;
}

.shop-shell__bottom-nav-item--active {
  color: var(--shop-shell-accent);
}

.shop-shell__bottom-nav-item--active .shop-shell__bottom-nav-icon {
  background: var(--shop-shell-accent-soft);
}

.shop-shell__bottom-nav-item--active .shop-shell__bottom-nav-label {
  font-weight: 700;
}

.shop-shell__bottom-nav-badge {
  position: absolute;
  top: -0.2rem;
  right: -0.15rem;
  min-width: 1rem;
  height: 1rem;
  padding: 0 0.22rem;
  border-radius: 999px;
  background: var(--tf-error, #c44536);
  color: #fff;
  font-size: 0.6rem;
  font-weight: 700;
  line-height: 1rem;
  text-align: center;
  box-shadow: 0 0 0 2px var(--shop-shell-surface);
}

.shop-shell__search-card {
  width: min(96vw, 520px);
  margin-top: 0.5rem;
  border-radius: 12px;
}

.shop-shell__signout-dialog :deep(.q-dialog__inner) {
  padding: 16px;
}

.shop-shell__signout-dialog :deep(.q-dialog__backdrop) {
  background: rgb(0 0 0 / 0.45);
}

.shop-shell__signout-card {
  width: min(92vw, 26rem);
  border-radius: 1.25rem;
  padding: 1.5rem;
  background: #ffffff;
  border: 1px solid #ebe7e2;
  box-shadow: 0 20px 60px rgb(0 0 0 / 0.18);
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.shop-shell__signout-identity {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.shop-shell__signout-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  background: #f1e9ee;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.8rem;
  font-weight: 700;
  color: #2a2b2a;
}

.shop-shell__signout-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.shop-shell__signout-name {
  font-size: 0.95rem;
  font-weight: 700;
  color: #2a2b2a;
}

.shop-shell__signout-email {
  font-size: 0.78rem;
  color: #5e4955;
}

.shop-shell__signout-message {
  margin: 0;
  font-size: 0.85rem;
  color: #5e4955;
  line-height: 1.5;
}

.shop-shell__signout-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}

.shop-shell__signout-btn {
  padding: 0.55rem 0;
  border-radius: 8px;
  border: none;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
}

.shop-shell__signout-btn--cancel {
  background: #f3f1f2;
  color: #2a2b2a;
  border: 1px solid #e4e0e2;
}

.shop-shell__signout-btn--confirm {
  background: #2a2b2a;
  color: #ffffff;
}
</style>
