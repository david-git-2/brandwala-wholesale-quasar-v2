<template>
  <WorkspaceShell
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
