<template>
  <q-page class="dashboard-page theme-shop">
    <section class="dashboard-hero">
      <div class="dashboard-copy">
        <div class="dashboard-eyebrow">Customer</div>
        <h1>{{ headline }}</h1>
        <p>{{ introCopy }}</p>
      </div>

      <div class="dashboard-panel">
        <div class="dashboard-panel__label">Current access</div>
        <div class="dashboard-panel__value">{{ roleLabel }}</div>
        <div class="dashboard-panel__meta">
          {{ customerGroupName || tenantName }}
        </div>
      </div>
    </section>

    <section class="dashboard-strip">
      <article class="dashboard-block">
        <div class="dashboard-block__label">Role</div>
        <h2>{{ roleLabel }}</h2>
        <p>{{ roleSummary }}</p>
      </article>

      <article class="dashboard-block">
        <div class="dashboard-block__label">Modules</div>
        <h2>{{ enabledModuleCount }} active</h2>
        <p>
          Your navigation is built from the modules enabled for this tenant and your customer-group
          access.
        </p>
      </article>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'

const authStore = useAuthStore()

const tenantName = computed(() => authStore.tenant?.name ?? 'Tenant workspace')
const customerGroupName = computed(
  () => authStore.customerGroup?.name ?? authStore.member?.name ?? '',
)
const enabledModuleCount = computed(() => authStore.activeModuleKeys.length)

const roleLabel = computed(() => {
  switch (authStore.matchedRole) {
    case 'customer_admin':
      return 'Customer Admin'
    case 'customer_negotiator':
      return 'Customer Negotiator'
    case 'customer_staff':
      return 'Customer Staff'
    default:
      return 'Customer User'
  }
})

const headline = computed(() => {
  if (customerGroupName.value) {
    return `${customerGroupName.value} stays focused here.`
  }

  return 'Keep ordering, approvals, and negotiation in one place.'
})

const introCopy = computed(() => {
  if (customerGroupName.value) {
    return `${customerGroupName.value} is signed in to ${tenantName.value}. This shop workspace is scoped to your customer-group access and only shows the modules your tenant has enabled for you.`
  }

  return `This shop workspace is scoped to your customer-group access in ${tenantName.value} and only shows the modules your tenant has enabled for you.`
})

const roleSummary = computed(() => {
  switch (authStore.matchedRole) {
    case 'customer_admin':
      return 'You can oversee the whole customer-side workflow and step across the enabled shop experience.'
    case 'customer_negotiator':
      return 'You can manage negotiation-focused work and confirm the next step inside the enabled shop flow.'
    case 'customer_staff':
      return 'You can prepare carts and keep order input moving inside the enabled shop flow.'
    default:
      return 'Your shop access is based on your customer-group membership.'
  }
})
</script>

<style scoped>
.dashboard-page {
  --dashboard-border: var(--bw-theme-border);
  --dashboard-surface: color-mix(in srgb, var(--bw-theme-surface) 94%, white 6%);
  --dashboard-ink: var(--bw-theme-ink);
  --dashboard-muted: var(--bw-theme-muted);
  --dashboard-accent-soft: rgb(var(--bw-theme-primary-rgb) / 0.1);
  display: grid;
  gap: 1.25rem;
}

.dashboard-hero,
.dashboard-block,
.dashboard-panel {
  border: 1px solid var(--dashboard-border);
  border-radius: 1.25rem;
  background: var(--dashboard-surface);
  padding: 1.35rem;
}

.dashboard-hero {
  display: grid;
  gap: 1.25rem;
  grid-template-columns: minmax(0, 1.4fr) minmax(220px, 0.7fr);
  align-items: stretch;
}

.dashboard-copy {
  max-width: 46rem;
}

.dashboard-eyebrow,
.dashboard-panel__label,
.dashboard-block__label {
  font-size: 0.74rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--dashboard-muted);
}

.dashboard-hero h1 {
  margin: 0.45rem 0 0;
  line-height: 1.02;
  color: var(--dashboard-ink);
  font-size: clamp(2rem, 4vw, 3rem);
  max-width: 14ch;
}

.dashboard-hero p,
.dashboard-block p,
.dashboard-panel__meta {
  margin: 0.85rem 0 0;
  color: var(--dashboard-muted);
  line-height: 1.65;
}

.dashboard-panel {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  background: var(--dashboard-accent-soft);
}

.dashboard-panel__value {
  margin-top: 0.45rem;
  font-size: 1.6rem;
  font-weight: 700;
  color: var(--dashboard-ink);
}

.dashboard-strip {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.dashboard-block h2 {
  margin: 0.4rem 0 0;
  font-size: 1.18rem;
  color: var(--dashboard-ink);
}

@media (max-width: 900px) {
  .dashboard-hero,
  .dashboard-strip {
    grid-template-columns: 1fr;
  }
}
</style>
