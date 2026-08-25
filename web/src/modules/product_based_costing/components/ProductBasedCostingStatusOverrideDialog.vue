<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 360px; max-width: 440px; border-radius: 14px">
      <q-card-section>
        <div class="text-h6 text-weight-bold">{{ $t('product_based_costing.override_status_title') }}</div>
        <div class="text-caption text-grey-7 q-mt-xs">
          {{ $t('product_based_costing.override_status_hint') }}
        </div>
      </q-card-section>

      <q-card-section class="q-pt-none q-gutter-y-md">
        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">
            {{ $t('product_based_costing.status') }}
          </div>
          <q-input
            :model-value="currentStatusLabel"
            dense
            outlined
            readonly
            bg-color="grey-1"
          />
        </div>

        <div>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">
            {{ $t('product_based_costing.override_new_status') }}
          </div>
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
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">
            {{ $t('product_based_costing.override_reason') }}
          </div>
          <q-input
            v-model="reason"
            type="textarea"
            autogrow
            dense
            outlined
            :placeholder="$t('product_based_costing.override_reason_placeholder')"
            :rules="[(val) => !!String(val || '').trim() || $t('product_based_costing.override_reason_required')]"
          />
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps :label="$t('product_based_costing.cancel')" @click="close" />
        <q-btn
          unelevated
          color="primary"
          no-caps
          :label="$t('product_based_costing.apply_override')"
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
import { useI18n } from 'vue-i18n';
import type { ProductBasedCostingFile } from '../types';
import { normalizePbcFileStatus, workflowStatuses } from '../composables/useProductBasedCostingFileDetailsState';

const props = defineProps<{
  modelValue: boolean;
  file: ProductBasedCostingFile | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'apply', payload: { status: string; reason: string }): void;
}>();

const { t } = useI18n();

const targetStatus = ref('pending');
const reason = ref('');

const currentStatusLabel = computed(() => {
  const st = normalizePbcFileStatus(props.file?.status || 'pending');
  return t(`product_based_costing.status_${st}`);
});

const statusOptions = computed(() => [
  ...workflowStatuses.map((st) => ({
    label: t(`product_based_costing.status_${st}`),
    value: st,
  })),
  { label: t('product_based_costing.status_cancelled'), value: 'cancelled' },
]);

const canSubmit = computed(
  () =>
    !!targetStatus.value &&
    targetStatus.value !== normalizePbcFileStatus(props.file?.status || 'pending') &&
    !!reason.value.trim(),
);

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    targetStatus.value = normalizePbcFileStatus(props.file?.status || 'pending');
    reason.value = '';
  },
);

function close() {
  emit('update:modelValue', false);
}

function submit() {
  if (!canSubmit.value) return;
  emit('apply', { status: targetStatus.value, reason: reason.value.trim() });
}
</script>
