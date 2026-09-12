<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error"
    show-export
    :export-disabled="!kpis"
    @export="exportCsv"
    @refresh="() => refetch()"
  >
    <template #filters>
      <q-btn dense outline size="sm" icon="ph ph-caret-left" class="rounded-sq-btn" @click="prevMonth" />
      <span class="text-subtitle2 text-weight-bold">{{ monthLabel }}</span>
      <q-btn dense outline size="sm" icon="ph ph-caret-right" class="rounded-sq-btn" @click="nextMonth" />
      <q-btn dense flat size="sm" no-caps label="This month" @click="thisMonth" />
    </template>

    <template #kpi>
      <div class="row q-col-gutter-sm">
        <div v-for="tile in tiles" :key="tile.label" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="q-pa-sm cursor-pointer" @click="tile.to && go(tile.to)">
            <div class="text-caption text-grey-7 text-uppercase">{{ tile.label }}</div>
            <div class="text-h6 text-weight-bolder text-primary bw-tabular">{{ tile.value }}</div>
            <div v-if="tile.caption" class="text-caption text-grey-6">{{ tile.caption }}</div>
          </q-card>
        </div>
      </div>
    </template>

    <div class="column flex-center q-pa-xl text-grey-6">
      <q-icon name="ph ph-chart-pie" size="48px" class="q-mb-sm" />
      <div class="text-body2">Owner snapshot for {{ monthLabel }}. Use the tiles above to drill into detail reports.</div>
    </div>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import { useMonthSnapshotReport } from '../composables/useMonthSnapshotReport';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const base = computed(() => `/${tenantSlug.value || 'tenant'}/app/finance/reports`);

const {
  kpis, monthLabel, startDate, endDate, isLoading, error,
  prevMonth, nextMonth, thisMonth, exportCsv, refetch,
} = useMonthSnapshotReport();

const tiles = computed(() => [
  { label: 'Net sales', value: formatAmountBdt(kpis.value?.net_sales ?? 0), caption: 'Issued minus returns', to: `${base.value}/invoice-book` },
  { label: 'Gross profit', value: formatAmountBdt(kpis.value?.gross_profit ?? 0), caption: 'Revenue minus COGS', to: `${base.value}/invoice-profit` },
  { label: 'Cash collected', value: formatAmountBdt(kpis.value?.cash_collected ?? 0), caption: 'Tenant wallet credits', to: `${base.value}/cash-in` },
  { label: 'AR outstanding', value: formatAmountBdt(kpis.value?.ar_outstanding ?? 0), caption: 'Live wholesale dues', to: `${base.value}/customer-dues` },
  { label: 'Wallet liability', value: formatAmountBdt(kpis.value?.wallet_liability ?? 0), caption: 'Store credit owed', to: `${base.value}/wallet` },
  { label: 'Unsold stock', value: formatAmountBdt(kpis.value?.unsold_stock_value ?? 0), caption: 'At landed cost', to: `${base.value}/shipment-profit` },
]);

function go(path: string) {
  const query = startDate.value && endDate.value ? `?from=${startDate.value}&to=${endDate.value}` : '';
  void router.push(`${path}${query}`);
}
</script>

<style scoped>
.rounded-sq-btn { border-radius: 8px !important; }
</style>
