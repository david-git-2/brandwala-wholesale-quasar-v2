<template>
  <AuthLoginPanel
    scope="shop"
    eyebrow="Customer Entry"
    title="Enter the shop workspace"
    description="Sign in with the Google account linked to your customer group."
    cta-label="Sign in to shop"
    support-text="Customer access is validated through customer-group membership for the shop scope."
    tone="shop"
  />
</template>

<script setup lang="ts">
import AuthLoginPanel from '../components/AuthLoginPanel.vue'
</script>
