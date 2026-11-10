<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error ? (error as Error).message : null"
    @refresh="() => refetch()"
  >
    <template #filters>
      <q-btn
        flat
        dense
        no-caps
        color="primary"
        icon="ph ph-arrow-left"
        label="Back"
        :to="listRoute"
      />
      <div class="column q-ml-sm" style="min-width: 0">
        <div class="row items-center no-wrap q-gutter-x-xs">
          <span v-if="detail?.header?.shipment_name" class="text-subtitle2 text-weight-bold ellipsis">
            {{ detail.header.shipment_name }}
          </span>
          <TfStatusBadge
            v-if="detail?.header?.shipment_status"
            :status="detail.header.shipment_status"
          />
        </div>
        <div class="row items-center q-gutter-x-sm text-caption text-grey-7">
          <span v-if="detail?.header?.shipment_no" class="font-mono">{{ detail.header.shipment_no }}</span>
          <span v-if="detail?.header?.vendor_name">{{ detail.header.vendor_name }}</span>
        </div>
      </div>
    </template>

    <template #toolbar-actions>
      <q-btn
        v-if="canOpenProcurement"
        flat
        dense
        no-caps
        size="sm"
        color="grey-8"
        icon="ph ph-package"
        label="Open shipment"
        :to="procurementShipmentRoute"
      />
    </template>

    <template #kpi>
      <ShipmentReportKpiStrip
        v-if="detail"
        :matrix="matrix"
        :warehouse-value-bdt="qty.warehouse_value_bdt"
      />
    </template>

    <div v-if="!isLoading && detail" class="detail-scroll">
      <div class="detail-inner column q-gutter-y-md">
        <!-- Story row -->
        <q-card flat bordered class="q-pa-md report-card">
          <div class="row q-col-gutter-lg">
            <div class="col-12 col-md-6">
              <ShipmentReportQuantityStory :qty="qty" />
            </div>
            <div class="col-12 col-md-6">
              <div class="text-subtitle2 text-weight-bold q-mb-sm">Cost vs sell</div>
              <div class="q-mb-sm">
                <div class="row items-center justify-between text-caption text-grey-7 q-mb-xs">
                  <span>Total cost</span>
                  <span class="tf-num">{{ formatMoney(matrix.total_cost_bdt, 'BDT') }}</span>
                </div>
                <q-linear-progress
                  :value="moneyBarScale > 0 ? matrix.total_cost_bdt / moneyBarScale : 0"
                  size="8px"
                  rounded
                  color="grey-7"
                  track-color="grey-3"
                />
              </div>
              <div class="q-mb-sm">
                <div class="row items-center justify-between text-caption text-grey-7 q-mb-xs">
                  <span>Total sell</span>
                  <span class="tf-num text-primary">{{ formatMoney(matrix.total_sell_bdt, 'BDT') }}</span>
                </div>
                <q-linear-progress
                  :value="moneyBarScale > 0 ? matrix.total_sell_bdt / moneyBarScale : 0"
                  size="8px"
                  rounded
                  color="primary"
                  track-color="grey-3"
                />
              </div>
              <p v-if="matrix.receive_loss_bdt > 0" class="text-caption text-grey-7 q-mb-none">
                Receive loss (info): {{ formatMoney(matrix.receive_loss_bdt, 'BDT') }}
              </p>
            </div>
          </div>
        </q-card>

        <!-- Cost -->
        <q-card flat bordered class="q-pa-md report-card">
          <div class="row items-center justify-between q-mb-sm">
            <div class="text-subtitle2 text-weight-bold">Cost by type</div>
            <div v-if="showExchangeRates" class="row q-gutter-xs">
              <q-chip v-if="showProductRate" dense size="sm" class="tf-num">
                Goods {{ formatRate(exchangeRates?.product_rate) }}
              </q-chip>
              <q-chip v-if="showFreightRate" dense size="sm" class="tf-num">
                Flight {{ formatRate(exchangeRates?.freight_rate) }}
              </q-chip>
              <q-chip v-if="showBlendedRate" dense size="sm" class="tf-num">
                Blended {{ formatRate(exchangeRates?.blended_rate) }}
              </q-chip>
            </div>
          </div>
          <q-list v-if="detail.cost_buckets.length" dense separator class="q-mb-sm">
            <q-item v-for="bucket in detail.cost_buckets" :key="bucket.ap_kind" class="q-px-none column">
              <div class="row items-center full-width q-mb-xs">
                <div class="col">
                  <q-item-label class="text-weight-medium">{{ bucket.label }}</q-item-label>
                  <q-item-label caption class="row q-gutter-x-sm">
                    <span
                      v-for="(leg, idx) in foreignLegsFor(bucket)"
                      :key="`${bucket.ap_kind}-${leg.currency_code}-${idx}`"
                      class="tf-num"
                    >
                      {{ formatMoney(leg.amount, leg.currency_code) }}
                    </span>
                    <span v-if="!foreignLegsFor(bucket).length" class="text-grey-6">—</span>
                  </q-item-label>
                </div>
                <div class="col-auto text-weight-bold tf-num">
                  {{ formatMoney(bucket.bdt_amount, 'BDT') }}
                </div>
              </div>
              <q-linear-progress
                :value="bucketShare(bucket)"
                size="4px"
                rounded
                color="primary"
                track-color="grey-3"
              />
            </q-item>
          </q-list>
          <div v-else class="text-caption text-grey-6 q-py-sm">No supplier bills linked yet.</div>

          <q-expansion-item
            v-if="detail.ap_bills.length"
            dense
            header-class="text-caption text-grey-8 q-px-none"
            label="All supplier bills"
          >
            <q-table
              flat
              bordered
              dense
              :rows="detail.ap_bills"
              :columns="apColumns"
              row-key="id"
              hide-pagination
              :pagination="{ rowsPerPage: 0 }"
              class="detail-table q-mt-xs"
            >
              <template #body-cell-invoice_no="props">
                <q-td :props="props">
                  <router-link
                    v-if="canViewBills"
                    :to="billRoute(props.row.id)"
                    class="text-primary text-weight-medium"
                    @click.stop
                  >
                    {{ props.row.invoice_no }}
                  </router-link>
                  <span v-else>{{ props.row.invoice_no }}</span>
                </q-td>
              </template>
              <template #body-cell-txn="props">
                <q-td :props="props" class="tf-num text-right">
                  {{ formatMoney(props.row.txn_total_amount, txnCode(props.row)) }}
                </q-td>
              </template>
              <template #body-cell-total_amount="props">
                <q-td :props="props" class="tf-num text-right">
                  {{ formatMoney(props.row.total_amount, 'BDT') }}
                </q-td>
              </template>
            </q-table>
          </q-expansion-item>
        </q-card>

        <!-- Sales -->
        <q-card flat bordered class="q-pa-md report-card">
          <q-tabs
            v-model="salesTab"
            dense
            class="text-grey-8"
            active-color="primary"
            indicator-color="primary"
            align="left"
            narrow-indicator
          >
            <q-tab
              name="sell"
              :label="`Sell · ${formatMoney(matrix.total_sell_bdt, 'BDT')}`"
              no-caps
            />
            <q-tab
              v-if="showUnpaidTab"
              name="unpaid"
              :label="`Not paid · ${formatMoney(matrix.unpaid_total_bdt, 'BDT')}`"
              no-caps
            />
          </q-tabs>
          <q-separator />
          <q-tab-panels v-model="salesTab" animated>
            <q-tab-panel name="sell" class="q-pa-none q-pt-sm">
              <q-table
                v-if="detail.sell_lines.length"
                flat
                bordered
                dense
                :rows="detail.sell_lines"
                :columns="sellColumns"
                row-key="invoice_item_id"
                hide-pagination
                :pagination="{ rowsPerPage: 0 }"
                class="detail-table"
              >
                <template #body-cell-invoice_no="props">
                  <q-td :props="props">
                    <router-link
                      v-if="canViewBills"
                      :to="billRoute(props.row.bill_id)"
                      class="text-primary text-weight-medium"
                      @click.stop
                    >
                      {{ props.row.invoice_no }}
                    </router-link>
                    <span v-else>{{ props.row.invoice_no }}</span>
                  </q-td>
                </template>
                <template #body-cell-amount_bdt="props">
                  <q-td :props="props" class="tf-num text-right">
                    {{ formatMoney(props.row.amount_bdt, 'BDT') }}
                  </q-td>
                </template>
              </q-table>
              <div v-else class="text-caption text-grey-6 q-py-sm">
                No issued sales from this batch yet.
              </div>
            </q-tab-panel>
            <q-tab-panel v-if="showUnpaidTab" name="unpaid" class="q-pa-none q-pt-sm">
              <q-table
                v-if="detail.unpaid_customers.length"
                flat
                bordered
                dense
                :rows="detail.unpaid_customers"
                :columns="unpaidColumns"
                row-key="bill_id"
                hide-pagination
                :pagination="{ rowsPerPage: 0 }"
                class="detail-table"
              >
                <template #body-cell-invoice_no="props">
                  <q-td :props="props">
                    <router-link
                      v-if="canViewBills"
                      :to="billRoute(props.row.bill_id)"
                      class="text-primary text-weight-medium"
                      @click.stop
                    >
                      {{ props.row.invoice_no }}
                    </router-link>
                    <span v-else>{{ props.row.invoice_no }}</span>
                  </q-td>
                </template>
                <template #body-cell-open_bdt="props">
                  <q-td :props="props" class="tf-num text-right">
                    {{ formatMoney(props.row.open_bdt, 'BDT') }}
                  </q-td>
                </template>
              </q-table>
            </q-tab-panel>
          </q-tab-panels>
        </q-card>
      </div>
    </div>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import type { QTableColumn } from 'quasar';
import { storeToRefs } from 'pinia';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import ShipmentReportKpiStrip from '../components/ShipmentReportKpiStrip.vue';
import ShipmentReportQuantityStory from '../components/ShipmentReportQuantityStory.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import { useShipmentReportDetail } from '../composables/useShipmentReportDetail';
import type {
  ShipmentReportApBillRow,
  ShipmentReportCostBucket,
  ShipmentReportSellLine,
  ShipmentReportUnpaidCustomer,
} from '../types/shipmentReportDetailTypes';

const route = useRoute();
const authStore = useAuthStore();
const { tenantSlug } = storeToRefs(authStore);

const salesTab = ref<'sell' | 'unpaid'>('sell');

const shipmentId = computed(() => {
  const raw = route.params.shipmentId;
  const n = typeof raw === 'string' ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) && n > 0 ? n : null;
});

const { detail, isLoading, error, refetch } = useShipmentReportDetail(shipmentId);

const qty = computed(() => detail.value?.qty_summary ?? {
  should_arrive: 0,
  arrived: 0,
  loss_at_shipment: 0,
  warehouse_stalled: 0,
  warehouse_remaining: 0,
  sold: 0,
  warehouse_value_bdt: 0,
});

const matrix = computed(() => detail.value?.profit_matrix ?? {
  total_cost_bdt: 0,
  total_cost_by_currency: [],
  total_sell_bdt: 0,
  receive_loss_bdt: 0,
  unpaid_total_bdt: 0,
  profit_loss_bdt: 0,
  profit_loss_pct: 0,
});

const moneyBarScale = computed(() =>
  Math.max(matrix.value.total_cost_bdt, matrix.value.total_sell_bdt, 1),
);

const showUnpaidTab = computed(() => matrix.value.unpaid_total_bdt > 0.009);

watch(showUnpaidTab, (on) => {
  if (!on && salesTab.value === 'unpaid') salesTab.value = 'sell';
});

const exchangeRates = computed(() => detail.value?.exchange_rates ?? null);

function rateDiffersFromOne(rate: number | null | undefined) {
  if (rate == null || Number.isNaN(rate)) return false;
  return Math.abs(rate - 1) > 0.0001;
}

const showProductRate = computed(
  () =>
    (exchangeRates.value?.material_payment_count ?? 0) > 0
    || rateDiffersFromOne(exchangeRates.value?.product_rate),
);

const showFreightRate = computed(
  () =>
    (exchangeRates.value?.freight_payment_count ?? 0) > 0
    || rateDiffersFromOne(exchangeRates.value?.freight_rate),
);

const showBlendedRate = computed(
  () =>
    showProductRate.value
    && showFreightRate.value
    && rateDiffersFromOne(exchangeRates.value?.blended_rate),
);

const showExchangeRates = computed(() => showProductRate.value || showFreightRate.value);

function formatRate(rate: number | null | undefined) {
  if (rate == null || Number.isNaN(rate)) return '—';
  return rate.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });
}

function formatMoney(amount: number | null | undefined, currencyCode: string) {
  return formatSettlementCurrencyAmount(amount, currencyCode);
}

function bucketShare(bucket: ShipmentReportCostBucket) {
  const total = matrix.value.total_cost_bdt;
  if (total <= 0) return 0;
  return Math.min(1, bucket.bdt_amount / total);
}

function foreignLegsFor(bucket: ShipmentReportCostBucket) {
  const legs = bucket.foreign_legs ?? [];
  if (legs.length) return legs;
  if (
    bucket.foreign_amount != null
    && bucket.foreign_currency
    && bucket.foreign_amount > 0
    && bucket.foreign_currency.toUpperCase() !== 'BDT'
  ) {
    return [{ currency_code: bucket.foreign_currency, amount: bucket.foreign_amount }];
  }
  return [];
}

function txnCode(row: ShipmentReportApBillRow) {
  return (row.txn_currency_code || row.currency_code || 'BDT').toUpperCase();
}

const listRoute = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/finance/reports/shipment-report`,
);

const procurementShipmentRoute = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/procurement/shipment/${shipmentId.value ?? ''}`,
);

const canViewBills = computed(() =>
  (authStore.access?.effectiveGrants ?? []).some(
    (g) => g.module_key === 'global_invoice' && g.action === 'view',
  ),
);

const canOpenProcurement = computed(() =>
  (authStore.access?.effectiveGrants ?? []).some(
    (g) => g.module_key === 'global_shipment' && g.action === 'view',
  ),
);

function billRoute(billId: number) {
  return `/${tenantSlug.value || 'tenant'}/app/bills/${billId}`;
}

const apColumns: QTableColumn<ShipmentReportApBillRow>[] = [
  { name: 'invoice_no', label: 'Bill no.', field: 'invoice_no', align: 'left' },
  { name: 'ap_kind', label: 'Type', field: 'ap_kind', align: 'left', format: (v) => String(v || '—') },
  { name: 'invoice_status', label: 'Status', field: 'invoice_status', align: 'left' },
  { name: 'txn', label: 'Foreign amount', field: 'txn_total_amount', align: 'right' },
  { name: 'total_amount', label: 'In taka', field: 'total_amount', align: 'right' },
];

const sellColumns: QTableColumn<ShipmentReportSellLine>[] = [
  { name: 'invoice_no', label: 'Bill no.', field: 'invoice_no', align: 'left' },
  { name: 'product_name', label: 'Product', field: 'product_name', align: 'left' },
  { name: 'qty', label: 'Qty', field: 'qty', align: 'right' },
  { name: 'amount_bdt', label: 'Amount', field: 'amount_bdt', align: 'right' },
];

const unpaidColumns: QTableColumn<ShipmentReportUnpaidCustomer>[] = [
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'invoice_no', label: 'Bill no.', field: 'invoice_no', align: 'left' },
  { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'left', format: (v) => String(v || '—') },
  { name: 'open_bdt', label: 'Still owed', field: 'open_bdt', align: 'right' },
];
</script>

<style scoped>
.detail-scroll {
  overflow-y: auto;
  max-height: 100%;
}

.detail-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 8px;
  width: 100%;
}

.report-card {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}

.detail-table :deep(thead tr th) {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}
</style>
