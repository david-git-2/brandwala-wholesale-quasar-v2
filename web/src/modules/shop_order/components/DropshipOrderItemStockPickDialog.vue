<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { shopOrderRepository, type OrderItemPickStockRow } from '../repositories/shopOrderRepository';
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
const rows = ref<OrderItemPickStockRow[]>([]);
const meta = ref<Record<string, unknown>>({});
const qtyByStockId = ref<Record<number, number>>({});

const parseNum = (value: unknown, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const remainingToPick = computed(() => parseNum(meta.value.remaining_to_pick));
const orderedQty = computed(() => props.orderItem?.quantity ?? 0);
const pickedTotal = computed(() => parseNum(meta.value.already_picked_total));

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
    if (remainingToPick.value <= 0) close();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to add pick'));
  } finally {
    addingStockId.value = null;
  }
};
</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: min(920px, 96vw); max-width: 960px">
      <q-card-section class="row items-center q-pb-none">
        <div>
          <div class="text-h6">Pick stock</div>
          <div v-if="orderItem" class="text-caption text-grey-7">
            {{ orderItem.name }} · ordered {{ orderedQty }} · picked {{ pickedTotal }} · remaining
            {{ remainingToPick }}
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
          placeholder="Search shipment, barcode, code…"
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
            { name: 'item', label: 'Item', field: 'item_name', align: 'left' },
            { name: 'atp', label: 'ATP', field: 'available_atp', align: 'right' },
            { name: 'picked', label: 'Picked', field: 'already_picked', align: 'right' },
            { name: 'cost', label: 'Cost', field: 'unit_cost_amount', align: 'right' },
            { name: 'qty', label: 'Qty', field: 'global_stock_id', align: 'center' },
            { name: 'action', label: '', field: 'global_stock_id', align: 'right' },
          ]"
          :loading="loading"
          :pagination="{ rowsPerPage: 10 }"
          no-data-label="No matching sellable stock for this line."
        >
          <template #body-cell-atp="props">
            <q-td :props="props">{{ props.row.available_atp }}</q-td>
          </template>
          <template #body-cell-picked="props">
            <q-td :props="props">{{ props.row.already_picked || 0 }}</q-td>
          </template>
          <template #body-cell-cost="props">
            <q-td :props="props">{{ Number(props.row.unit_cost_amount || 0).toFixed(2) }}</q-td>
          </template>
          <template #body-cell-qty="props">
            <q-td :props="props">
              <q-input
                v-model.number="qtyByStockId[props.row.global_stock_id]"
                type="number"
                min="1"
                :max="props.row.available_atp"
                dense
                outlined
                style="width: 72px"
                input-class="text-center"
              />
            </q-td>
          </template>
          <template #body-cell-action="props">
            <q-td :props="props">
              <q-btn
                color="primary"
                unelevated
                no-caps
                dense
                label="Add"
                :loading="addingStockId === props.row.global_stock_id"
                :disable="remainingToPick <= 0"
                @click="addPick(props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>
