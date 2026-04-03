<template>
  <q-page class="dashboard-page theme-app">
    <q-banner
      v-if="!selectedTenantName"
      rounded
      class="dashboard-banner"
    >
      Choose a tenant from the tenant list to load a specific internal workspace.
    </q-banner>

    <section class="dashboard-hero">
      <div class="dashboard-copy">
        <div class="dashboard-eyebrow">Admin</div>
        <h1>{{ selectedTenantName ? `${selectedTenantName} is ready for work.` : 'Daily operations, without the clutter.' }}</h1>
        <p>
          {{
            selectedTenantName
              ? `Use the tenant list to switch workspaces when this account belongs to more than one business.`
              : 'This workspace is for internal teams handling tenant setup, member access, and the operational pieces behind wholesale activity.'
          }}
        </p>
      </div>

      <div class="dashboard-panel">
        <div class="dashboard-panel__label">Workspace</div>
        <div class="dashboard-panel__value">{{ selectedTenantName || 'Internal operations' }}</div>
        <div class="dashboard-panel__meta">
          {{
            selectedTenantName
              ? 'Tenant context is active for this internal workspace.'
              : 'Manage people, customer groups, and enabled tenant workflows.'
          }}
        </div>
      </div>
    </section>

    <section class="dashboard-strip">
      <article class="dashboard-block">
        <div class="dashboard-block__label">Members</div>
        <h2>Keep internal access tidy</h2>
        <p>Staff memberships live here, so operational access stays simple and reviewable.</p>
      </article>

      <article class="dashboard-block">
        <div class="dashboard-block__label">Customer groups</div>
        <h2>Manage external buying teams</h2>
        <p>Set up customer-side organizations and keep their access separate from staff users.</p>
      </article>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'

const tenantStore = useTenantStore()
const selectedTenantName = computed(() => tenantStore.selectedTenant?.name ?? '')
</script>

<style scoped>
.dashboard-banner {
  background: rgb(var(--bw-theme-primary-rgb) / 0.1);
  color: var(--bw-theme-ink);
  border: 1px solid rgb(var(--bw-theme-primary-rgb) / 0.15);
}

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
  max-width: 44rem;
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
  font-size: clamp(2rem, 4vw, 3.2rem);
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
