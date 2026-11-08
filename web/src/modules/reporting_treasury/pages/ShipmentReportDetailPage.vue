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
      <span v-if="detail?.header?.shipment_name" class="text-subtitle2 text-weight-bold q-ml-sm ellipsis">
        {{ detail.header.shipment_name }}
      </span>
      <span v-if="detail?.header?.shipment_no" class="text-caption text-grey-7 font-mono q-ml-xs">
        {{ detail.header.shipment_no }}
      </span>
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

    <div v-if="!isLoading && detail" class="detail-scroll column q-gutter-y-sm q-pa-xs">
      <!-- At a glance -->
      <q-card flat bordered class="q-pa-md glance-card">
        <div class="section-title q-mb-md">At a glance</div>
        <div class="row q-col-gutter-md">
          <div class="col-6 col-sm-4 col-lg-2">
            <div class="metric-label">Total cost</div>
            <div class="metric-val tf-num">{{ formatMoney(matrix.total_cost_bdt, 'BDT') }}</div>
            <div
              v-for="c in matrix.total_cost_by_currency"
              :key="c.currency_code"
              class="metric-sub tf-num"
            >
              {{ formatMoney(c.amount, c.currency_code) }}
            </div>
          </div>
          <div class="col-6 col-sm-4 col-lg-2">
            <div class="metric-label">Total sell</div>
            <div class="metric-val tf-num text-primary">
              {{ formatMoney(matrix.total_sell_bdt, 'BDT') }}
            </div>
          </div>
          <div class="col-6 col-sm-4 col-lg-2">
            <div class="metric-label">Receive loss</div>
            <div class="metric-val tf-num text-warning">
              {{ formatMoney(matrix.receive_loss_bdt, 'BDT') }}
            </div>
          </div>
          <div class="col-6 col-sm-4 col-lg-2">
            <div class="metric-label">Profit / loss</div>
            <div
              class="metric-val tf-num"
              :class="matrix.profit_loss_bdt >= 0 ? 'text-positive' : 'text-negative'"
            >
              {{ formatMoney(matrix.profit_loss_bdt, 'BDT') }}
            </div>
            <div class="metric-sub">{{ matrix.profit_loss_pct }}% of sell</div>
          </div>
          <div class="col-6 col-sm-4 col-lg-2">
            <div class="metric-label">Customers not paid</div>
            <div class="metric-val tf-num">{{ formatMoney(matrix.unpaid_total_bdt, 'BDT') }}</div>
          </div>
          <div class="col-6 col-sm-4 col-lg-2">
            <div class="metric-label">Warehouse value</div>
            <div class="metric-val tf-num">{{ formatMoney(qty.warehouse_value_bdt, 'BDT') }}</div>
          </div>
        </div>
      </q-card>

      <!-- Pieces -->
      <q-card flat bordered class="q-pa-sm">
        <div class="section-title q-mb-sm">Pieces</div>
        <div class="row q-col-gutter-sm">
          <div class="col-4 col-sm-2">
            <div class="metric-label">Should arrive</div>
            <div class="metric-val tf-num">{{ qty.should_arrive }}</div>
          </div>
          <div class="col-4 col-sm-2">
            <div class="metric-label">Arrived</div>
            <div class="metric-val tf-num">{{ qty.arrived }}</div>
          </div>
          <div class="col-4 col-sm-2">
            <div class="metric-label">Loss</div>
            <div class="metric-val tf-num">{{ qty.loss_at_shipment }}</div>
          </div>
          <div class="col-4 col-sm-2">
            <div class="metric-label">Stalled (held)</div>
            <div class="metric-val tf-num">{{ qty.warehouse_stalled }}</div>
          </div>
          <div class="col-4 col-sm-2">
            <div class="metric-label">Remaining</div>
            <div class="metric-val tf-num">{{ qty.warehouse_remaining }}</div>
          </div>
          <div class="col-4 col-sm-2">
            <div class="metric-label">Sold</div>
            <div class="metric-val tf-num">{{ qty.sold }}</div>
          </div>
        </div>
      </q-card>

      <!-- Exchange rates -->
      <q-card v-if="showExchangeRates" flat bordered class="q-pa-sm">
        <div class="section-title q-mb-xs">Exchange rates</div>
        <div class="row q-col-gutter-sm">
          <div v-if="showProductRate" class="col-4">
            <div class="metric-label">Goods</div>
            <div class="metric-val tf-num">{{ formatRate(exchangeRates?.product_rate) }}</div>
          </div>
          <div v-if="showFreightRate" class="col-4">
            <div class="metric-label">Flight</div>
            <div class="metric-val tf-num">{{ formatRate(exchangeRates?.freight_rate) }}</div>
          </div>
          <div v-if="showBlendedRate" class="col-4">
            <div class="metric-label">Blended</div>
            <div class="metric-val tf-num">{{ formatRate(exchangeRates?.blended_rate) }}</div>
          </div>
        </div>
      </q-card>

      <!-- Cost by type -->
      <q-card flat bordered class="q-pa-sm">
        <div class="section-title q-mb-sm">Cost by type</div>
        <q-list v-if="detail.cost_buckets.length" dense separator>
          <q-item v-for="bucket in detail.cost_buckets" :key="bucket.ap_kind" class="q-px-none">
            <q-item-section>
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
            </q-item-section>
            <q-item-section side>
              <div class="text-weight-bold tf-num">{{ formatMoney(bucket.bdt_amount, 'BDT') }}</div>
            </q-item-section>
          </q-item>
        </q-list>
        <div v-else class="text-caption text-grey-6 q-py-sm">No supplier bills linked yet.</div>

        <q-expansion-item
          v-if="detail.ap_bills.length"
          dense
          header-class="text-caption text-grey-8 q-px-none"
          label="All supplier bills"
          class="q-mt-sm"
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

      <!-- Sell -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-mb-sm">
          <div class="section-title">Sell</div>
          <div class="text-subtitle2 text-weight-bold tf-num">
            {{ formatMoney(matrix.total_sell_bdt, 'BDT') }}
          </div>
        </div>
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
      </q-card>

      <!-- Not paid yet -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-mb-sm">
          <div class="section-title">Not paid yet</div>
          <div class="text-subtitle2 text-weight-bold tf-num">
            {{ formatMoney(matrix.unpaid_total_bdt, 'BDT') }}
          </div>
        </div>
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
        <div v-else class="text-caption text-grey-6 q-py-sm">No open customer dues for this batch.</div>
      </q-card>
    </div>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import type { QTableColumn } from 'quasar';
import { storeToRefs } from 'pinia';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
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

.glance-card {
  background: var(--tf-neutral-chrome);
}

.section-title {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-muted);
}

.metric-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-muted);
}

.metric-val {
  font-size: 15px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
}

.metric-sub {
  font-size: 11px;
  color: var(--tf-neutral-muted);
}

.detail-table :deep(thead tr th) {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}
</style>
