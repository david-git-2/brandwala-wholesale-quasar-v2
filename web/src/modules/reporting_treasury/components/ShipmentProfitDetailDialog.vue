<template>
  <q-dialog
    :model-value="modelValue"
    position="right"
    transition-show="jump-left"
    transition-hide="jump-right"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <q-card
      class="column no-wrap bg-white q-ma-md rounded-borders-lg overflow-hidden shadow-10"
      style="width: 820px; max-width: 95vw; height: calc(100vh - 32px); border-radius: 16px"
    >
      <!-- Header -->
      <div class="row items-center justify-between q-px-md q-py-sm border-bottom bg-grey-1 shrink-0">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="32px" color="primary" text-color="white" icon="ph ph-package" font-size="18px" />
          <div>
            <div class="text-subtitle2 text-weight-bold text-grey-9">
              {{ shipment?.shipment_name || 'Shipment Batch Details' }}
            </div>
            <div class="text-caption text-grey-6 row items-center q-gutter-x-xs">
              <span>ID #{{ shipmentId }}</span>
              <span v-if="shipment?.shipment_code">• Code: {{ shipment.shipment_code }}</span>
              <span v-if="shipment?.created_at">• {{ formatDate(shipment.created_at) }}</span>
            </div>
          </div>
        </div>
        <div class="row items-center q-gutter-x-xs">
          <q-btn flat round dense icon="ph ph-x" color="grey-7" v-close-popup />
        </div>
      </div>

      <!-- Loading / Error -->
      <div v-if="isLoading" class="col column items-center justify-center q-pa-lg">
        <q-spinner color="primary" size="3em" />
        <div class="text-caption text-grey-6 q-mt-sm">Loading SKU breakdown...</div>
      </div>

      <div v-else-if="error" class="col column items-center justify-center q-pa-lg text-negative">
        <q-icon name="ph ph-warning-circle" size="3em" />
        <div class="text-body2 text-weight-bold q-mt-sm">Failed to load shipment details</div>
        <div class="text-caption">{{ error.message }}</div>
      </div>

      <!-- Main Content -->
      <div v-else class="col column no-wrap overflow-hidden bg-grey-1">
        <!-- Top Metrics Cards -->
        <div class="q-pa-sm grid-metrics shrink-0">
          <div class="metric-card">
            <span class="metric-label">Landed Cost</span>
            <span class="metric-val text-grey-9">{{ formatAmountBdt(shipment?.total_landed_cost || 0) }}</span>
            <span class="metric-sub">{{ shipment?.inbound_quantity || 0 }} inbound pcs</span>
          </div>

          <div class="metric-card">
            <span class="metric-label">Sold Revenue</span>
            <span class="metric-val text-primary">{{ formatAmountBdt(shipment?.gross_sold_revenue || 0) }}</span>
            <span class="metric-sub">{{ shipment?.net_sold_quantity || 0 }} sold pcs ({{ shipment?.batch_sold_pct || 0 }}%)</span>
          </div>

          <div class="metric-card">
            <span class="metric-label">Realized Profit</span>
            <span
              class="metric-val"
              :class="(shipment?.realized_gross_profit || 0) >= 0 ? 'text-positive' : 'text-negative'"
            >
              {{ (shipment?.realized_gross_profit || 0) >= 0 ? '+' : '' }}{{ formatAmountBdt(shipment?.realized_gross_profit || 0) }}
            </span>
            <span class="metric-sub">{{ shipment?.realized_gp_margin_pct || 0 }}% margin</span>
          </div>

          <div class="metric-card">
            <span class="metric-label">Unsold Valuation</span>
            <span class="metric-val text-warning">{{ formatAmountBdt(shipment?.unsold_stock_value || 0) }}</span>
            <span class="metric-sub">{{ shipment?.sellable_stock_qty || 0 }} sellable pcs</span>
          </div>
        </div>

        <!-- SKU Items Table Container -->
        <div class="col-grow overflow-hidden q-px-sm q-pb-sm">
          <q-table
            flat
            dense
            :rows="items"
            :columns="itemColumns"
            row-key="item_id"
            :pagination="{ rowsPerPage: 50 }"
            class="compact-ops-table full-height bg-white rounded-borders border-grey"
            no-data-label="No line items found for this shipment"
          >
            <template #body="props">
              <q-tr :props="props">
                <!-- SKU / Product Name -->
                <q-td key="product_name" :props="props">
                  <div class="text-weight-bold text-grey-9 text-truncate" style="max-width: 220px">
                    {{ props.row.product_name }}
                  </div>
                  <div v-if="props.row.barcode" class="text-caption text-grey-6 font-mono">
                    {{ props.row.barcode }}
                  </div>
                </q-td>

                <!-- Inbound Qty -->
                <q-td key="inbound_qty" :props="props" class="bw-tabular text-right font-mono">
                  {{ props.row.inbound_qty }}
                </q-td>

                <!-- Unit Cost (BDT) -->
                <q-td key="unit_cost_bdt" :props="props" class="bw-tabular text-right font-mono">
                  {{ formatAmountBdt(props.row.unit_cost_bdt || 0) }}
                </q-td>

                <!-- Net Sold Qty -->
                <q-td key="sold_qty" :props="props" class="bw-tabular text-right font-mono">
                  {{ props.row.sold_qty }}
                </q-td>

                <!-- Sold Revenue -->
                <q-td key="sold_revenue" :props="props" class="bw-tabular text-right font-mono text-primary font-bold">
                  {{ formatAmountBdt(props.row.sold_revenue || 0) }}
                </q-td>

                <!-- Gross Profit -->
                <q-td
                  key="gross_profit"
                  :props="props"
                  class="bw-tabular text-right font-mono font-bold"
                  :class="props.row.gross_profit >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ props.row.gross_profit >= 0 ? '+' : '' }}{{ formatAmountBdt(props.row.gross_profit || 0) }}
                </q-td>

                <!-- Sellable Qty -->
                <q-td key="sellable_qty" :props="props" class="bw-tabular text-right font-mono">
                  <span :class="props.row.sellable_qty > 0 ? 'text-grey-9' : 'text-grey-4'">
                    {{ props.row.sellable_qty }}
                  </span>
                </q-td>

                <!-- Unsold Stock Value -->
                <q-td key="unsold_stock_value" :props="props" class="bw-tabular text-right font-mono text-grey-8">
                  {{ formatAmountBdt(props.row.unsold_stock_value || 0) }}
                </q-td>

                <!-- Damaged Qty / Loss -->
                <q-td key="damaged_qty" :props="props" class="bw-tabular text-right font-mono">
                  <span v-if="props.row.damaged_qty > 0" class="text-negative font-bold">
                    {{ props.row.damaged_qty }} ({{ formatAmountBdt(props.row.damage_loss_value) }})
                  </span>
                  <span v-else class="text-grey-4">—</span>
                </q-td>
              </q-tr>
            </template>
          </q-table>
        </div>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';
import { formatAmountBdt } from 'src/utils/currency';
import { useShipmentProfitDetail } from '../composables/useShipmentProfitReport';
import type { ShipmentProfitReportItem } from '../types/shipmentProfitTypes';

const props = defineProps<{
  modelValue: boolean;
  shipmentId: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const { shipment, items, isLoading, error } = useShipmentProfitDetail(() => props.shipmentId);

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

const itemColumns: QTableColumn<ShipmentProfitReportItem>[] = [
  { name: 'product_name', label: 'Item / Barcode', field: 'product_name', align: 'left', sortable: true },
  { name: 'inbound_qty', label: 'Inbound', field: 'inbound_qty', align: 'right', sortable: true },
  { name: 'unit_cost_bdt', label: 'Unit Cost', field: 'unit_cost_bdt', align: 'right', sortable: true },
  { name: 'sold_qty', label: 'Sold', field: 'sold_qty', align: 'right', sortable: true },
  { name: 'sold_revenue', label: 'Revenue', field: 'sold_revenue', align: 'right', sortable: true },
  { name: 'gross_profit', label: 'Realized GP', field: 'gross_profit', align: 'right', sortable: true },
  { name: 'sellable_qty', label: 'Unsold', field: 'sellable_qty', align: 'right', sortable: true },
  { name: 'unsold_stock_value', label: 'Unsold Val', field: 'unsold_stock_value', align: 'right', sortable: true },
  { name: 'damaged_qty', label: 'Damage', field: 'damaged_qty', align: 'right', sortable: true },
];
</script>

<style scoped>
.shrink-0 {
  flex-shrink: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}

.border-grey {
  border: 1px solid #e2e8f0;
}

.grid-metrics {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}

.metric-card {
  background: #ffffff;
  padding: 8px 12px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
}

.metric-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  color: #64748b;
  letter-spacing: 0.5px;
}

.metric-val {
  font-size: 15px;
  font-weight: 800;
  font-family: monospace;
}

.metric-sub {
  font-size: 10px;
  color: #94a3b8;
  margin-top: 2px;
}

.compact-ops-table :deep(.q-table__container) {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.compact-ops-table :deep(.q-table__middle) {
  flex: 1 1 auto;
  overflow-y: auto;
}

.compact-ops-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc;
  font-weight: 700;
  color: #475569;
  border-bottom: 2px solid #e2e8f0;
}

.font-bold {
  font-weight: 700;
}
</style>
