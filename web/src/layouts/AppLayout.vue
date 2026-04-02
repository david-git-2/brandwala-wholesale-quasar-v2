<template>
  <WorkspaceShell
    badge="APP"
    eyebrow="Tenant Workspace"
    title="Internal Operations"
    subtitle="Manage members, configure customer groups, and run daily wholesale work."
    scope-label="Internal"
    logout-to="/auth/app/login"
    theme="app"
    :links="links"
  >
    <template #header-extra>
      <TenantSelector />
    </template>

    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import TenantSelector from 'src/components/TenantSelector.vue'
import { useAppWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'

const { links } = useAppWorkspaceLinks()
</script>
