<template>
  <AuthLoginPanelSkeleton v-if="validShopType && loading && !tenant" />

  <q-banner
    v-else-if="shopTypeError"
    class="bg-orange-1 text-orange-10"
    rounded
    dense
  >
    {{ shopTypeError }}
  </q-banner>

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
    :shop-type-path="shopTypePath"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';

import AuthLoginPanel from '../components/AuthLoginPanel.vue';
import AuthLoginPanelSkeleton from '../components/AuthLoginPanelSkeleton.vue';
import { useShopEntryShopType } from 'src/modules/tenant/composables/useShopEntryShopType';
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext';

const { validShopType, shopTypeError, shopTypePath } = useShopEntryShopType();
const { loading, tenant, resolvedTenantSlug, error: entryError } = useTenantEntryContext({
  requireShopType: true,
});

const title = computed(() => (tenant.value ? tenant.value.name : 'Customer Login'));

const isLoginDisabled = computed(
  () => loading.value || !tenant.value || !validShopType.value,
);
</script>