<template>
  <section class="procurement-card">
    <!-- Ship Illustration Background -->
    <div class="procurement-card__bg" />
    <div class="procurement-card__vignette" />

    <!-- Top Left: Stock Inventory & Valuation (Click to open on-paper ledger slide drawer) -->
    <div class="procurement-card__top-left">
      <div
        class="glass-panel glass-panel--top glass-panel--interactive"
        role="button"
        tabindex="0"
        @click="showStockDetail = true"
        @keydown.enter="showStockDetail = true"
      >
        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--success" />
            <span class="stat-item__label">Sellable Stock</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">14,280</span>
            <span class="stat-item__unit">Pcs</span>
          </div>
        </div>

        <div class="glass-divider" />

        <div class="stat-item">
          <div class="stat-item__header">
            <span class="pulse-dot pulse-dot--primary" />
            <span class="stat-item__label">Stock Valuation</span>
          </div>
          <div class="stat-item__value-row">
            <span class="stat-item__number">৳8.45M</span>
            <span class="stat-item__badge">Landed BDT</span>
          </div>
        </div>

        <i class="ph ph-chart-donut glass-panel__action-icon" />
      </div>
    </div>

    <!-- Bottom Right: Pipeline & Logistics Movement (Click to navigate to Shipments page) -->
    <div class="procurement-card__bottom-right">
      <div
        class="glass-panel glass-panel--bottom glass-panel--interactive"
        role="button"
        tabindex="0"
        @click="navigateToShipments"
        @keydown.enter="navigateToShipments"
      >
        <div class="pill-stat pill-stat--transit">
          <div class="pill-stat__icon">
            <i class="ph ph-boat" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">In Transit</span>
            <span class="pill-stat__value">4 Batches</span>
          </div>
        </div>

        <div class="pill-stat pill-stat--processing">
          <div class="pill-stat__icon">
            <i class="ph ph-hourglass-medium" />
          </div>
          <div class="pill-stat__meta">
            <span class="pill-stat__label">Under Processing</span>
            <span class="pill-stat__value">3 Batches</span>
          </div>
        </div>

        <i class="ph ph-arrow-up-right glass-panel__action-icon" />
      </div>
    </div>

    <!-- On-Paper Ledger Slide Drawer -->
    <ProcurementStockDetailDialog v-model="showStockDetail" />
  </section>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import ProcurementStockDetailDialog from './ProcurementStockDetailDialog.vue';

const router = useRouter();
const route = useRoute();

const showStockDetail = ref(false);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const navigateToShipments = () => {
  if (tenantSlug.value) {
    void router.push(`/${tenantSlug.value}/app/procurement/shipment/list`);
  } else {
    void router.push('/app/procurement/shipment/list');
  }
};
</script>

<style scoped>
.procurement-card {
  position: relative;
  width: 100%;
  min-height: 300px;
  height: clamp(300px, 38vw, 460px);
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  box-shadow: none;
  background: var(--bw-theme-surface, #ffffff);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 1.25rem 1.45rem;
}

.procurement-card__bg {
  position: absolute;
  inset: 0;
  background-image: url('src/assets/procurement-ship-bg.jpg');
  background-size: cover;
  background-position: center 42%;
  background-repeat: no-repeat;
  z-index: 1;
}

.procurement-card__vignette {
  position: absolute;
  inset: 0;
  background: radial-gradient(
    circle at 20% 20%,
    rgba(255, 255, 255, 0.35) 0%,
    transparent 50%
  ),
  radial-gradient(
    circle at 85% 85%,
    rgba(255, 255, 255, 0.35) 0%,
    transparent 50%
  );
  pointer-events: none;
  z-index: 2;
}

/* --- OVERLAY POSITIONS --- */
.procurement-card__top-left {
  position: relative;
  z-index: 3;
  width: fit-content;
  align-self: flex-start;
}

.procurement-card__bottom-right {
  position: relative;
  z-index: 3;
  width: fit-content;
  align-self: flex-end;
}

/* --- FROSTED GLASS PANELS --- */
.glass-panel {
  display: flex;
  align-items: center;
  gap: 1.15rem;
  background: rgba(255, 255, 255, 0.68);
  backdrop-filter: blur(18px) saturate(180%);
  -webkit-backdrop-filter: blur(18px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.75);
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.06);
  border-radius: 12px;
  padding: 0.75rem 1.15rem;
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

.glass-panel--interactive {
  cursor: pointer;
  user-select: none;
}

.glass-panel--interactive:hover {
  transform: translateY(-2px);
  background: rgba(255, 255, 255, 0.88);
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
}

.glass-panel__action-icon {
  font-size: 1.05rem;
  color: #94a3b8;
  transition: all 0.2s ease;
  margin-left: 0.15rem;
}

.glass-panel--interactive:hover .glass-panel__action-icon {
  color: var(--bw-theme-primary, #0284c7);
  transform: scale(1.15) translate(1px, -1px);
}

.glass-panel--bottom {
  gap: 0.75rem;
  padding: 0.55rem 0.85rem;
  background: rgba(255, 255, 255, 0.72);
}

/* --- STAT ITEM (TOP LEFT) --- */
.stat-item {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.stat-item__header {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.pulse-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  display: inline-block;
}

.pulse-dot--success {
  background: #10b981;
  box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.25);
}

.pulse-dot--primary {
  background: #0284c7;
  box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.25);
}

.stat-item__label {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #475569;
}

.stat-item__value-row {
  display: flex;
  align-items: baseline;
  gap: 0.35rem;
}

.stat-item__number {
  font-size: 1.45rem;
  font-weight: 800;
  color: #0f172a;
  letter-spacing: -0.02em;
  line-height: 1.15;
}

.stat-item__unit {
  font-size: 0.76rem;
  font-weight: 600;
  color: #64748b;
}

.stat-item__badge {
  font-size: 0.68rem;
  font-weight: 700;
  color: #0284c7;
  background: rgba(2, 132, 199, 0.12);
  padding: 0.1rem 0.35rem;
  border-radius: 4px;
}

.glass-divider {
  width: 1px;
  height: 32px;
  background: rgba(203, 213, 225, 0.8);
}

/* --- PILL STAT (BOTTOM RIGHT) --- */
.pill-stat {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  padding: 0.35rem 0.65rem;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.65);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 1px solid rgba(255, 255, 255, 0.7);
}

.pill-stat__icon {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.95rem;
}

.pill-stat--transit .pill-stat__icon {
  background: rgba(2, 132, 199, 0.15);
  color: #0284c7;
}

.pill-stat--processing .pill-stat__icon {
  background: rgba(245, 158, 11, 0.15);
  color: #d97706;
}

.pill-stat__meta {
  display: flex;
  flex-direction: column;
}

.pill-stat__label {
  font-size: 0.68rem;
  font-weight: 600;
  color: #64748b;
  line-height: 1.1;
}

.pill-stat__value {
  font-size: 0.84rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.2;
}

@media (max-width: 640px) {
  .procurement-card {
    gap: 1rem;
  }
  .procurement-card__bottom-right {
    align-self: flex-start;
  }
  .glass-panel--top {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.65rem;
  }
  .glass-divider {
    display: none;
  }
  .glass-panel--bottom {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
