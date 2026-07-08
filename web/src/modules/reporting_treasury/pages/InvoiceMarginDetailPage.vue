<template>
  <TreasuryPageShell
    :title="`Invoice Margin Details: ${invoice?.invoice_no || '#' + id}`"
    subtitle="Analyze line-item costs, sell prices, discounts, returns, and gross profit breakdown for this invoice."
    :error="error"
  >
    <template #action>
      <q-btn flat dense no-caps icon="arrow_back" label="Back to Margin Reports" @click="goBack" />
    </template>

    <!-- Loading spinner -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else-if="invoice" class="q-gutter-y-lg">
      <!-- Stats Grid -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Invoice Info Card -->
      <q-card flat bordered class="q-pa-md bg-white">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6 col-md-3">
            <div class="text-caption text-grey-6">Invoice Number</div>
            <div class="text-subtitle1 text-weight-bold text-primary">{{ invoice.invoice_no }}</div>
          </div>
          <div class="col-12 col-sm-6 col-md-3">
            <div class="text-caption text-grey-6">Customer / Recipient</div>
            <div class="text-subtitle1 text-weight-bold">
              {{ invoice.recipient_name || 'Walk-in / Direct' }}
            </div>
            <div v-if="invoice.recipient_phone" class="text-caption text-grey-6">
              {{ invoice.recipient_phone }}
            </div>
          </div>
          <div class="col-12 col-sm-6 col-md-3">
            <div class="text-caption text-grey-6">Invoice Date</div>
            <div class="text-subtitle1 text-weight-bold">{{ invoice.invoice_date }}</div>
          </div>
          <div class="col-12 col-sm-6 col-md-3">
            <div class="text-caption text-grey-6">Type / Status</div>
            <div class="row q-gutter-xs items-center q-mt-xs">
              <q-chip
                dense
                square
                color="blue-1"
                text-color="blue-9"
                class="text-weight-bold text-uppercase text-xs m-0"
              >
                {{ invoice.invoice_type }}
              </q-chip>
              <q-chip
                dense
                square
                color="green-1"
                text-color="green-9"
                class="text-weight-bold text-uppercase text-xs m-0"
              >
                {{ invoice.invoice_status }}
              </q-chip>
              <q-chip
                dense
                square
                color="orange-1"
                text-color="orange-9"
                class="text-weight-bold text-uppercase text-xs m-0"
              >
                {{ invoice.payment_status }}
              </q-chip>
            </div>
          </div>
        </div>
      </q-card>

      <!-- Line Items Details Table -->
      <q-card flat bordered class="q-pa-md bg-white">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
          Line Item Costs &amp; Margins
        </div>

        <TreasuryTableWrap>
          <q-table
            flat
            row-key="id"
            :rows="lines"
            :columns="lineColumns"
            :pagination="{ rowsPerPage: 50 }"
            :dense="$q.screen.lt.md"
            table-style="min-width: 1000px;"
          >
            <template #body-cell-name_snapshot="props">
              <q-td :props="props" class="text-weight-bold">
                {{ props.row.name_snapshot }}
              </q-td>
            </template>

            <template #body-cell-quantity="props">
              <q-td :props="props" class="text-right">
                {{ props.row.quantity }}
              </q-td>
            </template>

            <template #body-cell-unit_cost_price="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{ formatAmountBdt(props.row.unit_cost_price) }}
              </q-td>
            </template>

            <template #body-cell-total_cost="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{ formatAmountBdt(props.row.unit_cost_price * props.row.quantity) }}
              </q-td>
            </template>

            <template #body-cell-sell_price_amount="props">
              <q-td :props="props" class="text-right">
                {{ formatAmountBdt(props.row.sell_price_amount) }}
              </q-td>
            </template>

            <template #body-cell-line_discount_amount="props">
              <q-td :props="props" class="text-right text-negative">
                {{
                  props.row.line_discount_amount > 0
                    ? `-${formatAmountBdt(props.row.line_discount_amount)}`
                    : '-'
                }}
              </q-td>
            </template>

            <template #body-cell-line_total_amount="props">
              <q-td :props="props" class="text-right text-weight-bold">
                {{
                  formatAmountBdt(
                    props.row.sell_price_amount * props.row.quantity -
                      props.row.line_discount_amount,
                  )
                }}
              </q-td>
            </template>

            <template #body-cell-line_margin="props">
              <q-td :props="props" class="text-right text-weight-bold text-primary">
                {{ formatAmountBdt(props.row.line_margin) }}
              </q-td>
            </template>

            <template #body-cell-margin_pct="props">
              <q-td
                :props="props"
                class="text-right text-weight-bold"
                :class="
                  getMarginClass(
                    props.row.line_margin,
                    props.row.sell_price_amount * props.row.quantity,
                  )
                "
              >
                {{
                  formatPercent(
                    props.row.line_margin,
                    props.row.sell_price_amount * props.row.quantity,
                  )
                }}
              </q-td>
            </template>
          </q-table>
        </TreasuryTableWrap>
      </q-card>

      <!-- Returns Details Table -->
      <q-card v-if="returns && returns.length > 0" flat bordered class="q-pa-md bg-white">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-negative">
          Returns cost reversal &amp; loss adjustment
        </div>

        <TreasuryTableWrap>
          <q-table
            flat
            row-key="id"
            :rows="returns"
            :columns="returnColumns"
            :pagination="{ rowsPerPage: 50 }"
            :dense="$q.screen.lt.md"
            table-style="min-width: 900px;"
          >
            <template #body-cell-item_name="props">
              <q-td :props="props" class="text-weight-bold">
                {{ getItemName(props.row.invoice_item_id) }}
              </q-td>
            </template>

            <template #body-cell-quantity="props">
              <q-td :props="props" class="text-right">
                {{ props.row.quantity }}
              </q-td>
            </template>

            <template #body-cell-unit_cost_price="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{ formatAmountBdt(getItemUnitCost(props.row.invoice_item_id)) }}
              </q-td>
            </template>

            <template #body-cell-total_cost_reversal="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{
                  formatAmountBdt(getItemUnitCost(props.row.invoice_item_id) * props.row.quantity)
                }}
              </q-td>
            </template>

            <template #body-cell-return_accounting_amount="props">
              <q-td :props="props" class="text-right text-negative">
                {{ formatAmountBdt(props.row.return_accounting_amount) }}
              </q-td>
            </template>

            <template #body-cell-return_margin="props">
              <q-td :props="props" class="text-right text-weight-bold text-negative">
                {{ formatAmountBdt(props.row.return_margin) }}
              </q-td>
            </template>

            <template #body-cell-return_reason="props">
              <q-td :props="props" class="text-left text-grey-7">
                {{ props.row.return_reason || '-' }}
              </q-td>
            </template>
          </q-table>
        </TreasuryTableWrap>
      </q-card>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { treasuryRepository } from '../repositories/treasuryRepository';
import TreasuryPageShell from '../components/TreasuryPageShell.vue';
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue';
import TreasuryTableWrap from '../components/TreasuryTableWrap.vue';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const id = Number(route.params.id);
const loading = ref(false);
const error = ref<string | null>(null);

const invoice = ref<any>(null);
const lines = ref<any[]>([]);
const returns = ref<any[]>([]);
const grossProfit = ref(0);

const lineColumns: QTableColumn[] = [
  {
    name: 'name_snapshot',
    label: 'Product / Item Name',
    field: 'name_snapshot',
    align: 'left',
    sortable: true,
  },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right', sortable: true },
  {
    name: 'unit_cost_price',
    label: 'Landed Unit Cost',
    field: 'unit_cost_price',
    align: 'right',
    sortable: true,
  },
  { name: 'total_cost', label: 'Total Landed Cost', field: 'id', align: 'right' },
  {
    name: 'sell_price_amount',
    label: 'Unit Sell Price',
    field: 'sell_price_amount',
    align: 'right',
    sortable: true,
  },
  {
    name: 'line_discount_amount',
    label: 'Line Discount',
    field: 'line_discount_amount',
    align: 'right',
    sortable: true,
  },
  { name: 'line_total_amount', label: 'Line Total (Net)', field: 'id', align: 'right' },
  { name: 'line_margin', label: 'Line GP', field: 'line_margin', align: 'right', sortable: true },
  { name: 'margin_pct', label: 'GP %', field: 'id', align: 'right' },
];

const returnColumns: QTableColumn[] = [
  { name: 'item_name', label: 'Returned Product', field: 'invoice_item_id', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
  { name: 'unit_cost_price', label: 'Landed Unit Cost', field: 'invoice_item_id', align: 'right' },
  {
    name: 'total_cost_reversal',
    label: 'Landed Cost Reversal',
    field: 'invoice_item_id',
    align: 'right',
  },
  {
    name: 'return_accounting_amount',
    label: 'Refund/Reversal Amt',
    field: 'return_accounting_amount',
    align: 'right',
  },
  { name: 'return_margin', label: 'Return Profit Impact', field: 'return_margin', align: 'right' },
  { name: 'return_reason', label: 'Reason', field: 'return_reason', align: 'left' },
];

// Calculate total charges
const chargesAmount = computed(() => {
  if (!invoice.value) return 0;
  const type = invoice.value.invoice_type;
  if (type === 'wholesale' || type === 'dropship') {
    return Number(invoice.value.shipping_charge || 0);
  } else if (type === 'retail') {
    return (
      Number(invoice.value.shipping_charge || 0) +
      Number(invoice.value.cod_charge || 0) +
      Number(invoice.value.print_charge || 0) +
      Number(invoice.value.wrapping_charge || 0)
    );
  }
  return 0;
});

const statCards = computed<
  {
    label: string;
    value: number | string;
    caption?: string;
    class?: string;
    valueClass?: string;
    format?: 'currency' | 'percent' | 'number' | 'text';
  }[]
>(() => [
  {
    label: 'Invoice Total',
    value: invoice.value?.total_amount || 0,
    caption: 'Total amount including charges',
    class: 'col-12 col-sm-6 col-md-2',
  },
  {
    label: 'Paid Amount',
    value: invoice.value?.paid_amount || 0,
    caption: 'Total payments applied',
    valueClass: 'text-positive',
    class: 'col-12 col-sm-6 col-md-2',
  },
  {
    label: 'Outstanding Due',
    value: invoice.value?.due_amount || 0,
    caption: 'Unpaid remaining balance',
    valueClass: invoice.value?.due_amount > 0 ? 'text-negative text-weight-bold' : 'text-grey-6',
    class: 'col-12 col-sm-6 col-md-2',
  },
  {
    label: 'Total Charges',
    value: chargesAmount.value,
    caption: 'Shipping / COD / Print / Wrap',
    class: 'col-12 col-sm-6 col-md-2',
  },
  {
    label: 'Gross Profit',
    value: grossProfit.value,
    caption: 'Gross Profit including charges',
    valueClass: 'text-primary',
    class: 'col-12 col-sm-6 col-md-2',
  },
  {
    label: 'GP %',
    value: formatPercent(grossProfit.value, invoice.value?.total_amount || 0),
    caption: 'Gross profit ÷ invoice total',
    format: 'text',
    valueClass: getMarginClass(grossProfit.value, invoice.value?.total_amount || 0),
    class: 'col-12 col-sm-6 col-md-2',
  },
]);

const loadDetail = async () => {
  loading.value = true;
  error.value = null;
  try {
    const res = await treasuryRepository.getInvoiceMarginDetail(id);
    invoice.value = res.invoice;
    lines.value = res.lines || [];
    returns.value = res.returns || [];
    grossProfit.value = res.gross_profit || 0;
  } catch (err: any) {
    error.value = err.message;
    $q.notify({
      type: 'negative',
      message: `Failed to load invoice margin detail: ${err.message}`,
    });
  } finally {
    loading.value = false;
  }
};

const getItemName = (invoiceItemId: number) => {
  const line = lines.value.find((l) => l.id === invoiceItemId);
  return line ? line.name_snapshot : 'Unknown Item';
};

const getItemUnitCost = (invoiceItemId: number) => {
  const line = lines.value.find((l) => l.id === invoiceItemId);
  return line ? Number(line.unit_cost_price || 0) : 0;
};

const getMarginClass = (profit: number, total: number) => {
  if (total <= 0) return 'text-grey-6';
  const pct = (profit / total) * 100;
  if (pct >= 40) return 'text-positive';
  if (pct >= 20) return 'text-primary';
  if (pct >= 0) return 'text-warning';
  return 'text-negative';
};

const formatPercent = (profit: number, total: number) => {
  if (total <= 0) return '0.0%';
  const pct = (profit / total) * 100;
  return `${pct.toFixed(1)}%`;
};

const goBack = () => {
  void router.push({
    name: 'app-finance-invoices-page',
    params: { tenantSlug: authStore.tenantSlug ?? undefined },
  });
};

onMounted(() => {
  void loadDetail();
});
</script>
