<template>
  <div class="catalog-order-summary q-pa-md q-pt-sm">
    <div class="text-subtitle2 text-weight-bold q-mb-md text-grey-9 row items-center">
      <q-icon name="ph ph-chart-line-up" class="q-mr-xs text-primary" size="18px" />
      Order totals
    </div>

    <div class="summary-hero row q-col-gutter-sm q-mb-md">
      <div class="col-6 col-sm-3">
        <div class="summary-hero__tile">
          <div class="summary-hero__lbl">Line items</div>
          <div class="summary-hero__val">{{ itemCount }}</div>
        </div>
      </div>
      <div class="col-6 col-sm-3">
        <div class="summary-hero__tile">
          <div class="summary-hero__lbl">Customer qty</div>
          <div class="summary-hero__val">{{ formatQty(totals.totalQuantity) }}</div>
        </div>
      </div>
      <div class="col-12 col-sm-6">
        <div class="summary-hero__tile summary-hero__tile--accent">
          <div class="row items-center justify-between no-wrap q-gutter-x-sm">
            <div class="min-width-0">
              <div class="summary-hero__lbl">Final offer ({{ sellCurrencySymbol }})</div>
              <div class="summary-hero__val summary-hero__val--lg">
                {{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalFinalOffer) }}
              </div>
            </div>
            <q-badge
              v-if="finalMarginLabel"
              color="green-2"
              text-color="green-9"
              class="text-weight-bold q-px-sm"
            >
              {{ finalMarginLabel }}
            </q-badge>
          </div>
        </div>
      </div>
    </div>

    <q-card flat bordered class="summary-section q-mb-sm">
      <div class="summary-section__head">
        <q-icon name="ph ph-currency-circle-dollar" size="16px" class="text-teal-8" />
        <span>Purchase &amp; landed</span>
      </div>
      <dl class="summary-dl">
        <div class="summary-dl__row">
          <dt>Purchase total</dt>
          <dd>{{ buyCurrencySymbol }}{{ formatMoney(totals.grandTotalPurchasePrice) }}</dd>
        </div>
        <div class="summary-dl__row">
          <dt>Landed total (purchase currency)</dt>
          <dd>{{ buyCurrencySymbol }}{{ formatMoney(totals.grandTotalLandedPurchase) }}</dd>
        </div>
        <div class="summary-dl__row">
          <dt>Landed total (sell currency)</dt>
          <dd>{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalLandedSell) }}</dd>
        </div>
        <div class="summary-dl__row summary-dl__row--muted">
          <dt>Total weight</dt>
          <dd>{{ formatWeight(totals.totalWeightGm) }}</dd>
        </div>
      </dl>
      <div class="summary-rates text-caption text-grey-7">
        FX {{ conversionRate }} · Cargo {{ buyCurrencySymbol }}{{ cargoRate }}/kg
      </div>
    </q-card>

    <q-card flat bordered class="summary-section">
      <div class="summary-section__head">
        <q-icon name="ph ph-tag" size="16px" class="text-deep-purple-8" />
        <span>Offer breakdown</span>
      </div>
      <dl class="summary-dl">
        <div class="summary-dl__row">
          <dt>1st offer</dt>
          <dd>
            <span class="summary-dl__amount">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalFirstOffer) }}</span>
            <span v-if="firstMarginLabel" class="summary-dl__meta">{{ firstMarginLabel }}</span>
          </dd>
        </div>
        <div v-if="hasCounterOffer" class="summary-dl__row">
          <dt>Counter offer</dt>
          <dd>
            <span class="summary-dl__amount">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalCounterOffer) }}</span>
            <span v-if="counterMarginLabel" class="summary-dl__meta">{{ counterMarginLabel }}</span>
          </dd>
        </div>
        <div class="summary-dl__row summary-dl__row--emphasis">
          <dt>Final offer</dt>
          <dd>
            <span class="summary-dl__amount">{{ sellCurrencySymbol }}{{ formatMoney(totals.grandTotalFinalOffer) }}</span>
            <span v-if="finalMarginLabel" class="summary-dl__meta">{{ finalMarginLabel }}</span>
          </dd>
        </div>
      </dl>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  itemCount: number;
  buyCurrencySymbol: string;
  sellCurrencySymbol: string;
  conversionRate: number;
  cargoRate: number;
  totals: {
    totalQuantity: number;
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

const hasCounterOffer = computed(() => Number(props.totals.grandTotalCounterOffer || 0) > 0);

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
  const gm = Number(value || 0);
  if (gm >= 1000) {
    return `${(gm / 1000).toLocaleString(undefined, { maximumFractionDigits: 2 })} kg (${gm.toLocaleString()} g)`;
  }
  return `${gm.toLocaleString()} g`;
}

function marginLabel(offerTotal: number, marginPct: number): string | null {
  if (Number(offerTotal || 0) <= 0) return null;
  return `Margin ${Number(marginPct || 0).toFixed(1)}%`;
}

const firstMarginLabel = computed(() =>
  marginLabel(props.totals.grandTotalFirstOffer, props.totals.overallFirstOfferMargin),
);
const counterMarginLabel = computed(() =>
  marginLabel(props.totals.grandTotalCounterOffer, props.totals.overallCounterOfferMargin),
);
const finalMarginLabel = computed(() =>
  marginLabel(props.totals.grandTotalFinalOffer, props.totals.overallFinalOfferMargin),
);
</script>

<style scoped lang="scss">
.catalog-order-summary {
  border-top: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.08));
  background: var(--tf-neutral-canvas, #fafbfc);
}

.summary-hero__tile {
  border: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.1));
  border-radius: 8px;
  background: var(--tf-neutral-surface, #fff);
  padding: 10px 12px;
  min-height: 100%;
}

.summary-hero__tile--accent {
  border-color: color-mix(in srgb, var(--q-positive) 35%, var(--tf-neutral-border, #e0e0e0));
  background: color-mix(in srgb, var(--q-positive) 6%, var(--tf-neutral-surface, #fff));
}

.summary-hero__lbl {
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-muted, #64748b);
  line-height: 1.2;
  margin-bottom: 2px;
}

.summary-hero__val {
  font-size: 18px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--tf-neutral-ink, #1e293b);
  line-height: 1.2;
}

.summary-hero__val--lg {
  font-size: 20px;
}

.summary-section {
  border-radius: 8px;
  background: var(--tf-neutral-surface, #fff);
  overflow: hidden;
}

.summary-section__head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  font-size: 13px;
  font-weight: 700;
  color: var(--tf-neutral-ink, #334155);
  border-bottom: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.08));
  background: color-mix(in srgb, var(--tf-neutral-canvas, #f8fafc) 80%, transparent);
}

.summary-dl {
  margin: 0;
  padding: 4px 0;
}

.summary-dl__row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 12px;
  border-bottom: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.06));

  &:last-child {
    border-bottom: none;
  }
}

.summary-dl__row--muted dd {
  font-weight: 500;
  font-size: 13px;
}

.summary-dl__row--emphasis {
  background: color-mix(in srgb, var(--q-positive) 8%, transparent);

  dt {
    font-weight: 700;
  }

  .summary-dl__amount {
    font-size: 15px;
  }
}

.summary-dl__row dt {
  margin: 0;
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-neutral-muted, #64748b);
  flex: 1 1 auto;
  min-width: 0;
}

.summary-dl__row dd {
  margin: 0;
  text-align: right;
  flex-shrink: 0;
  font-size: 14px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--tf-neutral-ink, #0f172a);
}

.summary-dl__amount {
  display: block;
}

.summary-dl__meta {
  display: block;
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-muted, #64748b);
  margin-top: 2px;
}

.summary-rates {
  padding: 8px 12px 10px;
  border-top: 1px dashed var(--tf-neutral-border, rgba(0, 0, 0, 0.08));
}

.min-width-0 {
  min-width: 0;
}
</style>
