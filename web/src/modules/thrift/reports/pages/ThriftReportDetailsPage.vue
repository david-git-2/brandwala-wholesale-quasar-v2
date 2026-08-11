<template>
  <q-page class="bw-page thrift-report-details-page">
    <div class="bw-page__stack">
      <header class="page-nav">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="primary"
          aria-label="Back to shipments"
          :to="shipmentsListPath"
        />
        <div>
          <div class="text-overline text-primary">Thrift / Reports</div>
          <h1 class="text-h5 text-weight-bold q-my-none">
            {{ report?.shipment.name || 'Purchase shipment' }}
          </h1>
          <p class="page-nav__sub q-mb-none">Was this purchase worth it?</p>
        </div>
      </header>

      <div v-if="isLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="isError" class="error-banner">
        {{ errorMessage }}
      </div>

      <template v-else-if="report">
        <section
          class="hero-panel"
          :class="summary.netProfit >= 0 ? 'hero-panel--good' : 'hero-panel--bad'"
        >
          <div class="hero-panel__label">Profit on this purchase</div>
          <div class="hero-panel__amount">
            {{ formatThriftAmount(summary.netProfit) }}
          </div>
          <div class="hero-panel__sentence">{{ profitSentence }}</div>
        </section>

        <div class="chips-grid">
          <div class="chip-card">
            <div class="chip-card__value">{{ summary.unitsSold }}</div>
            <div class="chip-card__label">Delivered</div>
          </div>
          <div class="chip-card chip-card--warn">
            <div class="chip-card__value">{{ summary.unitsRto }}</div>
            <div class="chip-card__label">Came back</div>
          </div>
          <div class="chip-card chip-card--warn">
            <div class="chip-card__value">{{ summary.unitsReturned }}</div>
            <div class="chip-card__label">Returned</div>
          </div>
        </div>

        <section class="story-card">
          <div class="story-card__title">In plain words</div>
          <div class="story-row">
            <span>Customers paid</span>
            <strong>{{ formatThriftAmount(summary.deliveredRevenue) }}</strong>
          </div>
          <div class="story-row">
            <span>
              Product cost
              <q-icon name="ph ph-info" size="14px" class="q-ml-xs text-grey-5">
                <q-tooltip>Product cost (also called COGS)</q-tooltip>
              </q-icon>
            </span>
            <strong>{{ formatThriftAmount(summary.cogs) }}</strong>
          </div>
          <div class="story-row story-row--loss">
            <span>Shipping &amp; courier costs</span>
            <strong>{{ formatThriftAmount(summary.allocatedFeesTotal) }}</strong>
          </div>
        </section>

        <q-card flat bordered class="detail-card">
          <q-expansion-item
            dense
            expand-separator
            icon="ph ph-list-bullets"
            label="More detail"
            header-class="text-subtitle2 text-weight-bold"
          >
            <q-card-section class="q-pt-none q-gutter-y-md">
              <div>
                <div class="text-subtitle2 text-weight-bold q-mb-sm">By result</div>
                <q-table
                  flat
                  :rows="report.byOutcome"
                  :columns="outcomeColumns"
                  row-key="outcome"
                  hide-pagination
                  :rows-per-page-options="[0]"
                  class="thrift-table"
                >
                  <template #body-cell-outcome="props">
                    <q-td :props="props">
                      <q-badge
                        :color="outcomeColor(props.row.outcome)"
                        :label="outcomeLabel(props.row.outcome)"
                      />
                    </q-td>
                  </template>
                  <template #body-cell-netRevenue="props">
                    <q-td :props="props" class="text-right">
                      {{ formatThriftAmount(props.row.netRevenue) }}
                    </q-td>
                  </template>
                  <template #body-cell-cogs="props">
                    <q-td :props="props" class="text-right">
                      {{ formatThriftAmount(props.row.cogs) }}
                    </q-td>
                  </template>
                  <template #body-cell-allocatedFeesTotal="props">
                    <q-td :props="props" class="text-right">
                      {{ formatThriftAmount(props.row.allocatedFeesTotal) }}
                    </q-td>
                  </template>
                  <template #body-cell-netProfit="props">
                    <q-td
                      :props="props"
                      class="text-right text-weight-bold"
                      :class="props.row.netProfit >= 0 ? 'text-positive' : 'text-negative'"
                    >
                      {{ formatThriftAmount(props.row.netProfit) }}
                    </q-td>
                  </template>
                  <template #no-data>
                    <div class="full-width column flex-center q-pa-md text-grey-6">
                      No finished sales for this shipment yet.
                    </div>
                  </template>
                </q-table>
              </div>

              <div>
                <div class="text-subtitle2 text-weight-bold q-mb-sm">
                  Every piece ({{ report.lines.length }})
                </div>

                <q-input
                  v-if="report.lines.length"
                  v-model="lineSearch"
                  dense
                  outlined
                  clearable
                  debounce="200"
                  class="q-mb-sm"
                  placeholder="Search invoice #, item, barcode…"
                >
                  <template #prepend>
                    <q-icon name="ph ph-magnifying-glass" />
                  </template>
                </q-input>

                <q-table
                  flat
                  :rows="filteredLines"
                  :columns="lineColumns"
                  row-key="id"
                  :pagination="{ rowsPerPage: 25 }"
                  :rows-per-page-options="[25, 50, 100]"
                  class="thrift-table"
                >
                  <template #body-cell-invoice="props">
                    <q-td :props="props">
                      <div class="text-weight-medium">{{ props.row.invoiceNumber }}</div>
                      <div class="text-caption text-grey-7">{{ formatDate(props.row.invoiceDate) }}</div>
                    </q-td>
                  </template>

                  <template #body-cell-outcome="props">
                    <q-td :props="props">
                      <q-badge
                        :color="outcomeColor(props.row.outcome)"
                        :label="outcomeLabel(props.row.outcome)"
                      />
                    </q-td>
                  </template>

                  <template #body-cell-item="props">
                    <q-td :props="props">
                      <div class="text-weight-medium">
                        {{ props.row.stockName || `Stock #${props.row.stockId}` }}
                      </div>
                      <div v-if="props.row.barcode" class="text-caption text-grey-7">
                        {{ props.row.barcode }}
                      </div>
                    </q-td>
                  </template>

                  <template #body-cell-sellAmount="props">
                    <q-td :props="props" class="text-right">
                      {{ formatThriftAmount(props.row.sellAmount) }}
                    </q-td>
                  </template>

                  <template #body-cell-allocatedFeesTotal="props">
                    <q-td :props="props" class="text-right">
                      {{ formatThriftAmount(props.row.allocatedFeesTotal) }}
                    </q-td>
                  </template>

                  <template #body-cell-cogs="props">
                    <q-td :props="props" class="text-right">
                      {{ formatThriftAmount(props.row.cogs) }}
                    </q-td>
                  </template>

                  <template #body-cell-netProfit="props">
                    <q-td
                      :props="props"
                      class="text-right text-weight-bold"
                      :class="props.row.netProfit >= 0 ? 'text-positive' : 'text-negative'"
                    >
                      {{ formatThriftAmount(props.row.netProfit) }}
                    </q-td>
                  </template>

                  <template #no-data>
                    <div class="full-width column flex-center q-pa-xl text-grey-6">
                      <q-icon name="ph ph-receipt" size="40px" class="q-mb-sm" />
                      <div class="text-subtitle1 text-weight-medium">
                        No finished sales for this shipment yet
                      </div>
                      <div class="text-body2">
                        Delivered, courier return, and customer return pieces will appear here.
                      </div>
                    </div>
                  </template>
                </q-table>
              </div>
            </q-card-section>
          </q-expansion-item>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useThriftShipmentSalesReportQuery } from '../composables/useThriftReportsQuery';

const route = useRoute();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const lineSearch = ref('');

const shipmentId = computed(() => {
  const raw = route.params.shipmentId;
  const n = Number(Array.isArray(raw) ? raw[0] : raw);
  return Number.isFinite(n) && n > 0 ? n : null;
});

const shipmentsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports/shipments`,
);

const { data: report, isLoading, isError, error } = useThriftShipmentSalesReportQuery(
  tenantId,
  shipmentId,
);

const summary = computed(
  () =>
    report.value?.summary || {
      unitsSold: 0,
      unitsRto: 0,
      unitsReturned: 0,
      grossSales: 0,
      discounts: 0,
      netRevenue: 0,
      deliveredRevenue: 0,
      cogs: 0,
      allocatedFeesTotal: 0,
      netProfit: 0,
      deliveredNet: 0,
      rtoFeeLoss: 0,
      returnFeeLoss: 0,
      deliveredLineCount: 0,
      rtoLineCount: 0,
      returnLineCount: 0,
      marginPct: 0,
    },
);

const profitSentence = computed(() => {
  if (summary.value.netProfit >= 0) {
    return 'This shipment is making money so far.';
  }
  return 'This shipment is losing money so far (shipping losses or returns).';
});

const errorMessage = computed(() => {
  if (!error.value) return 'Failed to load report';
  return error.value instanceof Error ? error.value.message : String(error.value);
});

const outcomeColumns: QTableColumn[] = [
  { name: 'outcome', label: 'Result', field: 'outcome', align: 'left' },
  { name: 'units', label: 'Units', field: 'units', align: 'right' },
  { name: 'lineCount', label: 'Pieces', field: 'lineCount', align: 'right' },
  { name: 'netRevenue', label: 'Sell', field: 'netRevenue', align: 'right' },
  { name: 'cogs', label: 'Product cost', field: 'cogs', align: 'right' },
  { name: 'allocatedFeesTotal', label: 'Fees', field: 'allocatedFeesTotal', align: 'right' },
  { name: 'netProfit', label: 'Profit', field: 'netProfit', align: 'right' },
];

const lineColumns: QTableColumn[] = [
  { name: 'invoice', label: 'Invoice', field: 'invoiceNumber', align: 'left' },
  { name: 'outcome', label: 'Result', field: 'outcome', align: 'left' },
  { name: 'item', label: 'Item', field: 'stockName', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right', style: 'width: 64px' },
  { name: 'sellAmount', label: 'Sell', field: 'sellAmount', align: 'right' },
  { name: 'allocatedFeesTotal', label: 'Fees', field: 'allocatedFeesTotal', align: 'right' },
  { name: 'cogs', label: 'Product cost', field: 'cogs', align: 'right' },
  { name: 'netProfit', label: 'Profit', field: 'netProfit', align: 'right' },
];

const filteredLines = computed(() => {
  const lines = report.value?.lines || [];
  const q = lineSearch.value.trim().toLowerCase();
  if (!q) return lines;
  return lines.filter(
    (line) =>
      line.invoiceNumber.toLowerCase().includes(q) ||
      (line.stockName || '').toLowerCase().includes(q) ||
      (line.barcode || '').toLowerCase().includes(q) ||
      (line.outcome || '').toLowerCase().includes(q) ||
      String(line.stockId).includes(q),
  );
});

function outcomeLabel(outcome: string): string {
  if (outcome === 'DELIVERED') return 'Delivered';
  if (outcome === 'RTO') return 'Came back (RTO)';
  if (outcome === 'CUSTOMER_RETURN') return 'Customer return';
  return outcome || '—';
}

function outcomeColor(outcome: string): string {
  if (outcome === 'DELIVERED') return 'positive';
  if (outcome === 'RTO') return 'warning';
  if (outcome === 'CUSTOMER_RETURN') return 'orange-8';
  return 'grey-7';
}

function formatDate(value: string) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleString();
  } catch {
    return value;
  }
}
</script>

<style scoped>
.page-nav {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
}

.page-nav__sub {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--bw-theme-muted, #6b7280);
}

.hero-panel {
  border-radius: 16px;
  padding: 1.25rem 1.25rem 1.15rem;
  border: 1px solid transparent;
}

.hero-panel--good {
  background: var(--bw-theme-primary-soft, rgb(var(--bw-theme-primary-rgb, 52 211 153) / 0.12));
  border-color: color-mix(in srgb, var(--bw-theme-primary, var(--q-primary)) 28%, transparent);
}

.hero-panel--bad {
  background: rgba(239, 68, 68, 0.08);
  border-color: rgba(239, 68, 68, 0.25);
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
}

.hero-panel--good .hero-panel__amount {
  color: var(--q-positive, #21ba45);
}

.hero-panel--bad .hero-panel__amount {
  color: var(--q-negative, #c10015);
}

.hero-panel__sentence {
  margin-top: 0.55rem;
  font-size: 0.95rem;
  font-weight: 600;
}

.hero-panel--good .hero-panel__sentence {
  color: var(--q-positive, #21ba45);
}

.hero-panel--bad .hero-panel__sentence {
  color: var(--q-negative, #c10015);
}

.chips-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.65rem;
}

.chip-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
  text-align: center;
  padding: 0.85rem 0.5rem;
}

.chip-card__value {
  font-size: 1.25rem;
  font-weight: 750;
  line-height: 1.2;
}

.chip-card--warn .chip-card__value {
  color: #b45309;
}

.chip-card__label {
  margin-top: 0.2rem;
  font-size: 0.72rem;
  color: var(--bw-theme-muted, #6b7280);
}

.story-card,
.detail-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
}

.story-card {
  padding: 1rem 1.1rem;
}

.story-card__title {
  font-size: 0.95rem;
  font-weight: 700;
  margin-bottom: 0.65rem;
}

.story-row {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 1rem;
  padding: 0.55rem 0;
  border-top: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
  font-size: 0.95rem;
  color: var(--bw-theme-muted, #6b7280);
}

.story-row:first-of-type {
  border-top: 0;
  padding-top: 0;
}

.story-row strong {
  color: var(--bw-theme-ink, inherit);
  font-weight: 650;
  text-align: right;
}

.story-row--loss strong {
  color: var(--q-negative, #c10015);
}

.error-banner {
  background: var(--q-negative);
  color: #fff;
  padding: 0.9rem 1rem;
  border-radius: 12px;
}
</style>
