<template>
  <ShipmentReportSectionShell title="Sales out">
    <div v-if="customerBills.length" class="q-mb-md">
      <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">By customer</div>
      <q-table
        flat
        bordered
        dense
        :rows="customerBills"
        :columns="customerColumns"
        row-key="id"
        hide-pagination
        :pagination="{ rowsPerPage: 0 }"
        class="detail-table q-mb-sm"
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
        <template #body-cell-attributed_qty="props">
          <q-td :props="props" class="tf-num text-right">{{ props.row.attributed_qty }}</q-td>
        </template>
        <template #body-cell-attributed_revenue_bdt="props">
          <q-td :props="props" class="tf-num text-right">
            {{ formatMoney(props.row.attributed_revenue_bdt, 'BDT') }}
          </q-td>
        </template>
      </q-table>
    </div>

    <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">By product line</div>
    <q-table
      v-if="sellLines.length"
      flat
      bordered
      dense
      :rows="sellLines"
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
      <template #body-cell-qty="props">
        <q-td :props="props" class="tf-num text-right">{{ props.row.qty }}</q-td>
      </template>
      <template #body-cell-amount_bdt="props">
        <q-td :props="props" class="tf-num text-right">
          {{ formatMoney(props.row.amount_bdt, 'BDT') }}
        </q-td>
      </template>
    </q-table>
    <div v-else class="text-caption text-grey-6">No issued sales from this batch yet.</div>

    <template v-if="showUnpaid">
      <q-separator class="q-my-md" />
      <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Still owed on this batch</div>
      <q-table
        v-if="unpaidCustomers.length"
        flat
        bordered
        dense
        :rows="unpaidCustomers"
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
    </template>
  </ShipmentReportSectionShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type {
  ShipmentReportCustomerBillRow,
  ShipmentReportSellLine,
  ShipmentReportUnpaidCustomer,
} from '../../types/shipmentReportDetailTypes';
import ShipmentReportSectionShell from './ShipmentReportSectionShell.vue';

const props = defineProps<{
  customerBills: ShipmentReportCustomerBillRow[];
  sellLines: ShipmentReportSellLine[];
  unpaidCustomers: ShipmentReportUnpaidCustomer[];
  unpaidTotalBdt: number;
  canViewBills: boolean;
  billRoute: (billId: number) => string;
}>();

const showUnpaid = computed(() => props.unpaidTotalBdt > 0.009);

function formatMoney(amount: number | null | undefined, currencyCode: string) {
  return formatSettlementCurrencyAmount(amount, currencyCode);
}

const customerColumns: QTableColumn<ShipmentReportCustomerBillRow>[] = [
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'invoice_no', label: 'Bill no.', field: 'invoice_no', align: 'left' },
  { name: 'attributed_qty', label: 'Qty', field: 'attributed_qty', align: 'right' },
  { name: 'attributed_revenue_bdt', label: 'Revenue', field: 'attributed_revenue_bdt', align: 'right' },
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
.detail-table :deep(thead tr th) {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}
</style>