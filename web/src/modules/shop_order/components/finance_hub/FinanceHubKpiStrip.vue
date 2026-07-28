<template>
  <div class="row q-col-gutter-md">
    <div class="col-12 col-md-4">
      <q-card flat bordered class="stat-card">
        <q-card-section>
          <div class="text-caption text-uppercase text-weight-medium text-negative">
            1. Courier COD Liability
          </div>
          <div class="text-h5 text-weight-bold q-mt-xs">
            {{ formatCurrency(kpis.courierOwedTotal) }}
          </div>
          <div class="text-caption text-muted q-mt-2">
            Held by couriers (Pending Remittance)
          </div>
        </q-card-section>
      </q-card>
    </div>

    <div class="col-12 col-md-4">
      <q-card flat bordered class="stat-card">
        <q-card-section>
          <div class="text-caption text-uppercase text-weight-medium text-positive">
            2. Tenant Operations Cash
          </div>
          <div class="text-h5 text-weight-bold q-mt-xs">
            {{ formatCurrency(kpis.tenantCashTotal) }}
          </div>
          <div class="text-caption text-muted q-mt-2">
            Remitted cash in tenant treasury
          </div>
        </q-card-section>
      </q-card>
    </div>

    <div class="col-12 col-md-4">
      <q-card flat bordered class="stat-card">
        <q-card-section>
          <div class="text-caption text-uppercase text-weight-medium text-warning">
            3. Middleman Profit Payable
          </div>
          <div class="text-h5 text-weight-bold q-mt-xs">
            {{ formatCurrency(kpis.middlemanPayableTotal) }}
          </div>
          <div class="text-caption text-muted q-mt-2">
            Owed to merchant / middleman profiles
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { FinanceHubKpiSummary } from '../../repositories/dropshipFinanceRepository';

defineProps<{
  kpis: FinanceHubKpiSummary;
}>();

function formatCurrency(val: number) {
  return new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT', minimumFractionDigits: 0 }).format(val || 0);
}
</script>

<style scoped>
.stat-card {
  border-radius: 10px;
  background: var(--bw-theme-surface);
}
.text-muted {
  color: var(--bw-theme-muted);
}
</style>
