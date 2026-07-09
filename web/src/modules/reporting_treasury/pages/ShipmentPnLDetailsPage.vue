<template>
  <q-page class="q-pa-xs q-sm-pa-md pnl-page">
    <!-- Loading spinner -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <!-- Error Banner -->
    <div v-else-if="error" class="bg-negative text-white q-pa-sm rounded-borders q-mb-md">
      {{ error }}
    </div>

    <div v-else-if="shipment" class="q-gutter-y-sm" style="min-width: 0">
      <!-- Hero Header Card -->
      <q-card flat class="q-mb-sm q-sm-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm">
              <div class="row items-center q-gutter-sm">
                <q-badge color="primary" outline class="text-weight-bold">
                  #{{ id }}
                </q-badge>
                <div class="text-subtitle1 text-weight-bold">
                  Shipment P&amp;L: {{ shipment.name || 'Unnamed Shipment' }}
                </div>
              </div>
            </div>
            <div class="col-12 col-sm-auto row items-center q-gutter-sm justify-start justify-sm-end q-mt-xs q-mt-sm-none wrap">
              <!-- Type Chip -->
              <q-chip
                v-if="shipment.type"
                dense
                square
                color="blue-1"
                text-color="blue-9"
                class="text-weight-bold text-uppercase text-xs"
              >
                {{ shipment.type }}
              </q-chip>
              <!-- Status Chip -->
              <q-chip
                dense
                square
                :style="statusChipStyle(shipment.status)"
                class="costing-file-status-chip q-px-md q-py-sm header-status-chip text-weight-bold"
              >
                <span
                  class="status-chip-dot"
                  :style="{ backgroundColor: statusDotColor(shipment.status) }"
                />
                {{ shipment.status }}
              </q-chip>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Search Filter Card -->
      <q-card flat class="q-mb-xs q-sm-mb-sm floating-surface shadow-1">
        <q-card-section class="q-py-xs">
          <div class="row items-center q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                v-model="search"
                placeholder="Search items by name or ID..."
                dense
                outlined
                clearable
                class="soft-input"
              >
                <template #append>
                  <q-icon name="search" />
                </template>
              </q-input>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Stats Row -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Tabbed P&L Tables -->
      <q-card flat class="overflow-hidden floating-surface shadow-1" style="min-width: 0">
        <q-tabs
          v-model="activeTable"
          dense
          align="left"
          active-color="primary"
          indicator-color="primary"
          class="text-grey-7"
        >
          <q-tab name="trading" label="Trading Cost & Profit" />
          <q-tab name="disposition" label="Stock Disposition & Shrinkage" />
        </q-tabs>
        <q-separator />

        <q-tab-panels v-model="activeTable" animated>
          <q-tab-panel name="trading" class="q-pa-md">
            <q-table
          flat
          v-model:pagination="pagination"
          :rows-per-page-options="[0]"
          row-key="id"
          :rows="filteredItems"
          :columns="tradingColumns"
          :dense="$q.screen.lt.md"
          class="pnl-sticky-table"
          table-style="min-width: 1100px;"
        >
            <template #body-cell-id="props">
              <q-td :props="props" class="font-mono text-grey-6 text-sm">
                #{{ props.row.id }}
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="text-weight-bold">
                {{ props.row.name }}
              </q-td>
            </template>

            <template #body-cell-ordered_quantity="props">
              <q-td :props="props" class="text-right">
                {{ props.row.ordered_quantity }}
              </q-td>
            </template>

            <template #body-cell-landed_unit_cost="props">
              <q-td :props="props" class="text-right">
                {{ formatAmountBdt(props.row.landed_unit_cost) }}
              </q-td>
            </template>

            <template #body-cell-total_landed_cost="props">
              <q-td :props="props" class="text-right">
                {{ formatAmountBdt(props.row.landed_unit_cost * props.row.ordered_quantity) }}
              </q-td>
            </template>

            <template #body-cell-sold_qty="props">
              <q-td :props="props" class="text-right text-primary text-weight-bold">
                {{ props.row.sold_qty }}
              </q-td>
            </template>

            <template #body-cell-sold_cost="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{ formatAmountBdt(props.row.sold_cost) }}
              </q-td>
            </template>

            <template #body-cell-revenue="props">
              <q-td :props="props" class="text-right text-positive">
                {{ formatAmountBdt(props.row.revenue) }}
              </q-td>
            </template>

            <template #body-cell-gross_profit="props">
              <q-td :props="props" class="text-right text-weight-bold text-primary">
                {{ formatAmountBdt(props.row.revenue - props.row.sold_cost) }}
              </q-td>
            </template>

            <template #bottom-row>
              <q-tr class="text-weight-bold bg-grey-1 text-right">
                <q-td class="text-left" colspan="2">TOTAL</q-td>
                <q-td class="bg-blue-highlight">{{ tradingTotals.receivedQty }}</q-td>
                <q-td class="bg-orange-highlight">{{ formatAmountBdt(tradingTotals.avgLandedUnitCost) }}</q-td>
                <q-td class="bg-orange-highlight">{{ formatAmountBdt(tradingTotals.totalLandedCost) }}</q-td>
                <q-td class="bg-blue-highlight text-primary">{{ tradingTotals.soldQty }}</q-td>
                <q-td class="bg-orange-highlight text-grey-8">{{ formatAmountBdt(tradingTotals.soldCost) }}</q-td>
                <q-td class="bg-green-highlight text-positive">{{ formatAmountBdt(tradingTotals.revenue) }}</q-td>
                <q-td class="bg-green-highlight text-primary">{{ formatAmountBdt(tradingTotals.grossProfit) }}</q-td>
              </q-tr>
            </template>
        </q-table>
          </q-tab-panel>

          <q-tab-panel name="disposition" class="q-pa-md">
            <div class="row items-center justify-end q-mb-md">
              <q-badge
                v-if="!totals.disposition_available"
                color="warning"
                label="Stock not received — disposition unavailable"
              />
            </div>

            <q-table
          flat
          v-model:pagination="pagination"
          :rows-per-page-options="[0]"
          row-key="id"
          :rows="filteredItems"
          :columns="dispositionColumns"
          :dense="$q.screen.lt.md"
          class="pnl-sticky-table"
          table-style="min-width: 1000px;"
        >
            <template #body-cell-id="props">
              <q-td :props="props" class="font-mono text-grey-6 text-sm">
                #{{ props.row.id }}
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="text-weight-bold">
                {{ props.row.name }}
              </q-td>
            </template>

            <template #body-cell-sellable_qty="props">
              <q-td :props="props" class="text-right text-weight-bold text-warning">
                {{ props.row.sellable_qty }}
              </q-td>
            </template>

            <template #body-cell-sellable_value="props">
              <q-td :props="props" class="text-right text-weight-bold text-warning">
                {{ formatAmountBdt(props.row.sellable_value) }}
              </q-td>
            </template>

            <template #body-cell-box_damage_qty="props">
              <q-td :props="props" class="text-right">
                {{ props.row.box_damage_qty }}
              </q-td>
            </template>

            <template #body-cell-box_damage_value="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{ formatAmountBdt(props.row.box_damage_value) }}
              </q-td>
            </template>

            <template #body-cell-stolen_qty="props">
              <q-td :props="props" class="text-right">
                {{ props.row.stolen_qty }}
              </q-td>
            </template>

            <template #body-cell-stolen_value="props">
              <q-td :props="props" class="text-right text-negative">
                {{ formatAmountBdt(props.row.stolen_value) }}
              </q-td>
            </template>

            <template #body-cell-expired_qty="props">
              <q-td :props="props" class="text-right">
                {{ props.row.expired_qty }}
              </q-td>
            </template>

            <template #body-cell-expired_value="props">
              <q-td :props="props" class="text-right text-grey-8">
                {{ formatAmountBdt(props.row.expired_value) }}
              </q-td>
            </template>

            <template #body-cell-shrinkage_value="props">
              <q-td :props="props" class="text-right text-weight-bold text-negative">
                {{ formatAmountBdt(props.row.shrinkage_value) }}
              </q-td>
            </template>

            <template #body-cell-reconciliation_gap="props">
              <q-td
                :props="props"
                class="text-right text-weight-bold"
                :class="props.row.reconciliation_gap !== 0 ? 'text-negative' : 'text-grey-6'"
              >
                {{ formatGapQty(props.row.reconciliation_gap) }}
              </q-td>
            </template>

            <template #bottom-row>
              <q-tr class="text-weight-bold bg-grey-1 text-right">
                <q-td class="text-left" colspan="2">TOTAL</q-td>
                <q-td class="bg-blue-highlight text-warning">{{ dispositionTotals.sellableQty }}</q-td>
                <q-td class="bg-green-highlight text-warning">{{ formatAmountBdt(dispositionTotals.sellableValue) }}</q-td>
                <q-td class="bg-blue-highlight">{{ dispositionTotals.boxDamageQty }}</q-td>
                <q-td class="bg-orange-highlight text-grey-8">{{ formatAmountBdt(dispositionTotals.boxDamageValue) }}</q-td>
                <q-td class="bg-blue-highlight">{{ dispositionTotals.stolenQty }}</q-td>
                <q-td class="bg-orange-highlight text-negative">{{ formatAmountBdt(dispositionTotals.stolenValue) }}</q-td>
                <q-td class="bg-blue-highlight">{{ dispositionTotals.expiredQty }}</q-td>
                <q-td class="bg-orange-highlight text-grey-8">{{ formatAmountBdt(dispositionTotals.expiredValue) }}</q-td>
                <q-td class="bg-orange-highlight text-negative">{{ formatAmountBdt(dispositionTotals.shrinkageValue) }}</q-td>
                <q-td :class="dispositionTotals.reconciliationGap !== 0 ? 'text-negative' : 'text-grey-6'">
                  {{ formatGapQty(dispositionTotals.reconciliationGap) }}
                </q-td>
              </q-tr>
            </template>
        </q-table>

        <!-- Reconciliation Gap Warning Banner -->
        <q-banner
          v-if="reconciliationSummary.hasGap"
          class="bg-warning text-black rounded-borders q-mt-md"
        >
          <template #avatar>
            <q-icon name="warning" color="black" />
          </template>
          <div class="text-weight-bold q-mb-xs">Unit count mismatch</div>
          <div class="q-mb-sm">{{ reconciliationSummary.message }}</div>
          <div class="row q-col-gutter-md q-mb-sm text-body2">
            <div class="col-auto">
              <span class="text-grey-8">Received:</span>
              <span class="text-weight-medium q-ml-xs"
                >{{ reconciliationSummary.received.toLocaleString() }} units</span
              >
            </div>
            <div class="col-auto">
              <span class="text-grey-8">Sold + stock:</span>
              <span class="text-weight-medium q-ml-xs"
                >{{ reconciliationSummary.accounted.toLocaleString() }} units</span
              >
            </div>
            <div class="col-auto">
              <span class="text-grey-8">Difference:</span>
              <span class="text-weight-bold q-ml-xs"
                >{{ formatGapQty(reconciliationSummary.gap) }} units</span
              >
            </div>
          </div>
          <div class="text-caption text-grey-9">{{ reconciliationSummary.actionHint }}</div>
          <div v-if="gapOffenders.length" class="q-mt-sm">
            <div class="text-caption text-weight-bold q-mb-xs">Largest mismatches by item</div>
            <ul class="q-pl-md q-my-none text-caption">
              <li v-for="row in gapOffenders" :key="row.id">
                {{ row.name }} (#{{ row.id }}): {{ formatGapQty(row.reconciliation_gap) }} units
              </li>
            </ul>
          </div>
        </q-banner>
          </q-tab-panel>
        </q-tab-panels>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useQuasar } from 'quasar';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { treasuryRepository } from '../repositories/treasuryRepository';
import TreasuryStatGrid from '../components/TreasuryStatGrid.vue';
import type { StatCardItem } from '../components/TreasuryStatGrid.vue';

const search = ref('');
const activeTable = ref('trading');
const pagination = ref({ rowsPerPage: 0 });

const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const id = Number(route.params.id);
const loading = ref(false);
const error = ref<string | null>(null);

const shipment = ref<any>(null);
const items = ref<any[]>([]);
const totals = ref({
  landed_cost: 0,
  sold_cost: 0,
  revenue: 0,
  gross_profit: 0,
  sellable_on_hand_value: 0,
  shrinkage_value: 0,
  stolen_value: 0,
  box_damage_value: 0,
  expired_value: 0,
  unsold_value: 0,
  disposition_available: false,
  reconciliation_gap: 0,
});

const tradingColumns: QTableColumn[] = [
  { name: 'id', label: 'Item ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  {
    name: 'ordered_quantity',
    label: 'Received Qty',
    field: 'ordered_quantity',
    align: 'right',
    sortable: true,
    classes: 'bg-blue-highlight',
    headerClasses: 'bg-blue-highlight',
  },
  {
    name: 'landed_unit_cost',
    label: 'Landed Unit Cost',
    field: 'landed_unit_cost',
    align: 'right',
    sortable: true,
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'total_landed_cost',
    label: 'Total Landed Cost',
    field: 'id',
    align: 'right',
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'sold_qty',
    label: 'Sold Qty',
    field: 'sold_qty',
    align: 'right',
    sortable: true,
    classes: 'bg-blue-highlight',
    headerClasses: 'bg-blue-highlight',
  },
  {
    name: 'sold_cost',
    label: 'Sold Cost',
    field: 'sold_cost',
    align: 'right',
    sortable: true,
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'revenue',
    label: 'Revenue',
    field: 'revenue',
    align: 'right',
    sortable: true,
    classes: 'bg-green-highlight',
    headerClasses: 'bg-green-highlight',
  },
  {
    name: 'gross_profit',
    label: 'Gross Profit',
    field: 'id',
    align: 'right',
    classes: 'bg-green-highlight',
    headerClasses: 'bg-green-highlight',
  },
];

const dispositionColumns: QTableColumn[] = [
  { name: 'id', label: 'Item ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  {
    name: 'sellable_qty',
    label: 'Sellable Qty',
    field: 'sellable_qty',
    align: 'right',
    sortable: true,
    classes: 'bg-blue-highlight',
    headerClasses: 'bg-blue-highlight',
  },
  {
    name: 'sellable_value',
    label: 'Sellable Value',
    field: 'sellable_value',
    align: 'right',
    sortable: true,
    classes: 'bg-green-highlight',
    headerClasses: 'bg-green-highlight',
  },
  {
    name: 'box_damage_qty',
    label: 'Box Damage Qty',
    field: 'box_damage_qty',
    align: 'right',
    sortable: true,
    classes: 'bg-blue-highlight',
    headerClasses: 'bg-blue-highlight',
  },
  {
    name: 'box_damage_value',
    label: 'Box Damage Value',
    field: 'box_damage_value',
    align: 'right',
    sortable: true,
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'stolen_qty',
    label: 'Stolen Qty',
    field: 'stolen_qty',
    align: 'right',
    sortable: true,
    classes: 'bg-blue-highlight',
    headerClasses: 'bg-blue-highlight',
  },
  {
    name: 'stolen_value',
    label: 'Stolen Value',
    field: 'stolen_value',
    align: 'right',
    sortable: true,
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'expired_qty',
    label: 'Expired Qty',
    field: 'expired_qty',
    align: 'right',
    sortable: true,
    classes: 'bg-blue-highlight',
    headerClasses: 'bg-blue-highlight',
  },
  {
    name: 'expired_value',
    label: 'Expired Value',
    field: 'expired_value',
    align: 'right',
    sortable: true,
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'shrinkage_value',
    label: 'Shrinkage Total',
    field: 'shrinkage_value',
    align: 'right',
    sortable: true,
    classes: 'bg-orange-highlight',
    headerClasses: 'bg-orange-highlight',
  },
  {
    name: 'reconciliation_gap',
    label: 'Unit Gap',
    field: 'reconciliation_gap',
    align: 'right',
    sortable: true,
  },
];

const filteredItems = computed(() => {
  if (!search.value) return items.value;
  const q = search.value.trim().toLowerCase();
  return items.value.filter((item) => {
    const name = (item.name || '').toLowerCase();
    const idStr = String(item.id || '');
    return name.includes(q) || idStr.includes(q);
  });
});

const statusChipStyle = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase().trim();
  if (value === 'ready stock' || value === 'ready_stock') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    };
  }
  if (value === 'draft') {
    return {
      backgroundColor: '#f3f4f6',
      color: '#374151',
      border: '1px solid #e5e7eb',
    };
  }
  if (value === 'warehouse received' || value === 'warehouse_received' || value === 'uk warehouse delivery received') {
    return {
      backgroundColor: '#f3e8ff',
      color: '#581c87',
      border: '1px solid #e9d5ff',
    };
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    };
  }
  return {
    backgroundColor: '#c8d8f8',
    color: '#27487a',
    border: '1px solid #a9c4f3',
  };
};

const statusDotColor = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase().trim();
  if (value === 'ready stock' || value === 'ready_stock') return '#2f8b5d';
  if (value === 'draft') return '#4b5563';
  if (value === 'warehouse received' || value === 'warehouse_received' || value === 'uk warehouse delivery received') return '#7c3aed';
  if (value === 'cancelled') return '#b91c1c';
  return '#3f67b3';
};

const tradingTotals = computed(() => {
  const list = filteredItems.value;
  const receivedQty = list.reduce((sum, item) => sum + Number(item.ordered_quantity || 0), 0);
  const totalLandedCost = list.reduce((sum, item) => sum + Number(item.landed_unit_cost || 0) * Number(item.ordered_quantity || 0), 0);
  const avgLandedUnitCost = receivedQty > 0 ? totalLandedCost / receivedQty : 0;
  const soldQty = list.reduce((sum, item) => sum + Number(item.sold_qty || 0), 0);
  const soldCost = list.reduce((sum, item) => sum + Number(item.sold_cost || 0), 0);
  const revenue = list.reduce((sum, item) => sum + Number(item.revenue || 0), 0);
  const grossProfit = revenue - soldCost;

  return {
    receivedQty,
    avgLandedUnitCost,
    totalLandedCost,
    soldQty,
    soldCost,
    revenue,
    grossProfit,
  };
});

const dispositionTotals = computed(() => {
  const list = filteredItems.value;
  const sellableQty = list.reduce((sum, item) => sum + Number(item.sellable_qty || 0), 0);
  const sellableValue = list.reduce((sum, item) => sum + Number(item.sellable_value || 0), 0);
  const boxDamageQty = list.reduce((sum, item) => sum + Number(item.box_damage_qty || 0), 0);
  const boxDamageValue = list.reduce((sum, item) => sum + Number(item.box_damage_value || 0), 0);
  const stolenQty = list.reduce((sum, item) => sum + Number(item.stolen_qty || 0), 0);
  const stolenValue = list.reduce((sum, item) => sum + Number(item.stolen_value || 0), 0);
  const expiredQty = list.reduce((sum, item) => sum + Number(item.expired_qty || 0), 0);
  const expiredValue = list.reduce((sum, item) => sum + Number(item.expired_value || 0), 0);
  const shrinkageValue = list.reduce((sum, item) => sum + Number(item.shrinkage_value || 0), 0);
  const reconciliationGap = list.reduce((sum, item) => sum + Number(item.reconciliation_gap || 0), 0);

  return {
    sellableQty,
    sellableValue,
    boxDamageQty,
    boxDamageValue,
    stolenQty,
    stolenValue,
    expiredQty,
    expiredValue,
    shrinkageValue,
    reconciliationGap,
  };
});

const itemAccountedQty = (row: {
  sold_qty?: number;
  sellable_qty?: number;
  stolen_qty?: number;
  box_damage_qty?: number;
  expired_qty?: number;
  reserved_qty?: number;
}) =>
  Number(row.sold_qty || 0) +
  Number(row.sellable_qty || 0) +
  Number(row.stolen_qty || 0) +
  Number(row.box_damage_qty || 0) +
  Number(row.expired_qty || 0) +
  Number(row.reserved_qty || 0);

const formatGapQty = (gap: number) => (gap > 0 ? `+${gap.toLocaleString()}` : gap.toLocaleString());

const reconciliationSummary = computed(() => {
  const received = items.value.reduce((sum, row) => sum + Number(row.ordered_quantity || 0), 0);
  const accounted = items.value.reduce((sum, row) => sum + itemAccountedQty(row), 0);
  const gap = totals.value.reconciliation_gap;
  const absGap = Math.abs(gap).toLocaleString();

  if (gap === 0) {
    return { hasGap: false, received, accounted, gap, message: '', actionHint: '' };
  }

  if (gap < 0) {
    return {
      hasGap: true,
      received,
      accounted,
      gap,
      message: `${absGap} more units are recorded as sold or in stock than were marked received on this shipment.`,
      actionHint:
        'Check shipment received quantities, invoice quantities, and stock split or adjustment records.',
    };
  }

  return {
    hasGap: true,
    received,
    accounted,
    gap,
    message: `${absGap} received units are not showing as sold or in any stock bucket (sellable, stolen, damage, expired, reserved).`,
    actionHint:
      'Complete warehouse receive or split, link sales to this batch, or record missing disposition.',
  };
});

const gapOffenders = computed(() =>
  [...items.value]
    .filter((row) => Number(row.reconciliation_gap || 0) !== 0)
    .sort((a, b) => Math.abs(Number(b.reconciliation_gap)) - Math.abs(Number(a.reconciliation_gap)))
    .slice(0, 5),
);

const statCards = computed<StatCardItem[]>(() => [
  {
    label: 'Landed Cost BDT',
    value: totals.value.landed_cost,
    caption: 'Total import asset cost',
    format: 'currency',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Gross Revenue BDT',
    value: totals.value.revenue,
    caption: 'Sales subtotal less returns',
    format: 'currency',
    valueClass: 'text-positive',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Gross Profit BDT',
    value: totals.value.gross_profit,
    caption: 'Derived profit rollup',
    format: 'currency',
    valueClass: 'text-primary',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Sellable on-hand',
    value: totals.value.sellable_on_hand_value,
    caption: 'Recoverable on-hand stock',
    format: 'currency',
    valueClass: 'text-warning',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Inventory Loss (Shrinkage)',
    value: totals.value.shrinkage_value,
    caption: 'Stolen/damaged/expired',
    format: 'currency',
    valueClass: 'text-negative',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Stolen at cost',
    value: totals.value.stolen_value,
    caption: 'Stolen value at landed cost',
    format: 'currency',
    valueClass: 'text-negative',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
]);

const loadPnL = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId) return;

  loading.value = true;
  error.value = null;
  try {
    const res = await treasuryRepository.getShipmentPnL(tenantId, id);
    shipment.value = res.shipment;
    items.value = res.items || [];
    totals.value = res.totals;
  } catch (err: any) {
    error.value = err.message;
    $q.notify({ type: 'negative', message: `Failed to load shipment details: ${err.message}` });
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadPnL();
});
</script>

<style scoped>
.q-page,
:deep(.q-page) {
  max-width: 100% !important;
  width: 100% !important;
}
.hero-surface {
  border-radius: 16px;
}

.costing-file-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-transform: capitalize;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.pnl-page :deep(.q-card) {
  border-radius: 12px;
}

</style>

<style>
.pnl-sticky-table {
  height: clamp(400px, calc(100vh - 280px), 82vh);
}

.pnl-sticky-table .q-table__middle {
  height: 100%;
  max-height: 100% !important;
  overflow: auto;
}

.pnl-sticky-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #ffffff;
}

.pnl-sticky-table tbody tr:last-child td {
  position: sticky;
  bottom: 0;
  z-index: 2;
  background-color: #f5f5f5;
  box-shadow: 0 -2px 4px rgba(0, 0, 0, 0.05);
}

.pnl-sticky-table .bg-blue-highlight {
  background-color: #eff6ff !important;
}
.pnl-sticky-table .bg-purple-highlight {
  background-color: #faf5ff !important;
}
.pnl-sticky-table .bg-green-highlight {
  background-color: #f0fdf4 !important;
}
.pnl-sticky-table .bg-orange-highlight {
  background-color: #fff7ed !important;
}
</style>
