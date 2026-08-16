<template>
  <q-dialog v-model="isOpen" persistent @show="onShow">
    <q-card style="width: 520px; max-width: 95vw;" class="q-pa-sm">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
          <q-icon name="ph ph-arrows-down-up" color="primary" size="24px" />
          <span>Move / Re-Grade Stock</span>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <!-- Source Stock Card -->
        <div v-if="stockRow" class="bg-grey-2 q-pa-sm rounded-borders q-mb-md">
          <div class="text-caption text-grey-7 text-weight-medium uppercase">Source Stock</div>
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-xs">{{ stockRow.item_name }}</div>
          <div class="row items-center justify-between text-caption text-grey-7 q-mt-xs">
            <div>Loc: <strong>{{ stockRow.location_name || 'Main Warehouse' }}</strong></div>
            <div>Grade: <strong>{{ currentGradeLabel }}</strong></div>
            <div>Qty: <strong class="text-primary">{{ stockRow.quantity }} pcs</strong></div>
          </div>
        </div>

        <q-form class="q-gutter-y-md" @submit.prevent="onConfirm">
          <!-- Quantity to Move -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Quantity to Move / Split</div>
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

          <!-- Target Grade -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Target Condition Grade</div>
            <q-select
              v-model="selectedGrade"
              :options="gradeOptions"
              option-label="name"
              option-value="id"
              emit-value
              map-options
              filled
              dense
              @update:model-value="onGradeChange"
            >
              <template #option="scope">
                <q-item v-bind="scope.itemProps">
                  <q-item-section>
                    <q-item-label>{{ scope.opt.name }}</q-item-label>
                    <q-item-label v-if="scope.opt.slug" caption>{{ scope.opt.slug }}</q-item-label>
                  </q-item-section>
                </q-item>
              </template>
            </q-select>
          </div>

          <!-- Target Availability Gate -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Availability Gate</div>
            <q-select
              v-model="targetAvailability"
              :options="availabilityOptions"
              emit-value
              map-options
              filled
              dense
            />
          </div>

          <!-- Target Bin Location -->
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Target Location</div>
            <q-select
              v-model="targetLocationId"
              :options="locationOptions"
              emit-value
              map-options
              filled
              dense
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
              placeholder="e.g. Unboxing crushed box split"
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
              :disable="!selectedGrade"
              label="Confirm Move & Split"
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
import {
  STOCK_AVAILABILITY_OPTIONS,
  type StockAvailability,
} from '../constants/stockAvailability';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
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
const selectedGrade = ref<number | null>(null);
const targetAvailability = ref<StockAvailability>('sellable');
const targetLocationId = ref<number | null>(null);
const notes = ref<string>('');
const submitting = ref<boolean>(false);

const gradeOptions = ref<Tag[]>([]);
const availabilityOptions = STOCK_AVAILABILITY_OPTIONS;

const currentGradeLabel = computed(() => {
  const id = props.stockRow?.grade_tag_id;
  const match = gradeOptions.value.find((g) => g.id === id);
  return match?.name || props.stockRow?.grade_name || 'Standard';
});

const locationOptions = computed(() =>
  toLocationSelectOptions(getLeafLocations(stockLocationStore.items)),
);

const fetchSystemGrades = async () => {
  try {
    gradeOptions.value = await tagRepository.listTagsForCategory({
      moduleKey: 'stock_grade',
      code: 'warehouse',
    });
  } catch (err: unknown) {
    gradeOptions.value = [];
    showErrorNotification(err instanceof Error ? err.message : 'Failed to load stock grades');
  }
};

const onShow = async () => {
  await fetchSystemGrades();
  if (props.stockRow) {
    moveQty.value = props.stockRow.quantity;
    targetAvailability.value = props.stockRow.availability || 'sellable';
    targetLocationId.value = props.stockRow.location_id || null;
    notes.value = '';

    const existing = gradeOptions.value.find((g) => g.id === props.stockRow?.grade_tag_id);
    selectedGrade.value = existing?.id ?? gradeOptions.value[0]?.id ?? null;
  }
};

const onGradeChange = (gradeId: number) => {
  const g = gradeOptions.value.find((opt) => opt.id === gradeId);
  if (!g) return;
  if (g.metadata?.maps_to_availability === 'unsellable') {
    targetAvailability.value = 'unsellable';
  } else if (
    targetAvailability.value === 'unsellable'
    && g.metadata?.maps_to_availability === 'sellable'
  ) {
    targetAvailability.value = 'sellable';
  }
};

const onConfirm = async () => {
  if (!props.stockRow || !props.tenantId || !selectedGrade.value) return;

  submitting.value = true;
  try {
    await globalStockRepository.createAndPostMovement({
      tenantId: props.tenantId,
      stockId: props.stockRow.id,
      quantity: moveQty.value,
      toLocationId: targetLocationId.value,
      toAvailability: targetAvailability.value,
      toGradeTagId: selectedGrade.value,
      movementType: 'grade_change',
      notes: notes.value.trim() || null,
    });

    showSuccessNotification('Stock moved & condition updated successfully');
    isOpen.value = false;
    emit('updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to move stock');
  } finally {
    submitting.value = false;
  }
};
</script>
