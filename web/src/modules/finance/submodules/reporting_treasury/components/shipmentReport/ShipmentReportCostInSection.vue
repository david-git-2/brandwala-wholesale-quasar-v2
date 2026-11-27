<template>
  <ShipmentReportSectionShell :title="embedded ? undefined : 'Costs'" :bare="embedded">
    <div v-if="showExchangeRates" class="row items-center q-gutter-sm q-mb-md">
      <span class="text-caption text-weight-bold" style="color: var(--tf-neutral-chrome-text)">
        Exchange rates
      </span>
      <q-chip v-if="showProductRate" dense size="sm" class="tf-num">
        Goods {{ formatRate(exchangeRates?.product_rate) }}
      </q-chip>
      <q-chip v-if="showFreightRate" dense size="sm" class="tf-num">
        Freight {{ formatRate(exchangeRates?.freight_rate) }}
      </q-chip>
      <q-chip v-if="showBlendedRate" dense size="sm" class="tf-num">
        Blended {{ formatRate(exchangeRates?.blended_rate) }}
      </q-chip>
    </div>

    <q-table
      v-if="apBills.length"
      flat
      bordered
      dense
      :rows="apBills"
      :columns="apColumns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="detail-table q-mb-md"
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
      <template #body-cell-bdt_amount="props">
        <q-td :props="props" class="tf-num text-right">
          {{ formatMoney(billBdtAmount(props.row), 'BDT') }}
        </q-td>
      </template>
      <template #body-cell-payment_status="props">
        <q-td :props="props">
          <TfStatusBadge v-if="props.row.payment_status" :status="String(props.row.payment_status)" />
          <span v-else>—</span>
        </q-td>
      </template>
    </q-table>
    <div v-else class="text-caption text-grey-6 q-mb-md">No supplier bills linked yet.</div>

    <div
      v-if="apBooksTotalBdt > 0.009"
      class="row q-col-gutter-md q-mb-md text-caption tf-num cost-summary-strip"
    >
      <div class="col-auto">
        <span class="text-weight-bold">Gross in taka</span>
        {{ formatMoney(apBooksTotalBdt, 'BDT') }}
      </div>
      <div v-if="vendorCreditBdt > 0.009" class="col-auto">
        <span class="text-weight-bold">Vendor credits</span>
        −{{ formatMoney(vendorCreditBdt, 'BDT') }}
      </div>
      <div v-if="vendorCreditBdt > 0.009" class="col-auto">
        <span class="text-weight-bold">Net in taka</span>
        {{ formatMoney(netCostBdt, 'BDT') }}
      </div>
    </div>

    <div
      v-if="vendorCreditNotes.length"
      class="text-caption text-weight-bold q-mb-xs"
      style="color: var(--tf-neutral-chrome-text)"
    >
      Vendor credit notes
    </div>
    <q-table
      v-if="vendorCreditNotes.length"
      flat
      bordered
      dense
      :rows="vendorCreditNotes"
      :columns="cnColumns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="detail-table q-mb-md"
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
      <template #body-cell-parent="props">
        <q-td :props="props">
          <router-link
            v-if="canViewBills && props.row.parent_bill_id"
            :to="billRoute(props.row.parent_bill_id)"
            class="text-primary"
            @click.stop
          >
            {{ props.row.parent_invoice_no || '—' }}
          </router-link>
          <span v-else>{{ props.row.parent_invoice_no || '—' }}</span>
        </q-td>
      </template>
      <template #body-cell-txn="props">
        <q-td :props="props" class="tf-num text-right">
          {{ formatMoney(props.row.txn_amount, props.row.txn_currency_code || 'BDT') }}
        </q-td>
      </template>
      <template #body-cell-bdt="props">
        <q-td :props="props" class="tf-num text-right">
          {{ formatMoney(props.row.bdt_credit, 'BDT') }}
        </q-td>
      </template>
      <template #body-cell-payment_status="props">
        <q-td :props="props">
          <TfStatusBadge v-if="props.row.payment_status" :status="String(props.row.payment_status)" />
          <span v-else>—</span>
        </q-td>
      </template>
    </q-table>

    <div class="text-caption text-weight-bold q-mb-xs q-mt-sm" style="color: var(--tf-neutral-chrome-text)">
      Cost by type
    </div>
    <q-list v-if="costBuckets.length" dense separator>
      <q-item v-for="bucket in costBuckets" :key="bucket.ap_kind" class="q-px-none">
        <q-item-section>
          <q-item-label class="text-weight-medium">
            {{ bucket.label }}
            <span v-if="bucketSharePct(bucket) > 0" class="tf-num text-caption" style="color: var(--tf-neutral-muted)">
              · {{ bucketSharePct(bucket).toFixed(1) }}%
            </span>
          </q-item-label>
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
        <q-item-section side class="text-weight-bold tf-num">
          {{ formatMoney(bucket.bdt_amount, 'BDT') }}
        </q-item-section>
      </q-item>
    </q-list>
    <div v-else class="text-caption text-grey-6">No cost buckets yet.</div>
  </ShipmentReportSectionShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type {
  ShipmentReportApBillRow,
  ShipmentReportCostBucket,
  ShipmentReportExchangeRates,
  ShipmentReportVendorCreditNote,
} from '../../types/shipmentReportDetailTypes';
import ShipmentReportSectionShell from './ShipmentReportSectionShell.vue';

const props = withDefaults(
  defineProps<{
    apBills: ShipmentReportApBillRow[];
    costBuckets: ShipmentReportCostBucket[];
    exchangeRates: ShipmentReportExchangeRates | null;
    totalCostBdt?: number;
    apBooksTotalBdt?: number;
    vendorCreditNotes?: ShipmentReportVendorCreditNote[];
    vendorCreditBdt?: number;
    netCostBdt?: number;
    canViewBills: boolean;
    billRoute: (billId: number) => string;
    embedded?: boolean;
  }>(),
  {
    totalCostBdt: 0,
    apBooksTotalBdt: 0,
    vendorCreditNotes: () => [],
    vendorCreditBdt: 0,
    netCostBdt: 0,
    embedded: false,
  },
);

function billBdtAmount(row: ShipmentReportApBillRow) {
  return row.bdt_amount ?? row.total_amount;
}

function bucketSharePct(bucket: ShipmentReportCostBucket) {
  const total = props.totalCostBdt > 0 ? props.totalCostBdt : props.costBuckets.reduce((a, b) => a + b.bdt_amount, 0);
  if (total <= 0) return 0;
  return (bucket.bdt_amount / total) * 100;
}

function formatMoney(amount: number | null | undefined, currencyCode: string) {
  return formatSettlementCurrencyAmount(amount, currencyCode);
}

function txnCode(row: ShipmentReportApBillRow) {
  return (row.txn_currency_code || row.currency_code || 'BDT').toUpperCase();
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

function rateDiffersFromOne(rate: number | null | undefined) {
  if (rate == null || Number.isNaN(rate)) return false;
  return Math.abs(rate - 1) > 0.0001;
}

const showProductRate = computed(
  () =>
    (props.exchangeRates?.material_payment_count ?? 0) > 0
    || rateDiffersFromOne(props.exchangeRates?.product_rate),
);

const showFreightRate = computed(
  () =>
    (props.exchangeRates?.freight_payment_count ?? 0) > 0
    || rateDiffersFromOne(props.exchangeRates?.freight_rate),
);

const showBlendedRate = computed(
  () =>
    showProductRate.value
    && showFreightRate.value
    && rateDiffersFromOne(props.exchangeRates?.blended_rate),
);

const showExchangeRates = computed(() => showProductRate.value || showFreightRate.value);

function formatRate(rate: number | null | undefined) {
  if (rate == null || Number.isNaN(rate)) return '—';
  return rate.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });
}

const cnColumns: QTableColumn<ShipmentReportVendorCreditNote>[] = [
  { name: 'invoice_no', label: 'Credit no.', field: 'invoice_no', align: 'left' },
  { name: 'parent', label: 'Against AP', field: 'parent_invoice_no', align: 'left' },
  { name: 'txn', label: 'Foreign', field: 'txn_amount', align: 'right' },
  { name: 'bdt', label: 'In taka', field: 'bdt_credit', align: 'right' },
  {
    name: 'reason',
    label: 'Reason',
    field: 'reason',
    align: 'left',
    format: (v) => String(v || '—'),
  },
  { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'left' },
];

const apColumns: QTableColumn<ShipmentReportApBillRow>[] = [
  { name: 'invoice_no', label: 'Bill no.', field: 'invoice_no', align: 'left' },
  { name: 'ap_kind', label: 'Type', field: 'ap_kind', align: 'left', format: (v) => String(v || '—') },
  { name: 'txn', label: 'Foreign', field: 'txn_total_amount', align: 'right' },
  { name: 'bdt_amount', label: 'In taka', field: 'bdt_amount', align: 'right' },
  { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'left' },
];
</script>

<style scoped>
.detail-table :deep(thead tr th) {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.cost-summary-strip {
  color: var(--tf-neutral-chrome-text);
}
</style>