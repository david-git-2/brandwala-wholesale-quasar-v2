<template>
  <figure class="landing-preview hero-ui" aria-hidden="true">
    <div class="hero-ui__chrome">
      <span class="hero-ui__crumb">Inbound</span>
      <span class="hero-ui__crumb-sep">/</span>
      <span>Shipments</span>
    </div>
    <div class="hero-ui__toolbar">
      <div class="hero-ui__search">
        <i class="ph ph-magnifying-glass" />
        Search by shipment name or ID...
      </div>
      <span class="hero-ui__new">New Shipment</span>
    </div>
    <div class="hero-ui__list">
      <div class="hero-ui__row">
        <div class="hero-ui__info">
          <div class="hero-ui__name">Oct Korea — COSRX / innisfree</div>
          <div class="hero-ui__meta">
            Seoul Beauty Ltd · Air · 12 Oct 2026
          </div>
        </div>
        <TfStatusBadge status="shipped" label="In transit" />
      </div>
      <div class="hero-ui__row hero-ui__row--open">
        <div class="hero-ui__info">
          <div class="hero-ui__name">SHP-24081 Dhaka receive</div>
          <div class="hero-ui__meta">Seoul Beauty Ltd · Sea · 4 Oct 2026</div>
        </div>
        <TfStatusBadge status="received" label="Received" />
      </div>
    </div>
    <table class="hero-ui__table">
      <thead>
        <tr>
          <th>SKU</th>
          <th>Product</th>
          <th class="tf-num">Qty</th>
          <th class="tf-num">Landed</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="hero-ui__sku">COSRX-SN96-100</td>
          <td>Snail Mucin 96 100ml</td>
          <td class="tf-num">240</td>
          <td class="tf-num hero-ui__cost">৳ 1,84,200</td>
        </tr>
        <tr>
          <td class="hero-ui__sku">INNI-GTS-80</td>
          <td>Green Tea Seed 80ml</td>
          <td class="tf-num">150</td>
          <td class="tf-num hero-ui__cost">৳ 96,750</td>
        </tr>
      </tbody>
    </table>
    <div class="hero-ui__foot">
      <TfStatusBadge status="completed" label="Cost locked" />
    </div>
    <figcaption class="landing-preview__caption">{{ landingCopy.previewCaption }}</figcaption>
  </figure>
</template>

<script setup lang="ts">
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { landingCopy } from '../../content';
</script>

<style scoped>
.hero-ui {
  pointer-events: none;
  user-select: none;
}

.hero-ui__chrome {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  border-bottom: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-canvas);
  font-size: var(--tf-text-meta);
  font-weight: 600;
  color: var(--tf-neutral-ink);
}

.hero-ui__crumb {
  color: var(--tf-neutral-chrome-text);
  font-weight: 500;
}

.hero-ui__crumb-sep {
  color: var(--tf-neutral-chrome);
}

.hero-ui__toolbar {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.5rem;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.hero-ui__search {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 0.375rem;
  min-height: 28px;
  padding: 0 0.5rem;
  border: 1px solid var(--tf-neutral-border-strong);
  border-radius: var(--tf-radius-sm);
  font-size: 12px;
  color: var(--tf-neutral-chrome-text);
}

.hero-ui__new {
  flex-shrink: 0;
  padding: 0.25rem 0.5rem;
  border-radius: var(--tf-radius-sm);
  background: var(--tf-theme-primary);
  color: var(--tf-theme-on-primary);
  font-size: 12px;
  font-weight: 600;
}

.hero-ui__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  min-height: 44px;
  padding: 0.5rem 0.75rem;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.hero-ui__row--open {
  background: var(--tf-theme-primary-soft);
}

.hero-ui__name {
  font-size: 13px;
  font-weight: 600;
  letter-spacing: -0.01em;
}

.hero-ui__meta {
  margin-top: 2px;
  font-size: 11.5px;
  color: var(--tf-neutral-muted);
}

.hero-ui__table {
  width: 100%;
  border-collapse: collapse;
}

.hero-ui__table th,
.hero-ui__table td {
  padding: 4px 8px;
  border-bottom: 1px solid var(--tf-neutral-border);
  font-size: 12px;
  text-align: left;
}

.hero-ui__table th {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text);
  background: var(--tf-neutral-canvas);
}

.hero-ui__sku {
  font-family: var(--tf-font-mono);
  white-space: nowrap;
}

.hero-ui__cost {
  background: var(--tf-ops-hue-cost);
}

.hero-ui__foot {
  padding: 0.375rem 0.75rem;
}
</style>
