<template>
  <WorkspaceShell
    badge="SHOP"
    eyebrow="Customer Workspace"
    title="Ordering Portal"
    subtitle="Build carts, coordinate approvals, and manage order negotiation with your team."
    scope-label="Customer"
    logout-to="/auth/shop/login"
    theme="shop"
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
    caption: 'Current orders, approvals, and next actions',
    icon: 'shopping_bag',
    to: '/shop/dashboard',
  },
]
</script>
