<template>
  <q-page class="q-pa-md">
    <PageInitialLoader v-if="shopsQuery.isLoading.value" />
    <q-banner v-else-if="shopsError" class="tf-status-banner bg-negative text-white" rounded>
      {{ shopsError }}
    </q-banner>
  </q-page>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerShopsQuery } from '../../composables/useShopQuery';
import {
  filterShopsByRouteType,
  rememberCatalogShop,
  resolveCatalogShop,
  resolveCustomerShopTypePath,
  shopCatalogPath,
  shopHomePath,
} from '../../utils/catalogShop';
import { shopTypeFromPathSegment } from '../../utils/shopRouteTypes';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId ?? null);
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : authStore.tenantSlug,
);
const routeShopTypePath = computed(() =>
  resolveCustomerShopTypePath(route, tenantId.value),
);
const routeShopType = computed(() => shopTypeFromPathSegment(routeShopTypePath.value));

const shopsQuery = useCustomerShopsQuery(tenantId);
const shops = computed(() =>
  filterShopsByRouteType(shopsQuery.data.value ?? [], routeShopTypePath.value),
);
const shopsError = computed(() => (shopsQuery.error.value as Error | null)?.message || null);

const searchQuery = computed(() => {
  const raw = route.query.q;
  if (Array.isArray(raw)) return raw[0] || null;
  return raw ? String(raw) : null;
});

watch(
  [() => shopsQuery.isLoading.value, () => shopsQuery.isError.value, shops, tenantSlug, searchQuery],
  () => {
    if (shopsQuery.isLoading.value || shopsQuery.isError.value) return;

    const shop = resolveCatalogShop(tenantId.value, shops.value, routeShopType.value);
    if (!shop) {
      void router.replace(shopHomePath(tenantSlug.value, routeShopTypePath.value));
      return;
    }

    if (tenantId.value) {
      rememberCatalogShop(tenantId.value, shop);
    }
    void router.replace(
      shopCatalogPath(tenantSlug.value, shop.slug, searchQuery.value, shop.shop_type),
    );
  },
  { immediate: true },
);
</script>
