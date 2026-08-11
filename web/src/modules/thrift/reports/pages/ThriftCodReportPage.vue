<template>
  <q-page class="bw-page thrift-cod-report-page">
    <div class="bw-page__stack">
      <header class="page-nav">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="primary"
          aria-label="Back to Reports"
          :to="reportsListPath"
        />
        <div>
          <div class="text-overline text-primary">Thrift / Reports</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Money still coming</h1>
        </div>
      </header>

      <div v-if="isLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="isError" class="error-banner">
        {{ errorMessage }}
      </div>

      <template v-else>
        <section class="hero-panel">
          <div class="hero-panel__icon" aria-hidden="true">
            <q-icon name="ph ph-hand-coins" size="28px" />
          </div>
          <div class="hero-panel__label">Still expected from COD</div>
          <div class="hero-panel__amount">
            {{ formatThriftAmount(codOutstanding.codExpectedTotal) }}
          </div>
          <p class="hero-panel__note q-mb-none">
            All open COD parcels — not tied to the earn date range.
          </p>
        </section>

        <div class="support-grid">
          <div class="support-card">
            <div class="support-card__label">Invoices waiting</div>
            <div class="support-card__value">{{ codOutstanding.invoiceCount }}</div>
          </div>
          <div class="support-card">
            <div class="support-card__label">Already remitted</div>
            <div class="support-card__value">
              {{ formatThriftAmount(codOutstanding.codRemittedTotal) }}
            </div>
          </div>
        </div>

        <p class="help-text q-mb-none">
          This is cash the courier still owes you (or partially paid). It is separate from
          “How much did I earn?”
        </p>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useThriftPeriodSalesReportQuery } from '../composables/useThriftReportsQuery';

function startOfMonthIsoDate(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

function dayStartIso(date: string): string {
  return new Date(`${date}T00:00:00`).toISOString();
}

function dayEndIso(date: string): string {
  return new Date(`${date}T23:59:59.999`).toISOString();
}

const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const dateFromIso = computed(() => dayStartIso(startOfMonthIsoDate()));
const dateToIso = computed(() => dayEndIso(todayIsoDate()));
const saleChannel = ref<'IN_STORE' | 'ONLINE' | null>(null);

const {
  data: report,
  isLoading,
  isError,
  error,
} = useThriftPeriodSalesReportQuery(tenantId, dateFromIso, dateToIso, saleChannel);

const reportsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports`,
);

const codOutstanding = computed(() => report.value?.codOutstanding || {
  invoiceCount: 0,
  codExpectedTotal: 0,
  codRemittedTotal: 0,
});

const errorMessage = computed(() => {
  const err = error.value as { message?: string } | null;
  return err?.message || 'Failed to load COD';
});
</script>

<style scoped>
.page-nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.hero-panel {
  border-radius: 16px;
  padding: 1.25rem 1.25rem 1.15rem;
  background: rgba(245, 158, 11, 0.1);
  border: 1px solid rgba(245, 158, 11, 0.28);
}

.hero-panel__icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: rgba(245, 158, 11, 0.18);
  color: #b45309;
  margin-bottom: 0.75rem;
}

.hero-panel__label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--bw-theme-muted, #6b7280);
}

.hero-panel__amount {
  margin-top: 0.25rem;
  font-size: clamp(1.85rem, 5vw, 2.35rem);
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  color: #b45309;
}

.hero-panel__note {
  margin-top: 0.85rem;
  font-size: 0.8rem;
  line-height: 1.4;
  color: var(--bw-theme-muted, #6b7280);
}

.support-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.support-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
  padding: 1rem;
}

.support-card__label {
  font-size: 0.75rem;
  color: var(--bw-theme-muted, #6b7280);
}

.support-card__value {
  margin-top: 0.35rem;
  font-size: 1.35rem;
  font-weight: 700;
}

.help-text {
  font-size: 0.9rem;
  line-height: 1.45;
  color: var(--bw-theme-muted, #6b7280);
}

.error-banner {
  background: var(--q-negative);
  color: #fff;
  padding: 0.9rem 1rem;
  border-radius: 12px;
}
</style>
