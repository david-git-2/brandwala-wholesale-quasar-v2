<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 360px; max-width: 440px; border-radius: 14px">
      <q-card-section>
        <div class="text-h6 text-weight-bold">Override order status</div>
        <div class="text-caption text-grey-7 q-mt-xs">
          Use only to fix mistakes. This bypasses normal workflow actions.
        </div>
      </q-card-section>

      <q-card-section class="q-pt-none q-gutter-y-md">
        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Current status</div>
          <q-input
            :model-value="currentStatusLabel"
            dense
            outlined
            readonly
            bg-color="grey-1"
          />
        </div>

        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">New status</div>
          <q-select
            v-model="targetStatus"
            :options="statusOptions"
            emit-value
            map-options
            dense
            outlined
            options-dense
          />
        </div>

        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">Reason</div>
          <q-input
            v-model="reason"
            type="textarea"
            autogrow
            dense
            outlined
            placeholder="Why is this status being changed?"
            :rules="[(val) => !!String(val || '').trim() || 'Reason is required']"
          />
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          color="primary"
          no-caps
          label="Apply override"
          :loading="loading"
          :disable="!canSubmit"
          @click="submit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ShopOrder } from '../types';
import { getStaffCatalogStatusLabel, normalizeCatalogOrderStatus } from '../utils/catalogOrderStatus';

const props = defineProps<{
  modelValue: boolean;
  order: ShopOrder | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'apply', payload: { status: string; reason: string }): void;
}>();

const CATALOG_OVERRIDE_STATUSES = [
  'submitted',
  'priced',
  'countered',
  'final_offered',
  'confirmed',
  'procuring',
  'ordered',
  'delivered',
  'cancelled',
] as const;

const targetStatus = ref<string>('submitted');
const reason = ref('');

const currentStatusLabel = computed(() =>
  getStaffCatalogStatusLabel(props.order?.status),
);

const statusOptions = computed(() =>
  CATALOG_OVERRIDE_STATUSES.map((value) => ({
    label: getStaffCatalogStatusLabel(value),
    value,
  })),
);

const canSubmit = computed(
  () =>
    !!targetStatus.value &&
    !!reason.value.trim() &&
    targetStatus.value !== normalizeCatalogOrderStatus(props.order?.status),
);

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    targetStatus.value = normalizeCatalogOrderStatus(props.order?.status) || 'submitted';
    reason.value = '';
  },
);

function close() {
  emit('update:modelValue', false);
}

function submit() {
  if (!canSubmit.value) return;
  emit('apply', {
    status: targetStatus.value,
    reason: reason.value.trim(),
  });
}
</script>
