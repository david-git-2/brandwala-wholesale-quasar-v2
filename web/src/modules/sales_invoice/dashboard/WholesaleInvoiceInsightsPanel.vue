<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load invoice pulse.
  </q-banner>
  <DashboardPulseCard v-else title="Invoice pulse">
    <DashboardMetric label="Today billed" :value="billedLabel" unit="Today" tone="ok" />
    <DashboardMetric
      label="Unpaid invoices"
      :value="unpaidLabel"
      unit="Open"
      :to="unpaidTo"
    />
    <DashboardMetric
      label="Overdue"
      :value="overdueCountLabel"
      :to="overdueTo"
      tone="warn"
    />
    <DashboardMetric label="Drafts" :value="draftLabel" :to="invoiceListTo" />

    <template #chart>
      <div class="invoice-pulse__chart-col">
        <DashboardDonut
          :data="mixChartData"
          :center-value="`${paidPct}%`"
          center-caption="Paid"
          :empty="!hasMix"
        />
        <DashboardChartLegend :rows="mixLegend" />
      </div>
    </template>

    <template #visuals>
      <DashboardShareBars :rows="overdueRows" empty-label="No overdue customers" />
    </template>

    <template v-if="(metrics?.overdueCustomers?.length ?? 0) > 3" #footer>
      <q-btn
        flat
        no-caps
        color="primary"
        label="All overdue"
        icon-right="ph ph-arrow-up-right"
        @click="showDetail = true"
      />
    </template>
  </DashboardPulseCard>

  <WholesaleInvoiceDetailDialog v-model="showDetail" :metrics="metrics" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useRoute } from 'vue-router';
import type { ChartData } from 'chart.js';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import DashboardPulseCard from 'src/modules/dashboard/components/DashboardPulseCard.vue';
import DashboardPulseSkeleton from 'src/modules/dashboard/components/DashboardPulseSkeleton.vue';
import DashboardMetric from 'src/modules/dashboard/components/DashboardMetric.vue';
import DashboardDonut from 'src/modules/dashboard/components/DashboardDonut.vue';
import DashboardChartLegend from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import type { DashboardChartLegendRow } from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import DashboardShareBars from 'src/modules/dashboard/components/DashboardShareBars.vue';
import type { DashboardShareBarRow } from 'src/modules/dashboard/components/DashboardShareBars.vue';
import {
  dashboardSharePct,
  formatDashboardCount,
  formatDashboardMoney,
  formatDashboardMoneyFull,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useSalesInvoiceDashboardQuery } from '../composables/useSalesInvoiceDashboardQuery';
import WholesaleInvoiceDetailDialog from './WholesaleInvoiceDetailDialog.vue';

const route = useRoute();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const showDetail = ref(false);
const { data: metrics, isLoading, isError } = useSalesInvoiceDashboardQuery(tenantId);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');
const withSlug = () => (tenantSlug.value ? { tenantSlug: tenantSlug.value } : {});

const invoiceListTo = computed(() => ({ name: 'app-global-invoices-page', params: withSlug() }));
const unpaidTo = computed(() => ({
  name: 'app-global-invoices-page',
  params: withSlug(),
  query: { quick_filter: 'unpaid' },
}));
const overdueTo = computed(() => ({
  name: 'app-global-invoices-page',
  params: withSlug(),
  query: { payment_status: 'overdue' },
}));

const billedLabel = computed(() => formatDashboardMoney(metrics.value?.todayBilledAmount ?? 0));
const unpaidLabel = computed(() => formatDashboardCount(metrics.value?.unpaidCount ?? 0));
const overdueCountLabel = computed(
  () => `${formatDashboardCount(metrics.value?.overdueCount ?? 0)} invoices`,
);
const draftLabel = computed(
  () => `${formatDashboardCount(metrics.value?.draftCount ?? 0)} invoices`,
);

const mixTotal = computed(
  () =>
    (metrics.value?.paidAmount ?? 0) +
    (metrics.value?.dueAmount ?? 0) +
    (metrics.value?.overdueAmount ?? 0),
);
const hasMix = computed(() => mixTotal.value > 0);
const paidPct = computed(() => dashboardSharePct(metrics.value?.paidAmount ?? 0, mixTotal.value));

const colors = computed(() => dashboardChartColors());

const mixChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Paid', 'Due', 'Overdue'],
  datasets: [
    {
      data: [
        metrics.value?.paidAmount ?? 0,
        metrics.value?.dueAmount ?? 0,
        metrics.value?.overdueAmount ?? 0,
      ],
      backgroundColor: [colors.value.success, colors.value.warning, colors.value.error],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const mixLegend = computed<DashboardChartLegendRow[]>(() => [
  {
    color: colors.value.success,
    label: 'Paid',
    value: formatDashboardMoney(metrics.value?.paidAmount ?? 0),
    pct: dashboardSharePct(metrics.value?.paidAmount ?? 0, mixTotal.value),
  },
  {
    color: colors.value.warning,
    label: 'Due',
    value: formatDashboardMoney(metrics.value?.dueAmount ?? 0),
    pct: dashboardSharePct(metrics.value?.dueAmount ?? 0, mixTotal.value),
  },
  {
    color: colors.value.error,
    label: 'Overdue',
    value: formatDashboardMoney(metrics.value?.overdueAmount ?? 0),
    pct: dashboardSharePct(metrics.value?.overdueAmount ?? 0, mixTotal.value),
  },
]);

const overdueRows = computed<DashboardShareBarRow[]>(() => {
  const customers = (metrics.value?.overdueCustomers ?? []).slice(0, 3);
  const max = Math.max(1, ...customers.map((c) => c.dueAmount));
  return customers.map((row) => ({
    label: row.name,
    value: row.dueAmount,
    max,
    displayValue: formatDashboardMoneyFull(row.dueAmount),
    tone: 'warn',
  }));
});
</script>

<style scoped>
.invoice-pulse__chart-col {
  display: grid;
  gap: 0.75rem;
  justify-items: center;
  width: 100%;
}
</style>
