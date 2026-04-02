<template>
  <q-page class="dashboard-page theme-platform">
    <section class="dashboard-hero">
      <div>
        <div class="dashboard-eyebrow">Platform overview</div>
        <h1>Keep tenants, features, and rollout controls aligned.</h1>
        <p>
          This area is the command surface for superadmins. From here, BrandWala can shape how
          each business enters the platform and which modules are available.
        </p>
      </div>

      <div class="dashboard-chip">Signed in as {{ authStore.matchedRole }}</div>
    </section>

    <section class="dashboard-grid">
      <article class="dashboard-card">
        <div class="dashboard-card__label">Tenants</div>
        <div class="dashboard-card__title">Business rollout</div>
        <p>Create tenants, verify domains, and keep activation status clean.</p>
      </article>

      <article class="dashboard-card">
        <div class="dashboard-card__label">Modules</div>
        <div class="dashboard-card__title">Feature governance</div>
        <p>Control what each tenant can see and keep navigation generated from enabled modules.</p>
      </article>

      <article class="dashboard-card dashboard-card--accent">
        <div class="dashboard-card__label">Direction</div>
        <div class="dashboard-card__title">Customer groups next</div>
        <p>The next major slice is customer-group access and the shop-side ordering flow.</p>
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
  --dashboard-surface: color-mix(in srgb, var(--bw-theme-surface) 88%, white 12%);
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

.dashboard-hero {
  display: grid;
  gap: 1rem;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: start;
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
  margin: 0.4rem 0 0;
  line-height: 1;
  color: var(--dashboard-ink);
}

.dashboard-hero h1 {
  font-size: clamp(2rem, 5vw, 3.4rem);
  max-width: 13ch;
}

.dashboard-hero p,
.dashboard-card p {
  margin: 0.9rem 0 0;
  max-width: 48ch;
  color: var(--dashboard-muted);
  line-height: 1.7;
}

.dashboard-chip {
  padding: 0.7rem 0.95rem;
  border-radius: 999px;
  background: var(--dashboard-accent-soft);
  color: var(--dashboard-ink);
  white-space: nowrap;
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
  .dashboard-hero,
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}
</style>
