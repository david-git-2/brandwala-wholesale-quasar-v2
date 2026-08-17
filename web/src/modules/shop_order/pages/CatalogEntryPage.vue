<template>
  <q-page class="q-pa-md">
    <PageInitialLoader v-if="shopsQuery.isLoading.value" />
    <q-banner v-else-if="shopsError" class="bw-status-banner bg-negative text-white" rounded>
      {{ shopsError }}
    </q-banner>
  </q-page>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerShopsQuery } from '../composables/useShopQuery';
import {
  rememberCatalogShop,
  resolveCatalogShop,
  shopCatalogPath,
  shopHomePath,
} from '../utils/catalogShop';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const tenantId = computed(() => authStore.tenantId ?? null);
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : authStore.tenantSlug,
);

const shopsQuery = useCustomerShopsQuery(tenantId);
const shops = computed(() => shopsQuery.data.value ?? []);
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

    const shop = resolveCatalogShop(tenantId.value, shops.value);
    if (!shop) {
      void router.replace(shopHomePath(tenantSlug.value));
      return;
    }

    if (tenantId.value) {
      rememberCatalogShop(tenantId.value, shop);
    }
    void router.replace(shopCatalogPath(tenantSlug.value, shop.slug, searchQuery.value));
  },
  { immediate: true },
);
</script>
