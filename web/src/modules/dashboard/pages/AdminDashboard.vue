<template>
  <q-page class="dashboard-page theme-app">
    <section class="dashboard-hero">
      <div class="dashboard-eyebrow">Internal workspace</div>
      <h1>Run tenant operations without losing visibility.</h1>
      <p>
        This is where internal teams manage tenant access, customer organizations, and the
        operational modules that power wholesale workflows.
      </p>
    </section>

    <section class="dashboard-grid">
      <article class="dashboard-card">
        <div class="dashboard-card__label">Memberships</div>
        <div class="dashboard-card__title">Internal users</div>
        <p>Admins manage staff access here. Customer-side users will live in dedicated groups.</p>
      </article>

      <article class="dashboard-card">
        <div class="dashboard-card__label">Customer groups</div>
        <div class="dashboard-card__title">External organizations</div>
        <p>Customer organizations will place orders through the shop area using their own roles.</p>
      </article>

      <article class="dashboard-card dashboard-card--accent">
        <div class="dashboard-card__label">Modules</div>
        <div class="dashboard-card__title">Tenant-enabled features</div>
        <p>Only superadmins assign modules, but internal teams work inside the enabled set.</p>
      </article>
    </section>
  </q-page>
</template>

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
  font-size: clamp(2rem, 5vw, 3.4rem);
  max-width: 14ch;
}

.dashboard-hero p,
.dashboard-card p {
  margin: 0.9rem 0 0;
  max-width: 48ch;
  color: var(--dashboard-muted);
  line-height: 1.7;
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
