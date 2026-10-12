<template>
  <q-dialog v-model="open" persistent>
    <q-card style="min-width: 360px; max-width: 480px">
      <q-card-section class="text-weight-bold">Add bill line</q-card-section>
      <q-card-section class="q-pt-none q-gutter-y-md">
        <div>
          <div class="text-caption text-grey-7 q-mb-xs">Line kind</div>
          <div class="row q-gutter-xs">
            <q-chip
              v-for="opt in lineKindOptions"
              :key="opt.value"
              dense
              clickable
              :outline="draft.line_kind !== opt.value"
              :color="draft.line_kind === opt.value ? 'primary' : 'grey-3'"
              :text-color="draft.line_kind === opt.value ? 'white' : 'grey-8'"
              @click="draft.line_kind = opt.value"
            >
              {{ opt.label }}
            </q-chip>
          </div>
        </div>

        <template v-if="draft.line_kind === 'description'">
          <q-input v-model="draft.name" outlined dense label="Description *" autogrow />
          <div class="row q-col-gutter-sm">
            <div class="col-4">
              <q-input v-model.number="draft.quantity" type="number" outlined dense label="Qty" min="0.001" />
            </div>
            <div class="col-4">
              <q-input
                v-model.number="draft.sell_price_amount"
                type="number"
                outlined
                dense
                label="Unit price"
                min="0"
              />
            </div>
            <div class="col-4">
              <q-input
                v-model.number="draft.line_discount_amount"
                type="number"
                outlined
                dense
                label="Discount"
                min="0"
              />
            </div>
          </div>
        </template>

        <template v-else>
          <q-select
            v-model="draft.charge_type"
            :options="chargeTypeOptions"
            outlined
            dense
            label="Charge type"
            emit-value
            map-options
          />
          <q-input v-model="draft.name" outlined dense label="Label *" />
          <q-input
            v-model.number="draft.sell_price_amount"
            type="number"
            outlined
            dense
            label="Amount *"
            min="0"
          />
        </template>
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" @click="open = false" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Add"
          :disable="!canAdd"
          @click="submit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue';

export type ComposeLineKind = 'stock' | 'description' | 'charge';

export type ComposeLineDraft = {
  line_kind: ComposeLineKind;
  name: string;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount: number;
  charge_type: string;
};

const open = defineModel<boolean>({ required: true });

const emit = defineEmits<{
  add: [line: ComposeLineDraft];
}>();

const lineKindOptions: Array<{ label: string; value: ComposeLineKind }> = [
  { label: 'Description', value: 'description' },
  { label: 'Charge', value: 'charge' },
];

const chargeTypeOptions = [
  { label: 'Shipping', value: 'shipping' },
  { label: 'Wrapping', value: 'wrapping' },
  { label: 'Print', value: 'print' },
  { label: 'Delivery', value: 'delivery' },
  { label: 'Other', value: 'other' },
];

const defaultDraft = (): ComposeLineDraft => ({
  line_kind: 'description',
  name: '',
  quantity: 1,
  sell_price_amount: 0,
  line_discount_amount: 0,
  charge_type: 'shipping',
});

const draft = reactive(defaultDraft());

watch(open, (isOpen) => {
  if (!isOpen) return;
  Object.assign(draft, defaultDraft());
});

watch(
  () => draft.line_kind,
  (kind) => {
    if (kind === 'charge' && !draft.name) {
      const opt = chargeTypeOptions.find((o) => o.value === draft.charge_type);
      draft.name = opt?.label ?? 'Charge';
    }
  },
);

watch(
  () => draft.charge_type,
  (type) => {
    if (draft.line_kind !== 'charge') return;
    const opt = chargeTypeOptions.find((o) => o.value === type);
    if (opt) draft.name = opt.label;
  },
);

const canAdd = computed(() => {
  if (!draft.name.trim()) return false;
  if (draft.line_kind === 'charge') {
    return draft.sell_price_amount >= 0;
  }
  return draft.quantity > 0 && draft.sell_price_amount >= 0;
});

const submit = () => {
  if (!canAdd.value) return;
  emit('add', {
    line_kind: draft.line_kind,
    name: draft.name.trim(),
    quantity: draft.line_kind === 'charge' ? 1 : draft.quantity,
    sell_price_amount: draft.sell_price_amount,
    line_discount_amount: draft.line_kind === 'charge' ? 0 : draft.line_discount_amount || 0,
    charge_type: draft.charge_type,
  });
  open.value = false;
};
</script>
