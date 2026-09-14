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
          <ShopCustomerGroupHeaderSwitcher
            :current-name="companyName"
            :current-id="authStore.customerGroupId"
            :groups="loginGroups"
            @switch-company="onSwitchCompany"
          />
        </div>

        <nav v-if="!$q.screen.xs" class="shop-shell__nav" aria-label="Shop">
          <q-btn
            flat
            no-caps
            dense
            class="shop-shell__labeled-btn"
            :class="{ 'shop-shell__labeled-btn--active': isCatalogNavActive }"
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
            :class="{ 'shop-shell__labeled-btn--active': isOrdersNavActive }"
            icon="ph ph-clipboard-text"
            :label="$t('navigation.orders')"
            data-test="shop-header-orders-btn"
            @click="goToOrders"
          />
        </nav>

        <div class="shop-shell__actions">
          <q-btn
            v-if="showHeaderSearch"
            flat
            round
            dense
            class="shop-shell__icon-btn"
            aria-label="Search products"
            data-test="shop-header-search-trigger"
            @click="searchOpen = true"
          >
            <q-icon name="ph ph-magnifying-glass" size="20px" />
          </q-btn>

          <div v-if="showCatalogShopHeader" class="shop-shell__shop-switch">
            <CatalogShopHeaderSwitcher
              :shop-name="headerShopName"
              :current-slug="headerShopSlug"
              :shops="customerShops"
              @switch-shop="onSwitchHeaderShop"
            />
          </div>

          <NotificationBell scope="shop" />

          <q-btn
            v-if="canShowCartIcon && !$q.screen.xs"
            flat
            round
            dense
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
              :label="cartItemCount"
            />
          </q-btn>

          <UserProfileMenu @sign-out="openSignOutDialog" />
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
          <span class="shop-shell__bottom-nav-label">{{ $t('navigation.home') }}</span>
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
import NotificationBell from 'src/modules/notifications/components/NotificationBell.vue';
import ShopHeaderProductSearch from 'src/modules/shop_order/components/ShopHeaderProductSearch.vue';
import CatalogShopHeaderSwitcher from 'src/modules/shop_order/components/CatalogShopHeaderSwitcher.vue';
import ShopCustomerGroupHeaderSwitcher from 'src/modules/shop_order/components/ShopCustomerGroupHeaderSwitcher.vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useActiveShopCartsQuery } from 'src/modules/shop_order/composables/useActiveShopCartsQuery';
import { useCustomerShopsQuery } from 'src/modules/shop_order/composables/useShopQuery';
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore';
import { clearShopOrderQueryCache } from 'src/query/queryClient';
import { getShopDashboardRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';
import {
  bootstrapShopCustomerGroup,
  listShopLoginGroups,
  type ShopLoginGroupRow,
} from 'src/modules/auth/utils/shopCustomerGroupSession';
import {
  getLastVisitedShopId,
  rememberCatalogShop,
  resolveCartShopId,
  resolveCatalogShop,
  shopCartPath,
  shopCatalogEntryPath,
  shopCatalogPath,
  shopHomePath,
} from 'src/modules/shop_order/utils/catalogShop';

const WORKSPACE_THEME_CLASSES = ['theme-platform', 'theme-app', 'theme-shop', 'theme-investor'];

const props = defineProps<{
  logoutTo: string;
}>();

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const kobaCartStore = useKobaCartStore();
const { data: activeCarts } = useActiveShopCartsQuery();

const loginGroups = ref<ShopLoginGroupRow[]>([]);
const companyName = computed(() => authStore.customerGroup?.name ?? '');

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

const showHeaderSearch = computed(() => route.name === 'customer-dashboard');

const routeName = computed(() => String(route.name ?? ''));

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
  resolveCartShopId(authStore.tenantId, activeCarts.value ?? [], route.query.shopId),
);

const activeCartInfo = computed(() => {
  const shopId = activeCartShopId.value;
  if (!shopId) return null;
  return (activeCarts.value ?? []).find((cart) => cart.shop_id === shopId) ?? null;
});

const tenantName = computed(
  () => authStore.tenant?.name || authStore.selectedTenant?.name || 'Shop',
);

const shopsQuery = useCustomerShopsQuery(computed(() => authStore.tenantId ?? null));
const customerShops = computed(() => shopsQuery.data.value ?? []);

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
  return customerShops.value.find((shop) => shop.id === shopId)?.slug ?? '';
});

const cartShopName = computed(() => {
  if (activeCartInfo.value?.shop_name) {
    return activeCartInfo.value.shop_name;
  }
  const shopId = activeCartShopId.value;
  if (!shopId) return cartShopSlug.value;
  return customerShops.value.find((shop) => shop.id === shopId)?.name ?? cartShopSlug.value;
});

const rememberedShop = computed(() =>
  resolveCatalogShop(authStore.tenantId, customerShops.value),
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
  const match = customerShops.value.find((shop) => shop.slug === headerShopSlug.value);
  return match?.name || headerShopSlug.value;
});

const showCatalogShopHeader = computed(() => {
  if (showHeaderSearch.value) return false;
  if (routeName.value === 'shop-order-detail-page') return false;
  return headerShopSlug.value.length > 0;
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

const cartItemCount = computed(() => {
  if (isKobaActive.value) {
    return kobaCartStore.itemCount;
  }
  return (activeCarts.value ?? []).reduce((sum, c) => sum + Number(c.item_count), 0);
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
  void router.push(shopHomePath(authStore.tenantSlug));
};

const loadLoginGroups = async () => {
  const email = authStore.user?.email;
  const tenantId = authStore.tenantId;
  if (!email || tenantId == null) {
    loginGroups.value = [];
    return;
  }
  try {
    loginGroups.value = await listShopLoginGroups(email, tenantId);
  } catch (error) {
    console.error('[shop] Failed to list companies for header', error);
    loginGroups.value = [];
  }
};

const onSwitchCompany = async (group: ShopLoginGroupRow) => {
  const user = authStore.user;
  const email = user?.email;
  const tenantId = authStore.tenantId;
  if (!user || !email || tenantId == null || group.customer_group_id === authStore.customerGroupId) {
    return;
  }

  try {
    const snapshot = await bootstrapShopCustomerGroup({
      user,
      email,
      tenantId,
      memberId: group.member_id,
      createdAt: group.member_created_at,
      updatedAt: group.member_updated_at,
    });
    if (!snapshot) {
      return;
    }
    authStore.saveAccess({
      ...snapshot,
      savedAt: new Date().toISOString(),
    });
    tenantStore.hydrateSelectedTenantFromAuth(snapshot.tenant);
    clearShopOrderQueryCache();
    await router.replace(getShopDashboardRouteLocation(route, snapshot.tenant?.slug));
    await loadLoginGroups();
  } catch (error) {
    console.error('[shop] Failed to switch company', error);
  }
};

onMounted(() => {
  void loadLoginGroups();
  window.addEventListener('scroll', onWindowScroll, { passive: true });
});

onBeforeUnmount(() => {
  window.removeEventListener('scroll', onWindowScroll);
  if (typeof document === 'undefined') {
    return;
  }
  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
});

watch(
  () => [authStore.user?.email, authStore.tenantId, authStore.customerGroupId] as const,
  () => {
    void loadLoginGroups();
  },
);

const goToCatalog = () => {
  const tenantId = authStore.tenantId;
  const cartSlug = activeCartInfo.value?.shop_slug;
  const cartShopId = activeCartInfo.value?.shop_id;
  if (cartSlug && cartShopId) {
    if (tenantId) {
      rememberCatalogShop(tenantId, { id: cartShopId, slug: cartSlug });
    }
    void router.push(shopCatalogPath(authStore.tenantSlug, cartSlug));
    return;
  }

  const shop = resolveCatalogShop(tenantId, customerShops.value);
  if (shop?.slug) {
    if (tenantId) {
      rememberCatalogShop(tenantId, shop);
    }
    void router.push(shopCatalogPath(authStore.tenantSlug, shop.slug));
    return;
  }
  void router.push(shopCatalogEntryPath(authStore.tenantSlug));
};

const onSwitchHeaderShop = (shop: { id: number; slug: string; name: string }) => {
  if (!shop.slug) return;
  if (authStore.tenantId) {
    rememberCatalogShop(authStore.tenantId, shop);
  }
  if (isCartRoute.value) {
    if (shop.id === activeCartShopId.value) return;
    void router.push(shopCartPath(authStore.tenantSlug, shop.id));
    return;
  }
  if (isOrdersNavActive.value) return;
  if (shop.slug === headerShopSlug.value) return;
  void router.push(shopCatalogPath(authStore.tenantSlug, shop.slug));
};

const goToOrders = () => {
  const tenantSlug = authStore.tenantSlug;
  void router.push(tenantSlug ? `/${tenantSlug}/shop/orders` : '/shop/orders');
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
    resolveCartShopId(authStore.tenantId, activeCarts.value ?? []) ??
    (Number.isNaN(parsedLastId) ? null : parsedLastId);
  await router.push(shopCartPath(authStore.tenantSlug, shopId));
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
  --shop-shell-base: var(--bw-theme-base, #ffffff);
  --shop-shell-surface: var(--bw-theme-surface, #ffffff);
  --shop-shell-border: var(--bw-theme-border, #ebe7e2);
  --shop-shell-ink: var(--bw-theme-ink, #2a2b2a);
  --shop-shell-muted: var(--bw-theme-muted, #5e4955);
  --shop-shell-accent: var(--bw-theme-primary, #2a2b2a);
  --shop-shell-accent-soft: var(--bw-theme-primary-soft, rgb(153 104 136 / 0.16));
  background: var(--shop-shell-base);
  color: var(--shop-shell-ink);
}

.shop-shell__header {
  background: color-mix(in srgb, var(--shop-shell-surface) 90%, var(--color-mix-tint, white) 10%);
  border-bottom: 1px solid var(--shop-shell-border);
}

.shop-shell__toolbar {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.75rem;
  min-height: 52px;
}

.shop-shell__left {
  justify-self: start;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.05rem;
}

.shop-shell__nav {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.15rem;
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
  flex: 0 0 auto;
  min-width: 0;
  max-width: 9rem;
  color: var(--bw-shop-charcoal, #2a2b2a);
}

.shop-shell__tenant-text {
  min-width: 0;
  font-size: clamp(0.95rem, 2.8vw, 1.15rem);
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
  gap: 0.15rem;
  min-width: 0;
}

.shop-shell__shop-switch {
  min-width: 0;
  max-width: 11rem;
}

.shop-shell__shop-switch :deep(.catalog-header-shop) {
  justify-content: flex-end;
}

.shop-shell__shop-switch :deep(.catalog-header-shop__static),
.shop-shell__shop-switch :deep(.catalog-header-shop__trigger) {
  font-size: 0.9rem;
}

.shop-shell__icon-btn {
  min-width: 40px;
  min-height: 40px;
  color: var(--shop-shell-ink);
}

.shop-shell__icon-btn :deep(.q-icon) {
  color: var(--shop-shell-ink);
}

.shop-shell__labeled-btn {
  min-height: 36px;
  padding: 0.3rem 0.65rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--shop-shell-ink);
  background: color-mix(in srgb, var(--shop-shell-border) 35%, transparent);
}

.shop-shell__labeled-btn :deep(.q-icon) {
  font-size: 1rem;
  color: var(--shop-shell-ink);
}

.shop-shell__labeled-btn :deep(.q-btn__content) {
  gap: 0.3rem;
}

.shop-shell__labeled-btn--active {
  background: var(--shop-shell-accent-soft);
}

@media (max-width: 1023px) {
  .shop-shell__toolbar {
    padding: 0.3rem 0.4rem;
    gap: 0.25rem;
  }

  .shop-shell__labeled-btn {
    min-width: 40px;
    min-height: 40px;
    padding: 0.3rem;
    border-radius: 999px;
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
    gap: 0.05rem;
  }

  .shop-shell__tenant-link {
    max-width: min(58vw, 14rem);
    justify-content: flex-start;
    padding: 0;
  }

  .shop-shell__tenant-text {
    font-size: 0.9375rem;
    font-weight: 700;
    letter-spacing: -0.02em;
    line-height: 1.2;
  }

  .shop-shell__left :deep(.shop-company-switch__trigger),
  .shop-shell__left :deep(.shop-company-switch__static) {
    min-height: 0;
    padding: 0;
    font-size: 0.6875rem;
    font-weight: 500;
    color: var(--shop-shell-muted);
  }

  .shop-shell__actions {
    gap: 0.05rem;
  }

  .shop-shell__shop-switch {
    max-width: 7.5rem;
  }

  .shop-shell__shop-switch :deep(.catalog-header-shop__static),
  .shop-shell__shop-switch :deep(.catalog-header-shop__trigger) {
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.15rem 0.2rem;
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

  .shop-shell__actions :deep(.user-profile-btn .ph-caret-down) {
    display: none;
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
    0 10px 28px rgb(var(--bw-theme-primary-rgb, 51 104 160) / 0.1),
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
  background: var(--bw-error, #c44536);
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
