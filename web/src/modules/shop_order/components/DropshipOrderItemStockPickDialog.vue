<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  shopOrderRepository,
  type OrderItemPickStockRow,
  type ActiveStockPick,
  type ListStockForOrderItemPickMeta,
} from '../repositories/shopOrderRepository';
import type { ShopOrderItem } from '../types';
import { overlayPickListWithDraft } from '../utils/dropshipPickListDraftOverlay';
import { showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  orderItem: ShopOrderItem | null;
  draftPicks: ActiveStockPick[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'draft-add', payload: { row: OrderItemPickStockRow; quantity: number }): void;
  (e: 'draft-remove', pickId: number): void;
  (e: 'mark-unavailable'): void;
}>();

const loading = ref(false);
const serverRows = ref<OrderItemPickStockRow[]>([]);
const serverMeta = ref<ListStockForOrderItemPickMeta>({});
const qtyByStockId = ref<Record<number, number>>({});

const orderedQty = computed(() => props.orderItem?.quantity ?? 0);

const overlaid = computed(() =>
  overlayPickListWithDraft(
    { data: serverRows.value, meta: serverMeta.value },
    props.draftPicks,
    orderedQty.value,
  ),
);

const rows = computed(() => overlaid.value.data);
const meta = computed(() => overlaid.value.meta);

const parseNum = (value: unknown, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const remainingToPick = computed(() => parseNum(meta.value.remaining_to_pick));
const pickedTotal = computed(() => parseNum(meta.value.already_picked_total));
const activePicks = computed<ActiveStockPick[]>(() => meta.value.active_picks ?? []);
const isFullyPicked = computed(() => remainingToPick.value <= 0 && pickedTotal.value >= orderedQty.value);

const tableRows = computed(() =>
  rows.value.filter((row) => row.available_atp > 0 || (row.already_picked ?? 0) > 0),
);

const loadRows = async () => {
  if (!props.orderItem) return;
  loading.value = true;
  try {
    const result = await shopOrderRepository.listStockForOrderItemPick(props.orderItem.id, {
      limit: 50,
    });
    serverRows.value = result.data;
    serverMeta.value = result.meta;
    for (const row of result.data) {
      if (qtyByStockId.value[row.global_stock_id] == null) {
        const cap = Math.max(remainingToPick.value, 1);
        qtyByStockId.value[row.global_stock_id] = Math.min(cap, row.available_atp);
      }
    }
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to load stock'));
  } finally {
    loading.value = false;
  }
};

watch(
  () => props.modelValue,
  (open) => {
    if (open && props.orderItem) {
      qtyByStockId.value = {};
      void loadRows();
    }
  },
);

const close = () => emit('update:modelValue', false);

const addPick = (row: OrderItemPickStockRow) => {
  if (!props.orderItem) return;
  const qty = Math.trunc(qtyByStockId.value[row.global_stock_id] ?? 0);
  if (qty <= 0) {
    showErrorNotification('Enter a quantity greater than zero.');
    return;
  }
  if (qty > row.available_atp) {
    showErrorNotification(`Only ${row.available_atp} available.`);
    return;
  }
  if (qty > remainingToPick.value) {
    showErrorNotification(`Only ${remainingToPick.value} left on this line.`);
    return;
  }

  emit('draft-add', { row, quantity: qty });
};

const removePick = (pickId: number) => {
  emit('draft-remove', pickId);
};

const canAddRow = (row: OrderItemPickStockRow) =>
  remainingToPick.value > 0 && row.available_atp > 0;
</script>

<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="stock-pick-dialog" style="width: min(640px, 94vw); border-radius: 12px">
      <q-card-section class="row items-start no-wrap q-pb-sm">
        <div class="col min-width-0">
          <div class="text-subtitle1 text-weight-bold ellipsis">
            {{ orderItem?.name ?? 'Pick stock' }}
          </div>
          <div class="text-caption text-grey-7 q-mt-xs">
            Need {{ orderedQty }} · Picked {{ pickedTotal }}
            <span v-if="remainingToPick > 0"> · {{ remainingToPick }} left</span>
          </div>
        </div>
        <q-chip
          dense
          :color="isFullyPicked ? 'positive' : 'orange-9'"
          text-color="white"
          class="q-ml-sm"
        >
          {{ isFullyPicked ? 'Done' : 'Pending' }}
        </q-chip>
        <q-btn flat round dense icon="ph ph-x" class="q-ml-xs" aria-label="Close" @click="close" />
      </q-card-section>

      <q-separator />

      <q-card-section v-if="activePicks.length" class="q-py-sm">
        <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Allocated</div>
        <div class="column q-gutter-y-xs">
          <div
            v-for="pick in activePicks"
            :key="pick.id"
            class="stock-pick-dialog__alloc row items-center no-wrap q-px-sm q-py-xs rounded-borders"
          >
            <span class="col ellipsis text-body2">
              {{ pick.shipment_name }}
              <span class="text-grey-6">· {{ pick.quantity }} pc</span>
            </span>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="ph ph-x"
              color="grey-7"
              aria-label="Remove allocation"
              @click="removePick(pick.id)"
            />
          </div>
        </div>
      </q-card-section>

      <template v-if="!isFullyPicked">
        <q-separator v-if="activePicks.length" />
        <q-card-section class="q-pt-sm">
          <q-table
            flat
            dense
            row-key="global_stock_id"
            :rows="tableRows"
            :columns="[
              { name: 'stock', label: 'Shipment', field: 'shipment_name', align: 'left' },
              { name: 'avail', label: 'Avail', field: 'available_atp', align: 'center' },
              { name: 'pick', label: '', field: 'global_stock_id', align: 'right' },
            ]"
            :loading="loading"
            hide-pagination
            :pagination="{ rowsPerPage: 0 }"
            class="stock-pick-dialog__table"
          >
            <template #body-cell-stock="props">
              <q-td :props="props">
                <div class="text-body2">{{ props.row.shipment_name }}</div>
                <div class="text-caption text-grey-6">
                  #{{ props.row.global_stock_id }}
                  <span v-if="props.row.already_picked > 0" class="text-positive">
                    · {{ props.row.already_picked }} here
                  </span>
                </div>
              </q-td>
            </template>

            <template #body-cell-avail="props">
              <q-td :props="props" class="text-center text-body2">
                {{ props.row.available_atp }}
              </q-td>
            </template>

            <template #body-cell-pick="props">
              <q-td :props="props">
                <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                  <q-input
                    v-model.number="qtyByStockId[props.row.global_stock_id]"
                    type="number"
                    dense
                    outlined
                    min="0"
                    :max="Math.min(props.row.available_atp, remainingToPick)"
                    :disable="!canAddRow(props.row)"
                    style="width: 56px"
                    input-class="text-center"
                  />
                  <q-btn
                    flat
                    dense
                    round
                    color="primary"
                    icon="ph ph-plus"
                    aria-label="Add"
                    :disable="!canAddRow(props.row)"
                    @click="addPick(props.row)"
                  />
                </div>
              </q-td>
            </template>

            <template #no-data>
              <div class="text-caption text-grey-6 q-pa-md text-center">
                {{ loading ? 'Loading…' : 'No sellable stock found.' }}
              </div>
            </template>
          </q-table>
        </q-card-section>
      </template>

      <q-separator />

      <q-card-actions align="between" class="q-px-md q-py-sm">
        <q-btn
          flat
          dense
          no-caps
          color="negative"
          label="Line unavailable"
          @click="emit('mark-unavailable')"
        />
        <q-btn unelevated no-caps color="primary" label="Done" style="border-radius: 8px" @click="close" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<style scoped>
.stock-pick-dialog__alloc {
  background: var(--tf-theme-primary-soft, rgba(16, 185, 129, 0.08));
  border: 1px solid var(--tf-theme-border, rgba(0, 0, 0, 0.08));
}

.stock-pick-dialog__table :deep(thead tr) {
  height: 36px;
}

.stock-pick-dialog__table :deep(tbody tr) {
  height: 48px;
}

body.body--dark .stock-pick-dialog__alloc {
  background: rgba(16, 185, 129, 0.12);
}
</style>
