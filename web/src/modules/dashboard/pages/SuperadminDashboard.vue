<template>
  <q-page class="dashboard-page theme-platform">
    <section class="dashboard-hero">
      <div class="dashboard-copy">
        <div class="dashboard-eyebrow">Platform</div>
        <h1>Platform control stays here.</h1>
        <p>
          Use this workspace to keep tenants, modules, and access rules in sync without digging
          through extra panels.
        </p>
      </div>

      <div class="dashboard-panel">
        <div class="dashboard-panel__label">Current access</div>
        <div class="dashboard-panel__value">{{ authStore.matchedRole }}</div>
        <div class="dashboard-panel__meta">Superadmin tools and rollout controls are available.</div>
      </div>
    </section>

    <section class="dashboard-strip">
      <article class="dashboard-block">
        <div class="dashboard-block__label">Tenants</div>
        <h2>Govern workspace rollout</h2>
        <p>Create businesses, review their status, and keep platform access clean.</p>
      </article>

      <article class="dashboard-block">
        <div class="dashboard-block__label">Modules</div>
        <h2>Control feature exposure</h2>
        <p>Decide which modules exist and which tenants are allowed to use them.</p>
      </article>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const authStore = useAuthStore();
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
  max-width: 12ch;
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
  text-transform: capitalize;
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
