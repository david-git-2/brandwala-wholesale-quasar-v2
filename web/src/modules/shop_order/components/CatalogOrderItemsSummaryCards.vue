<template>
  <div class="catalog-order-summary q-pa-md q-pt-sm">
    <div class="text-subtitle1 text-weight-bold q-mb-sm text-grey-9 row items-center">
      <q-icon name="ph ph-chart-line-up" class="q-mr-xs text-primary" size="20px" />
      Order totals
    </div>

    <div class="row q-col-gutter-md">
      <div class="col-12 col-md-4">
        <q-card flat bordered class="q-pa-md fill-height metric-card bg-surface-subtle">
          <div class="row items-center q-mb-md">
            <div class="metric-icon-badge bg-amber-subtle text-amber-10 q-mr-sm">
              <q-icon name="ph ph-stack" size="18px" />
            </div>
            <div class="text-subtitle2 text-weight-bold text-amber-10">Quantities</div>
          </div>
          <div class="q-gutter-y-sm">
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Items</span>
              <span class="text-body2 text-weight-bold text-grey-9">{{ itemCount }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Customer qty</span>
              <span class="text-body2 text-weight-bold text-grey-9">{{ formatQty(totals.totalQuantity) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Ordered qty</span>
              <span class="text-body2 text-weight-bold text-indigo-9">{{ formatQty(totals.totalOrderedQty) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Delivered qty</span>
              <span class="text-body2 text-weight-bold text-positive">{{ formatQty(totals.totalDeliveredQty) }}</span>
            </div>
          </div>
        </q-card>
      </div>

      <div class="col-12 col-md-4">
        <q-card flat bordered class="q-pa-md fill-height metric-card bg-surface-subtle">
          <div class="row items-center q-mb-md">
            <div class="metric-icon-badge bg-teal-subtle text-teal-9 q-mr-sm">
              <q-icon name="ph ph-currency-circle-dollar" size="18px" />
            </div>
            <div class="text-subtitle2 text-weight-bold text-teal-9">Cost summary</div>
          </div>
          <div class="q-gutter-y-sm">
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Total purchase ({{ buyCurrencySymbol }})</span>
              <span class="text-body2 text-weight-bold text-green-9">{{ buyCurrencySymbol }}{{ formatMoney(totals.grandTotalPurchasePrice) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Landed cost ({{ buyCurrencySymbol }})</span>
              <span class="text-body2 text-weight-bold text-teal-9">{{ buyCurrencySymbol }}{{ formatMoney(totals.grandTotalLandedPurchase) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Landed cost ({{ sellCurrencySymbol }})</span>
              <span class="text-body2 text-weight-bold text-teal-9">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalLandedSell) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">Total weight</span>
              <span class="text-body2 text-weight-medium text-grey-8">{{ formatWeight(totals.totalWeightGm) }}</span>
            </div>
            <q-separator light />
            <div class="row justify-between items-center">
              <span class="text-caption text-grey-7">FX · Cargo rate</span>
              <span class="text-body2 text-weight-medium text-grey-8">{{ conversionRate }} · {{ cargoRate }}/kg</span>
            </div>
          </div>
        </q-card>
      </div>

      <div class="col-12 col-md-4">
        <q-card flat bordered class="q-pa-md fill-height metric-card bg-surface-subtle">
          <div class="row items-center q-mb-md">
            <div class="metric-icon-badge bg-purple-subtle text-deep-purple-9 q-mr-sm">
              <q-icon name="ph ph-tag" size="18px" />
            </div>
            <div class="text-subtitle2 text-weight-bold text-deep-purple-9">Offer totals</div>
          </div>
          <div class="q-gutter-y-sm">
            <div class="summary-offer-row summary-offer-row--first">
              <div class="row justify-between items-center">
                <span class="text-caption text-weight-medium">1st offer ({{ sellCurrencySymbol }})</span>
                <span class="text-body2 text-weight-bold text-deep-purple-9">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalFirstOffer) }}</span>
              </div>
              <div class="text-caption text-grey-7 text-right">Margin {{ formatPercent(totals.overallFirstOfferMargin) }}</div>
            </div>
            <q-separator light />
            <div class="summary-offer-row summary-offer-row--counter">
              <div class="row justify-between items-center">
                <span class="text-caption text-weight-medium">Counter offer ({{ sellCurrencySymbol }})</span>
                <span class="text-body2 text-weight-bold text-orange-9">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalCounterOffer) }}</span>
              </div>
              <div class="text-caption text-grey-7 text-right">Margin {{ formatPercent(totals.overallCounterOfferMargin) }}</div>
            </div>
            <q-separator light />
            <div class="summary-offer-row summary-offer-row--final">
              <div class="row justify-between items-center">
                <span class="text-caption text-weight-medium">Final offer ({{ sellCurrencySymbol }})</span>
                <span class="text-body2 text-weight-bold text-positive">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalFinalOffer) }}</span>
              </div>
              <div class="text-caption text-grey-7 text-right">Margin {{ formatPercent(totals.overallFinalOfferMargin) }}</div>
            </div>
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  itemCount: number;
  buyCurrencySymbol: string;
  sellCurrencySymbol: string;
  conversionRate: number;
  cargoRate: number;
  totals: {
    totalQuantity: number;
    totalOrderedQty: number;
    totalDeliveredQty: number;
    totalWeightGm: number;
    grandTotalPurchasePrice: number;
    grandTotalLandedPurchase: number;
    grandTotalLandedSell: number;
    grandTotalFirstOffer: number;
    overallFirstOfferMargin: number;
    grandTotalCounterOffer: number;
    overallCounterOfferMargin: number;
    grandTotalFinalOffer: number;
    overallFinalOfferMargin: number;
  };
}>();

function formatMoney(value: number) {
  return Number(value || 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatQty(value: number) {
  return Number(value || 0).toLocaleString();
}

function formatWeight(value: number) {
  return `${Number(value || 0).toLocaleString()} g`;
}

function formatPercent(value: number) {
  return `${Number(value || 0).toFixed(1)}%`;
}
</script>

<style scoped lang="scss">
.metric-card {
  border-radius: 10px;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.metric-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.05);
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
  background: rgba(248, 250, 252, 0.9);
}

.bg-amber-subtle {
  background: rgba(255, 193, 7, 0.12);
}

.bg-teal-subtle {
  background: rgba(13, 148, 136, 0.1);
}

.bg-purple-subtle {
  background: rgba(123, 31, 162, 0.1);
}

.summary-offer-row {
  border-radius: 8px;
  padding: 8px 10px;
}

.summary-offer-row--first {
  background: #f3e5f5;
}

.summary-offer-row--counter {
  background: #fff8f0;
}

.summary-offer-row--final {
  background: #e8f5e9;
}

.catalog-order-summary {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  background: #fafbfc;
}
</style>
