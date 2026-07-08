<template>
  <AuthLoginPanel
    scope="shop"
    :title="title"
    cta-label="Sign in to shop"
    :disabled="isLoginDisabled"
    :tenant-slug="resolvedTenantSlug"
    tone="shop"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';

import AuthLoginPanel from '../components/AuthLoginPanel.vue';
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext';

const { loading, tenant, resolvedTenantSlug } = useTenantEntryContext();

const title = computed(() => (tenant.value ? tenant.value.name : 'Customer Login'));

const isLoginDisabled = computed(() => loading.value || !tenant.value);
</script>
