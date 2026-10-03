<template>
  <FilterSidebar
    v-model="isOpen"
    :title="drawerTitle"
    width="min(420px, 92vw)"
    :z-index="6000"
    @update:model-value="onDrawerToggle"
  >
    <div v-if="stockRow" class="column q-gutter-y-md">
      <div class="bg-grey-2 q-pa-md rounded-borders">
        <div class="text-caption text-grey-7 text-weight-medium">Product</div>
        <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-xs">{{ stockRow.item_name }}</div>
        <div v-if="stockRow.product_code" class="text-caption text-grey-7 font-mono q-mt-xs">
          {{ stockRow.product_code }}
        </div>
        <div class="text-caption text-grey-7 q-mt-xs">
          Grade: {{ gradeLabel }} · {{ formatStockAvailability(stockRow.availability) }}
        </div>
      </div>

      <template v-if="step === 'location'">
        <div v-if="siblingLots.length > 1" class="column q-gutter-y-sm">
          <div class="text-caption text-grey-7 text-weight-medium">
            Bins for this lot ({{ totalQtyAcrossBins }} total)
          </div>
          <q-list bordered separator class="rounded-borders">
            <q-item
              v-for="lot in siblingLots"
              :key="lot.id"
              dense
              :class="lot.id === stockRow.id ? 'bg-primary-1' : ''"
            >
              <q-item-section>
                <q-item-label class="text-weight-medium">
                  {{ binLabel(lot) }}
                  <q-badge
                    v-if="lot.id === stockRow.id"
                    color="primary"
                    outline
                    class="q-ml-xs"
                    label="This row"
                  />
                </q-item-label>
                <q-item-label caption style="line-height: 1.4">
                  {{ binPath(lot) }}
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-item-label class="text-weight-bold text-primary">{{ lot.quantity }}</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
          <div v-if="warehouseListIncomplete" class="text-caption bw-text-muted">
            Scroll the warehouse list to load more rows — other bins may not show yet.
          </div>
        </div>

        <div class="column q-gutter-y-sm">
          <div class="text-caption text-grey-7 text-weight-medium">This row’s place</div>
          <StockLocationHierarchyFields
            :locations="stockLocationStore.items"
            :location-id="stockRow.location_id"
          />
        </div>

        <div class="row q-col-gutter-md">
          <div class="col-6">
            <div class="text-caption text-grey-7">Qty here</div>
            <div class="text-h6 text-weight-bold text-primary">{{ stockRow.quantity }}</div>
          </div>
          <div class="col-6">
            <div class="text-caption text-grey-7">Sell status</div>
            <div class="text-body2 text-weight-medium text-grey-9">
              {{ formatStockAvailability(stockRow.availability) }}
            </div>
          </div>
        </div>

        <q-btn
          color="primary"
          unelevated
          no-caps
          class="full-width"
          icon="ph ph-plus-circle"
          label="Put quantity in another bin"
          @click="openTransferForm('split')"
        />
        <q-btn
          outline
          color="primary"
          no-caps
          class="full-width"
          icon="ph ph-map-pin-line"
          label="Move all from this bin"
          @click="openTransferForm('move_all')"
        />
      </template>

      <template v-else>
        <div class="text-caption text-grey-7">
          From: <span class="text-weight-medium text-grey-9">{{ currentLeafLabel }}</span>
          <span v-if="transferMode === 'split'" class="q-ml-xs">(split — qty stays in both bins)</span>
        </div>

        <q-form class="column q-gutter-y-md" @submit.prevent="onConfirm">
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Quantity to move</div>
            <q-input
              v-model.number="moveQty"
              type="number"
              outlined
              dense
              :rules="[
                (val) => val > 0 || 'Quantity must be > 0',
                (val) => val <= (stockRow?.quantity || 0) || `Cannot exceed ${stockRow?.quantity}`,
              ]"
            />
          </div>

          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">
              Destination (warehouse → zone → shelf → level → bin)
            </div>
            <StockLocationHierarchyPicker
              v-model="targetLocationId"
              :locations="stockLocationStore.items"
              :exclude-ids="excludeDestinationIds"
            />
          </div>

          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Notes (optional)</div>
            <q-input
              v-model="notes"
              type="textarea"
              outlined
              dense
              rows="2"
              placeholder="e.g. Split across shelf B-04"
            />
          </div>

          <div class="row q-gutter-x-sm q-pt-xs">
            <q-btn flat no-caps color="grey-7" class="col" label="Back" @click="step = 'location'" />
            <q-btn
              type="submit"
              color="primary"
              unelevated
              no-caps
              class="col"
              :loading="submitting"
              :label="confirmLabel"
            />
          </div>
        </q-form>
      </template>
    </div>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import StockLocationHierarchyFields from './StockLocationHierarchyFields.vue';
import StockLocationHierarchyPicker from './StockLocationHierarchyPicker.vue';
import type { GlobalStock } from '../repositories/globalStockRepository';
import { globalStockRepository } from '../repositories/globalStockRepository';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { formatStockAvailability } from '../constants/stockAvailability';
import { findStockLotsInOtherBins } from '../utils/stockLotGrain';
import { formatStockLocationPath } from '../utils/stockLocationOptions';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  stockRow: GlobalStock | null;
  tenantId: number;
  /** Loaded warehouse rows — used to show other bins for the same lot grain. */
  warehouseStockRows?: GlobalStock[];
  warehouseListIncomplete?: boolean;
  gradeLabel?: string;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'updated'): void;
}>();

const stockLocationStore = useStockLocationStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

type Step = 'location' | 'transfer';
type TransferMode = 'split' | 'move_all';

const step = ref<Step>('location');
const transferMode = ref<TransferMode>('split');

const moveQty = ref<number>(1);
const targetLocationId = ref<number | null>(null);
const notes = ref<string>('');
const submitting = ref<boolean>(false);

const gradeLabel = computed(() => props.gradeLabel ?? props.stockRow?.grade_name ?? 'Standard');

const siblingLots = computed(() => {
  if (!props.stockRow || !props.warehouseStockRows?.length) {
    return props.stockRow ? [props.stockRow] : [];
  }
  return findStockLotsInOtherBins(props.warehouseStockRows, props.stockRow);
});

const totalQtyAcrossBins = computed(() =>
  siblingLots.value.reduce((sum, lot) => sum + (lot.quantity ?? 0), 0),
);

const warehouseListIncomplete = computed(() => Boolean(props.warehouseListIncomplete));

const drawerTitle = computed(() => {
  if (step.value === 'location') return 'Stock locations';
  return transferMode.value === 'split' ? 'Put qty in another bin' : 'Move to another bin';
});

const confirmLabel = computed(() =>
  transferMode.value === 'split' ? 'Confirm split' : 'Confirm move',
);

const excludeDestinationIds = computed(() => {
  const ids: number[] = [];
  const currentId = props.stockRow?.location_id;
  if (currentId != null) ids.push(currentId);
  return ids;
});

const currentLeafLabel = computed(() => {
  const id = props.stockRow?.location_id;
  if (id == null) return props.stockRow?.location_name || '—';
  const loc = stockLocationStore.items.find((item) => item.id === id);
  if (loc) return `${loc.code} — ${loc.name}`;
  return props.stockRow?.location_name || '—';
});

const binLabel = (lot: GlobalStock) => {
  const id = lot.location_id;
  if (id == null) return lot.location_name || '—';
  const loc = stockLocationStore.items.find((item) => item.id === id);
  if (loc) return `${loc.code} — ${loc.name}`;
  return lot.location_name || `#${id}`;
};

const binPath = (lot: GlobalStock) =>
  formatStockLocationPath(stockLocationStore.items, lot.location_id);

const resetForm = () => {
  step.value = 'location';
  transferMode.value = 'split';
  if (props.stockRow) {
    moveQty.value = 1;
    targetLocationId.value = null;
    notes.value = '';
  }
};

const ensureLocationsLoaded = async () => {
  if (!props.tenantId || stockLocationStore.items.length > 0) return;
  try {
    await stockLocationStore.fetchLocations(props.tenantId, true);
  } catch (err: unknown) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to load locations');
  }
};

const openTransferForm = (mode: TransferMode) => {
  if (props.stockRow) {
    transferMode.value = mode;
    moveQty.value = mode === 'move_all' ? props.stockRow.quantity : 1;
    targetLocationId.value = null;
    notes.value = '';
  }
  step.value = 'transfer';
};

const onDrawerToggle = (open: boolean) => {
  if (!open) resetForm();
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      resetForm();
      void ensureLocationsLoaded();
    }
  },
);

const onConfirm = async () => {
  if (!props.stockRow || !props.tenantId || !targetLocationId.value) return;
  if (targetLocationId.value === props.stockRow.location_id) {
    showErrorNotification('Choose a different bin than the current one');
    return;
  }

  submitting.value = true;
  try {
    await globalStockRepository.createAndPostMovement({
      tenantId: props.tenantId,
      stockId: props.stockRow.id,
      quantity: moveQty.value,
      toLocationId: targetLocationId.value,
      toAvailability: props.stockRow.availability ?? null,
      toGradeTagId: props.stockRow.grade_tag_id ?? null,
      movementType: 'location_transfer',
      notes: notes.value.trim() || null,
    });

    showSuccessNotification(
      transferMode.value === 'split'
        ? 'Quantity is now in both bins'
        : 'Stock moved to the new bin',
    );
    isOpen.value = false;
    emit('updated');
  } catch (err: unknown) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to transfer location');
  } finally {
    submitting.value = false;
  }
};
</script>
