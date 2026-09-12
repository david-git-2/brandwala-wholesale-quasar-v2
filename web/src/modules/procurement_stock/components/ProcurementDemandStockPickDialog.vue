<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { globalRepository } from 'src/modules/global/repositories/globalRepository';
import type { StockNetworkRow } from 'src/modules/global/types';
import { parseSupabaseError, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

export type DemandStockPickRow = {
  global_stock_id: number;
  shipment_name: string;
  location_name: string;
  grade_label: string;
  available_atp: number;
  unit_cost_amount: number;
};

export type DemandStockPickSelection = {
  globalStockId: number;
  shipmentName: string;
  locationName: string;
  quantity: number;
};

const props = defineProps<{
  modelValue: boolean;
  tenantId: number | null;
  productId: number | null;
  productName: string;
  needQuantity: number;
  initialPicks?: DemandStockPickSelection[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'apply', payload: { picks: DemandStockPickSelection[]; totalQuantity: number }): void;
}>();

const search = ref('');
const loading = ref(false);
const qtyByStockId = ref<Record<number, number | null>>({});
const committedPicks = ref<DemandStockPickSelection[]>([]);
const addingStockId = ref<number | null>(null);
const stockRows = ref<DemandStockPickRow[]>([]);

const mapNetworkRow = (row: StockNetworkRow): DemandStockPickRow => ({
  global_stock_id: row.global_stock_id,
  shipment_name: row.shipment_name ?? '—',
  location_name: row.location_name ?? row.holding_tenant_name ?? '—',
  grade_label: row.is_pickable ? 'Sellable' : 'Not pickable',
  available_atp: Math.max(0, Math.trunc(Number(row.available_atp ?? row.excellent_qty ?? 0))),
  unit_cost_amount: Number(row.purchase_price ?? 0),
});

const loadRows = async () => {
  if (!props.tenantId || !props.productId) {
    stockRows.value = [];
    return;
  }

  loading.value = true;
  try {
    const result = await globalRepository.searchStockNetwork({
      context_tenant_id: props.tenantId,
      mode: 'search',
      product_id: props.productId,
      search: search.value.trim() || null,
      status: 'excellent',
      exclude_zero_qty: true,
      page: 1,
      page_size: 100,
      skip_count: true,
    });

    stockRows.value = result.data
      .filter((row) => row.is_pickable && (row.available_atp ?? 0) > 0)
      .map(mapNetworkRow);
  } catch (err) {
    stockRows.value = [];
    showErrorNotification(parseSupabaseError(err, 'Failed to load stock'));
  } finally {
    loading.value = false;
  }
};

const debouncedLoad = (() => {
  let timer: ReturnType<typeof setTimeout> | undefined;
  return () => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => void loadRows(), 300);
  };
})();

const rows = computed(() => {
  const term = search.value.trim().toLowerCase();
  if (!term) return stockRows.value;
  return stockRows.value.filter(
    (row) =>
      row.shipment_name.toLowerCase().includes(term) ||
      row.location_name.toLowerCase().includes(term) ||
      row.grade_label.toLowerCase().includes(term),
  );
});

const selectedTotal = computed(() =>
  committedPicks.value.reduce((sum, pick) => sum + pick.quantity, 0),
);

const remainingToPick = computed(() => Math.max(0, props.needQuantity - selectedTotal.value));

const committedQty = (stockId: number) =>
  committedPicks.value.find((pick) => pick.globalStockId === stockId)?.quantity ?? 0;

const resetQtyDefaults = () => {
  const nextQty: Record<number, number | null> = {};
  for (const row of stockRows.value) {
    const added = committedQty(row.global_stock_id);
    nextQty[row.global_stock_id] = added > 0 ? added : null;
  }
  qtyByStockId.value = nextQty;
};

const resetState = () => {
  committedPicks.value = (props.initialPicks ?? []).map((pick) => ({ ...pick }));
  resetQtyDefaults();
};

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    search.value = '';
    committedPicks.value = (props.initialPicks ?? []).map((pick) => ({ ...pick }));
    void loadRows().then(resetQtyDefaults);
  },
);

watch(search, () => debouncedLoad());

const close = () => emit('update:modelValue', false);

const setQty = (stockId: number, value: string | number | null, maxAtp: number) => {
  if (value === '' || value === null) {
    qtyByStockId.value[stockId] = null;
    return;
  }
  const parsed = Math.trunc(Number(value));
  if (!Number.isFinite(parsed) || parsed <= 0) {
    qtyByStockId.value[stockId] = null;
    return;
  }
  qtyByStockId.value[stockId] = Math.min(parsed, maxAtp);
};

const addPick = (row: DemandStockPickRow) => {
  const qty = Math.trunc(qtyByStockId.value[row.global_stock_id] ?? 0);
  if (qty <= 0) {
    showErrorNotification('Enter a quantity greater than zero.');
    return;
  }
  if (qty > row.available_atp) {
    showErrorNotification(`Only ${row.available_atp} units available on ${row.shipment_name}.`);
    return;
  }

  addingStockId.value = row.global_stock_id;
  const existing = committedPicks.value.find((pick) => pick.globalStockId === row.global_stock_id);
  if (existing) {
    existing.quantity = qty;
  } else {
    committedPicks.value.push({
      globalStockId: row.global_stock_id,
      shipmentName: row.shipment_name,
      locationName: row.location_name,
      quantity: qty,
    });
  }
  showSuccessNotification(`Added ${qty} from ${row.shipment_name}.`);
  addingStockId.value = null;
};

const removePick = (stockId: number) => {
  committedPicks.value = committedPicks.value.filter((pick) => pick.globalStockId !== stockId);
};

const apply = () => {
  if (committedPicks.value.length === 0) {
    showErrorNotification('Add at least one stock row.');
    return;
  }

  emit('apply', {
    picks: committedPicks.value.map((pick) => ({ ...pick })),
    totalQuantity: selectedTotal.value,
  });
  close();
};
</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="demand-stock-pick-dialog">
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="text-h6">Pick stock</div>
          <div class="text-caption text-grey-7">
            {{ productName }} · need {{ needQuantity }} · picked {{ selectedTotal }} · remaining
            {{ remainingToPick }}
          </div>
          <div class="text-caption text-grey-6 q-mt-xs">
            Stock rows for product #{{ productId ?? '—' }}. Delivered qty is the total across all picks.
          </div>
        </div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" @click="close" />
      </q-card-section>

      <q-card-section>
        <q-input
          v-model="search"
          dense
          outlined
          clearable
          placeholder="Search shipment or location…"
          class="q-mb-md"
          :disable="!productId || !tenantId"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>

        <q-table
          flat
          bordered
          row-key="global_stock_id"
          :rows="rows"
          :loading="loading"
          :columns="[
            { name: 'shipment', label: 'Shipment', field: 'shipment_name', align: 'left' },
            { name: 'location', label: 'Location', field: 'location_name', align: 'left' },
            { name: 'grade', label: 'Grade', field: 'grade_label', align: 'center' },
            { name: 'atp', label: 'Available', field: 'available_atp', align: 'right' },
            { name: 'added', label: 'Added', field: 'global_stock_id', align: 'right' },
            { name: 'cost', label: 'Cost', field: 'unit_cost_amount', align: 'right' },
            { name: 'qty', label: 'Qty', field: 'global_stock_id', align: 'center' },
            { name: 'action', label: '', field: 'global_stock_id', align: 'right' },
          ]"
          :pagination="{ rowsPerPage: 10 }"
          :no-data-label="
            !productId
              ? 'This line has no product id.'
              : loading
                ? 'Loading stock…'
                : 'No stock rows for this product.'
          "
        >
          <template #body-cell-atp="cell">
            <q-td :props="cell">{{ cell.row.available_atp }}</q-td>
          </template>
          <template #body-cell-added="cell">
            <q-td :props="cell">
              <span v-if="committedQty(cell.row.global_stock_id)" class="text-weight-medium text-primary">
                {{ committedQty(cell.row.global_stock_id) }}
              </span>
              <span v-else class="text-grey-5">—</span>
            </q-td>
          </template>
          <template #body-cell-cost="cell">
            <q-td :props="cell">{{ Number(cell.row.unit_cost_amount || 0).toFixed(2) }}</q-td>
          </template>
          <template #body-cell-qty="cell">
            <q-td :props="cell">
              <q-input
                :model-value="qtyByStockId[cell.row.global_stock_id] ?? null"
                type="number"
                min="0"
                :max="cell.row.available_atp"
                dense
                outlined
                hide-bottom-space
                class="demand-stock-pick-qty"
                input-class="text-center"
                @update:model-value="(v) => setQty(cell.row.global_stock_id, v, cell.row.available_atp)"
              />
            </q-td>
          </template>
          <template #body-cell-action="cell">
            <q-td :props="cell">
              <q-btn
                color="primary"
                unelevated
                no-caps
                dense
                :label="committedQty(cell.row.global_stock_id) ? 'Update' : 'Add'"
                :loading="addingStockId === cell.row.global_stock_id"
                @click="addPick(cell.row)"
              />
            </q-td>
          </template>
        </q-table>

        <div v-if="committedPicks.length" class="q-mt-md">
          <div class="text-subtitle2 text-weight-bold q-mb-sm">Selected stock ({{ committedPicks.length }})</div>
          <q-markup-table flat bordered dense class="demand-stock-pick-selected">
            <thead>
              <tr>
                <th class="text-left">Shipment</th>
                <th class="text-left">Location</th>
                <th class="text-right">Qty</th>
                <th class="text-right"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="pick in committedPicks" :key="pick.globalStockId">
                <td>{{ pick.shipmentName }}</td>
                <td>{{ pick.locationName }}</td>
                <td class="text-right text-weight-medium">{{ pick.quantity }}</td>
                <td class="text-right">
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="ph ph-trash"
                    @click="removePick(pick.globalStockId)"
                  >
                    <q-tooltip>Remove</q-tooltip>
                  </q-btn>
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          :label="`Apply (${selectedTotal})`"
          :disable="committedPicks.length === 0"
          @click="apply"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<style scoped>
.demand-stock-pick-dialog {
  min-width: min(920px, 96vw);
  max-width: 960px;
}

.demand-stock-pick-qty {
  width: 80px;
}

.demand-stock-pick-selected :deep(thead tr th) {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #64748b;
  background: #f8fafc;
}

.demand-stock-pick-selected :deep(tbody td) {
  font-size: 12.5px;
}
</style>
