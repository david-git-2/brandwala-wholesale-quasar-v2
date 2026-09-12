<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error"
    :export-disabled="!rows.length"
    @export="exportCsv"
    @refresh="() => refetch()"
  >
    <template #filters>
      <DatePresetPills :preset="preset" @set="setPreset" />
      <template v-if="preset === 'custom'">
        <q-input v-model="startDate" dense outlined type="date" class="compact-date-input bg-white" />
        <span class="text-caption text-grey-6">to</span>
        <q-input v-model="endDate" dense outlined type="date" class="compact-date-input bg-white" />
      </template>
      <q-input
        v-model="searchText"
        outlined rounded dense clearable
        placeholder="Search customer..."
        class="dense-search-input bg-white"
        style="min-width: 200px"
      >
        <template #prepend><q-icon name="ph ph-magnifying-glass" size="14px" /></template>
      </q-input>
    </template>

    <template #kpi>
      <div class="row items-center q-gutter-x-md wrap q-gutter-y-xs">
        <ReportKpiStrip label="Outstanding now" :value="totals?.outstanding" highlight />
        <ReportKpiStrip label="Credit issued" :value="totals?.credit_issued" />
        <ReportKpiStrip label="Credit applied" :value="totals?.credit_applied" />
        <ReportKpiStrip label="Customers" :value="totals?.customer_count" number />
      </div>
    </template>

    <q-table
      flat dense :rows="rows" :columns="columns" row-key="billing_profile_id"
      :loading="isLoading" :pagination="{ rowsPerPage: 50 }"
      class="compact-ops-table full-height bg-white"
      @row-click="(_, row) => openWallet(row)"
    />
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import DatePresetPills from '../components/DatePresetPills.vue';
import ReportKpiStrip from '../components/ReportKpiStrip.vue';
import { useWalletLiabilityReport } from '../composables/useWalletLiabilityReport';
import type { WalletLiabilityRow } from '../types/financeReportTypes';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const {
  totals, rows, isLoading, error, preset, startDate, endDate, searchText, setPreset, exportCsv, refetch,
} = useWalletLiabilityReport();

const columns: QTableColumn<WalletLiabilityRow>[] = [
  { name: 'name', label: 'Customer', field: 'name', align: 'left', sortable: true },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'credit_issued', label: 'Issued', field: 'credit_issued', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'credit_applied', label: 'Applied', field: 'credit_applied', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'outstanding', label: 'Outstanding', field: 'outstanding', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
];

function openWallet(row: WalletLiabilityRow) {
  void router.push({
    name: 'app-universal-wallet-page',
    params: {
      tenantSlug: tenantSlug.value || 'tenant',
      walletType: 'customer',
      entityId: row.billing_profile_id,
    },
  });
}
</script>

<style scoped>
.compact-date-input { width: 130px; }
.dense-search-input :deep(.q-field__control) { height: 30px; min-height: 30px; }
</style>
