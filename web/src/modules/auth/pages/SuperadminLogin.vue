<template>
  <AuthLoginPanel
    scope="platform"
    eyebrow="Platform Entry"
    title="Enter the superadmin platform"
    description="Use your platform-approved Google account to manage tenants, control enabled modules, and govern the system."
    cta-label="Sign in as superadmin"
    support-text="Platform access is reserved for the BrandWala core team."
    :notes="notes"
    tone="platform"
  />
</template>

<script setup lang="ts">
import AuthLoginPanel from '../components/AuthLoginPanel.vue'

const notes = [
  'Superadmins can create tenants and control module availability.',
  'This entry point governs the whole platform, not a single business.',
]
</script>
