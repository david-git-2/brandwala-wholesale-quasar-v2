<template>
  <div class="pbc-summary-panel column q-gutter-y-md">
    <q-card v-if="showFileMeta && fileMeta" flat bordered class="pbc-summary-panel__meta-card">
      <q-card-section class="q-pa-sm">
        <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs">
          {{ $t('product_based_costing.summary_file_context') }}
        </div>
        <div class="row q-col-gutter-sm">
          <div v-for="row in fileMetaRows" :key="row.label" class="col-6">
            <div class="text-caption text-grey-6">{{ row.label }}</div>
            <div class="text-body2 text-weight-medium text-grey-9 ellipsis" :title="row.value">
              {{ row.value }}
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered class="pbc-summary-panel__rates-card">
      <q-card-section class="q-pa-sm">
        <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs">
          {{ $t('product_based_costing.summary_rates_applied') }}
        </div>
        <div class="row q-col-gutter-xs">
          <div class="col-4">
            <div class="rate-chip">
              <span class="rate-chip__label">{{ $t('product_based_costing.conversion_rate') }}</span>
              <span class="rate-chip__value">৳{{ formatMoney(conversionRate) }}</span>
            </div>
          </div>
          <div class="col-4">
            <div class="rate-chip">
              <span class="rate-chip__label">{{ $t('product_based_costing.cargo_rate_label') }}</span>
              <span class="rate-chip__value">£{{ formatMoney(cargoRate) }}/kg</span>
            </div>
          </div>
          <div class="col-4">
            <div class="rate-chip">
              <span class="rate-chip__label">{{ $t('product_based_costing.profit_rate_label') }}</span>
              <span class="rate-chip__value">{{ profitRate }}%</span>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row q-col-gutter-sm">
      <div class="col-4">
        <div class="stat-tile">
          <div class="stat-tile__label">{{ $t('product_based_costing.summary_line_count') }}</div>
          <div class="stat-tile__value">{{ summaryMetrics.lineCount }}</div>
        </div>
      </div>
      <div class="col-4">
        <div class="stat-tile stat-tile--primary">
          <div class="stat-tile__label">{{ $t('product_based_costing.total_quantity') }}</div>
          <div class="stat-tile__value">
            {{ summaryMetrics.totalQuantity.toLocaleString() }}
            <span class="text-caption">{{ $t('product_based_costing.pcs') }}</span>
          </div>
        </div>
      </div>
      <div class="col-4">
        <div
          class="stat-tile"
          :class="summaryMetrics.incompleteLineCount > 0 ? 'stat-tile--warning' : 'stat-tile--ok'"
        >
          <div class="stat-tile__label">{{ $t('product_based_costing.summary_incomplete_lines') }}</div>
          <div class="stat-tile__value">{{ summaryMetrics.incompleteLineCount }}</div>
        </div>
      </div>
    </div>

    <q-banner
      v-if="summaryMetrics.incompleteLineCount > 0"
      dense
      rounded
      class="bg-orange-1 text-grey-9"
    >
      {{ $t('product_based_costing.summary_incomplete_hint', { count: summaryMetrics.incompleteLineCount }) }}
    </q-banner>

    <q-card flat bordered class="metric-card bg-surface-subtle">
      <q-card-section class="q-pa-sm">
        <div class="row items-center q-mb-sm">
          <div class="metric-icon-badge bg-primary-subtle text-primary q-mr-sm">
            <q-icon name="ph ph-package" size="16px" />
          </div>
          <div class="text-subtitle2 text-weight-bold text-primary">
            {{ $t('product_based_costing.goods_cost_summary') }}
          </div>
        </div>
        <div class="metric-rows">
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.total_purchase_price_gbp') }}</span>
            <span class="text-body2 text-weight-bold text-grey-9">£ {{ formatMoney(summaryMetrics.goodsCostGbp) }}</span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.goods_cost_bdt') }}</span>
            <span class="text-subtitle2 text-weight-bold text-primary">৳ {{ formatMoney(summaryMetrics.goodsCostBdt) }}</span>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered class="metric-card bg-surface-subtle">
      <q-card-section class="q-pa-sm">
        <div class="row items-center q-mb-sm">
          <div class="metric-icon-badge bg-teal-subtle text-teal-9 q-mr-sm">
            <q-icon name="ph ph-truck" size="16px" />
          </div>
          <div class="text-subtitle2 text-weight-bold text-teal-9">
            {{ $t('product_based_costing.cargo_cost_summary') }}
          </div>
        </div>
        <div class="metric-rows">
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.cargo_weight_kg') }}</span>
            <span class="text-body2 text-weight-bold text-grey-9">{{ summaryMetrics.cargoWeightKg.toFixed(2) }} kg</span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.cargo_cost_gbp') }}</span>
            <span class="text-body2 text-weight-bold text-grey-9">£ {{ formatMoney(summaryMetrics.cargoCostGbp) }}</span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.cargo_cost_bdt') }}</span>
            <span class="text-subtitle2 text-weight-bold text-teal-9">৳ {{ formatMoney(summaryMetrics.cargoCostBdt) }}</span>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered class="total-landed-cost-card">
      <q-card-section class="q-pa-sm">
        <div class="row items-center justify-between">
          <div>
            <div class="text-caption text-uppercase text-weight-bold text-grey-7">
              {{ $t('product_based_costing.total_landed_cost') }}
            </div>
            <div class="text-caption text-grey-6">{{ $t('product_based_costing.total_landed_formula') }}</div>
            <div class="text-caption text-grey-6 q-mt-xs">
              {{ $t('product_based_costing.summary_total_cost_gbp') }}:
              £ {{ formatMoney(summaryMetrics.totalCostGbp) }}
            </div>
          </div>
          <div class="text-h5 text-weight-bolder text-primary">
            ৳ {{ formatMoney(summaryMetrics.totalCostBdt) }}
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered class="metric-card offer-profit-card">
      <q-card-section class="q-pa-sm">
        <div class="row items-center q-mb-sm">
          <div class="metric-icon-badge bg-green-subtle text-positive q-mr-sm">
            <q-icon name="ph ph-chart-line-up" size="16px" />
          </div>
          <div class="text-subtitle2 text-weight-bold text-positive">
            {{ $t('product_based_costing.summary_offer_profit') }}
          </div>
        </div>
        <div class="metric-rows">
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.preview_total_offer_bdt') }}</span>
            <span class="text-subtitle2 text-weight-bold text-positive">৳ {{ formatMoney(summaryMetrics.totalOfferPriceBdt) }}</span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.preview_profit_bdt') }}</span>
            <span
              class="text-body2 text-weight-bold"
              :class="summaryMetrics.totalProfitBdt >= 0 ? 'text-positive' : 'text-negative'"
            >
              ৳ {{ formatMoney(summaryMetrics.totalProfitBdt) }}
            </span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.summary_profit_margin') }}</span>
            <span class="text-body2 text-weight-bold text-grey-9">{{ summaryMetrics.profitMarginPercent.toFixed(1) }}%</span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.summary_avg_offer_unit') }}</span>
            <span class="text-body2 text-weight-bold text-grey-9">৳ {{ formatMoney(summaryMetrics.avgOfferPerUnitBdt) }}</span>
          </div>
          <div class="metric-row row justify-between items-center">
            <span class="text-caption text-grey-7">{{ $t('product_based_costing.summary_avg_cost_unit') }}</span>
            <span class="text-body2 text-weight-bold text-grey-9">৳ {{ formatMoney(summaryMetrics.avgCostPerUnitBdt) }}</span>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  formatMoney,
  formatStatusLabel,
  normalizePbcFileStatus,
} from '../composables/useProductBasedCostingFileDetailsState';
import type { PbcFileSummaryMetrics } from '../composables/usePbcFileSummaryMetrics';

export type PbcSummaryFileMeta = {
  name?: string | null;
  orderFor?: string | null;
  customerLabel?: string | null;
  status?: string | null;
  vendorCode?: string | null;
  marketCode?: string | null;
};

const { t } = useI18n();

const props = defineProps<{
  summaryMetrics: PbcFileSummaryMetrics;
  conversionRate: number;
  cargoRate: number;
  profitRate: number;
  fileMeta?: PbcSummaryFileMeta | null;
  showFileMeta?: boolean;
}>();

const fileMetaRows = computed(() => {
  if (!props.fileMeta) return [];
  const rows: Array<{ label: string; value: string }> = [];
  if (props.fileMeta.name) {
    rows.push({ label: t('product_based_costing.col_name'), value: props.fileMeta.name });
  }
  if (props.fileMeta.customerLabel) {
    rows.push({ label: t('product_based_costing.customer'), value: props.fileMeta.customerLabel });
  }
  if (props.fileMeta.orderFor) {
    rows.push({ label: t('product_based_costing.col_created_for'), value: props.fileMeta.orderFor });
  }
  if (props.fileMeta.status) {
    rows.push({
      label: t('product_based_costing.col_status'),
      value: formatStatusLabel(normalizePbcFileStatus(props.fileMeta.status)),
    });
  }
  if (props.fileMeta.vendorCode) {
    rows.push({ label: t('product_based_costing.summary_vendor'), value: props.fileMeta.vendorCode });
  }
  if (props.fileMeta.marketCode) {
    rows.push({ label: t('product_based_costing.summary_market'), value: props.fileMeta.marketCode });
  }
  return rows;
});
</script>

<style scoped lang="scss">
.pbc-summary-panel__meta-card,
.pbc-summary-panel__rates-card {
  border-radius: 10px;
}

.rate-chip {
  background: rgba(15, 23, 42, 0.04);
  border-radius: 8px;
  padding: 8px;
  text-align: center;
}

.rate-chip__label {
  display: block;
  font-size: 10px;
  text-transform: uppercase;
  color: #64748b;
  font-weight: 600;
}

.rate-chip__value {
  display: block;
  font-size: 13px;
  font-weight: 700;
  color: #0f172a;
  font-family: ui-monospace, monospace;
}

.stat-tile {
  background: #f8fafc;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 10px;
  padding: 10px;
  text-align: center;
}

.stat-tile--primary {
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.06);
  border-color: rgba(var(--q-primary-rgb, 15, 98, 254), 0.15);
}

.stat-tile--warning {
  background: #fff7ed;
  border-color: #fdba74;
}

.stat-tile--ok {
  background: #f0fdf4;
  border-color: #86efac;
}

.stat-tile__label {
  font-size: 10px;
  text-transform: uppercase;
  color: #64748b;
  font-weight: 600;
}

.stat-tile__value {
  font-size: 18px;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.2;
}

.metric-card {
  border-radius: 10px;
}

.metric-rows {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.metric-row {
  padding: 2px 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}

.metric-row:last-child {
  border-bottom: none;
}

.metric-icon-badge {
  width: 28px;
  height: 28px;
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

.bg-green-subtle {
  background: rgba(22, 163, 74, 0.1);
}

.total-landed-cost-card {
  border-radius: 10px;
  background: rgba(var(--q-primary-rgb, 15, 98, 254), 0.04);
  border-color: rgba(var(--q-primary-rgb, 15, 98, 254), 0.15);
}

.offer-profit-card {
  border-color: rgba(22, 163, 74, 0.2);
  background: rgba(22, 163, 74, 0.03);
}
</style>
