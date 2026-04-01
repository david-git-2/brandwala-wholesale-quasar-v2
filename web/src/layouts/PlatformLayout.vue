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
import WorkspaceShell, { type WorkspaceLink } from 'src/components/WorkspaceShell.vue'

const links: WorkspaceLink[] = [
  {
    title: 'Dashboard',
    caption: 'Platform pulse and rollout status',
    icon: 'space_dashboard',
    to: '/platform/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Create and govern businesses',
    icon: 'apartment',
    to: '/platform/tenants',
  },
  {
    title: 'Feature Catalog',
    caption: 'Control modules and activation',
    icon: 'inventory_2',
    to: '/platform/modules',
  },
]
</script>
