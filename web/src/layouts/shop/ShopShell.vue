<template>
  <q-layout view="hHh lpR fFf" class="shop-shell theme-shop">
    <q-header class="shop-shell__header" reveal>
      <q-toolbar class="shop-shell__toolbar">
        <button
          v-if="showHeaderTenantLink"
          type="button"
          class="shop-shell__tenant-link"
          data-test="shop-header-tenant-link"
          @click="goHome"
        >
          <q-icon
            class="shop-shell__tenant-home"
            name="ph ph-house"
            size="20px"
            :aria-label="$t('navigation.home')"
          />
          <span class="shop-shell__tenant-text shop-banner-font">{{ tenantName }}</span>
        </button>

        <div v-if="showCatalogShopHeader" class="shop-shell__catalog-shop">
          <CatalogShopHeaderSwitcher
            :shop-name="headerShopName"
            :current-slug="headerShopSlug"
            :shops="customerShops"
            @switch-shop="onSwitchCatalogShop"
          />
        </div>

        <div v-else-if="showOrdersHeaderTitle" class="shop-shell__catalog-shop">
          <h1 class="shop-shell__header-title shop-banner-font q-my-none ellipsis">
            {{ $t('customer_dashboard.glance_title') }}
          </h1>
        </div>

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

          <q-btn
            v-if="showCatalogOrdersButton"
            flat
            no-caps
            dense
            class="shop-shell__labeled-btn"
            icon="ph ph-clipboard-text"
            :label="$t('navigation.orders')"
            data-test="shop-header-orders-btn"
            @click="goToOrders"
          />

          <q-btn
            v-if="showOrdersCatalogButton || showCartCatalogButton"
            flat
            no-caps
            dense
            class="shop-shell__labeled-btn"
            icon="ph ph-storefront"
            :label="$t('navigation.catalog')"
            data-test="shop-header-catalog-btn"
            @click="goToCatalog"
          />

          <q-btn
            v-if="canShowCartIcon"
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
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import UserProfileMenu from 'src/components/navigation/UserProfileMenu.vue';
import ShopHeaderProductSearch from 'src/modules/shop_order/components/ShopHeaderProductSearch.vue';
import CatalogShopHeaderSwitcher from 'src/modules/shop_order/components/CatalogShopHeaderSwitcher.vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useActiveShopCartsQuery } from 'src/modules/shop_order/composables/useActiveShopCartsQuery';
import { useCustomerShopsQuery } from 'src/modules/shop_order/composables/useShopQuery';
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore';
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
const kobaCartStore = useKobaCartStore();
const { data: activeCarts } = useActiveShopCartsQuery();

const showLogoutDialog = ref(false);
const searchOpen = ref(false);

const CATALOG_ROUTE_NAMES = new Set([
  'shop-catalog-entry-page',
  'shop-storefront-browse-page',
  'shop-storefront-product-detail-page',
]);

const ORDER_ROUTE_NAMES = new Set(['shop-orders-page', 'shop-order-detail-page']);

const CART_ROUTE_NAMES = new Set(['shop-cart-page', 'shop-checkout-page']);

const showHeaderSearch = computed(() => route.name === 'customer-dashboard');

const showCatalogOrdersButton = computed(() =>
  CATALOG_ROUTE_NAMES.has(String(route.name ?? '')),
);

const showOrdersCatalogButton = computed(() =>
  ORDER_ROUTE_NAMES.has(String(route.name ?? '')),
);

const isCartRoute = computed(() => CART_ROUTE_NAMES.has(String(route.name ?? '')));

const activeCartShopId = computed(() =>
  resolveCartShopId(authStore.tenantId, activeCarts.value ?? [], route.query.shopId),
);

const activeCartInfo = computed(() => {
  const shopId = activeCartShopId.value;
  if (!shopId) return null;
  return (activeCarts.value ?? []).find((cart) => cart.shop_id === shopId) ?? null;
});

const isCatalogCartContext = computed(() => {
  if (!isCartRoute.value) return false;
  if (activeCartInfo.value?.shop_type === 'dropship') return false;
  if (activeCartInfo.value) return true;
  return (activeCarts.value ?? []).some((cart) => cart.shop_type !== 'dropship');
});

const showCartCatalogButton = computed(() => isCatalogCartContext.value);

const showOrdersHeaderTitle = computed(() => showOrdersCatalogButton.value);

const showHeaderTenantLink = computed(
  () =>
    CATALOG_ROUTE_NAMES.has(String(route.name ?? '')) ||
    ORDER_ROUTE_NAMES.has(String(route.name ?? '')) ||
    isCatalogCartContext.value,
);

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

const headerShopSlug = computed(() =>
  isCatalogCartContext.value ? cartShopSlug.value : catalogShopSlug.value,
);

const headerShopName = computed(() => {
  if (isCatalogCartContext.value) {
    return cartShopName.value;
  }
  const match = customerShops.value.find((shop) => shop.slug === catalogShopSlug.value);
  return match?.name || catalogShopSlug.value;
});

const showCatalogShopHeader = computed(() => {
  const routeName = String(route.name ?? '');
  if (isCatalogCartContext.value && headerShopSlug.value.length > 0) {
    return true;
  }
  return routeName === 'shop-storefront-browse-page' && catalogShopSlug.value.length > 0;
});

watch(showHeaderSearch, (visible) => {
  if (!visible) {
    searchOpen.value = false;
  }
});

const applyBodyThemeClass = () => {
  if (typeof document === 'undefined') {
    return;
  }
  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
  document.body.classList.add('theme-shop');
};

applyBodyThemeClass();

onBeforeUnmount(() => {
  if (typeof document === 'undefined') {
    return;
  }
  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
});

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

const isKobaActive = computed(() => !!(route.name && String(route.name).includes('koba')));

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

const onSwitchCatalogShop = (shop: { id: number; slug: string; name: string }) => {
  if (!shop.slug || shop.slug === headerShopSlug.value) return;
  if (authStore.tenantId) {
    rememberCatalogShop(authStore.tenantId, shop);
  }
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
  background: #ffffff;
  border-bottom: none;
}

.shop-shell__toolbar {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.75rem;
  min-height: 52px;
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

.shop-shell__tenant-home {
  display: none;
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

.shop-shell__catalog-shop {
  position: static;
  z-index: 1;
  flex: 1 1 auto;
  width: auto;
  min-width: 0;
  pointer-events: none;
}

.shop-shell__catalog-shop > * {
  pointer-events: auto;
}

.shop-shell__header-title {
  font-size: clamp(1rem, 3.5vw, 1.45rem);
  line-height: 1.1;
  text-align: center;
  width: 100%;
}

.shop-shell__actions {
  display: flex;
  align-items: center;
  gap: 0.15rem;
  flex: 0 0 auto;
  margin-left: auto;
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
  .shop-shell__tenant-link {
    max-width: none;
  }

  .shop-shell__tenant-text {
    display: none;
  }

  .shop-shell__tenant-home {
    display: block;
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
