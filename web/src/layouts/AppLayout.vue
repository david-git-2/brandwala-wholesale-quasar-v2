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
import WorkspaceShell, { type WorkspaceLink } from 'src/components/WorkspaceShell.vue'
import TenantSelector from 'src/components/TenantSelector.vue'

const links: WorkspaceLink[] = [
  {
    title: 'Dashboard',
    caption: 'Internal activity and quick actions',
    icon: 'insights',
    to: '/app/dashboard',
  },
  {
    title: 'Tenants',
    caption: 'Open tenant details and assignments',
    icon: 'domain',
    to: '/app/tenants',
  },
]
</script>
