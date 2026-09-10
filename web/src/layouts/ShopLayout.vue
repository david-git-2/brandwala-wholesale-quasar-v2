<template>
  <ShopShell ref="shopShellRef" :logout-to="logoutTo">
    <router-view />
  </ShopShell>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';

import ShopShell from 'src/layouts/shop/ShopShell.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
const authStore = useAuthStore();
const shopShellRef = ref<InstanceType<typeof ShopShell> | null>(null);

const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/shop/login` : '/shop/login',
);
</script>
