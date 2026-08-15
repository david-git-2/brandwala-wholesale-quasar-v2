<template>
  <q-dialog v-model="isOpen" persistent @show="onShow">
    <q-card style="width: 460px; max-width: 95vw;" class="q-pa-sm">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
          <q-icon name="ph ph-map-pin-line" color="primary" size="24px" />
          <span>Transfer Location</span>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <!-- Source Stock Summary -->
        <div v-if="stockRow" class="bg-grey-2 q-pa-sm rounded-borders q-mb-md">
          <div class="text-caption text-grey-7 text-weight-medium uppercase">Source Stock</div>
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-xs">{{ stockRow.item_name }}</div>
          <div class="row items-center justify-between text-caption text-grey-7 q-mt-xs">
            <div>Current Loc: <strong>{{ stockRow.location_name || 'Main Warehouse' }}</strong></div>
            <div>Qty: <strong class="text-primary">{{ stockRow.quantity }} pcs</strong></div>
          </div>
        </div>

        <q-form class="q-gutter-y-md" @submit.prevent="onConfirm">
          <!-- Quantity to Move -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Quantity to Move</div>
            <q-input
              v-model.number="moveQty"
              type="number"
              filled
              dense
              :rules="[
                (val) => val > 0 || 'Quantity must be > 0',
                (val) => val <= (stockRow?.quantity || 0) || `Cannot exceed ${stockRow?.quantity} pcs`
              ]"
            />
          </div>

          <!-- Target Location -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">New Target Location</div>
            <q-select
              v-model="targetLocationId"
              :options="locationOptions"
              emit-value
              map-options
              filled
              dense
              :rules="[(val) => !!val || 'Target location is required']"
            />
          </div>

          <!-- Notes -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Notes / Reason (Optional)</div>
            <q-input
              v-model="notes"
              type="textarea"
              filled
              dense
              rows="2"
              placeholder="e.g. Moved to shelf B-04"
            />
          </div>

          <div class="row justify-end q-gutter-x-sm q-pt-sm">
            <q-btn v-close-popup flat label="Cancel" color="grey-7" no-caps />
            <q-btn
              type="submit"
              color="primary"
              unelevated
              no-caps
              :loading="submitting"
              label="Transfer Location"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type { GlobalStock } from '../repositories/globalStockRepository';
import { globalStockRepository } from '../repositories/globalStockRepository';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { getLeafLocations, toLocationSelectOptions } from '../utils/stockLocationOptions';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  stockRow: GlobalStock | null;
  tenantId: number;
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

const moveQty = ref<number>(1);
const targetLocationId = ref<number | null>(null);
const notes = ref<string>('');
const submitting = ref<boolean>(false);

const locationOptions = computed(() =>
  toLocationSelectOptions(getLeafLocations(stockLocationStore.items)),
);

const onShow = () => {
  if (props.stockRow) {
    moveQty.value = props.stockRow.quantity;
    targetLocationId.value = props.stockRow.location_id || null;
    notes.value = '';
  }
};

const onConfirm = async () => {
  if (!props.stockRow || !props.tenantId || !targetLocationId.value) return;

  submitting.value = true;
  try {
    await globalStockRepository.createAndPostMovement({
      tenantId: props.tenantId,
      stockId: props.stockRow.id,
      quantity: moveQty.value,
      toLocationId: targetLocationId.value,
      toAvailability: props.stockRow.availability ?? null,
      toGradeTagId: (props.stockRow as any).grade_tag_id ?? null,
      movementType: 'location_transfer',
      notes: notes.value.trim() || null,
    });

    showSuccessNotification('Stock location transferred successfully');
    isOpen.value = false;
    emit('updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to transfer location');
  } finally {
    submitting.value = false;
  }
};
</script>
