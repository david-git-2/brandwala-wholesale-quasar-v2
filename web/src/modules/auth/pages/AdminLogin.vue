<template>
  <AuthLoginPanel
    scope="app"
    title="App Login"
    cta-label="Continue with Google"
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
