<template>
  <AuthLoginPanel
    scope="app"
    eyebrow="Internal Entry"
    title="Enter the app workspace"
    description="Use your approved Google account to access internal operations."
    cta-label="Continue with Google"
    support-text="Internal access is granted from tenant memberships."
    tone="app"
  />
</template>

<script setup lang="ts">
import AuthLoginPanel from '../components/AuthLoginPanel.vue'
</script>
