<template>
  <q-card flat bordered class="policy-program-card">
    <q-card-section>
      <div class="row items-center justify-between q-mb-md">
        <div>
          <div class="policy-program-card__title">{{ displayTitle }}</div>
          <div class="policy-program-card__caption">{{ displayCaption }}</div>
        </div>
        <q-badge outline color="grey-7" :label="program.program.replace(/_/g, ' ')" />
      </div>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-4">
          <q-input
            :model-value="program.window_days"
            type="number"
            min="0"
            outlined
            dense
            label="Window (days)"
            :readonly="readonly"
            @update:model-value="patch({ window_days: Number($event) || 0 })"
          />
        </div>
        <div class="col-12 col-md-4">
          <q-select
            :model-value="program.window_anchor"
            :options="windowAnchorOptions"
            outlined
            dense
            emit-value
            map-options
            label="Window anchor"
            :readonly="readonly"
            :disable="readonly"
            @update:model-value="patch({ window_anchor: $event })"
          />
        </div>
        <div class="col-12 col-md-4">
          <q-select
            :model-value="program.default_to_availability"
            :options="availabilityOptions"
            outlined
            dense
            emit-value
            map-options
            label="Default availability"
            :readonly="readonly"
            :disable="readonly"
            @update:model-value="patch({ default_to_availability: $event })"
          />
        </div>
        <div class="col-12">
          <q-select
            :model-value="program.allowed_outcomes"
            :options="outcomeOptions"
            outlined
            dense
            multiple
            emit-value
            map-options
            use-chips
            label="Allowed outcomes"
            :readonly="readonly"
            :disable="readonly"
            @update:model-value="patch({ allowed_outcomes: $event })"
          />
        </div>
        <div class="col-12 col-md-4">
          <q-select
            :model-value="program.restock_fee_type"
            :options="feeTypeOptions"
            outlined
            dense
            emit-value
            map-options
            label="Restock fee type"
            :readonly="readonly"
            :disable="readonly"
            @update:model-value="patch({ restock_fee_type: $event })"
          />
        </div>
        <div class="col-12 col-md-4">
          <q-input
            :model-value="program.restock_fee_value"
            type="number"
            min="0"
            outlined
            dense
            label="Restock fee value"
            :readonly="readonly"
            @update:model-value="patch({ restock_fee_value: Number($event) || 0 })"
          />
        </div>
        <div class="col-12 col-md-4">
          <q-input
            :model-value="program.approval_threshold_bdt"
            type="number"
            min="0"
            outlined
            dense
            label="Approval threshold (BDT)"
            :readonly="readonly"
            @update:model-value="patch({ approval_threshold_bdt: Number($event) || 0 })"
          />
        </div>
        <div class="col-12 col-md-6">
          <q-toggle
            :model-value="program.requires_approval"
            label="Requires manager approval"
            :disable="readonly"
            @update:model-value="patch({ requires_approval: $event })"
          />
        </div>
        <div class="col-12">
          <q-input
            :model-value="program.customer_visible_note ?? ''"
            type="textarea"
            autogrow
            outlined
            dense
            label="Customer-visible note"
            :readonly="readonly"
            @update:model-value="patch({ customer_visible_note: String($event) || null })"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { AfterSalesOutcome, AfterSalesPolicyProgram, AfterSalesProgram } from '../types/afterSales.types';

const props = defineProps<{
  program: AfterSalesPolicyProgram;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:program', value: AfterSalesPolicyProgram): void;
}>();

const PROGRAM_META: Record<
  AfterSalesProgram,
  { title: string; caption: string }
> = {
  return_credit: { title: 'Return credit', caption: 'Change of mind, unused goods' },
  doa: { title: 'DOA', caption: 'Dead or wrong at delivery' },
  replacement: { title: 'Replacement', caption: 'Swap unit for same SKU' },
  warranty: { title: 'Warranty', caption: 'Repair or replace after normal use' },
};

const title = computed(() => PROGRAM_META[props.program.program].title);
const caption = computed(() => PROGRAM_META[props.program.program].caption);
const displayTitle = computed(() => props.program.name.trim() || title.value);
const displayCaption = computed(() =>
  props.program.name.trim() ? caption.value : 'Give this policy a name above.',
);

const windowAnchorOptions = [
  { label: 'Invoice date', value: 'invoice_date' },
  { label: 'Delivery date', value: 'delivery_date' },
];

const availabilityOptions = [
  { label: 'Held (quarantine)', value: 'held' },
  { label: 'Sellable', value: 'sellable' },
  { label: 'Unsellable', value: 'unsellable' },
];

const outcomeOptions: { label: string; value: AfterSalesOutcome }[] = [
  { label: 'Credit', value: 'credit' },
  { label: 'Replace', value: 'replace' },
  { label: 'Repair', value: 'repair' },
  { label: 'Reject', value: 'reject' },
];

const feeTypeOptions = [
  { label: 'None', value: 'none' },
  { label: 'Percent', value: 'percent' },
  { label: 'Flat BDT', value: 'flat_bdt' },
];

const patch = (partial: Partial<AfterSalesPolicyProgram>) => {
  emit('update:program', { ...props.program, ...partial });
};
</script>

<style scoped>
.policy-program-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
}

.policy-program-card__title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.policy-program-card__caption {
  margin-top: 0.2rem;
  font-size: 0.78rem;
  color: var(--bw-theme-muted);
}
</style>
