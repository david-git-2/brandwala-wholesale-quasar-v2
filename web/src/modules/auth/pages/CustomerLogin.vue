<template>
  <AuthLoginPanel
    scope="shop"
    eyebrow="Customer Entry"
    :title="title"
    :description="description"
    cta-label="Sign in to shop"
    :disabled="isLoginDisabled"
    :support-text="supportText"
    tone="shop"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'

import AuthLoginPanel from '../components/AuthLoginPanel.vue'
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext'

const { error, loading, tenant } = useTenantEntryContext()

const title = computed(() =>
  tenant.value ? `Enter ${tenant.value.name}` : 'Enter the shop workspace',
)

const description = computed(() => {
  if (loading.value) {
    return 'Checking which tenant workspace this shop link belongs to.'
  }

  if (error.value) {
    return error.value
  }

  if (tenant.value) {
    return `Sign in with the Google account linked to your customer group for ${tenant.value.name}.`
  }

  return 'Sign in with the Google account linked to your customer group.'
})

const supportText = computed(() => {
  if (tenant.value?.public_domain) {
    return `Customer access is validated by tenant and customer-group membership. This tenant can also be reached through ${tenant.value.public_domain}.`
  }

  return 'Customer access is validated by tenant and customer-group membership for this shop entry.'
})

const isLoginDisabled = computed(
  () => loading.value || !tenant.value,
)
</script>
