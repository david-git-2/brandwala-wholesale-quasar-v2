<template>
  <TreasuryPageShell
    :title="`Shipment P&L: ${shipment?.name || '#' + id}`"
    subtitle="Analyze itemized landed costs, sales revenue conversion, gross profit margin, and stock disposition breakdown."
    :error="error"
  >
    <template #action>
      <q-btn flat dense no-caps icon="arrow_back" label="Back to Shipments" @click="goBack" />
    </template>

    <!-- Loading spinner -->
    <div v-if="loading" class="row justify-center py-12">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <div v-else-if="shipment" class="q-gutter-y-lg" style="min-width: 0">
      <!-- Stats Row -->
      <TreasuryStatGrid :items="statCards" />

      <!-- Trading P&L Table Card -->
      <q-card flat bordered class="q-pa-md bg-white overflow-hidden" style="min-width: 0">
        <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
          Trading Cost &amp; Profit Allocations
        </div>

        <TreasuryTableWrap>
          <q-table
            flat
            row-key="id"
            :rows="items"
            :columns="tradingColumns"
            :pagination="{ rowsPerPage: 50 }"
            :dense="$q.screen.lt.md"
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
          </q-table>
        </TreasuryTableWrap>
      </q-card>

      <!-- Stock Disposition & Shrinkage Table Card -->
      <q-card flat bordered class="q-pa-md bg-white overflow-hidden" style="min-width: 0">
        <div class="row items-center justify-between q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-primary">
            Stock Disposition &amp; Shrinkage
          </div>
          <q-badge
            v-if="!totals.disposition_available"
            color="warning"
            label="Stock not received — disposition unavailable"
          />
        </div>

        <TreasuryTableWrap>
          <q-table
            flat
            row-key="id"
            :rows="items"
            :columns="dispositionColumns"
            :pagination="{ rowsPerPage: 50 }"
            :dense="$q.screen.lt.md"
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
          </q-table>
        </TreasuryTableWrap>

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
  },
  {
    name: 'landed_unit_cost',
    label: 'Landed Unit Cost',
    field: 'landed_unit_cost',
    align: 'right',
    sortable: true,
  },
  { name: 'total_landed_cost', label: 'Total Landed Cost', field: 'id', align: 'right' },
  { name: 'sold_qty', label: 'Sold Qty', field: 'sold_qty', align: 'right', sortable: true },
  { name: 'sold_cost', label: 'Sold Cost', field: 'sold_cost', align: 'right', sortable: true },
  { name: 'revenue', label: 'Revenue', field: 'revenue', align: 'right', sortable: true },
  { name: 'gross_profit', label: 'Gross Profit', field: 'id', align: 'right' },
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
  },
  {
    name: 'sellable_value',
    label: 'Sellable Value',
    field: 'sellable_value',
    align: 'right',
    sortable: true,
  },
  {
    name: 'box_damage_qty',
    label: 'Box Damage Qty',
    field: 'box_damage_qty',
    align: 'right',
    sortable: true,
  },
  {
    name: 'box_damage_value',
    label: 'Box Damage Value',
    field: 'box_damage_value',
    align: 'right',
    sortable: true,
  },
  { name: 'stolen_qty', label: 'Stolen Qty', field: 'stolen_qty', align: 'right', sortable: true },
  {
    name: 'stolen_value',
    label: 'Stolen Value',
    field: 'stolen_value',
    align: 'right',
    sortable: true,
  },
  {
    name: 'expired_qty',
    label: 'Expired Qty',
    field: 'expired_qty',
    align: 'right',
    sortable: true,
  },
  {
    name: 'expired_value',
    label: 'Expired Value',
    field: 'expired_value',
    align: 'right',
    sortable: true,
  },
  {
    name: 'shrinkage_value',
    label: 'Shrinkage Total',
    field: 'shrinkage_value',
    align: 'right',
    sortable: true,
  },
  {
    name: 'reconciliation_gap',
    label: 'Unit Gap',
    field: 'reconciliation_gap',
    align: 'right',
    sortable: true,
  },
];

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

const statCards = computed(() => [
  {
    label: 'Landed Cost BDT',
    value: totals.value.landed_cost,
    caption: 'Total import asset cost',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Gross Revenue BDT',
    value: totals.value.revenue,
    caption: 'Sales subtotal less returns',
    valueClass: 'text-positive',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Gross Profit BDT',
    value: totals.value.gross_profit,
    caption: 'Derived profit rollup',
    valueClass: 'text-primary',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Sellable on-hand',
    value: totals.value.sellable_on_hand_value,
    caption: 'Recoverable on-hand stock',
    valueClass: 'text-warning',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Inventory Loss (Shrinkage)',
    value: totals.value.shrinkage_value,
    caption: 'Stolen/damaged/expired',
    valueClass: 'text-negative',
    class: 'col-12 col-sm-6 col-md-4 col-lg-2',
  },
  {
    label: 'Stolen at cost',
    value: totals.value.stolen_value,
    caption: 'Stolen value at landed cost',
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

const goBack = () => {
  void router.push({
    name: 'app-finance-shipments-page',
    params: { tenantSlug: authStore.tenantSlug ?? undefined },
  });
};

onMounted(() => {
  void loadPnL();
});
</script>
