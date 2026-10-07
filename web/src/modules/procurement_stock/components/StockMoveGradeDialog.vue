<template>
  <FilterSidebar
    v-model="isOpen"
    :title="drawerTitle"
    width="min(420px, 92vw)"
    storage-key="procurement.stock-move-grade-width"
    @update:model-value="onDrawerToggle"
  >
    <div v-if="stockRow" class="column q-gutter-y-md">
      <div class="bg-grey-2 q-pa-md rounded-borders">
        <div class="text-caption text-grey-7 text-weight-medium">Product</div>
        <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-xs">{{ stockRow.item_name }}</div>
        <div v-if="stockRow.product_code" class="text-caption text-grey-7 font-mono q-mt-xs">
          {{ stockRow.product_code }}
        </div>
      </div>

      <template v-if="step === 'overview'">
        <div class="column q-gutter-y-sm">
          <div class="text-caption text-grey-7 text-weight-medium">Current status</div>
          <div class="row q-col-gutter-md">
            <div class="col-6">
              <div class="text-caption text-grey-7">Sell status</div>
              <div class="text-body1 text-weight-bold text-grey-9">
                {{ formatStockAvailability(stockRow.availability) }}
              </div>
            </div>
            <div class="col-6">
              <div class="text-caption text-grey-7">Condition</div>
              <div class="text-body1 text-weight-bold text-grey-9">{{ currentGradeLabel }}</div>
            </div>
          </div>
          <div class="row q-col-gutter-md q-pt-xs">
            <div class="col-6">
              <div class="text-caption text-grey-7">Quantity</div>
              <div class="text-h6 text-weight-bold text-primary">{{ stockRow.quantity }}</div>
            </div>
            <div class="col-6">
              <div class="text-caption text-grey-7">Bin</div>
              <div class="text-body2 text-weight-medium text-grey-9">
                {{ stockRow.location_name || '—' }}
              </div>
            </div>
          </div>
        </div>

        <div class="text-caption bw-text-muted">
          To move stock to another bin, use <strong>Stock location</strong> on this row.
        </div>

        <q-btn
          color="primary"
          unelevated
          no-caps
          class="full-width"
          icon="ph ph-pencil-simple"
          label="Update condition & sell status"
          @click="openStep('update')"
        />
        <q-btn
          outline
          color="primary"
          no-caps
          class="full-width"
          icon="ph ph-arrows-split"
          label="Split quantity to new condition"
          @click="openStep('split')"
        />
      </template>

      <template v-else>
        <div class="text-caption text-grey-7">
          <span v-if="step === 'update'">Updates all {{ stockRow.quantity }} pcs in this bin.</span>
          <span v-else>Leaves remaining qty in the current condition.</span>
        </div>

        <q-form class="column q-gutter-y-md" @submit.prevent="onConfirm">
          <div v-if="step === 'split'">
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Quantity to split</div>
            <q-input
              v-model.number="moveQty"
              type="number"
              outlined
              dense
              :rules="[
                (val) => val > 0 || 'Quantity must be > 0',
                (val) => val < (stockRow?.quantity || 0) || 'Split must be less than on-hand qty',
              ]"
            />
          </div>

          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">New condition</div>
            <q-select
              v-model="selectedGrade"
              :options="gradeOptions"
              option-label="name"
              option-value="id"
              emit-value
              map-options
              outlined
              dense
              :rules="[(v) => v != null || 'Pick a condition']"
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

          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">New sell status</div>
            <q-select
              v-model="targetAvailability"
              :options="availabilityOptions"
              emit-value
              map-options
              outlined
              dense
              :rules="[(v) => !!v || 'Pick sell status']"
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
              placeholder="e.g. Regraded after inspection"
            />
          </div>

          <div class="row q-gutter-x-sm q-pt-xs">
            <q-btn flat no-caps color="grey-7" class="col" label="Back" @click="step = 'overview'" />
            <q-btn
              type="submit"
              color="primary"
              unelevated
              no-caps
              class="col"
              :loading="submitting"
              :disable="!canSubmit"
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
import type { GlobalStock } from '../repositories/globalStockRepository';
import { globalStockRepository } from '../repositories/globalStockRepository';
import {
  STOCK_AVAILABILITY_OPTIONS,
  formatStockAvailability,
  type StockAvailability,
} from '../constants/stockAvailability';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  stockRow: GlobalStock | null;
  tenantId: number;
  gradeLabel?: string;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'updated'): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

type Step = 'overview' | 'update' | 'split';
const step = ref<Step>('overview');

const moveQty = ref<number>(1);
const selectedGrade = ref<number | null>(null);
const targetAvailability = ref<StockAvailability>('sellable');
const notes = ref<string>('');
const submitting = ref<boolean>(false);

const gradeOptions = ref<Tag[]>([]);
const availabilityOptions = STOCK_AVAILABILITY_OPTIONS;

const currentGradeLabel = computed(
  () =>
    props.gradeLabel ||
    props.stockRow?.grade_name ||
    gradeOptions.value.find((g) => g.id === props.stockRow?.grade_tag_id)?.name ||
    'Standard',
);

const drawerTitle = computed(() => {
  if (step.value === 'overview') return 'Condition & sell status';
  if (step.value === 'update') return 'Update condition & sell status';
  return 'Split to new condition';
});

const confirmLabel = computed(() =>
  step.value === 'update' ? 'Confirm update' : 'Confirm split',
);

const statusUnchanged = computed(() => {
  if (!props.stockRow || selectedGrade.value == null) return true;
  const sameGrade = selectedGrade.value === (props.stockRow.grade_tag_id ?? null);
  const sameAvail =
    targetAvailability.value === (props.stockRow.availability ?? 'sellable');
  return sameGrade && sameAvail;
});

const canSubmit = computed(() => {
  if (!selectedGrade.value || !props.stockRow) return false;
  if (statusUnchanged.value) return false;
  if (step.value === 'split') {
    return moveQty.value > 0 && moveQty.value < props.stockRow.quantity;
  }
  return props.stockRow.quantity > 0;
});

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

const resetTargetsFromRow = () => {
  if (!props.stockRow) return;
  moveQty.value = 1;
  targetAvailability.value = props.stockRow.availability || 'sellable';
  notes.value = '';
  const existing = gradeOptions.value.find((g) => g.id === props.stockRow?.grade_tag_id);
  selectedGrade.value = existing?.id ?? gradeOptions.value[0]?.id ?? null;
};

const resetForm = () => {
  step.value = 'overview';
  resetTargetsFromRow();
};

const openStep = (next: 'update' | 'split') => {
  resetTargetsFromRow();
  step.value = next;
};

const onDrawerToggle = (open: boolean) => {
  if (!open) resetForm();
};

const onGradeChange = (gradeId: number) => {
  const g = gradeOptions.value.find((opt) => opt.id === gradeId);
  if (!g) return;
  const mapped = g.metadata?.maps_to_availability;
  if (mapped === 'unsellable' || mapped === 'held' || mapped === 'sellable') {
    targetAvailability.value = mapped;
  }
};

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return;
    resetForm();
    await fetchSystemGrades();
    resetTargetsFromRow();
  },
);

const movementTypeForSubmit = (): 'grade_change' | 'availability_transfer' => {
  if (!props.stockRow || selectedGrade.value == null) return 'grade_change';
  const gradeChanged = selectedGrade.value !== (props.stockRow.grade_tag_id ?? null);
  const availChanged =
    targetAvailability.value !== (props.stockRow.availability ?? 'sellable');
  if (availChanged && !gradeChanged) return 'availability_transfer';
  return 'grade_change';
};

const onConfirm = async () => {
  if (!props.stockRow || !props.tenantId || !selectedGrade.value || !canSubmit.value) return;

  const qty =
    step.value === 'update' ? props.stockRow.quantity : moveQty.value;

  submitting.value = true;
  try {
    await globalStockRepository.createAndPostMovement({
      tenantId: props.tenantId,
      stockId: props.stockRow.id,
      quantity: qty,
      toLocationId: props.stockRow.location_id ?? null,
      toAvailability: targetAvailability.value,
      toGradeTagId: selectedGrade.value,
      movementType: movementTypeForSubmit(),
      notes: notes.value.trim() || null,
    });

    showSuccessNotification(
      step.value === 'update'
        ? 'Condition and sell status updated'
        : 'Quantity split to the new condition',
    );
    isOpen.value = false;
    emit('updated');
  } catch (err: unknown) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update stock');
  } finally {
    submitting.value = false;
  }
};
</script>
