<template>
  <AppTradeFlowLoadingScreen
    v-if="loading && !tenant"
    scope="shop"
    tagline="Loading shop…"
  />

  <q-banner
    v-else-if="entryError && !tenant"
    class="bg-orange-1 text-orange-10"
    rounded
    dense
  >
    {{ entryError }}
  </q-banner>

  <AuthLoginPanel
    v-else
    scope="shop"
    :title="title"
    cta-label="Sign in to shop"
    :disabled="isLoginDisabled"
    :tenant-slug="resolvedTenantSlug"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';

import AuthLoginPanel from '../components/AuthLoginPanel.vue';
import AppTradeFlowLoadingScreen from 'src/components/brand/AppTradeFlowLoadingScreen.vue';
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext';

const { loading, tenant, resolvedTenantSlug, error: entryError } = useTenantEntryContext();

const title = computed(() => (tenant.value ? tenant.value.name : 'Customer Login'));

const isLoginDisabled = computed(() => loading.value || !tenant.value);
</script>
