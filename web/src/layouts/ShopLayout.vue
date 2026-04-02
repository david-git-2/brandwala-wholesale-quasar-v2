<template>
  <WorkspaceShell
    :logout-to="logoutTo"
    theme="shop"
    :links="links"
  >
    <template #header-left>
      <div v-if="tenantName" class="shop-context__title">
        {{ tenantName }}
      </div>
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShopWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'

const authStore = useAuthStore()
const { links } = useShopWorkspaceLinks()

const tenantName = computed(() => authStore.tenant?.name ?? '')
const logoutTo = computed(() =>
  authStore.tenant?.slug ? `/auth/shop/${authStore.tenant.slug}/login` : '/auth/shop/login',
)
</script>

<style scoped>
.shop-context__title {
  overflow: hidden;
  font-size: clamp(1.2rem, 2vw, 1.7rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
