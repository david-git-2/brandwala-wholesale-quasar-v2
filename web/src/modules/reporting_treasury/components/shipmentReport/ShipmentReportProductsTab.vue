<template>
  <q-table
    v-if="rows.length"
    flat
    bordered
    dense
    :rows="rows"
    :columns="columns"
    row-key="item_id"
    hide-pagination
    :pagination="{ rowsPerPage: 0 }"
    class="detail-table"
  >
    <template #body-cell-product_name="props">
      <q-td :props="props" class="text-weight-medium">{{ props.row.product_name }}</q-td>
    </template>
    <template #body-cell-margin_pct="props">
      <q-td :props="props" class="tf-num text-right">
        <div class="row items-center justify-end no-wrap q-gutter-x-xs">
          <div class="margin-bar">
            <div
              class="margin-bar__fill"
              :style="{ width: `${Math.min(100, Math.max(0, props.row.margin_pct))}%` }"
            />
          </div>
          <span>{{ props.row.margin_pct.toFixed(1) }}%</span>
        </div>
      </q-td>
    </template>
    <template #body-cell-unit_cost_bdt="props">
      <q-td :props="props" class="tf-num text-right">
        {{ formatMoney(props.row.unit_cost_bdt, 'BDT') }}
      </q-td>
    </template>
    <template #body-cell-sold_revenue="props">
      <q-td :props="props" class="tf-num text-right">
        {{ formatMoney(props.row.sold_revenue, 'BDT') }}
      </q-td>
    </template>
    <template #body-cell-gross_profit="props">
      <q-td
        :props="props"
        class="tf-num text-right"
        :class="props.row.gross_profit >= 0 ? 'text-positive' : 'text-negative'"
      >
        {{ formatMoney(props.row.gross_profit, 'BDT') }}
      </q-td>
    </template>
  </q-table>
  <div v-else class="text-caption" style="color: var(--tf-neutral-muted)">No products on this batch.</div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ShipmentProfitReportItem } from '../../types/shipmentProfitTypes';

const props = defineProps<{
  items?: ShipmentProfitReportItem[] | null;
}>();

function formatMoney(amount: number | null | undefined, currencyCode: string) {
  return formatSettlementCurrencyAmount(amount, currencyCode);
}

interface ProductRow extends ShipmentProfitReportItem {
  lost_qty: number;
  left_qty: number;
  margin_pct: number;
}

const rows = computed((): ProductRow[] =>
  (props.items ?? []).map((item) => {
    const left = item.sellable_qty ?? 0;
    const lost = Math.max(0, item.inbound_qty - item.sold_qty - left - (item.damaged_qty ?? 0))
      + (item.damaged_qty ?? 0);
    const margin_pct =
      item.sold_revenue > 0 ? (item.gross_profit / item.sold_revenue) * 100 : 0;
    return { ...item, lost_qty: lost, left_qty: left, margin_pct };
  }),
);

const columns: QTableColumn<ProductRow>[] = [
  { name: 'product_name', label: 'Product', field: 'product_name', align: 'left' },
  { name: 'inbound_qty', label: 'Ordered', field: 'inbound_qty', align: 'right' },
  { name: 'sold_qty', label: 'Sold', field: 'sold_qty', align: 'right' },
  { name: 'lost_qty', label: 'Lost', field: 'lost_qty', align: 'right' },
  { name: 'left_qty', label: 'Left', field: 'left_qty', align: 'right' },
  { name: 'unit_cost_bdt', label: 'Unit cost', field: 'unit_cost_bdt', align: 'right' },
  { name: 'sold_revenue', label: 'Sales', field: 'sold_revenue', align: 'right' },
  { name: 'gross_profit', label: 'Profit', field: 'gross_profit', align: 'right' },
  { name: 'margin_pct', label: 'Margin', field: 'margin_pct', align: 'right' },
];
</script>

<style scoped>
.detail-table :deep(thead tr th) {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text);
}

.margin-bar {
  width: 48px;
  height: 6px;
  border-radius: 2px;
  background: var(--tf-neutral-subtle);
  border: 1px solid var(--tf-neutral-border);
  overflow: hidden;
}

.margin-bar__fill {
  height: 100%;
  background: var(--tf-positive-soft);
}
</style>