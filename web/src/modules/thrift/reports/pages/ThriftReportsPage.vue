<template>
  <q-page class="bw-page thrift-reports-page">
    <div class="bw-page__stack">
      <header class="page-header">
        <div class="text-overline text-primary">Thrift</div>
        <h1 class="text-h4 text-weight-bold q-my-none">Reports</h1>
        <p class="page-header__sub q-mb-none">What do you want to know?</p>
      </header>

      <div class="portal-stack">
        <button type="button" class="portal-card" @click="goEarn">
          <span class="portal-card__icon portal-card__icon--earn" aria-hidden="true">
            <q-icon name="ph ph-coins" size="26px" />
          </span>
          <span class="portal-card__body">
            <span class="portal-card__title">How much did I earn?</span>
            <span class="portal-card__caption">
              Profit after your product cost and shipping
            </span>
          </span>
          <q-icon name="ph ph-caret-right" class="portal-card__chevron" size="22px" aria-hidden="true" />
        </button>

        <button type="button" class="portal-card" @click="goCod">
          <span class="portal-card__icon portal-card__icon--cod" aria-hidden="true">
            <q-icon name="ph ph-hand-coins" size="26px" />
          </span>
          <span class="portal-card__body">
            <span class="portal-card__title">Money still coming?</span>
            <span class="portal-card__caption">
              COD waiting to be collected from courier
            </span>
          </span>
          <q-icon name="ph ph-caret-right" class="portal-card__chevron" size="22px" aria-hidden="true" />
        </button>

        <button type="button" class="portal-card" @click="goShipments">
          <span class="portal-card__icon portal-card__icon--buy" aria-hidden="true">
            <q-icon name="ph ph-package" size="26px" />
          </span>
          <span class="portal-card__body">
            <span class="portal-card__title">Was this purchase worth it?</span>
            <span class="portal-card__caption">
              Profit for one inbound shipment (carton)
            </span>
          </span>
          <q-icon name="ph ph-caret-right" class="portal-card__chevron" size="22px" aria-hidden="true" />
        </button>
      </div>

      <section class="glance-card">
        <div class="glance-card__label">Shop glance</div>
        <div v-if="metricsLoading" class="row justify-center q-py-md">
          <q-spinner color="primary" size="24px" />
        </div>
        <div v-else-if="metricsError" class="text-negative text-body2">
          {{ metricsErrorMessage }}
        </div>
        <div v-else-if="metrics" class="glance-card__grid">
          <div class="glance-card__metric">
            <div class="glance-card__value text-positive">{{ metrics.availableItems }}</div>
            <div class="glance-card__meta">Available</div>
          </div>
          <div class="glance-card__metric">
            <div class="glance-card__value">{{ metrics.soldItems }}</div>
            <div class="glance-card__meta">Sold</div>
          </div>
          <div class="glance-card__metric">
            <div class="glance-card__value text-warning">{{ metrics.codPendingCount }}</div>
            <div class="glance-card__meta">COD waiting</div>
          </div>
        </div>
      </section>

      <div class="text-center">
        <q-btn
          flat
          dense
          no-caps
          color="grey-7"
          icon-right="ph ph-arrow-right"
          label="Money in/out history"
          @click="goLedger"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftDashboardMetricsQuery } from '../composables/useThriftReportsQuery';

const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const {
  data: metrics,
  isLoading: metricsLoading,
  isError: metricsError,
  error: metricsErr,
} = useThriftDashboardMetricsQuery(tenantId);

const metricsErrorMessage = computed(() => {
  const err = metricsErr.value as { message?: string } | null;
  return err?.message || 'Failed to load shop glance';
});

const base = computed(() => `/${tenantSlug.value || 'tenant'}/app/thrift`);

function goEarn() {
  void router.push(`${base.value}/reports/sales`);
}

function goCod() {
  void router.push(`${base.value}/reports/cod`);
}

function goShipments() {
  void router.push(`${base.value}/reports/shipments`);
}

function goLedger() {
  void router.push(`${base.value}/ledger`);
}
</script>

<style scoped>
.page-header__sub {
  margin-top: 0.35rem;
  color: var(--bw-theme-muted, #6b7280);
  font-size: 0.95rem;
}

.portal-stack {
  display: grid;
  gap: 0.75rem;
}

.portal-card {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  width: 100%;
  padding: 1rem 1rem;
  min-height: 88px;
  text-align: left;
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
  color: inherit;
  cursor: pointer;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease,
    transform 0.12s ease;
}

.portal-card:hover {
  border-color: var(--bw-theme-primary, var(--q-primary));
  box-shadow: var(--bw-theme-shadow, 0 8px 24px rgb(0 0 0 / 0.06));
}

.portal-card:active {
  transform: scale(0.99);
}

.portal-card__icon {
  flex: 0 0 auto;
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.portal-card__icon--earn {
  background: var(--bw-theme-primary-soft, rgb(var(--bw-theme-primary-rgb, 52 211 153) / 0.15));
  color: var(--bw-theme-primary, var(--q-primary));
}

.portal-card__icon--cod {
  background: rgba(245, 158, 11, 0.14);
  color: #b45309;
}

.portal-card__icon--buy {
  background: rgba(55, 65, 81, 0.1);
  color: #374151;
}

.portal-card__body {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.portal-card__title {
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1.3;
  color: var(--bw-theme-ink, inherit);
}

.portal-card__caption {
  font-size: 0.875rem;
  line-height: 1.35;
  color: var(--bw-theme-muted, #6b7280);
}

.portal-card__chevron {
  flex: 0 0 auto;
  color: var(--bw-theme-muted, #9ca3af);
}

.glance-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  padding: 1rem 1.1rem;
  background: var(--bw-theme-surface, #fff);
}

.glance-card__label {
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #6b7280);
  margin-bottom: 0.75rem;
}

.glance-card__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  text-align: center;
}

.glance-card__value {
  font-size: 1.35rem;
  font-weight: 700;
  line-height: 1.2;
}

.glance-card__meta {
  margin-top: 0.2rem;
  font-size: 0.75rem;
  color: var(--bw-theme-muted, #6b7280);
}
</style>
