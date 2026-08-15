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
            <div>Grade: <strong>{{ stockRow.stock_type_description || stockRow.availability || 'Standard' }}</strong></div>
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
                    <q-item-label caption>{{ scope.opt.description }}</q-item-label>
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
import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/database.types';
import type { GlobalStock } from '../repositories/globalStockRepository';
import { globalStockRepository } from '../repositories/globalStockRepository';
import { useStockLocationStore } from '../stores/stockLocationStore';
import { getLeafLocations, toLocationSelectOptions } from '../utils/stockLocationOptions';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

type StockAvailability = Database['public']['Enums']['stock_availability'];

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

const gradeOptions = ref<Array<{ id: number; name: string; code: string; description?: string }>>([
  { id: 1, name: 'Standard', code: 'standard', description: 'Brand new sellable condition' },
  { id: 2, name: 'Open Box', code: 'open_box', description: 'Box opened but product intact' },
  { id: 3, name: 'Box Damage', code: 'box_damage', description: 'Torn/crushed outer box' },
  { id: 4, name: 'Box Less', code: 'box_less', description: 'No outer packaging' },
  { id: 5, name: 'Badly Damaged', code: 'badly_damaged', description: 'Defective/broken product' },
]);

const availabilityOptions = [
  { label: 'Sellable (Available for listing)', value: 'sellable' },
  { label: 'Quarantine (Held)', value: 'quarantine' },
  { label: 'Unsellable (Damaged / Return)', value: 'unsellable' },
];

const locationOptions = computed(() =>
  toLocationSelectOptions(getLeafLocations(stockLocationStore.items)),
);

const fetchSystemGrades = async () => {
  try {
    const { data, error } = await (supabase as any).rpc('list_tags_for_category', { p_code: 'stock_grade' });
    if (!error && Array.isArray(data) && data.length > 0) {
      gradeOptions.value = data.map((t: any) => ({
        id: t.id,
        name: t.name,
        code: t.code,
        description: t.description || '',
      }));
    }
  } catch {
    // fallback to static defaults
  }
};

const onShow = async () => {
  await fetchSystemGrades();
  if (props.stockRow) {
    moveQty.value = props.stockRow.quantity;
    targetAvailability.value = props.stockRow.availability || 'sellable';
    targetLocationId.value = props.stockRow.location_id || null;
    notes.value = '';

    // match existing grade tag if available
    const existing = gradeOptions.value.find((g) => g.id === (props.stockRow as any).grade_tag_id);
    if (existing) {
      selectedGrade.value = existing.id;
    } else {
      selectedGrade.value = gradeOptions.value[0]?.id || 1;
    }
  }
};

const onGradeChange = (gradeId: number) => {
  const g = gradeOptions.value.find((opt) => opt.id === gradeId);
  if (g && (g.code === 'badly_damaged' || g.name.toLowerCase().includes('badly damaged'))) {
    targetAvailability.value = 'unsellable';
  } else if (targetAvailability.value === 'unsellable' && g && g.code === 'standard') {
    targetAvailability.value = 'sellable';
  }
};

const onConfirm = async () => {
  if (!props.stockRow || !props.tenantId) return;

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
