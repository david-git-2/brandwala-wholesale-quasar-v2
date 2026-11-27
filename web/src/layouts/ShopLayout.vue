<template>
  <ShopShell ref="shopShellRef" :logout-to="logoutTo">
    <router-view />
  </ShopShell>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import ShopShell from 'src/layouts/shop/ShopShell.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { getLastShopTypePath } from 'src/modules/shop_order/utils/catalogShop';
import {
  getShopLoginRouteLocation,
  getShopTypePathFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const shopShellRef = ref<InstanceType<typeof ShopShell> | null>(null);

const logoutTo = computed(() => {
  const shopType =
    getShopTypePathFromRoute(route) ?? getLastShopTypePath(authStore.tenantId);
  const loc = getShopLoginRouteLocation(
    route,
    undefined,
    authStore.tenantSlug,
    shopType,
  );
  return router.resolve(loc).fullPath;
});
</script>
