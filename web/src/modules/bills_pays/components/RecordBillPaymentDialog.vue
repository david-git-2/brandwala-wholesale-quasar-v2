<template>
  <q-dialog
    v-if="!embedded"
    :model-value="modelValue"
    persistent
    @update:model-value="(value: boolean) => emit('update:modelValue', value)"
  >
    <RecordBillPaymentDialogPanel
      v-bind="panelBind"
      @update:model-value="(value: boolean) => emit('update:modelValue', value)"
      @submit="(payload) => emit('submit', payload)"
      @cancel="emit('cancel')"
    />
  </q-dialog>
  <div v-else>
    <RecordBillPaymentDialogPanel
      v-bind="panelBind"
      embedded
      @update:model-value="(value: boolean) => emit('update:modelValue', value)"
      @submit="(payload) => emit('submit', payload)"
      @cancel="emit('cancel')"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, useAttrs } from 'vue';
import RecordBillPaymentDialogPanel from './RecordBillPaymentDialogPanel.vue';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';

defineOptions({ inheritAttrs: false });

const props = defineProps<{
  modelValue: boolean;
  embedded?: boolean;
  dueAmount: number;
  dueCurrencyCode?: string | null;
  billId: number;
  profileId: number;
  tenantId: number;
  booksTenantId: number;
  isAp: boolean;
  channelMeta?: Record<string, unknown> | null;
  loading?: boolean;
  shipmentId?: number | null;
  replacingPayId?: number | null;
  prefillSnapshot?: PayCorrectionSnapshot | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: RecordBillPaymentInput];
  cancel: [];
}>();

const attrs = useAttrs();

const panelBind = computed(() => ({
  ...props,
  ...attrs,
}));
</script>
