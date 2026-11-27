<template>
  <ProxyShell ref="proxyShellRef" :logout-to="logoutTo">
    <router-view />
  </ProxyShell>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import ProxyShell from 'src/layouts/proxy/ProxyShell.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { getProxyLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const proxyShellRef = ref<InstanceType<typeof ProxyShell> | null>(null);

const logoutTo = computed(() => {
  const loc = getProxyLoginRouteLocation(route, undefined, authStore.tenantSlug);
  return router.resolve(loc).fullPath;
});
</script>
