<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { globalRepository } from 'src/modules/global/repositories/globalRepository';
import type { StockNetworkQuery, StockNetworkRow } from 'src/modules/global/types';
import { parseSupabaseError, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { createDemandPickClientKey } from '../utils/demandStockPickClientKey';

type StockMatchMode = 'product_id' | 'name_fallback' | 'manual_search';

export type DemandStockPickRow = {
  global_stock_id: number;
  product_name: string;
  shipment_name: string;
  location_name: string;
  grade_label: string;
  available_atp: number;
};

export type DemandCloseAction = 'take' | 'condition' | 'return';

export type DemandStockPickSelection = {
  clientKey: string;
  globalStockId: number;
  shipmentName: string;
  locationName: string;
  quantity: number;
  initialQuantity?: number;
  closeAction?: DemandCloseAction | null;
  isCloseSplit?: boolean;
  invoiceId?: number | null;
  returnedAt?: string | null;
};

const props = defineProps<{
  modelValue: boolean;
  tenantId: number | null;
  productId: number | null;
  productName: string;
  needQuantity: number;
  initialPicks?: DemandStockPickSelection[];
  /** Delivery paper: qty fields only; Apply commits picks (no per-lot Add). */
  hidePerLotAddButton?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'apply', payload: { picks: DemandStockPickSelection[]; totalQuantity: number }): void;
}>();

const loading = ref(false);
const qtyByStockId = ref<Record<number, number | null>>({});
const committedPicks = ref<DemandStockPickSelection[]>([]);
const addingStockId = ref<number | null>(null);
const stockRows = ref<DemandStockPickRow[]>([]);
const matchMode = ref<StockMatchMode>('product_id');
const stockSearchQuery = ref('');

const canLoadStock = computed(
  () =>
    props.tenantId != null &&
    (props.productId != null || props.productName.trim().length > 0),
);

const showAlternateMatchNote = computed(() => matchMode.value !== 'product_id');

const mapNetworkRow = (row: StockNetworkRow): DemandStockPickRow => ({
  global_stock_id: row.global_stock_id,
  product_name: row.name?.trim() || '—',
  shipment_name: row.shipment_name ?? '—',
  location_name: row.location_name ?? row.holding_tenant_name ?? '—',
  grade_label: row.is_pickable ? 'Sellable' : 'Not pickable',
  available_atp: Math.max(0, Math.trunc(Number(row.available_atp ?? row.excellent_qty ?? 0))),
});

const filterPickableRows = (data: StockNetworkRow[]) =>
  data
    .filter((row) => row.is_pickable && (row.available_atp ?? 0) > 0)
    .map(mapNetworkRow);

const baseNetworkQuery = (tenantId: number): Omit<StockNetworkQuery, 'product_id' | 'search' | 'search_field'> => ({
  context_tenant_id: tenantId,
  mode: 'search',
  status: 'excellent',
  exclude_zero_qty: true,
  page: 1,
  page_size: 100,
  skip_count: true,
});

const fetchPickableStock = async (query: StockNetworkQuery) => {
  const result = await globalRepository.searchStockNetwork(query);
  return filterPickableRows(result.data);
};

const loadRows = async () => {
  if (!canLoadStock.value || props.tenantId == null) {
    stockRows.value = [];
    matchMode.value = 'product_id';
    return;
  }

  const tenantId = props.tenantId;
  const manualSearch = stockSearchQuery.value.trim();

  loading.value = true;
  try {
    if (manualSearch) {
      stockRows.value = await fetchPickableStock({
        ...baseNetworkQuery(tenantId),
        product_id: null,
        search: manualSearch,
        search_field: 'all',
      });
      matchMode.value = 'manual_search';
      return;
    }

    if (props.productId != null) {
      const byProductId = await fetchPickableStock({
        ...baseNetworkQuery(tenantId),
        product_id: props.productId,
        search: null,
      });
      if (byProductId.length > 0) {
        stockRows.value = byProductId;
        matchMode.value = 'product_id';
        return;
      }
    }

    const lineName = props.productName.trim();
    if (lineName) {
      stockRows.value = await fetchPickableStock({
        ...baseNetworkQuery(tenantId),
        product_id: null,
        search: lineName,
        search_field: 'name',
      });
      matchMode.value = 'name_fallback';
      return;
    }

    stockRows.value = [];
    matchMode.value = 'product_id';
  } catch (err) {
    stockRows.value = [];
    showErrorNotification(parseSupabaseError(err, 'Failed to load stock'));
  } finally {
    loading.value = false;
  }
};

const onStockSearchInput = (value: string | number | null) => {
  stockSearchQuery.value = String(value ?? '').trimStart();
  void loadRows().then(resetQtyDefaults);
};

const noLineIdentity = computed(
  () => props.productId == null && !props.productName.trim(),
);

const emptyStockMessage = computed(() => {
  if (noLineIdentity.value) return '';
  if (props.productId != null && matchMode.value === 'product_id' && !stockSearchQuery.value.trim()) {
    return 'No pickable stock for this product.';
  }
  return 'No pickable stock for this name. Try another search.';
});

const selectedTotal = computed(() => {
  if (props.hidePerLotAddButton) {
    return stockRows.value.reduce((sum, row) => {
      const q = Math.trunc(qtyByStockId.value[row.global_stock_id] ?? 0);
      return sum + (q > 0 ? q : 0);
    }, 0);
  }
  return committedPicks.value.reduce((sum, pick) => sum + pick.quantity, 0);
});

const canApply = computed(() => {
  if (props.hidePerLotAddButton) {
    return selectedTotal.value > 0;
  }
  return (
    committedPicks.value.length > 0 &&
    committedPicks.value.every((pick) => Number(pick.quantity) > 0) &&
    selectedTotal.value > 0
  );
});

const applyDisabledReason = computed(() => {
  if (canApply.value) return '';
  if (props.hidePerLotAddButton) return 'Enter a quantity on at least one lot';
  if (!committedPicks.value.length) return 'Enter a quantity and tap Add on a lot';
  return 'Each pick needs a quantity greater than zero';
});

const remainingToPick = computed(() => Math.max(0, props.needQuantity - selectedTotal.value));

const needFilled = computed(() => props.needQuantity > 0 && remainingToPick.value === 0);

const maxPickableForRow = (row: DemandStockPickRow) => {
  const current = Math.trunc(qtyByStockId.value[row.global_stock_id] ?? 0);
  const otherPicked = selectedTotal.value - current;
  const left = Math.max(0, props.needQuantity - otherPicked);
  return Math.min(row.available_atp, left);
};

const fillRowMax = (row: DemandStockPickRow) => {
  const max = maxPickableForRow(row);
  if (max <= 0) {
    showErrorNotification('Nothing left to pick on this line.');
    return;
  }
  setQty(row.global_stock_id, max, row.available_atp);
};

const maybeAutoFillSingleLot = () => {
  if (!props.hidePerLotAddButton || stockRows.value.length !== 1) return;
  const row = stockRows.value[0];
  if (committedPicks.value.length > 0) return;
  const max = maxPickableForRow(row);
  if (max > 0 && selectedTotal.value === 0) {
    qtyByStockId.value[row.global_stock_id] = max;
  }
};

const committedQty = (stockId: number) => {
  if (props.hidePerLotAddButton) {
    const q = Math.trunc(qtyByStockId.value[stockId] ?? 0);
    return q > 0 ? q : 0;
  }
  return committedPicks.value
    .filter((pick) => pick.globalStockId === stockId)
    .reduce((sum, pick) => sum + pick.quantity, 0);
};

const resetQtyDefaults = () => {
  const nextQty: Record<number, number | null> = {};
  for (const row of stockRows.value) {
    const added = committedPicks.value
      .filter((pick) => pick.globalStockId === row.global_stock_id)
      .reduce((sum, pick) => sum + pick.quantity, 0);
    nextQty[row.global_stock_id] = added > 0 ? added : null;
  }
  qtyByStockId.value = nextQty;
};

watch(
  () => props.modelValue,
  (open, wasOpen) => {
    if (!open) {
      if (wasOpen) {
        stockRows.value = [];
        qtyByStockId.value = {};
        stockSearchQuery.value = '';
        matchMode.value = 'product_id';
      }
      return;
    }
    committedPicks.value = (props.initialPicks ?? []).map((pick) => ({
      ...pick,
      clientKey: pick.clientKey || createDemandPickClientKey(),
    }));
    void loadRows().then(() => {
      resetQtyDefaults();
      maybeAutoFillSingleLot();
    });
  },
);

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
    existing.initialQuantity = qty;
  } else {
    committedPicks.value.push({
      clientKey: createDemandPickClientKey(),
      globalStockId: row.global_stock_id,
      shipmentName: row.shipment_name,
      locationName: row.location_name,
      quantity: qty,
      initialQuantity: qty,
      isCloseSplit: false,
    });
  }
  showSuccessNotification(`Added ${qty} from ${row.shipment_name}.`);
  addingStockId.value = null;
};

const emitCurrentPicks = () => {
  emit('apply', {
    picks: committedPicks.value.map((pick) => ({ ...pick })),
    totalQuantity: selectedTotal.value,
  });
};

const removePick = (stockId: number) => {
  const id = Number(stockId);
  committedPicks.value = committedPicks.value.filter(
    (pick) => Number(pick.globalStockId) !== id,
  );
  qtyByStockId.value = { ...qtyByStockId.value, [id]: null };
  emitCurrentPicks();
};

const buildPicksFromQtyInputs = (): DemandStockPickSelection[] | null => {
  const picks: DemandStockPickSelection[] = [];
  for (const row of stockRows.value) {
    const qty = Math.trunc(qtyByStockId.value[row.global_stock_id] ?? 0);
    if (qty <= 0) continue;
    if (qty > row.available_atp) {
      showErrorNotification(`Only ${row.available_atp} units available on ${row.shipment_name}.`);
      return null;
    }
    const existing = committedPicks.value.find((pick) => pick.globalStockId === row.global_stock_id);
    picks.push({
      clientKey: existing?.clientKey ?? createDemandPickClientKey(),
      globalStockId: row.global_stock_id,
      shipmentName: row.shipment_name,
      locationName: row.location_name,
      quantity: qty,
      initialQuantity: qty,
      closeAction: existing?.closeAction ?? null,
      isCloseSplit: existing?.isCloseSplit ?? false,
      invoiceId: existing?.invoiceId ?? null,
      returnedAt: existing?.returnedAt ?? null,
    });
  }
  return picks;
};

const apply = () => {
  if (props.hidePerLotAddButton) {
    const picks = buildPicksFromQtyInputs();
    if (!picks || picks.length === 0) return;
    emit('apply', {
      picks,
      totalQuantity: picks.reduce((sum, p) => sum + p.quantity, 0),
    });
    close();
    return;
  }
  if (!canApply.value) return;
  emitCurrentPicks();
  close();
};

</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="demand-stock-pick-dialog">
      <q-card-section class="row items-start q-pb-sm">
        <div class="col">
          <div class="text-h6 text-weight-bold">Pick stock</div>
          <div class="text-body2 text-grey-8 q-mt-xs ellipsis-2-lines">{{ productName }}</div>
        </div>
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>

      <q-card-section class="q-pt-none q-pb-sm">
        <div class="row q-gutter-sm items-center">
          <div class="pick-stat">
            <span class="pick-stat__label">Need</span>
            <span class="pick-stat__value font-mono">{{ needQuantity }}</span>
          </div>
          <div class="pick-stat pick-stat--active">
            <span class="pick-stat__label">Picked</span>
            <span class="pick-stat__value font-mono">{{ selectedTotal }}</span>
          </div>
          <div class="pick-stat" :class="{ 'pick-stat--done': needFilled }">
            <span class="pick-stat__label">Left</span>
            <span class="pick-stat__value font-mono">{{ remainingToPick }}</span>
          </div>
        </div>
        <div
          v-if="hidePerLotAddButton && needFilled"
          class="text-caption text-positive q-mt-sm"
        >
          Need is covered. Tap Apply to save picks.
        </div>
      </q-card-section>

      <q-card-section v-if="canLoadStock" class="q-pt-none q-pb-sm">
        <q-input
          v-model="stockSearchQuery"
          dense
          outlined
          hide-bottom-space
          clearable
          debounce="300"
          placeholder="Search stock"
          aria-label="Search stock by name, barcode, or code"
          @update:model-value="onStockSearchInput"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="18px" />
          </template>
        </q-input>
        <div
          v-if="showAlternateMatchNote && !loading"
          class="text-caption text-grey-8 q-mt-sm"
        >
          Showing stock matched by name or search — lots may use a different product id than this line.
        </div>
      </q-card-section>

      <q-card-section class="q-pt-none pick-lots-scroll">
        <div v-if="loading" class="flex flex-center q-py-xl">
          <q-spinner color="primary" size="32px" />
        </div>

        <div
          v-else-if="noLineIdentity"
          class="text-center text-grey-7 q-py-lg text-body2"
        >
          This line has no product id.
        </div>

        <div
          v-else-if="!stockRows.length"
          class="text-center text-grey-7 q-py-lg text-body2"
        >
          {{ emptyStockMessage }}
        </div>

        <div v-else class="column q-gutter-y-sm">
          <div
            v-for="row in stockRows"
            :key="row.global_stock_id"
            class="pick-lot-card"
            :class="{ 'pick-lot-card--picked': committedQty(row.global_stock_id) > 0 }"
          >
            <div class="row items-start no-wrap q-gutter-sm">
              <div class="col min-width-0">
                <div class="text-subtitle2 text-weight-medium ellipsis">
                  {{ row.shipment_name }}
                </div>
                <div class="text-caption text-grey-8 ellipsis q-mt-xs">
                  {{ row.product_name }}
                </div>
                <div class="row items-center q-gutter-xs q-mt-xs flex-wrap">
                  <span class="pick-meta">
                    <q-icon name="ph ph-map-pin" size="12px" />
                    {{ row.location_name }}
                  </span>
                  <q-badge outline color="grey-7" :label="`${row.available_atp} avail`" />
                </div>
              </div>
              <q-btn
                v-if="!hidePerLotAddButton && committedQty(row.global_stock_id) > 0"
                flat
                round
                dense
                size="sm"
                color="grey-7"
                icon="ph ph-trash"
                aria-label="Remove pick"
                @click="removePick(row.global_stock_id)"
              >
                <q-tooltip>Remove pick</q-tooltip>
              </q-btn>
            </div>

            <div class="row items-center q-gutter-sm q-mt-sm">
              <q-input
                :model-value="qtyByStockId[row.global_stock_id] ?? null"
                type="number"
                min="0"
                :max="row.available_atp"
                dense
                outlined
                hide-bottom-space
                placeholder="Qty"
                class="pick-lot-card__qty"
                input-class="text-center font-mono"
                aria-label="Quantity to pick from this lot"
                @update:model-value="(v) => setQty(row.global_stock_id, v, row.available_atp)"
              />
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                class="pick-lot-card__max"
                :disable="maxPickableForRow(row) <= 0"
                :label="hidePerLotAddButton ? 'Fill' : 'Max'"
                @click="fillRowMax(row)"
              >
                <q-tooltip>
                  {{
                    hidePerLotAddButton
                      ? 'Fill remaining need from this lot'
                      : 'Pick the most you can from this lot'
                  }}
                </q-tooltip>
              </q-btn>
              <q-btn
                v-if="hidePerLotAddButton && committedQty(row.global_stock_id) > 0"
                flat
                round
                dense
                size="sm"
                color="grey-7"
                icon="ph ph-trash"
                aria-label="Clear quantity"
                @click="setQty(row.global_stock_id, null, row.available_atp)"
              >
                <q-tooltip>Clear</q-tooltip>
              </q-btn>
              <q-btn
                v-if="!hidePerLotAddButton"
                unelevated
                no-caps
                color="primary"
                class="pick-lot-card__add"
                :label="committedQty(row.global_stock_id) ? 'Update' : 'Add'"
                :loading="addingStockId === row.global_stock_id"
                @click="addPick(row)"
              />
              <q-badge
                v-if="committedQty(row.global_stock_id) > 0"
                color="primary"
                text-color="white"
                class="q-ml-auto"
              >
                Picked {{ committedQty(row.global_stock_id) }}
              </q-badge>
            </div>
          </div>
        </div>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          :label="canApply ? `Apply · ${selectedTotal} units` : 'Apply'"
          :disable="!canApply"
          @click="apply"
        >
          <q-tooltip v-if="applyDisabledReason">{{ applyDisabledReason }}</q-tooltip>
        </q-btn>
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<style scoped lang="scss">
.demand-stock-pick-dialog {
  width: min(520px, 96vw);
  max-height: min(88vh, 720px);
  display: flex;
  flex-direction: column;
  border-radius: var(--tf-radius-md, 12px);
}

.pick-lots-scroll {
  flex: 1;
  min-height: 0;
  max-height: min(52vh, 420px);
  overflow-y: auto;
}

.pick-stat {
  flex: 1;
  min-width: 0;
  padding: 0.5rem 0.65rem;
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-neutral-canvas, #fbfaf7);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  text-align: center;
}

.pick-stat--active {
  border-color: color-mix(in srgb, var(--q-primary) 35%, var(--tf-neutral-border, #e7e1d8));
  background: color-mix(in srgb, var(--q-primary) 8%, var(--tf-neutral-surface, #fff));
}

.pick-stat--done {
  border-color: color-mix(in srgb, var(--q-positive, #21ba45) 40%, var(--tf-neutral-border, #e7e1d8));
  background: color-mix(in srgb, var(--q-positive, #21ba45) 10%, var(--tf-neutral-surface, #fff));
}

.pick-stat__label {
  display: block;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-muted, #736a61);
}

.pick-stat__value {
  display: block;
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--tf-neutral-ink, #171412);
  line-height: 1.3;
  margin-top: 2px;
}

.pick-lot-card {
  padding: 0.75rem 0.85rem;
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  background: var(--tf-neutral-surface, #fff);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.pick-lot-card--picked {
  border-color: color-mix(in srgb, var(--q-primary) 40%, var(--tf-neutral-border, #e7e1d8));
}

.pick-meta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 12px;
  color: var(--tf-neutral-muted, #736a61);
}

.pick-lot-card__qty {
  width: 96px;
  flex-shrink: 0;
}

.pick-lot-card__max {
  min-width: 52px;
  font-weight: 600;
}

.pick-lot-card__add {
  border-radius: var(--tf-radius-sm, 8px);
  min-width: 72px;
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
