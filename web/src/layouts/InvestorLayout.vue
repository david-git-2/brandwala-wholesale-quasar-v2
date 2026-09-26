<template>
  <WorkspaceShell :logout-to="logoutTo" theme="investor" :links="links">
    <template #header-left>
      <div v-if="tenantName" class="investor-context">
        <div class="investor-context__title">{{ tenantName }}</div>
        <div class="investor-context__caption">Investor Portal</div>
      </div>
    </template>
    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import WorkspaceShell from 'src/components/WorkspaceShell.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const authStore = useAuthStore();

const tenantName = computed(() => authStore.tenant?.name ?? '');
const logoutTo = computed(() =>
  authStore.tenantSlug ? `/${authStore.tenantSlug}/investor/login` : '/investor/login',
);

const links = computed(() => {
  const slug = authStore.tenantSlug;
  if (!slug) return [];

  return [
    {
      title: 'Dashboard',
      caption: 'Wallet totals',
      icon: 'ph ph-piggy-bank',
      to: `/${slug}/investor`,
    },
    {
      title: 'Shipments',
      caption: 'Investment and profit by batch',
      icon: 'ph ph-truck',
      to: `/${slug}/investor/shipments`,
    },
  ];
});
</script>

<style scoped>
.investor-context__title {
  font-weight: 700;
  color: var(--bw-theme-ink, #171412);
}

.investor-context__caption {
  font-size: 0.75rem;
  color: var(--bw-theme-muted, #736a61);
}
</style>
