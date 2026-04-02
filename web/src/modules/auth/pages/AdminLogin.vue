<template>
  <AuthLoginPanel
    scope="app"
    eyebrow="Internal Entry"
    title="Enter the app workspace"
    description="Use your approved Google account to access internal operations."
    cta-label="Continue with Google"
    support-text="Internal access is granted from tenant memberships."
    :tenant-slug="tenantSlug"
    tone="app"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import AuthLoginPanel from '../components/AuthLoginPanel.vue'

const route = useRoute()
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
)
</script>
