<template>
  <PageInitialLoader
    v-if="loading && !tenant"
    compact
    message="Loading shop…"
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
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext';

const { loading, tenant, resolvedTenantSlug, error: entryError } = useTenantEntryContext();

const title = computed(() => (tenant.value ? tenant.value.name : 'Customer Login'));

const isLoginDisabled = computed(() => loading.value || !tenant.value);
</script>
