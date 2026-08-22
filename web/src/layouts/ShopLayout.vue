<template>
  <WorkspaceShell
    ref="workspaceShellRef"
    :logout-to="logoutTo"
    theme="shop"
    :links="links"
    use-header-profile
  >
    <template #header-left>
      <AppBreadcrumbs />
    </template>

    <template #header-center>
      <ShopHeaderProductSearch />
    </template>

    <template #header-extra>
      <div class="row items-center q-gutter-x-sm no-wrap">
        <q-btn
          v-if="canShowCartIcon"
          color="primary"
          flat
          icon="ph ph-shopping-cart"
          :round="isKobaActive"
          :dense="isKobaActive"
          :unelevated="!isKobaActive"
          :class="isKobaActive ? '' : 'shop-cart-btn'"
          no-caps
          aria-label="Cart"
          @click="goToCart"
        >
          <q-badge
            v-if="cartItemCount > 0"
            color="negative"
            floating
            rounded
            :label="cartItemCount"
          />
        </q-btn>

        <q-separator vertical inset class="q-mx-xs text-grey-4 gt-xs" />

        <UserProfileMenu @sign-out="onSignOut" />
      </div>
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import WorkspaceShell from 'src/components/WorkspaceShell.vue';
import AppBreadcrumbs from 'src/components/navigation/AppBreadcrumbs.vue';
import UserProfileMenu from 'src/components/navigation/UserProfileMenu.vue';
import ShopHeaderProductSearch from 'src/modules/shop_order/components/ShopHeaderProductSearch.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useActiveShopCartsQuery } from 'src/modules/shop_order/composables/useActiveShopCartsQuery';
import { useShopWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation';
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore';
import { resolveCartShopId, shopCartPath } from 'src/modules/shop_order/utils/catalogShop';

const authStore = useAuthStore();
const kobaCartStore = useKobaCartStore();
const workspaceShellRef = ref<InstanceType<typeof WorkspaceShell> | null>(null);
const { data: activeCarts } = useActiveShopCartsQuery();
const router = useRouter();
const route = useRoute();
const { links } = useShopWorkspaceLinks();

const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/shop/login` : '/shop/login',
);

const onSignOut = () => {
  workspaceShellRef.value?.openSignOutDialog();
};

const isKobaActive = computed(() => {
  return !!(route.name && String(route.name).includes('koba'));
});

const cartItemCount = computed(() => {
  if (isKobaActive.value) {
    return kobaCartStore.itemCount;
  }
  return (activeCarts.value ?? []).reduce((sum, c) => sum + Number(c.item_count), 0);
});

const canShowCartIcon = computed(() => {
  if (isKobaActive.value) {
    return true;
  }
  return true;
});

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
  const shopId = resolveCartShopId(authStore.tenantId, activeCarts.value ?? []);
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

</script>

<style scoped>
.shop-context {
  min-width: 0;
}

.shop-context__title {
  overflow: hidden;
  font-size: clamp(1.2rem, 2vw, 1.7rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.shop-cart-btn {
  border-radius: 999px;
}
</style>
