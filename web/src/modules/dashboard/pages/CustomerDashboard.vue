<template>
  <q-page class="dashboard-page">
    <section class="dashboard-hero">
      <div class="dashboard-eyebrow">Customer portal</div>
      <h1>Prepare carts, confirm orders, and keep negotiation moving.</h1>
      <p>
        The shop area is designed for customer organizations. Staff can build carts, negotiators
        can confirm pricing, and customer admins can oversee the full order path.
      </p>
    </section>

    <section class="dashboard-grid">
      <article class="dashboard-card">
        <div class="dashboard-card__label">Cart building</div>
        <div class="dashboard-card__title">Staff-driven input</div>
        <p>Customer staff can prepare complex carts so ordering does not bottleneck on one person.</p>
      </article>

      <article class="dashboard-card">
        <div class="dashboard-card__label">Negotiation</div>
        <div class="dashboard-card__title">Approval flow</div>
        <p>Negotiators review terms, confirm order direction, and coordinate final acceptance.</p>
      </article>

      <article class="dashboard-card dashboard-card--accent">
        <div class="dashboard-card__label">Oversight</div>
        <div class="dashboard-card__title">Customer admin control</div>
        <p>Customer admins see the complete picture and can act across the customer-side workflow.</p>
      </article>
    </section>
  </q-page>
</template>

<style scoped>
.dashboard-page {
  display: grid;
  gap: 1rem;
}

.dashboard-hero,
.dashboard-card {
  border: 1px solid rgba(156, 88, 52, 0.12);
  border-radius: 1.5rem;
  background: rgba(255, 249, 243, 0.8);
  padding: 1.25rem;
}

.dashboard-eyebrow,
.dashboard-card__label {
  font-size: 0.74rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #8c6b56;
}

.dashboard-hero h1,
.dashboard-card__title {
  margin: 0.5rem 0 0;
  line-height: 1;
  color: #2f1d16;
}

.dashboard-hero h1 {
  font-size: clamp(2rem, 5vw, 3.2rem);
  max-width: 13ch;
}

.dashboard-hero p,
.dashboard-card p {
  margin: 0.9rem 0 0;
  max-width: 48ch;
  color: #6f5a49;
  line-height: 1.7;
}

.dashboard-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.dashboard-card--accent {
  background: linear-gradient(180deg, rgba(250, 235, 224, 0.94), rgba(243, 220, 203, 0.76));
}

@media (max-width: 900px) {
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}
</style>
