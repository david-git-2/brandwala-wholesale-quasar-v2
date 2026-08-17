<template>
  <q-card flat bordered class="q-pa-md shipment-vendor-return-card">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
      Vendor return
    </div>
    <div class="text-caption text-grey-7 q-mb-md">
      Send goods back to the vendor.
    </div>
    <div class="row q-col-gutter-sm q-mb-md">
      <div class="col-12 col-sm-6">
        <q-select
          :model-value="returnOutcome"
          :options="returnOutcomeOptions"
          label="Return outcome"
          dense
          outlined
          emit-value
          map-options
          @update:model-value="(val) => $emit('update:returnOutcome', val)"
        />
      </div>
    </div>
    <q-table
      flat
      dense
      :rows="returnLines"
      :columns="returnLineColumns"
      row-key="shipment_item_id"
      hide-pagination
      :rows-per-page-options="[0]"
    >
      <template #body-cell-return_qty="props">
        <q-td :props="props">
          <q-input
            v-model.number="props.row.return_qty"
            type="number"
            dense
            outlined
            min="0"
            :max="props.row.max_qty"
            style="max-width: 100px"
          />
        </q-td>
      </template>
    </q-table>
    <q-btn
      color="negative"
      unelevated
      no-caps
      class="q-mt-md"
      icon="ph ph-arrow-u-up-left"
      label="Submit return"
      :disable="!hasReturnQty"
      :loading="returnSubmitting"
      @click="$emit('submit-return')"
    />
  </q-card>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';

export interface ReturnLineDraft {
  shipment_item_id: number;
  name: string;
  max_qty: number;
  return_qty: number;
}

defineProps<{
  returnOutcome: 'cash_refund' | 'store_credit';
  returnOutcomeOptions: Array<{ label: string; value: 'cash_refund' | 'store_credit' }>;
  returnLines: ReturnLineDraft[];
  returnLineColumns: QTableColumn<ReturnLineDraft>[];
  hasReturnQty: boolean;
  returnSubmitting: boolean;
}>();

defineEmits<{
  'update:returnOutcome': [val: 'cash_refund' | 'store_credit'];
  'submit-return': [];
}>();
</script>
