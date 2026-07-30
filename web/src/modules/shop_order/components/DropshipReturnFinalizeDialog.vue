<template>
  <q-dialog
    :model-value="props.modelValue"
    persistent
    @update:model-value="(v) => emit('update:modelValue', v)"
  >
    <q-card style="min-width: 520px; max-width: 600px; border-radius: 12px">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6 text-weight-bold row items-center">
          <q-icon name="ph ph-arrow-u-down-left" color="warning" size="24px" class="q-mr-xs" />
          Finalize Dropship Return
        </div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-card-section class="q-gutter-y-md">
        <div class="text-body2 text-grey-8">
          Order <strong>{{ props.order?.order_no }}</strong> — record returned item condition breakdown and return charges.
        </div>

        <!-- Condition Split Breakdown -->
        <q-card flat bordered class="q-pa-md bg-grey-1">
          <div class="text-subtitle2 text-weight-bold q-mb-sm">Condition Quantity Breakdown *</div>
          <div class="row q-col-gutter-sm">
            <div class="col-4">
              <q-input
                v-model.number="form.qty_normal"
                type="number"
                label="Normal (Restock)"
                outlined
                dense
                bg-color="white"
                min="0"
              />
            </div>
            <div class="col-4">
              <q-input
                v-model.number="form.qty_open_box"
                type="number"
                label="Open Box"
                outlined
                dense
                bg-color="white"
                min="0"
              />
            </div>
            <div class="col-4">
              <q-input
                v-model.number="form.qty_damaged"
                type="number"
                label="Damaged"
                outlined
                dense
                bg-color="white"
                min="0"
              />
            </div>
          </div>
        </q-card>

        <!-- Suggested vs Actual Return Fee -->
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <q-input
              :model-value="props.suggestedReturnFee"
              label="Suggested Fee (BDT)"
              outlined
              dense
              readonly
              bg-color="grey-2"
            />
          </div>
          <div class="col-6">
            <q-input
              v-model.number="form.actual_return_fee"
              type="number"
              label="Actual Return Fee (BDT) *"
              outlined
              dense
              min="0"
            />
          </div>
        </div>

        <!-- Override Reason (Required if actual fee != suggested fee) -->
        <q-input
          v-if="isFeeOverridden"
          v-model="form.override_reason"
          label="Fee Override Reason *"
          outlined
          dense
          type="textarea"
          rows="2"
          placeholder="State reason for overriding suggested return fee..."
          :rules="[(val) => !!val || 'Reason required for fee override']"
        />

        <q-toggle
          v-model="form.deduct_from_middle_man"
          label="Deduct return fee from merchant wallet"
          color="primary"
          dense
        />

        <q-input
          v-model="form.note"
          label="Return Notes"
          outlined
          dense
          type="textarea"
          rows="2"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat label="Cancel" v-close-popup no-caps />
        <q-btn
          color="warning"
          text-color="dark"
          label="Finalize Return"
          unelevated
          no-caps
          :loading="props.loading"
          :disable="!canSubmit"
          @click="handleFinalize"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { ShopOrder } from '../types';

const props = defineProps<{
  modelValue: boolean;
  order: ShopOrder | null;
  suggestedReturnFee: number;
  totalReturnableQty?: number;
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (
    e: 'submit',
    payload: {
      qty_normal: number;
      qty_open_box: number;
      qty_damaged: number;
      actual_return_fee: number;
      deduct_from_middle_man: boolean;
      override_reason: string;
      note: string;
    },
  ): void;
}>();

const form = ref({
  qty_normal: 0,
  qty_open_box: 0,
  qty_damaged: 0,
  actual_return_fee: 0,
  deduct_from_middle_man: true,
  override_reason: '',
  note: '',
});

watch(
  () => props.suggestedReturnFee,
  (newFee) => {
    form.value.actual_return_fee = newFee;
  },
  { immediate: true },
);

watch(
  () => [props.modelValue, props.totalReturnableQty] as const,
  ([open, total]) => {
    if (open) {
      form.value.qty_normal = Number(total) || 0;
      form.value.qty_open_box = 0;
      form.value.qty_damaged = 0;
      form.value.deduct_from_middle_man = true;
      form.value.override_reason = '';
      form.value.note = '';
      form.value.actual_return_fee = props.suggestedReturnFee;
    }
  },
);

const isFeeOverridden = computed(() => form.value.actual_return_fee !== props.suggestedReturnFee);

const canSubmit = computed(() => {
  const totalQty = form.value.qty_normal + form.value.qty_open_box + form.value.qty_damaged;
  if (totalQty <= 0) return false;
  const expected = Number(props.totalReturnableQty);
  if (Number.isFinite(expected) && expected > 0 && totalQty !== expected) return false;
  if (isFeeOverridden.value && !form.value.override_reason.trim()) return false;
  return true;
});

const handleFinalize = () => {
  emit('submit', { ...form.value });
};
</script>
