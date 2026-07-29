<template>
  <div class="q-mt-lg">
    <div class="text-subtitle1 text-weight-bold q-mb-sm text-grey-9 row items-center">
      <q-icon name="ph ph-chart-line-up" class="q-mr-xs text-primary" size="20px" />
      Summary Metrics & Cost Breakdown
    </div>

    <div class="row q-col-gutter-md">
      <!-- Goods Cost Card -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="q-pa-md fill-height card-hover metric-card bg-surface-subtle">
          <div class="row items-center q-mb-md">
            <div class="metric-icon-badge bg-primary-subtle text-primary q-mr-sm">
              <q-icon name="ph ph-package" size="18px" />
            </div>
            <div class="text-subtitle2 text-weight-bold text-primary">Goods Cost Summary</div>
          </div>
          <div class="q-gutter-y-sm">
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Total Quantity</span>
              <span class="text-body2 text-weight-bold text-grey-9">{{ summaryMetrics.totalQuantity.toLocaleString() }} pcs</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Total Purchase Price (GBP)</span>
              <span class="text-body2 text-weight-bold text-grey-9">£ {{ formatMoney(summaryMetrics.goodsCostGbp) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Conversion Rate</span>
              <span class="text-body2 text-weight-medium text-grey-8">{{ conversionRate }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-weight-medium text-grey-9">Goods Cost (BDT)</span>
              <span class="text-subtitle2 text-weight-bold text-primary">৳ {{ formatMoney(summaryMetrics.goodsCostBdt) }}</span>
            </div>
          </div>
        </q-card>
      </div>

      <!-- Cargo Cost Card -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="q-pa-md fill-height card-hover metric-card bg-surface-subtle">
          <div class="row items-center q-mb-md">
            <div class="metric-icon-badge bg-teal-subtle text-teal-9 q-mr-sm">
              <q-icon name="ph ph-truck" size="18px" />
            </div>
            <div class="text-subtitle2 text-weight-bold text-teal-9">Cargo Cost Summary</div>
          </div>
          <div class="q-gutter-y-sm">
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Cargo Weight (KG)</span>
              <span class="text-body2 text-weight-bold text-grey-9">{{ summaryMetrics.cargoWeightKg.toFixed(2) }} kg</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Cargo Cost (GBP)</span>
              <span class="text-body2 text-weight-bold text-grey-9">£ {{ formatMoney(summaryMetrics.cargoCostGbp) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Cargo Conversion Rate</span>
              <span class="text-body2 text-weight-medium text-grey-8">{{ conversionRate }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-weight-medium text-grey-9">Cargo Cost (BDT)</span>
              <span class="text-subtitle2 text-weight-bold text-teal-9">৳ {{ formatMoney(summaryMetrics.cargoCostBdt) }}</span>
            </div>
          </div>
        </q-card>
      </div>

      <!-- Total Cost Summary Card -->
      <div class="col-12">
        <q-card flat bordered class="q-pa-md total-landed-cost-card">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm-auto row items-center">
              <div class="metric-icon-badge bg-primary-subtle text-primary q-mr-sm">
                <q-icon name="ph ph-coins" size="20px" />
              </div>
              <div>
                <div class="text-caption text-uppercase text-weight-bold text-grey-7">Total Landed Cost</div>
                <div class="text-subtitle2 text-weight-bold text-grey-9">Goods Cost (BDT) + Cargo Cost (BDT)</div>
              </div>
            </div>
            <div class="col-12 col-sm-auto text-right">
              <div class="text-h6 text-weight-bolder text-primary">
                ৳ {{ formatMoney(summaryMetrics.totalCostBdt) }}
              </div>
            </div>
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatMoney } from '../composables/useProductBasedCostingFileDetailsState';

defineProps<{
  summaryMetrics: {
    totalQuantity: number;
    goodsCostGbp: number;
    goodsCostBdt: number;
    cargoWeightKg: number;
    cargoCostGbp: number;
    cargoCostBdt: number;
    totalCostBdt: number;
  };
  conversionRate: number;
}>();
</script>

<style scoped lang="scss">
.metric-card {
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
  border-radius: 10px;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(15, 23, 42, 0.05);
  }
}

.metric-icon-badge {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.bg-surface-subtle {
  background: var(--bw-theme-surface-subtle, rgba(248, 250, 252, 0.7));
}

.bg-primary-subtle {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.1);
}

.bg-teal-subtle {
  background: rgba(13, 148, 136, 0.1);
}

.total-landed-cost-card {
  border-radius: 10px;
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.04);
  border-color: rgba(var(--q-primary-rgb, 15, 98, 254), 0.15);
}
</style>
