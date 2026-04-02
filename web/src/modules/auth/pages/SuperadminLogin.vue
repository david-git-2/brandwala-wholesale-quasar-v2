<template>
  <AuthLoginPanel
    scope="platform"
    eyebrow="Platform Entry"
    title="Enter the platform workspace"
    description="Use your platform-approved Google account to manage tenants and modules."
    cta-label="Sign in as superadmin"
    support-text="Platform access is reserved for the BrandWala core team."
    tone="platform"
  />
</template>

<script setup lang="ts">
import AuthLoginPanel from '../components/AuthLoginPanel.vue'
</script>
