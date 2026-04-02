<template>
  <div class="customer-entry">
    <section class="customer-entry__hero">
      <div class="customer-entry__eyebrow">
        {{ lookupLabel }}
      </div>

      <h1 class="customer-entry__headline">
        {{ heroTitle }}
      </h1>

      <p class="customer-entry__copy">
        {{ heroDescription }}
      </p>

      <div v-if="tenant" class="customer-entry__chips">
        <div class="customer-entry__chip">
          <span class="customer-entry__chip-label">Tenant</span>
          <span class="customer-entry__chip-value">{{ tenant.name }}</span>
        </div>

        <div class="customer-entry__chip">
          <span class="customer-entry__chip-label">Slug</span>
          <span class="customer-entry__chip-value">{{ tenant.slug }}</span>
        </div>

        <div v-if="tenant.public_domain" class="customer-entry__chip">
          <span class="customer-entry__chip-label">Public URL</span>
          <span class="customer-entry__chip-value">{{ tenant.public_domain }}</span>
        </div>
      </div>
    </section>

    <AuthLoginPanel
      scope="shop"
      eyebrow="Customer Entry"
      :title="title"
      :description="description"
      cta-label="Sign in to shop"
      :disabled="isLoginDisabled"
      :support-text="supportText"
      :tenant-slug="resolvedTenantSlug"
      tone="shop"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import AuthLoginPanel from '../components/AuthLoginPanel.vue'
import { useTenantEntryContext } from 'src/modules/tenant/composables/useTenantEntryContext'

const { error, loading, lookup, tenant, resolvedTenantSlug } = useTenantEntryContext()

const lookupLabel = computed(() => {
  if (lookup.value.source === 'public_domain') {
    return 'Tenant entry resolved from public domain'
  }

  if (lookup.value.source === 'slug') {
    return 'Tenant entry resolved from shop link'
  }

  return 'Tenant entry required'
})

const heroTitle = computed(() => {
  if (loading.value) {
    return 'Checking your shop entry.'
  }

  if (tenant.value) {
    return `${tenant.value.name} shop access`
  }

  return 'A valid tenant shop link is required.'
})

const heroDescription = computed(() => {
  if (tenant.value?.public_domain) {
    return `You are entering the customer workspace for ${tenant.value.name}. Continue with the Google account linked to your customer group for this tenant.`
  }

  if (tenant.value) {
    return `You are entering the customer workspace for ${tenant.value.name}. Continue with the Google account linked to your customer group for this tenant.`
  }

  if (error.value) {
    return error.value
  }

  return 'Open the tenant-specific shop link shared by your business to continue.'
})

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

<style scoped>
.customer-entry {
  display: grid;
  gap: 1rem;
}

.customer-entry__hero {
  padding: 1rem 1.05rem;
  border-radius: 1.35rem;
  border: 1px solid rgb(var(--bw-theme-primary-rgb) / 0.14);
  background:
    radial-gradient(circle at top right, rgb(var(--bw-theme-primary-rgb) / 0.14), transparent 28%),
    linear-gradient(180deg, rgb(255 255 255 / 0.76), rgb(255 255 255 / 0.42));
}

.customer-entry__eyebrow {
  font-size: 0.72rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--bw-theme-primary);
}

.customer-entry__headline {
  margin: 0.45rem 0 0;
  font-size: clamp(1.45rem, 3vw, 1.9rem);
  line-height: 1.08;
  color: var(--bw-theme-ink);
}

.customer-entry__copy {
  margin: 0.7rem 0 0;
  color: var(--bw-theme-muted);
  line-height: 1.6;
}

.customer-entry__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  margin-top: 0.9rem;
}

.customer-entry__chip {
  min-width: 0;
  display: grid;
  gap: 0.15rem;
  padding: 0.65rem 0.8rem;
  border-radius: 0.95rem;
  background: rgb(var(--bw-theme-primary-rgb) / 0.08);
  border: 1px solid rgb(var(--bw-theme-primary-rgb) / 0.12);
}

.customer-entry__chip-label {
  font-size: 0.67rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.customer-entry__chip-value {
  font-size: 0.92rem;
  font-weight: 600;
  color: var(--bw-theme-ink);
  word-break: break-word;
}
</style>
