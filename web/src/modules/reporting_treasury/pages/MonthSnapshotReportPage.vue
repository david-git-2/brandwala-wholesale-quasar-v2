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
      <div class="column q-gutter-y-md">
        <div v-if="position">
          <div class="text-caption text-grey-7 text-uppercase q-mb-xs">Money position (right now)</div>
          <q-card flat bordered class="position-summary q-pa-md q-mb-sm">
            <div class="row items-center justify-between">
              <div>
                <div class="text-caption text-grey-7">Net buffer</div>
                <div
                  class="text-h5 text-weight-bolder bw-tabular"
                  :class="position.net_buffer >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ formatAmountBdt(position.net_buffer) }}
                </div>
              </div>
              <div class="text-caption text-grey-6 text-right" style="max-width: 220px">
                Cash + courier + receivables − payables and credits
              </div>
            </div>
          </q-card>
          <div class="row q-col-gutter-sm">
            <div
              v-for="tile in positionTiles"
              :key="tile.label"
              class="col-12 col-sm-6 col-md-4"
            >
              <q-card flat bordered class="q-pa-sm cursor-pointer position-tile" @click="tile.to && go(tile.to)">
                <div class="text-caption text-grey-7 text-uppercase">{{ tile.group }}</div>
                <div class="text-caption text-weight-medium">{{ tile.label }}</div>
                <div class="text-h6 text-weight-bolder bw-tabular" :class="tile.valueClass">{{ tile.value }}</div>
                <div v-if="tile.caption" class="text-caption text-grey-6">{{ tile.caption }}</div>
              </q-card>
            </div>
          </div>
        </div>

        <div>
          <div class="text-caption text-grey-7 text-uppercase q-mb-xs">This month</div>
          <div class="row q-col-gutter-sm">
            <div v-for="tile in monthTiles" :key="tile.label" class="col-12 col-sm-6 col-md-4">
              <q-card flat bordered class="q-pa-sm cursor-pointer" @click="tile.to && go(tile.to)">
                <div class="text-caption text-grey-7 text-uppercase">{{ tile.label }}</div>
                <div class="text-h6 text-weight-bolder text-primary bw-tabular">{{ tile.value }}</div>
                <div v-if="tile.caption" class="text-caption text-grey-6">{{ tile.caption }}</div>
              </q-card>
            </div>
          </div>
        </div>
      </div>
    </template>

    <div class="column flex-center q-pa-lg text-grey-6">
      <q-icon name="ph ph-chart-pie" size="40px" class="q-mb-sm" />
      <div class="text-body2 text-center" style="max-width: 420px">
        Tap a tile to open the detail report. Position numbers are as-of now; month tiles use {{ monthLabel }}.
      </div>
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
const appBase = computed(() => `/${tenantSlug.value || 'tenant'}/app`);
const reportsBase = computed(() => `${appBase.value}/finance/reports`);

const {
  kpis,
  position,
  monthLabel,
  startDate,
  endDate,
  isLoading,
  error,
  prevMonth,
  nextMonth,
  thisMonth,
  exportCsv,
  refetch,
} = useMonthSnapshotReport();

const monthTiles = computed(() => [
  {
    label: 'Sales',
    value: formatAmountBdt(kpis.value?.net_sales ?? 0),
    caption: 'Issued bills (not COD face)',
    to: `${reportsBase.value}/invoice-book`,
  },
  {
    label: 'Gross profit',
    value: formatAmountBdt(kpis.value?.gross_profit ?? 0),
    caption: 'Sales minus COGS',
    to: `${reportsBase.value}/invoice-profit`,
  },
  {
    label: 'Cash in',
    value: formatAmountBdt(kpis.value?.cash_collected ?? 0),
    caption: 'Receipts this month',
    to: `${reportsBase.value}/cash-in`,
  },
]);

type PositionTile = {
  group: string;
  label: string;
  value: string;
  caption?: string;
  to?: string;
  valueClass?: string;
};

const positionTiles = computed((): PositionTile[] => {
  const p = position.value;
  if (!p) return [];

  return [
    {
      group: 'We have',
      label: 'Bank / till',
      value: formatAmountBdt(p.tenant_cash),
      caption: 'Tenant cash on books',
      to: `${reportsBase.value}/cash-in`,
    },
    {
      group: 'We have',
      label: 'With courier',
      value: formatAmountBdt(p.courier_holding),
      caption: 'Courier cashbook balance',
      to: `${reportsBase.value}/courier-cod`,
    },
    {
      group: 'We will get',
      label: 'Customer bills due',
      value: formatAmountBdt(p.ar_outstanding),
      caption: 'Open AR (not AP)',
      to: `${reportsBase.value}/customer-dues`,
    },
    {
      group: 'We will get',
      label: 'COD not remitted',
      value: formatAmountBdt(p.cod_unremitted),
      caption: 'Delivered dropship, not in bank yet',
      to: `${reportsBase.value}/courier-cod`,
    },
    {
      group: 'We owe',
      label: 'Shipment AP',
      value: `−${formatAmountBdt(p.ap_payable)}`,
      caption: 'Vendor, cargo, local bills',
      to: `${appBase.value}/sales/invoices`,
      valueClass: 'text-negative',
    },
    {
      group: 'We owe',
      label: 'Shop leftover',
      value: `−${formatAmountBdt(p.merchant_payable)}`,
      caption: 'Merchant cashbook payable',
      to: `${appBase.value}/finance/payments`,
      valueClass: 'text-negative',
    },
    {
      group: 'We owe',
      label: 'Customer credit',
      value: `−${formatAmountBdt(p.customer_store_credit)}`,
      caption: 'Store credit on cashbook',
      to: `${appBase.value}/wallet`,
      valueClass: 'text-negative',
    },
  ];
});

function go(path: string) {
  const query = startDate.value && endDate.value ? `?from=${startDate.value}&to=${endDate.value}` : '';
  void router.push(`${path}${query}`);
}
</script>

<style scoped>
.rounded-sq-btn {
  border-radius: 8px !important;
}

.position-summary {
  background: linear-gradient(135deg, rgba(var(--q-primary-rgb), 0.06), transparent);
}

.position-tile {
  min-height: 108px;
}
</style>
