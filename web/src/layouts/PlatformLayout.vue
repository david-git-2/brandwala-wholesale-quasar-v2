<template>
  <WorkspaceShell
    badge="BW"
    eyebrow="BrandWala Core"
    title="Platform Control"
    subtitle="Configure tenants, modules, and platform-wide access from one place."
    scope-label="Superadmin"
    logout-to="/auth/platform/login"
    theme="platform"
    :links="links"
  >
    <router-view />
  </WorkspaceShell>
</template>

<script setup lang="ts">
import WorkspaceShell from 'src/components/WorkspaceShell.vue'
import { usePlatformWorkspaceLinks } from 'src/modules/navigation/useWorkspaceNavigation'

const { links } = usePlatformWorkspaceLinks()
</script>
