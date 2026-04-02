<template>
  <WorkspaceShell
    logout-to="/auth/app/login"
    theme="app"
    :links="links"
  >
    <template #header-left>
      <div v-if="tenantName" class="app-context__title">
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
import { useAppWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'

const authStore = useAuthStore()
const { links } = useAppWorkspaceLinks()
const tenantName = computed(() => authStore.tenant?.name ?? '')
</script>

<style scoped>
.app-context__title {
  overflow: hidden;
  font-size: clamp(1.2rem, 2vw, 1.7rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-theme-ink);
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
