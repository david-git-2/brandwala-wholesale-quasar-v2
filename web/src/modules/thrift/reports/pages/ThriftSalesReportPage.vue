<template>
  <q-page class="bw-page thrift-sales-report-page">
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
          <h1 class="text-h5 text-weight-bold q-my-none">How much did I earn?</h1>
        </div>
      </header>

      <section class="filter-card">
        <div class="filter-card__label">Time period</div>
        <q-btn-toggle
          v-model="periodPreset"
          class="period-toggle"
          spread
          no-caps
          unelevated
          toggle-color="primary"
          color="grey-3"
          text-color="grey-8"
          :options="periodOptions"
        />

        <div v-if="periodPreset === 'custom'" class="row q-col-gutter-md q-mt-md">
          <div class="col-12 col-sm-6">
            <q-input
              :model-value="dateFromLabel"
              label="From"
              outlined
              dense
              readonly
              class="date-input"
            >
              <template #append>
                <q-icon name="ph ph-calendar" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="dateFrom" mask="YYYY-MM-DD">
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat dense />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              :model-value="dateToLabel"
              label="To"
              outlined
              dense
              readonly
              class="date-input"
            >
              <template #append>
                <q-icon name="ph ph-calendar" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="dateTo" mask="YYYY-MM-DD">
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat dense />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
        </div>

        <q-select
          v-model="saleChannel"
          class="q-mt-md"
          :options="channelOptions"
          label="Where sold"
          outlined
          dense
          emit-value
          map-options
        />
      </section>

      <div v-if="isLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="isError" class="error-banner">
        {{ errorMessage }}
      </div>

      <template v-else-if="report">
        <section
          class="hero-panel"
          :class="summary.netAfterFees >= 0 ? 'hero-panel--good' : 'hero-panel--bad'"
        >
          <div class="hero-panel__label">You earned</div>
          <div class="hero-panel__amount">
            {{ formatThriftAmount(summary.netAfterFees) }}
          </div>
          <div class="hero-panel__meta">
            {{ summary.invoiceCount }} sales · {{ summary.unitsSold }} items
          </div>
          <p class="hero-panel__note q-mb-none">
            Finished sales only (delivered / closed). Open parcels are not counted as earned yet.
          </p>
        </section>

        <div class="sales-deeplink">
          <q-btn
            outline
            color="primary"
            no-caps
            label="Open sales list"
            :to="salesListPath"
          />
          <p class="sales-deeplink__caption q-mb-none">
            Sales list has no date filter yet — use search or COD/Ready presets.
          </p>
        </div>

        <section class="story-card">
          <div class="story-card__title">In plain words</div>
          <div class="story-row">
            <span>Customers paid</span>
            <strong>{{ formatThriftAmount(summary.netRevenue) }}</strong>
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
          <div class="story-row">
            <span>Shipping you paid</span>
            <strong>{{ formatThriftAmount(summary.totalFees) }}</strong>
          </div>
          <div class="story-row story-row--warn">
            <span>Came back (RTO + return)</span>
            <strong>
              {{ cameBackCount }}
              <span class="story-row__soft">· {{ formatThriftAmount(cameBackAmount) }}</span>
            </strong>
          </div>
        </section>

        <q-card flat bordered class="detail-card">
          <q-expansion-item
            dense
            expand-separator
            icon="ph ph-calculator"
            label="More detail"
            header-class="text-subtitle2 text-weight-bold"
          >
            <q-card-section class="q-pt-none">
              <div class="q-mb-md">
                <div class="text-caption text-grey-6">Gross profit (before shipping)</div>
                <div
                  class="text-h6 text-weight-bold"
                  :class="summary.lineProfit >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ formatThriftAmount(summary.lineProfit) }}
                </div>
              </div>

              <div class="text-subtitle2 text-weight-bold q-mb-sm">By where sold</div>
              <q-table
                flat
                :rows="report.byChannel"
                :columns="channelColumns"
                row-key="saleChannel"
                hide-pagination
                :rows-per-page-options="[0]"
                class="thrift-table"
              >
                <template #body-cell-saleChannel="props">
                  <q-td :props="props">
                    {{ props.row.saleChannel === 'ONLINE' ? 'Online' : 'In-store' }}
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
                <template #body-cell-lineProfit="props">
                  <q-td :props="props" class="text-right">
                    {{ formatThriftAmount(props.row.lineProfit) }}
                  </q-td>
                </template>
                <template #body-cell-totalFees="props">
                  <q-td :props="props" class="text-right">
                    {{ formatThriftAmount(props.row.totalFees) }}
                  </q-td>
                </template>
                <template #body-cell-netAfterFees="props">
                  <q-td :props="props" class="text-right text-weight-bold">
                    {{ formatThriftAmount(props.row.netAfterFees) }}
                  </q-td>
                </template>
                <template #no-data>
                  <div class="full-width column flex-center q-pa-lg text-grey-6">
                    No finished sales in this range yet.
                  </div>
                </template>
              </q-table>
            </q-card-section>
          </q-expansion-item>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useThriftPeriodSalesReportQuery } from '../composables/useThriftReportsQuery';

type PeriodPreset = 'week' | 'month' | 'custom';

function isoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function startOfMonthIsoDate(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

function startOfWeekIsoDate(): string {
  const d = new Date();
  const day = d.getDay();
  const diff = day === 0 ? 6 : day - 1;
  d.setDate(d.getDate() - diff);
  return isoDate(d);
}

function todayIsoDate(): string {
  return isoDate(new Date());
}

function dayStartIso(date: string): string {
  return new Date(`${date}T00:00:00`).toISOString();
}

function dayEndIso(date: string): string {
  return new Date(`${date}T23:59:59.999`).toISOString();
}

const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const periodPreset = ref<PeriodPreset>('month');
const dateFrom = ref(startOfMonthIsoDate());
const dateTo = ref(todayIsoDate());
const saleChannel = ref<'IN_STORE' | 'ONLINE' | null>(null);

watch(periodPreset, (preset) => {
  if (preset === 'week') {
    dateFrom.value = startOfWeekIsoDate();
    dateTo.value = todayIsoDate();
  } else if (preset === 'month') {
    dateFrom.value = startOfMonthIsoDate();
    dateTo.value = todayIsoDate();
  }
});

const dateFromIso = computed(() => dayStartIso(dateFrom.value));
const dateToIso = computed(() => dayEndIso(dateTo.value));

const dateFromLabel = computed(() => formatDisplayDate(dateFrom.value));
const dateToLabel = computed(() => formatDisplayDate(dateTo.value));

function formatDisplayDate(value: string): string {
  if (!value) return '—';
  try {
    return new Date(`${value}T00:00:00`).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return value;
  }
}

const {
  data: report,
  isLoading,
  isError,
  error,
} = useThriftPeriodSalesReportQuery(tenantId, dateFromIso, dateToIso, saleChannel);

const reportsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports`,
);

const salesListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/sales`,
);

const summary = computed(() => report.value?.summary || {
  invoiceCount: 0,
  unitsSold: 0,
  netRevenue: 0,
  cogs: 0,
  lineProfit: 0,
  courierCodAmount: 0,
  otherExpenseAmount: 0,
  totalFees: 0,
  netAfterFees: 0,
  refundCount: 0,
  refundAmount: 0,
  rtoCount: 0,
  rtoAmount: 0,
  customerReturnCount: 0,
  customerReturnAmount: 0,
});

const cameBackCount = computed(
  () => summary.value.rtoCount + summary.value.customerReturnCount,
);

const cameBackAmount = computed(
  () => summary.value.rtoAmount + summary.value.customerReturnAmount,
);

const errorMessage = computed(() => {
  const err = error.value as { message?: string } | null;
  return err?.message || 'Failed to load earnings';
});

const periodOptions = [
  { label: 'This week', value: 'week' },
  { label: 'This month', value: 'month' },
  { label: 'Custom', value: 'custom' },
];

const channelOptions = [
  { label: 'All places', value: null },
  { label: 'In-store', value: 'IN_STORE' },
  { label: 'Online', value: 'ONLINE' },
];

const channelColumns: QTableColumn[] = [
  { name: 'saleChannel', label: 'Where', field: 'saleChannel', align: 'left' },
  { name: 'invoiceCount', label: 'Sales', field: 'invoiceCount', align: 'right' },
  { name: 'unitsSold', label: 'Items', field: 'unitsSold', align: 'right' },
  { name: 'netRevenue', label: 'Customers paid', field: 'netRevenue', align: 'right' },
  { name: 'cogs', label: 'Product cost', field: 'cogs', align: 'right' },
  { name: 'lineProfit', label: 'Before shipping', field: 'lineProfit', align: 'right' },
  { name: 'totalFees', label: 'Shipping', field: 'totalFees', align: 'right' },
  { name: 'netAfterFees', label: 'You earned', field: 'netAfterFees', align: 'right' },
];
</script>

<style scoped>
.page-nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.filter-card,
.story-card,
.detail-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
}

.filter-card {
  padding: 1rem 1.1rem;
}

.filter-card__label {
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #6b7280);
  margin-bottom: 0.55rem;
}

.period-toggle {
  border-radius: 10px;
  overflow: hidden;
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
  color: var(--bw-theme-ink, inherit);
}

.hero-panel--good .hero-panel__amount {
  color: var(--q-positive, #21ba45);
}

.hero-panel--bad .hero-panel__amount {
  color: var(--q-negative, #c10015);
}

.hero-panel__meta {
  margin-top: 0.35rem;
  font-size: 0.95rem;
  color: var(--bw-theme-muted, #6b7280);
}

.hero-panel__note {
  margin-top: 0.85rem;
  font-size: 0.8rem;
  line-height: 1.4;
  color: var(--bw-theme-muted, #6b7280);
}

.sales-deeplink {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.4rem;
}

.sales-deeplink__caption {
  font-size: 0.8rem;
  line-height: 1.4;
  color: var(--bw-theme-muted, #6b7280);
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

.story-row--warn strong {
  color: var(--q-warning, #f2c037);
}

.story-row__soft {
  font-weight: 500;
  opacity: 0.9;
}

.error-banner {
  background: var(--q-negative);
  color: #fff;
  padding: 0.9rem 1rem;
  border-radius: 12px;
}
</style>
