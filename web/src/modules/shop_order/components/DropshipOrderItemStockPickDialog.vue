<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  shopOrderRepository,
  type OrderItemPickStockRow,
  type ActiveStockPick,
  type ListStockForOrderItemPickMeta,
} from '../repositories/shopOrderRepository';
import type { ShopOrderItem } from '../types';
import { showErrorNotification, showSuccessNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  orderItem: ShopOrderItem | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'picked'): void;
}>();

const search = ref('');
const loading = ref(false);
const addingStockId = ref<number | null>(null);
const removingPickId = ref<number | null>(null);
const rows = ref<OrderItemPickStockRow[]>([]);
const meta = ref<ListStockForOrderItemPickMeta>({});
const qtyByStockId = ref<Record<number, number>>({});

const parseNum = (value: unknown, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const remainingToPick = computed(() => parseNum(meta.value.remaining_to_pick));
const orderedQty = computed(() => props.orderItem?.quantity ?? 0);
const pickedTotal = computed(() => parseNum(meta.value.already_picked_total));
const activePicks = computed<ActiveStockPick[]>(() => meta.value.active_picks ?? []);
const isFullyPicked = computed(() => remainingToPick.value <= 0 && pickedTotal.value >= orderedQty.value);

const loadRows = async () => {
  if (!props.orderItem) return;
  loading.value = true;
  try {
    const result = await shopOrderRepository.listStockForOrderItemPick(props.orderItem.id, {
      search: search.value,
      limit: 50,
    });
    rows.value = result.data;
    meta.value = result.meta;
    for (const row of result.data) {
      if (qtyByStockId.value[row.global_stock_id] == null) {
        qtyByStockId.value[row.global_stock_id] = Math.min(
          Math.max(remainingToPick.value, 1),
          row.available_atp,
        );
      }
    }
  } catch (err) {
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

watch(
  () => props.modelValue,
  (open) => {
    if (open && props.orderItem) {
      search.value = '';
      qtyByStockId.value = {};
      void loadRows();
    }
  },
);

watch(search, () => debouncedLoad());

const close = () => emit('update:modelValue', false);

const addPick = async (row: OrderItemPickStockRow) => {
  if (!props.orderItem) return;
  const qty = Math.trunc(qtyByStockId.value[row.global_stock_id] ?? 0);
  if (qty <= 0) {
    showErrorNotification('Enter a quantity greater than zero.');
    return;
  }
  if (qty > row.available_atp) {
    showErrorNotification(`Only ${row.available_atp} units available on this stock row.`);
    return;
  }

  addingStockId.value = row.global_stock_id;
  try {
    await shopOrderRepository.addShopOrderItemStockPick(props.orderItem.id, row.global_stock_id, qty);
    showSuccessNotification('Stock linked and held.');
    emit('picked');
    await loadRows();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to add pick'));
  } finally {
    addingStockId.value = null;
  }
};

const removePick = async (pickId: number) => {
  removingPickId.value = pickId;
  try {
    await shopOrderRepository.removeShopOrderItemStockPick(pickId);
    showSuccessNotification('Pick removed and stock hold released.');
    emit('picked');
    await loadRows();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to remove pick'));
  } finally {
    removingPickId.value = null;
  }
};
</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: min(960px, 96vw); max-width: 1040px; border-radius: 12px">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-pb-sm bg-grey-1 border-bottom">
        <div>
          <div class="row items-center q-gutter-x-sm">
            <span class="text-h6 text-weight-bold">Stock Picker</span>
            <q-badge
              :color="isFullyPicked ? 'positive' : 'orange-9'"
              text-color="white"
              class="text-weight-bold q-px-sm q-py-xs"
            >
              {{ isFullyPicked ? 'Fully Picked' : `Pending (${remainingToPick} needed)` }}
            </q-badge>
          </div>
          <div v-if="orderItem" class="text-caption text-grey-8 q-mt-xs">
            <span class="text-weight-bold text-grey-10">{{ orderItem.name }}</span>
            <span v-if="orderItem.sku" class="q-ml-sm">· SKU: {{ orderItem.sku }}</span>
            <span v-if="orderItem.barcode" class="q-ml-sm">· Barcode: {{ orderItem.barcode }}</span>
            <span class="q-ml-sm font-mono">
              (Ordered: <strong>{{ orderedQty }}</strong> | Picked: <strong>{{ pickedTotal }}</strong> | Remaining: <strong>{{ remainingToPick }}</strong>)
            </span>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" @click="close" />
      </q-card-section>

      <!-- Active Picked Stock Section -->
      <q-card-section v-if="activePicks.length > 0" class="q-pb-none">
        <div class="picked-section q-pa-sm rounded-borders bg-green-1 border-green">
          <div class="row items-center justify-between q-mb-xs">
            <div class="row items-center q-gutter-x-xs text-weight-bold text-green-10">
              <q-icon name="ph ph-check-circle" size="18px" color="positive" />
              <span>Currently Picked Stock ({{ activePicks.length }} allocation{{ activePicks.length > 1 ? 's' : '' }})</span>
            </div>
            <span class="text-caption text-weight-medium text-green-9">
              Total Picked: {{ pickedTotal }} / {{ orderedQty }} units
            </span>
          </div>

          <div class="row q-col-gutter-sm q-mt-xs">
            <div v-for="pick in activePicks" :key="pick.id" class="col-12 col-md-6">
              <div class="active-pick-card row items-center justify-between q-pa-sm bg-white rounded-borders shadow-1">
                <div class="column q-gutter-y-none ellipsis">
                  <div class="row items-center q-gutter-x-xs no-wrap ellipsis">
                    <span class="text-weight-bold text-grey-9 ellipsis">{{ pick.shipment_name }}</span>
                    <span class="text-grey-6 font-mono text-caption">#{{ pick.global_stock_id }}</span>
                  </div>
                  <div class="text-caption text-grey-7">
                    <span class="text-weight-bold text-positive">{{ pick.quantity }} units</span>
                    <span v-if="pick.unit_cost_amount != null" class="q-ml-xs">
                      · Cost: ৳{{ Number(pick.unit_cost_amount).toFixed(2) }}
                    </span>
                  </div>
                </div>

                <q-btn
                  flat
                  dense
                  no-caps
                  color="negative"
                  icon="ph ph-trash"
                  label="Remove"
                  class="text-weight-bold"
                  style="border-radius: 6px"
                  :loading="removingPickId === pick.id"
                  @click="removePick(pick.id)"
                >
                  <q-tooltip>Remove this pick and release held stock</q-tooltip>
                </q-btn>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>

      <!-- Search & Available Warehouse Stock -->
      <q-card-section>
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle2 text-weight-bold text-grey-8">
            Available Sellable Stock
          </div>
          <span class="text-caption text-grey-6">
            Pick stock to allocate items from received shipments
          </span>
        </div>

        <q-input
          v-model="search"
          dense
          outlined
          clearable
          placeholder="Search by shipment name, barcode, product code…"
          class="q-mb-md"
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
          :columns="[
            { name: 'shipment', label: 'Shipment', field: 'shipment_name', align: 'left' },
            { name: 'item', label: 'Item Details', field: 'item_name', align: 'left' },
            { name: 'atp', label: 'Available ATP', field: 'available_atp', align: 'center' },
            { name: 'picked', label: 'Allocated', field: 'already_picked', align: 'center' },
            { name: 'cost', label: 'Cost', field: 'unit_cost_amount', align: 'right' },
            { name: 'qty', label: 'Pick Qty', field: 'global_stock_id', align: 'center' },
            { name: 'action', label: 'Actions', field: 'global_stock_id', align: 'right' },
          ]"
          :loading="loading"
          :pagination="{ rowsPerPage: 10 }"
          no-data-label="No matching sellable inventory found for this product grade."
        >
          <template #body-cell-shipment="props">
            <q-td :props="props">
              <div class="text-weight-bold text-grey-9">{{ props.row.shipment_name }}</div>
              <div class="text-caption text-grey-6 font-mono">Stock #{{ props.row.global_stock_id }}</div>
            </q-td>
          </template>

          <template #body-cell-item="props">
            <q-td :props="props">
              <div class="row items-center q-gutter-x-xs">
                <span>{{ props.row.item_name }}</span>
                <q-badge
                  v-if="props.row.stock_grade"
                  :style="props.row.stock_grade.color ? { backgroundColor: props.row.stock_grade.color } : undefined"
                  :label="props.row.stock_grade.label || props.row.stock_grade.slug"
                />
              </div>
              <div v-if="props.row.product_code || props.row.barcode" class="text-caption text-grey-6">
                <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                <span v-if="props.row.barcode" class="q-ml-xs">· Barcode: {{ props.row.barcode }}</span>
              </div>
            </q-td>
          </template>

          <template #body-cell-atp="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="props.row.available_atp > 0 ? 'positive' : 'grey-5'"
                class="text-weight-bold font-mono"
              >
                {{ props.row.available_atp }} units
              </q-badge>
            </q-td>
          </template>

          <template #body-cell-picked="props">
            <q-td :props="props" class="text-center">
              <q-badge
                v-if="props.row.already_picked > 0"
                color="blue-8"
                text-color="white"
                class="text-weight-bold font-mono"
              >
                {{ props.row.already_picked }} picked
              </q-badge>
              <span v-else class="text-grey-5">—</span>
            </q-td>
          </template>

          <template #body-cell-cost="props">
            <q-td :props="props" class="text-right font-mono">
              ৳{{ Number(props.row.unit_cost_amount || 0).toFixed(2) }}
            </q-td>
          </template>

          <template #body-cell-qty="props">
            <q-td :props="props" class="text-center">
              <q-input
                v-model.number="qtyByStockId[props.row.global_stock_id]"
                type="number"
                min="1"
                :max="props.row.available_atp"
                dense
                outlined
                style="width: 72px; margin: 0 auto"
                input-class="text-center"
                :disable="props.row.available_atp <= 0 || remainingToPick <= 0"
              />
            </q-td>
          </template>

          <template #body-cell-action="props">
            <q-td :props="props" class="text-right">
              <div class="row items-center justify-end q-gutter-x-xs no-wrap">
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  dense
                  icon="ph ph-plus"
                  label="Pick"
                  class="text-weight-bold q-px-sm"
                  style="border-radius: 6px"
                  :loading="addingStockId === props.row.global_stock_id"
                  :disable="remainingToPick <= 0 || props.row.available_atp <= 0"
                  @click="addPick(props.row)"
                />

                <q-btn
                  v-if="props.row.pick_id"
                  flat
                  dense
                  no-caps
                  color="negative"
                  icon="ph ph-trash"
                  label="Remove"
                  class="text-weight-bold"
                  style="border-radius: 6px"
                  :loading="removingPickId === props.row.pick_id"
                  @click="removePick(props.row.pick_id)"
                >
                  <q-tooltip>Remove this pick allocation</q-tooltip>
                </q-btn>
              </div>
            </q-td>
          </template>
        </q-table>
      </q-card-section>

      <!-- Footer -->
      <q-card-actions align="right" class="q-pa-md bg-grey-1 border-top">
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Done"
          class="text-weight-bold q-px-lg"
          style="border-radius: 8px"
          @click="close"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-top {
  border-top: 1px solid #e2e8f0;
}
.border-green {
  border: 1px solid #86efac;
}
.active-pick-card {
  border: 1px solid #e2e8f0;
  border-left: 3px solid #10b981;
}
</style>

