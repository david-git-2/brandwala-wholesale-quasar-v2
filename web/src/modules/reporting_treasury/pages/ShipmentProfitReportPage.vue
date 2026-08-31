<template>
  <q-page class="shipment-profit-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Compact Top Toolbar (Zero In-Page Header rule) -->
    <div class="bg-white border-bottom q-px-md q-py-xs shrink-0 shadow-xs">
      <div class="row items-center justify-between q-col-gutter-xs">
        <!-- Date Preset Filter Pills -->
        <div class="col-auto row items-center q-gutter-xs">
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'all'"
            :outline="preset !== 'all'"
            :color="preset === 'all' ? 'primary' : 'grey-7'"
            label="All Time"
            @click="setPreset('all')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'month'"
            :outline="preset !== 'month'"
            :color="preset === 'month' ? 'primary' : 'grey-7'"
            label="This Month"
            @click="setPreset('month')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'quarter'"
            :outline="preset !== 'quarter'"
            :color="preset === 'quarter' ? 'primary' : 'grey-7'"
            label="Last 90 Days"
            @click="setPreset('quarter')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'year'"
            :outline="preset !== 'year'"
            :color="preset === 'year' ? 'primary' : 'grey-7'"
            label="This Year"
            @click="setPreset('year')"
          />
          <q-btn
            dense
            size="sm"
            no-caps
            class="rounded-sq-btn text-weight-medium q-px-sm"
            :unelevated="preset === 'custom'"
            :outline="preset !== 'custom'"
            :color="preset === 'custom' ? 'primary' : 'grey-7'"
            label="Custom"
            @click="preset = 'custom'"
          />

          <!-- Custom Pickers inline -->
          <template v-if="preset === 'custom'">
            <q-input
              v-model="startDate"
              dense
              outlined
              type="date"
              class="compact-date-input bg-white"
            />
            <span class="text-caption text-grey-6">to</span>
            <q-input
              v-model="endDate"
              dense
              outlined
              type="date"
              class="compact-date-input bg-white"
            />
          </template>
        </div>

        <!-- Right Controls: Search, Export, Refresh -->
        <div class="col-auto row items-center q-gutter-x-xs">
          <q-input
            v-model="searchText"
            outlined
            rounded
            dense
            clearable
            placeholder="Search shipment or code..."
            class="dense-search-input bg-white"
            style="min-width: 220px"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="14px" />
            </template>
          </q-input>

          <q-btn
            outline
            dense
            size="sm"
            color="primary"
            icon="ph ph-file-csv"
            label="Export CSV"
            no-caps
            class="rounded-sq-btn q-px-sm text-weight-bold"
            :disable="isLoading || !shipments.length"
            @click="exportCsv"
          />

          <q-btn
            flat
            round
            dense
            size="sm"
            icon="ph ph-arrows-clockwise"
            color="grey-7"
            :loading="isFetching"
            @click="() => refetch()"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Error Banner -->
    <q-banner v-if="error" class="bg-negative text-white q-px-md q-py-xs shrink-0">
      {{ (error as Error).message }}
    </q-banner>

    <!-- Compact KPI Summary Bar -->
    <div class="bg-white border-bottom q-px-md q-py-xs shrink-0">
      <div class="row items-center justify-between wrap q-gutter-y-xs">
        <div class="row items-center q-gutter-x-lg wrap">
          <!-- Total Landed Cost -->
          <div class="row items-baseline q-gutter-x-xs">
            <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">Landed Cost:</span>
            <span class="text-subtitle2 text-weight-bolder text-grey-9 bw-tabular">
              {{ formatAmountBdt(summary?.total_landed_cost || 0) }}
            </span>
            <span class="text-caption text-grey-5">({{ summary?.total_inbound_units || 0 }} pcs)</span>
          </div>

          <q-separator vertical inset class="gt-xs" />

          <!-- Sold Revenue -->
          <div class="row items-baseline q-gutter-x-xs">
            <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">Billed Sales:</span>
            <span class="text-subtitle2 text-weight-bolder text-primary bw-tabular">
              {{ formatAmountBdt(summary?.total_gross_sold_revenue || 0) }}
            </span>
            <span class="text-caption text-grey-5">({{ summary?.total_net_sold_units || 0 }} sold)</span>
          </div>

          <q-separator vertical inset class="gt-xs" />

          <!-- Realized Profit -->
          <div class="row items-baseline q-gutter-x-xs">
            <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">Realized GP:</span>
            <span
              class="text-subtitle2 text-weight-bolder bw-tabular"
              :class="(summary?.total_realized_gross_profit || 0) >= 0 ? 'text-positive' : 'text-negative'"
            >
              {{ (summary?.total_realized_gross_profit || 0) >= 0 ? '+' : '' }}{{ formatAmountBdt(summary?.total_realized_gross_profit || 0) }}
            </span>
            <q-badge
              dense
              rounded
              class="q-ml-xs text-weight-bold"
              :color="(summary?.overall_realized_gp_margin_pct || 0) >= 0 ? 'green-1' : 'red-1'"
              :text-color="(summary?.overall_realized_gp_margin_pct || 0) >= 0 ? 'green-9' : 'red-9'"
            >
              {{ summary?.overall_realized_gp_margin_pct || 0 }}% GP
            </q-badge>
          </div>

          <q-separator vertical inset class="gt-xs" />

          <!-- Unsold Stock Value -->
          <div class="row items-baseline q-gutter-x-xs">
            <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">Unsold Inventory:</span>
            <span class="text-subtitle2 text-weight-bolder text-warning bw-tabular">
              {{ formatAmountBdt(summary?.total_unsold_stock_value || 0) }}
            </span>
          </div>

          <q-separator vertical inset class="gt-xs" />

          <!-- Damage Losses -->
          <div v-if="(summary?.total_damage_loss_value || 0) > 0" class="row items-baseline q-gutter-x-xs">
            <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size: 11px">Damage Loss:</span>
            <span class="text-subtitle2 text-weight-bolder text-negative bw-tabular">
              -{{ formatAmountBdt(summary?.total_damage_loss_value || 0) }}
            </span>
          </div>
        </div>

        <div class="text-caption text-grey-6 text-weight-medium">
          {{ summary?.total_shipments_count || 0 }} Batches
        </div>
      </div>
    </div>

    <!-- Main Table Container (Flex with Internal Scroll) -->
    <div class="table-scroll-container col-grow overflow-hidden q-pa-xs">
      <q-table
        flat
        dense
        :rows="shipments"
        :columns="columns"
        row-key="shipment_id"
        :loading="isLoading"
        :pagination="{ rowsPerPage: 50 }"
        class="compact-ops-table full-height bg-white"
        no-data-label="No shipment batches found for this period"
      >
        <template #body="props">
          <q-tr
            :props="props"
            class="cursor-pointer hover-row shipment-table-row"
            :class="`status-${props.row.shipment_status}`"
            @click="openShipmentDetail(props.row.shipment_id)"
          >
            <!-- Batch Name & Code -->
            <q-td key="shipment_name" :props="props">
              <div class="row items-center no-wrap q-gutter-x-xs">
                <q-avatar size="24px" square class="rounded-borders-sm" color="grey-3" text-color="grey-9" font-size="13px">
                  <q-icon name="ph ph-package" />
                </q-avatar>
                <div class="ellipsis" style="max-width: 220px">
                  <div class="text-weight-bold text-grey-9 ellipsis">{{ props.row.shipment_name }}</div>
                  <div class="text-caption text-grey-5 font-mono text-xxs">
                    ID #{{ props.row.shipment_id }}
                    <span v-if="props.row.shipment_code">• {{ props.row.shipment_code }}</span>
                  </div>
                </div>
              </div>
            </q-td>

            <!-- Status Badge -->
            <q-td key="shipment_status" :props="props">
              <span
                class="shipment-status-badge text-caption font-bold text-uppercase"
                :class="`shipment-status-${props.row.shipment_status}`"
              >
                {{ formatStatusName(props.row.shipment_status) }}
              </span>
            </q-td>

            <!-- Created / Received Date -->
            <q-td key="created_at" :props="props" class="bw-tabular text-grey-8">
              {{ formatDate(props.row.created_at) }}
            </q-td>

            <!-- Inbound Qty -->
            <q-td key="inbound_quantity" :props="props" class="bw-tabular text-right font-mono">
              {{ props.row.inbound_quantity.toLocaleString() }}
            </q-td>

            <!-- Total Landed Cost (BDT) -->
            <q-td key="total_landed_cost" :props="props" class="text-right text-weight-bold text-grey-9 bw-tabular font-mono">
              {{ formatAmountBdt(props.row.total_landed_cost) }}
            </q-td>

            <!-- Sold Qty & Progress Bar -->
            <q-td key="net_sold_quantity" :props="props" class="text-right bw-tabular">
              <div class="row items-center justify-end q-gutter-x-xs">
                <span class="font-mono text-grey-9 text-weight-medium">
                  {{ props.row.net_sold_quantity.toLocaleString() }}
                </span>
                <span class="text-caption text-grey-5">({{ props.row.batch_sold_pct }}%)</span>
              </div>
              <q-linear-progress
                :value="Math.min(1, props.row.batch_sold_pct / 100)"
                size="4px"
                rounded
                color="primary"
                track-color="grey-3"
                class="q-mt-2xs"
              />
            </q-td>

            <!-- Gross Sold Revenue -->
            <q-td key="gross_sold_revenue" :props="props" class="text-right text-weight-bold text-primary bw-tabular font-mono">
              {{ formatAmountBdt(props.row.gross_sold_revenue) }}
            </q-td>

            <!-- Realized Gross Profit & Margin -->
            <q-td key="realized_gross_profit" :props="props" class="text-right bw-tabular">
              <div
                class="text-weight-bolder font-mono"
                :class="props.row.realized_gross_profit >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ props.row.realized_gross_profit >= 0 ? '+' : '' }}{{ formatAmountBdt(props.row.realized_gross_profit) }}
              </div>
              <div class="text-xxs text-grey-6 text-weight-bold">
                {{ props.row.realized_gp_margin_pct }}% margin
              </div>
            </q-td>

            <!-- Unsold Stock Value -->
            <q-td key="unsold_stock_value" :props="props" class="text-right bw-tabular font-mono text-grey-8">
              <div>{{ formatAmountBdt(props.row.unsold_stock_value) }}</div>
              <div class="text-xxs text-grey-5">{{ props.row.sellable_stock_qty }} pcs left</div>
            </q-td>

            <!-- Row Actions -->
            <q-td key="actions" :props="props" class="text-right">
              <q-btn
                flat
                round
                dense
                size="sm"
                icon="ph ph-arrow-square-out"
                color="primary"
                @click.stop="openShipmentDetail(props.row.shipment_id)"
              >
                <q-tooltip>View SKU Breakdown</q-tooltip>
              </q-btn>
            </q-td>
          </q-tr>
        </template>
      </q-table>
    </div>

    <!-- SKU Breakdown Drill-Down Dialog -->
    <ShipmentProfitDetailDialog
      v-model="detailDialogOpen"
      :shipment-id="selectedShipmentId"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { QTableColumn } from 'quasar';
import { formatAmountBdt } from 'src/utils/currency';
import { useShipmentProfitReport } from '../composables/useShipmentProfitReport';
import ShipmentProfitDetailDialog from '../components/ShipmentProfitDetailDialog.vue';
import type { ShipmentProfitReportRow } from '../types/shipmentProfitTypes';

const {
  summary,
  shipments,
  isLoading,
  isFetching,
  error,
  preset,
  startDate,
  endDate,
  searchText,
  setPreset,
  exportCsv,
  refetch,
} = useShipmentProfitReport();

const detailDialogOpen = ref(false);
const selectedShipmentId = ref<number | null>(null);

function openShipmentDetail(shipmentId: number) {
  selectedShipmentId.value = shipmentId;
  detailDialogOpen.value = true;
}

function formatDate(iso: string) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function formatStatusName(status: string) {
  if (!status) return '—';
  return status.replace(/_/g, ' ');
}

const columns: QTableColumn<ShipmentProfitReportRow>[] = [
  { name: 'shipment_name', label: 'Shipment Batch', field: 'shipment_name', align: 'left', sortable: true },
  { name: 'shipment_status', label: 'Status', field: 'shipment_status', align: 'left', sortable: true },
  { name: 'created_at', label: 'Date', field: 'created_at', align: 'left', sortable: true },
  { name: 'inbound_quantity', label: 'Inbound Qty', field: 'inbound_quantity', align: 'right', sortable: true },
  { name: 'total_landed_cost', label: 'Landed Cost (BDT)', field: 'total_landed_cost', align: 'right', sortable: true },
  { name: 'net_sold_quantity', label: 'Sold Qty (% Batch)', field: 'net_sold_quantity', align: 'right', sortable: true },
  { name: 'gross_sold_revenue', label: 'Sold Revenue (BDT)', field: 'gross_sold_revenue', align: 'right', sortable: true },
  { name: 'realized_gross_profit', label: 'Realized GP (Margin)', field: 'realized_gross_profit', align: 'right', sortable: true },
  { name: 'unsold_stock_value', label: 'Unsold Val (Stock)', field: 'unsold_stock_value', align: 'right', sortable: true },
  { name: 'actions', label: '', field: 'shipment_id', align: 'right' },
];
</script>

<style scoped>
.rounded-sq-btn {
  border-radius: 8px !important;
}

.compact-date-input {
  width: 130px;
}

.dense-search-input :deep(.q-field__control) {
  height: 30px;
  min-height: 30px;
}

.shrink-0 {
  flex-shrink: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}

.table-scroll-container {
  display: flex;
  flex-direction: column;
}

.table-scroll-container :deep(.q-table__container) {
  height: 100%;
  display: flex;
  flex-direction: column;
  border-radius: 0;
  border: 1px solid #e2e8f0;
}

.table-scroll-container :deep(.q-table__middle) {
  flex: 1 1 auto;
  overflow-y: auto;
}

.table-scroll-container :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc;
  font-weight: 700;
  color: #475569;
  border-bottom: 2px solid #e2e8f0;
}

.hover-row:hover {
  background-color: #f8fafc;
}

/* Status High-Visibility Table Rows & Inset Left Bars */
.shipment-table-row.status-draft {
  background-color: #fffdf5;
  box-shadow: inset 3px 0 0 #f59e0b;
}

.shipment-table-row.status-in_transit,
.shipment-table-row.status-cargo_cleared {
  background-color: #fffbf7;
  box-shadow: inset 3px 0 0 #f97316;
}

.shipment-table-row.status-received,
.shipment-table-row.status-completed,
.shipment-table-row.status-stock_posted {
  background-color: #f6fcf8;
  box-shadow: inset 3px 0 0 #22c55e;
}

.shipment-table-row.status-cancelled {
  background-color: #fef7f7;
  box-shadow: inset 3px 0 0 #ef4444;
}

/* Status Badge */
.shipment-status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 11px;
  letter-spacing: 0.5px;
}

.shipment-status-draft {
  background: #fef3c7;
  color: #b45309;
  border: 1px solid #fde68a;
}

.shipment-status-in_transit,
.shipment-status-cargo_cleared {
  background: #ffedd5;
  color: #c2410c;
  border: 1px solid #fed7aa;
}

.shipment-status-received,
.shipment-status-completed,
.shipment-status-stock_posted {
  background: #dcfce7;
  color: #15803d;
  border: 1px solid #bbf7d0;
}

.shipment-status-cancelled {
  background: #fee2e2;
  color: #b91c1c;
  border: 1px solid #fecaca;
}

.font-bold {
  font-weight: 700;
}

.rounded-borders-sm {
  border-radius: 6px;
}
</style>
