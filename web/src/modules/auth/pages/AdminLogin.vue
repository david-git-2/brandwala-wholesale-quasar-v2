<template>
  <AuthLoginPanel
    scope="app"
    eyebrow="Internal Entry"
    title="Enter the tenant workspace"
    description="Use your approved Google account to manage internal operations, memberships, and customer organizations."
    cta-label="Continue with Google"
    support-text="Internal access is granted from tenant memberships."
    :notes="notes"
    tone="app"
  />
</template>

<script setup lang="ts">
import AuthLoginPanel from '../components/AuthLoginPanel.vue'

const notes = [
  'Admins can manage staff and customer organizations.',
  'Staff members see only the internal app area.',
]
</script>
