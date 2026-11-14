<template>
  <ShipmentReportSectionShell title="Pieces">
    <div class="row q-col-gutter-sm">
      <div
        v-for="stat in mainStats"
        :key="stat.key"
        class="col-12 col-sm"
      >
        <ShipmentReportStatTile
          :label="stat.label"
          :value="String(stat.value)"
          :emphasis="stat.emphasis"
        />
      </div>
    </div>
    <div class="row justify-end q-mt-sm q-mb-sm">
      <div class="text-caption text-grey-7 tf-num text-right">
        Sold {{ soldPct }}% of batch
        <span v-if="warehouseCaption"> · {{ warehouseCaption }}</span>
      </div>
    </div>

    <q-table
      v-if="skuRows.length"
      flat
      bordered
      dense
      :rows="skuRows"
      :columns="skuColumns"
      row-key="item_id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="detail-table"
    >
      <template #body-cell-inbound_qty="props">
        <q-td :props="props" class="tf-num text-right">{{ props.row.inbound_qty }}</q-td>
      </template>
      <template #body-cell-sold_qty="props">
        <q-td :props="props" class="tf-num text-right">{{ props.row.sold_qty }}</q-td>
      </template>
      <template #body-cell-sellable_qty="props">
        <q-td :props="props" class="tf-num text-right">{{ props.row.sellable_qty }}</q-td>
      </template>
      <template #body-cell-damaged_qty="props">
        <q-td :props="props" class="tf-num text-right">{{ props.row.damaged_qty }}</q-td>
      </template>
    </q-table>
  </ShipmentReportSectionShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { QTableColumn } from 'quasar';
import type { ShipmentReportQtySummary } from '../../types/shipmentReportDetailTypes';
import type { ShipmentProfitReportItem } from '../../types/shipmentProfitTypes';
import ShipmentReportSectionShell from './ShipmentReportSectionShell.vue';
import ShipmentReportStatTile from './ShipmentReportStatTile.vue';

const props = defineProps<{
  qty: ShipmentReportQtySummary;
  items?: ShipmentProfitReportItem[] | null;
}>();

const mainStats = computed(() => [
  { key: 'ordered', label: 'Ordered', value: props.qty.should_arrive, emphasis: 'default' as const },
  { key: 'arrived', label: 'Arrived', value: props.qty.arrived, emphasis: 'default' as const },
  {
    key: 'missing',
    label: 'Missing',
    value: props.qty.loss_at_shipment,
    emphasis: props.qty.loss_at_shipment > 0 ? ('negative' as const) : ('default' as const),
  },
  { key: 'sold', label: 'Sold', value: props.qty.sold, emphasis: 'default' as const },
  {
    key: 'warehouse',
    label: 'Still in warehouse',
    value: props.qty.warehouse_remaining + props.qty.warehouse_stalled,
    emphasis: 'default' as const,
  },
]);

const soldPct = computed(() => {
  if (props.qty.should_arrive <= 0) return '0';
  return ((props.qty.sold / props.qty.should_arrive) * 100).toFixed(1);
});

const warehouseCaption = computed(() => {
  const parts: string[] = [];
  if (props.qty.warehouse_stalled > 0) parts.push(`${props.qty.warehouse_stalled} held`);
  if (props.qty.warehouse_remaining > 0) parts.push(`${props.qty.warehouse_remaining} in warehouse`);
  return parts.join(', ');
});

const skuRows = computed(() => props.items ?? []);

const skuColumns: QTableColumn<ShipmentProfitReportItem>[] = [
  { name: 'product_name', label: 'Product', field: 'product_name', align: 'left' },
  { name: 'inbound_qty', label: 'Ordered', field: 'inbound_qty', align: 'right' },
  { name: 'sold_qty', label: 'Sold', field: 'sold_qty', align: 'right' },
  { name: 'sellable_qty', label: 'Still sellable', field: 'sellable_qty', align: 'right' },
  { name: 'damaged_qty', label: 'Damage', field: 'damaged_qty', align: 'right' },
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
</style>