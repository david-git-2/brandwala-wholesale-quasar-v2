<template>
  <div>
    <AppTradeFlowLoadingScreen
      v-if="loading && !tenantSlugFromRoute"
      scope="shop"
      tagline="Loading…"
    />

    <q-banner v-else-if="entryError" class="bg-orange-1 text-orange-10 q-mb-md" rounded dense>
      {{ entryError }}
    </q-banner>

    <AuthLoginPanel
      scope="proxy"
      :title="title"
      cta-label="Sign in to proxy portal"
      :disabled="isLoginDisabled"
      :tenant-slug="effectiveTenantSlug"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';

import AuthLoginPanel from 'src/modules/workspace/submodules/auth/components/AuthLoginPanel.vue';
import AppTradeFlowLoadingScreen from 'src/components/brand/AppTradeFlowLoadingScreen.vue';
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext';

const route = useRoute();
const { loading, tenant, resolvedTenantSlug, error: entryError } = useTenantEntryContext();

const tenantSlugFromRoute = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);

const effectiveTenantSlug = computed(
  () => resolvedTenantSlug.value ?? tenantSlugFromRoute.value,
);

const title = computed(() =>
  tenant.value ? `${tenant.value.name} — Proxy Portal` : 'Proxy Portal',
);

const isLoginDisabled = computed(
  () => loading.value || (!tenant.value && !tenantSlugFromRoute.value),
);
</script>