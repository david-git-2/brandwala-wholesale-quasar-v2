<template>
  <div>
    <!-- Summary card -->
    <q-card flat class="floating-surface shadow-1 q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold text-primary q-mb-xs">Shipment Summary</div>
        <q-separator class="q-my-sm" />
        <div class="row justify-between q-py-xs">
          <span class="text-caption text-grey-8">Total Items (U):</span>
          <span class="text-subtitle2 text-weight-bold text-grey-9">{{ totalUnits }}</span>
        </div>
        <div class="row justify-between q-py-xs">
          <span class="text-caption text-grey-8">Unique Stocks:</span>
          <span class="text-subtitle2 text-weight-bold text-grey-9">{{ stockCount }}</span>
        </div>
      </q-card-section>
    </q-card>

    <!-- Cost Inputs Editor -->
    <q-card flat class="floating-surface shadow-1">
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold text-primary q-mb-md">
          Landed Cost Inputs
        </div>

        <div class="column q-gutter-y-sm">
          <div class="text-caption text-weight-bold text-grey-7 q-mb-none">CARGO</div>
          <q-input
            :model-value="costForm.total_cargo_weight_kg"
            type="number"
            step="0.1"
            min="0"
            outlined
            dense
            label="Total Cargo Weight (kg)"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('total_cargo_weight_kg', val)"
            @change="onCostChange"
          />
          <q-input
            :model-value="costForm.cargo_rate"
            type="number"
            step="0.01"
            min="0"
            outlined
            dense
            label="Cargo Rate"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('cargo_rate', val)"
            @change="onCostChange"
          />
          <q-input
            :model-value="costForm.cargo_conversion_rate"
            type="number"
            step="0.0001"
            min="0"
            outlined
            dense
            label="Cargo conversion"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('cargo_conversion_rate', val)"
            @change="onCostChange"
          />

          <q-separator class="q-my-xs" />
          <div class="text-caption text-weight-bold text-grey-7 q-mb-none">OPERATIONS</div>
          <q-input
            :model-value="costForm.labor_total_cost"
            type="number"
            step="0.01"
            min="0"
            outlined
            dense
            label="Labor Total Cost"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('labor_total_cost', val)"
            @change="onCostChange"
          />
          <q-input
            :model-value="costForm.transportation_total_cost"
            type="number"
            step="0.01"
            min="0"
            outlined
            dense
            label="Transport Total Cost"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('transportation_total_cost', val)"
            @change="onCostChange"
          />
          <q-input
            :model-value="costForm.washing_total_cost"
            type="number"
            step="0.01"
            min="0"
            outlined
            dense
            label="Washing Total Cost"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('washing_total_cost', val)"
            @change="onCostChange"
          />

          <q-separator class="q-my-xs" />
          <div class="text-caption text-weight-bold text-grey-7 q-mb-none">RATES & MARKUP</div>
          <q-input
            :model-value="costForm.product_conversion_rate"
            type="number"
            step="0.0001"
            min="0"
            outlined
            dense
            label="Product conversion"
            class="soft-input"
            :readonly="!canEditLandedCost"
            @update:model-value="(val) => updateCostField('product_conversion_rate', val)"
            @change="onCostChange"
          />
          <q-input
            :model-value="markupPercentage"
            type="number"
            step="1"
            min="0"
            outlined
            dense
            label="Default Markup (%)"
            class="soft-input"
            suffix="%"
            :readonly="!canEditLandedCost"
            @update:model-value="
              (val) =>
                canEditLandedCost &&
                emit('update:markupPercentage', val !== null && val !== '' ? Number(val) : null)
            "
            @change="onCostChange"
          />
          <div
            class="text-caption text-grey-6 text-italic"
            style="font-size: 10px; line-height: 1.2"
          >
            Suggested sell = landed × (1 + markup)
          </div>
          <div
            class="q-pa-xs q-mt-xs bg-grey-2 rounded-borders text-caption text-grey-8"
            style="font-size: 11px"
          >
            <div>
              Sample Preview (using Default Origin:
              {{ formattedDefaultOrigin }}):
            </div>
            <div class="row justify-between text-weight-bold text-grey-9 q-mt-xs">
              <span>Suggested Sell:</span>
              <span>{{ formattedSuggestedPrice }}</span>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
export interface CostFormState {
  total_cargo_weight_kg: number | null;
  cargo_rate: number | null;
  cargo_conversion_rate: number | null;
  labor_total_cost: number | null;
  transportation_total_cost: number | null;
  washing_total_cost: number | null;
  default_markup_rate: number | null;
  product_conversion_rate: number | null;
}

const props = withDefaults(
  defineProps<{
    costForm: CostFormState;
    markupPercentage: number | null;
    totalUnits: number;
    stockCount: number;
    formattedDefaultOrigin: string;
    formattedSuggestedPrice: string;
    canEditLandedCost?: boolean;
  }>(),
  {
    canEditLandedCost: true,
  },
);

const emit = defineEmits<{
  (e: 'update:costForm', val: CostFormState): void;
  (e: 'update:markupPercentage', val: number | null): void;
  (e: 'save'): void;
}>();

function updateCostField(field: keyof CostFormState, rawVal: unknown) {
  if (!props.canEditLandedCost) return;
  const numVal = rawVal !== null && rawVal !== '' ? Number(rawVal) : null;
  emit('update:costForm', {
    ...props.costForm,
    [field]: numVal,
  });
}

function onCostChange() {
  if (!props.canEditLandedCost) return;
  emit('save');
}
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
