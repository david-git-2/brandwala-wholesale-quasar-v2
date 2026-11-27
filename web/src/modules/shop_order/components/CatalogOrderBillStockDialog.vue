<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  shopOrderRepository,
  type OrderItemPickStockRow,
} from '../repositories/shopOrderRepository';
import type { ShopOrderItem } from '../types';
import {
  catalogBillLineSourceStockId,
  type CatalogBillLineSourceRow,
} from '../utils/catalogBillKernelLines';
import { showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  orderItem: ShopOrderItem | null;
  orderId: number;
  deskTenantId: number | null;
  billId: number;
  booksTenantId: number | null;
  billLines: CatalogBillLineSourceRow[];
  /** Customer-submitted order line qty (`quantity`). */
  neededQuantity: number;
  onThisBillQuantity: number;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'updated'): void;
}>();

const loading = ref(false);
const rows = ref<OrderItemPickStockRow[]>([]);
/** User edits only. Prefill comes from bill lines via displayQtyForRow (not copied here). */
const qtyEditsByStockId = ref<Record<string, number>>({});
/** Only accept input updates after focus — Quasar can emit empty on mount and wipe prefill. */
const qtyTouchedByStockId = ref<Record<string, boolean>>({});
/** Prefill qty per stock lot from order-scoped bill-line RPC (current bill when billId set). */
const orderBillQtyByStockId = ref<Record<string, number>>({});
const saving = ref(false);

const stockKey = (stockId: number | string | null | undefined): string => {
  const n = Number(stockId ?? 0);
  return n > 0 ? String(n) : '';
};

const draftBillTotal = computed(() => {
  const item = props.orderItem;
  if (!item) return 0;
  return tableRows.value.reduce(
    (sum, row) => sum + parseQtyInput(row.global_stock_id),
    0,
  );
});

const tableRows = computed(() => {
  const item = props.orderItem;
  const base = rows.value.filter(
    (row) =>
      row.available_atp > 0 ||
      (row.already_picked ?? 0) > 0 ||
      billQtyOnThisBill(row.global_stock_id) > 0,
  );
  if (!item) return base;

  const seen = new Set(base.map((row) => stockKey(row.global_stock_id)));
  const extras: OrderItemPickStockRow[] = [];
  for (const line of billLinesForItem.value) {
    const stockId = catalogBillLineSourceStockId(line);
    const onBill = Number(line.quantity ?? 0);
    const key = stockKey(stockId);
    if (!key || onBill <= 0 || seen.has(key)) continue;
    seen.add(key);
    const linePickId = Number(line.line_meta?.shop_order_item_stock_pick_id ?? 0);
    extras.push({
      global_stock_id: stockId,
      shipment_item_id: line.shipment_item_id ?? 0,
      shipment_id: 0,
      shipment_name: line.name_snapshot?.trim() || 'On bill',
      item_name: line.name_snapshot ?? item.name,
      product_id: line.product_id ?? item.product_id,
      product_code: null,
      barcode: null,
      available_atp: 0,
      unit_cost_amount: 0,
      already_picked: 0,
      pick_id: linePickId > 0 ? linePickId : null,
    });
  }
  return [...base, ...extras];
});

const lineBelongsToOrderItem = (line: CatalogBillLineSourceRow, item: ShopOrderItem): boolean => {
  const pid = Number(item.product_id ?? 0);
  const linePid = Number(line.product_id ?? 0);
  if (pid > 0 && linePid === pid) return true;
  return Number(line.line_meta?.shop_order_item_id ?? 0) === Number(item.id);
};

const lineMatchesShownStock = (line: CatalogBillLineSourceRow, stockId: number): boolean => {
  if (stockId <= 0) return false;
  const sourceStock = catalogBillLineSourceStockId(line);
  const lineStock = Number(line.global_stock_id ?? 0);
  return sourceStock === stockId || lineStock === stockId;
};

const qtyOnBillForStockKey = (key: string): number | null => {
  if (!key) return null;
  if (!Object.prototype.hasOwnProperty.call(orderBillQtyByStockId.value, key)) return null;
  const qty = orderBillQtyByStockId.value[key];
  return qty > 0 ? qty : null;
};

/** Bill-line qty for shown stock id (RPC prefill, else draft billLines fallback). */
const billQtyForItemAndStock = (
  stockId: number | string | null | undefined,
): number | null => {
  const item = props.orderItem;
  const sid = Number(stockId ?? 0);
  if (!item || sid <= 0) return null;

  const fromApi = qtyOnBillForStockKey(stockKey(stockId));
  if (fromApi != null) return fromApi;

  let found = false;
  let sum = 0;
  for (const line of props.billLines) {
    if (!lineBelongsToOrderItem(line, item)) continue;
    if (!lineMatchesShownStock(line, sid)) continue;
    found = true;
    sum += Math.max(0, Math.trunc(Number(line.quantity ?? 0)));
  }
  return found ? sum : null;
};

const syncOrderBillQtyFromApi = async (stockRows: OrderItemPickStockRow[]) => {
  const item = props.orderItem;
  const tenantId = props.deskTenantId;
  const orderId = props.orderId;
  if (!item || tenantId == null || orderId <= 0) {
    orderBillQtyByStockId.value = {};
    return;
  }

  const stockIds = [
    ...new Set(stockRows.map((row) => Number(row.global_stock_id)).filter((id) => id > 0)),
  ];
  if (!stockIds.length) {
    orderBillQtyByStockId.value = {};
    return;
  }

  const results = await Promise.all(
    stockIds.map((globalStockId) =>
      shopOrderRepository.listShopOrderBillLinesForProductStock({
        tenantId,
        orderId,
        productId: item.product_id,
        globalStockId,
      }),
    ),
  );

  const next: Record<string, number> = {};
  for (let i = 0; i < stockIds.length; i++) {
    const res = results[i];
    if (!res?.success) continue;
    const lines = res.lines ?? [];
    const qty =
      props.billId > 0
        ? lines
            .filter((line) => Number(line.bill_id) === props.billId)
            .reduce((sum, line) => sum + Math.max(0, Math.trunc(Number(line.quantity ?? 0))), 0)
        : Math.max(0, Math.trunc(Number(res.total_quantity ?? 0)));
    next[stockKey(stockIds[i])] = qty;
  }
  orderBillQtyByStockId.value = next;
};

const billQtyOnThisBill = (sourceGlobalStockId: number | string) => {
  return billQtyForItemAndStock(sourceGlobalStockId) ?? 0;
};

const billLinesForItem = computed(() => {
  const item = props.orderItem;
  if (!item) return [];
  return props.billLines.filter((line) => lineBelongsToOrderItem(line, item));
});

const loadRows = async () => {
  if (!props.orderItem) return;
  loading.value = true;
  try {
    const result = await shopOrderRepository.listStockForOrderItemPick(props.orderItem.id, {
      productId: props.orderItem.product_id,
      limit: 50,
    });
    rows.value = result.data;
    await syncOrderBillQtyFromApi(result.data);
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to load stock'));
  } finally {
    loading.value = false;
  }
};

watch(
  () => [props.modelValue, props.orderItem?.id] as const,
  ([open]) => {
    if (open && props.orderItem) {
      qtyEditsByStockId.value = {};
      qtyTouchedByStockId.value = {};
      orderBillQtyByStockId.value = {};
      rows.value = [];
      void loadRows();
    }
  },
);

watch(
  () => [props.billLines, props.billId, props.modelValue] as const,
  async ([, , open]) => {
    if (open && rows.value.length > 0) {
      await syncOrderBillQtyFromApi(rows.value);
    }
  },
  { deep: true },
);

const close = () => emit('update:modelValue', false);

const parseQtyInput = (stockId: number | string): number => {
  const key = stockKey(stockId);
  if (key && Object.prototype.hasOwnProperty.call(qtyEditsByStockId.value, key)) {
    const raw = qtyEditsByStockId.value[key];
    const parsed = Math.trunc(Number(raw));
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }
  return billQtyForItemAndStock(stockId) ?? 0;
};

/** Empty string when no bill qty so the input stays blank (not 0). */
const displayQtyForRow = (stockId: number | string): number | '' => {
  const key = stockKey(stockId);
  if (key && Object.prototype.hasOwnProperty.call(qtyEditsByStockId.value, key)) {
    const raw = qtyEditsByStockId.value[key];
    if (raw == null || !Number.isFinite(Number(raw)) || Number(raw) <= 0) return '';
    return Number(raw);
  }
  const onBill = billQtyForItemAndStock(stockId);
  return onBill != null && onBill > 0 ? onBill : '';
};

const markQtyTouched = (stockId: number | string) => {
  const key = stockKey(stockId);
  if (!key) return;
  qtyTouchedByStockId.value = { ...qtyTouchedByStockId.value, [key]: true };
};

const onQtyChange = (stockId: number | string, value: number | string | null) => {
  const key = stockKey(stockId);
  if (!key) return;
  if (!qtyTouchedByStockId.value[key]) return;
  const parsed =
    value == null || (typeof value === 'string' && value.trim() === '')
      ? 0
      : Math.trunc(Number(value));
  qtyEditsByStockId.value = {
    ...qtyEditsByStockId.value,
    [key]: Number.isFinite(parsed) ? Math.max(0, parsed) : 0,
  };
};

const rowsNeedingUpdate = (): OrderItemPickStockRow[] =>
  tableRows.value.filter((row) => {
    const targetQty = parseQtyInput(row.global_stock_id);
    const current = billQtyOnThisBill(row.global_stock_id);
    return targetQty !== current;
  });

const onDone = async () => {
  const item = props.orderItem;
  const booksId = props.booksTenantId;
  if (!item || booksId == null || props.billId <= 0) {
    showErrorNotification('Open a draft bill first.');
    return;
  }

  const toApply = rowsNeedingUpdate();
  if (toApply.length === 0) {
    close();
    return;
  }

  saving.value = true;
  try {
    for (const row of toApply) {
      const targetQty = parseQtyInput(row.global_stock_id);
      const res = await shopOrderRepository.setCatalogDraftBillLineQtyFromStock({
        booksTenantId: booksId,
        billId: props.billId,
        orderItem: item,
        stockRow: row,
        quantity: targetQty,
      });
      if (!res.success) throw new Error('Update failed');
    }
    await syncOrderBillQtyFromApi(tableRows.value);
    emit('updated');
    close();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to update bill lines'));
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="catalog-bill-stock-dialog" style="width: min(640px, 94vw); border-radius: 12px">
      <q-card-section class="row items-start no-wrap q-pb-sm">
        <div class="col min-width-0">
          <div class="text-subtitle1 text-weight-bold ellipsis">
            {{ orderItem?.name ?? 'Bill stock' }}
          </div>
          <div class="text-caption text-grey-7 q-mt-xs">
            Need {{ neededQuantity }}
            · {{ onThisBillQuantity }} on this bill
            <span v-if="draftBillTotal > 0"> · {{ draftBillTotal }} in form</span>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" class="q-ml-sm" aria-label="Close" @click="close" />
      </q-card-section>

      <q-separator />

      <q-card-section class="q-pt-sm">
        <q-table
          flat
          dense
          row-key="global_stock_id"
          :rows="tableRows"
          :columns="[
            {
              name: 'shipment',
              label: 'Shipment',
              field: 'shipment_name',
              align: 'left',
              style: 'width: auto',
            },
            {
              name: 'avail',
              label: 'Avail',
              field: 'available_atp',
              align: 'center',
              headerStyle: 'width: 4.5rem',
              style: 'width: 4.5rem',
            },
            {
              name: 'qty',
              label: 'Qty',
              field: 'global_stock_id',
              align: 'center',
              headerStyle: 'width: 5.5rem',
              style: 'width: 5.5rem',
            },
          ]"
          :loading="loading"
          hide-pagination
          :pagination="{ rowsPerPage: 0 }"
          class="catalog-bill-stock-dialog__table"
        >
          <template #body-cell-shipment="props">
            <q-td :props="props">
              <div class="text-body2">{{ props.row.shipment_name }}</div>
              <div class="text-caption text-grey-6">#{{ props.row.global_stock_id }}</div>
              <div
                v-if="billQtyOnThisBill(props.row.global_stock_id) > 0"
                class="text-caption text-positive"
              >
                {{ billQtyOnThisBill(props.row.global_stock_id) }} on this bill
              </div>
            </q-td>
          </template>

          <template #body-cell-avail="props">
            <q-td :props="props" class="text-center text-body2 catalog-bill-stock-dialog__num">
              {{ props.row.available_atp }}
            </q-td>
          </template>

          <template #body-cell-qty="cell">
            <q-td :props="cell" class="text-center">
              <q-input
                :model-value="displayQtyForRow(cell.row.global_stock_id)"
                type="number"
                dense
                outlined
                min="0"
                hide-bottom-space
                class="catalog-bill-stock-dialog__qty-input"
                input-class="text-center"
                @focus="markQtyTouched(cell.row.global_stock_id)"
                @update:model-value="onQtyChange(cell.row.global_stock_id, $event)"
              />
            </q-td>
          </template>

          <template #no-data>
            <div class="text-caption text-grey-6 q-pa-md text-center">
              {{ loading ? 'Loading…' : 'No sellable stock for this product.' }}
            </div>
          </template>
        </q-table>
      </q-card-section>

      <q-separator />

      <q-card-actions align="between" class="q-px-md q-py-sm">
        <q-btn flat no-caps color="grey-8" label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Done"
          style="border-radius: 8px"
          :loading="saving"
          @click="onDone"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<style scoped>
.catalog-bill-stock-dialog__table :deep(thead tr) {
  height: 36px;
}

.catalog-bill-stock-dialog__table :deep(tbody tr) {
  height: 52px;
}

.catalog-bill-stock-dialog__table :deep(thead th) {
  vertical-align: middle;
}

.catalog-bill-stock-dialog__table :deep(tbody td) {
  vertical-align: middle;
}

.catalog-bill-stock-dialog__num {
  white-space: nowrap;
}

.catalog-bill-stock-dialog__qty-input {
  width: 4.25rem;
  margin: 0 auto;
}

.catalog-bill-stock-dialog__qty-input :deep(input[type='number']) {
  -moz-appearance: textfield;
  appearance: textfield;
}

.catalog-bill-stock-dialog__qty-input :deep(input[type='number']::-webkit-outer-spin-button),
.catalog-bill-stock-dialog__qty-input :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}
</style>