<template>
  <AuthLoginPanel
    scope="investor"
    :title="title"
    cta-label="Sign in to investor portal"
    :disabled="isLoginDisabled"
    :tenant-slug="resolvedTenantSlug"
    tone="investor"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';

import AuthLoginPanel from 'src/modules/auth/components/AuthLoginPanel.vue';
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext';

const { loading, tenant, resolvedTenantSlug } = useTenantEntryContext();

const title = computed(() =>
  tenant.value ? `${tenant.value.name} — Investor Portal` : 'Investor Portal',
);

const isLoginDisabled = computed(() => loading.value || !tenant.value);
</script>
