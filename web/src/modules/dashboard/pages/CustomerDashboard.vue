<template>
  <q-page class="dashboard-page theme-shop">
    <section class="dashboard-hero">
      <div class="dashboard-eyebrow">Customer portal</div>
      <h1>{{ headline }}</h1>
      <p>{{ introCopy }}</p>

      <div class="dashboard-meta row q-col-gutter-sm">
        <div class="col-auto">
          <q-chip
            dense
            color="white"
            text-color="dark"
            icon="storefront"
            class="dashboard-chip"
          >
            {{ tenantName }}
          </q-chip>
        </div>
        <div class="col-auto" v-if="customerGroupName">
          <q-chip
            dense
            color="white"
            text-color="dark"
            icon="groups"
            class="dashboard-chip"
          >
            {{ customerGroupName }}
          </q-chip>
        </div>
        <div class="col-auto">
          <q-chip
            dense
            color="white"
            text-color="dark"
            icon="badge"
            class="dashboard-chip"
          >
            {{ roleLabel }}
          </q-chip>
        </div>
      </div>
    </section>

    <section class="dashboard-grid">
      <article class="dashboard-card">
        <div class="dashboard-card__label">Your role</div>
        <div class="dashboard-card__title">{{ roleLabel }}</div>
        <p>{{ roleSummary }}</p>
      </article>

      <article class="dashboard-card">
        <div class="dashboard-card__label">Enabled modules</div>
        <div class="dashboard-card__title">{{ enabledModuleCount }} active</div>
        <p>
          Navigation in this workspace is generated from your tenant's enabled modules plus your
          customer-group role.
        </p>
      </article>

      <article class="dashboard-card dashboard-card--accent">
        <div class="dashboard-card__label">Access model</div>
        <div class="dashboard-card__title">Customer-group controlled</div>
        <p>
          Shop access is now tied to customer-group membership, so internal tenant users do not
          enter this area unless they are also assigned to this customer group.
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
    return `Keep ${customerGroupName.value} moving.`
  }

  return 'Prepare carts, confirm orders, and keep negotiation moving.'
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
  --dashboard-surface: color-mix(in srgb, var(--bw-theme-surface) 90%, white 10%);
  --dashboard-ink: var(--bw-theme-ink);
  --dashboard-muted: var(--bw-theme-muted);
  --dashboard-accent-soft: rgb(var(--bw-theme-primary-rgb) / 0.12);
  display: grid;
  gap: 1rem;
}

.dashboard-hero,
.dashboard-card {
  border: 1px solid var(--dashboard-border);
  border-radius: 1.5rem;
  background: var(--dashboard-surface);
  padding: 1.25rem;
}

.dashboard-eyebrow,
.dashboard-card__label {
  font-size: 0.74rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--dashboard-muted);
}

.dashboard-hero h1,
.dashboard-card__title {
  margin: 0.5rem 0 0;
  line-height: 1;
  color: var(--dashboard-ink);
}

.dashboard-hero h1 {
  font-size: clamp(2rem, 5vw, 3.2rem);
  max-width: 14ch;
}

.dashboard-hero p,
.dashboard-card p {
  margin: 0.9rem 0 0;
  max-width: 54ch;
  color: var(--dashboard-muted);
  line-height: 1.7;
}

.dashboard-meta {
  margin-top: 1rem;
}

.dashboard-chip {
  border: 1px solid var(--dashboard-border);
  box-shadow: 0 10px 18px rgb(var(--bw-theme-primary-rgb) / 0.08);
}

.dashboard-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.dashboard-card--accent {
  background: linear-gradient(180deg, var(--dashboard-accent-soft), var(--dashboard-surface));
}

@media (max-width: 900px) {
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}
</style>
