<template>
  <div class="pbc-staff-actions">
    <div class="pbc-staff-actions__inner row items-center justify-end q-gutter-sm">
      <span v-if="waitMessage" class="text-caption text-grey-7 wait-copy">
        {{ waitMessage }}
      </span>
      <q-btn
        v-if="showCancel"
        outline
        color="negative"
        dense
        no-caps
        icon="ph ph-x-circle"
        :label="$t('product_based_costing.cancel_file')"
        class="text-weight-bold action-btn square-btn"
        :loading="isCancelling"
        @click="emit('cancel-file')"
      />
      <q-btn
        v-if="primaryAction"
        unelevated
        color="primary"
        dense
        no-caps
        icon-right="ph ph-arrow-right"
        class="text-weight-bold q-px-md action-btn square-btn"
        :label="primaryActionLabel"
        :loading="isPrimaryLoading"
        :disable="primaryDisabled"
        @click="emit('primary-action', primaryAction)"
      >
        <q-tooltip v-if="primaryDisabledReason">{{ primaryDisabledReason }}</q-tooltip>
      </q-btn>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  getStaffPbcPrimaryAction,
  isPbcTerminalStatus,
  type StaffPbcPrimaryAction,
} from '../utils/pbcFileStatus';
import { normalizePbcFileStatus } from '../composables/useProductBasedCostingFileDetailsState';

const props = defineProps<{
  status: string;
  isPrimaryLoading?: boolean;
  isCancelling?: boolean;
  primaryDisabled?: boolean;
  primaryDisabledReason?: string;
  showCancel?: boolean;
}>();

const emit = defineEmits<{
  (e: 'primary-action', action: StaffPbcPrimaryAction): void;
  (e: 'cancel-file'): void;
}>();

const { t } = useI18n();

const primaryAction = computed(() => getStaffPbcPrimaryAction(props.status));

const primaryActionLabel = computed(() => {
  if (!primaryAction.value) return '';
  const key = `product_based_costing.action_${primaryAction.value}`;
  return t(key);
});

const waitMessage = computed(() => {
  const st = normalizePbcFileStatus(props.status);
  if (st === 'delivered') return t('product_based_costing.wait_delivered');
  if (st === 'cancelled') return t('product_based_costing.wait_cancelled');
  if (isPbcTerminalStatus(st)) return '';
  return '';
});
</script>

<style scoped>
.pbc-staff-actions {
  position: sticky;
  bottom: 0;
  z-index: 10;
  background: #fff;
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.05);
  margin: 0 -8px -8px;
  border-radius: 10px 10px 0 0;
}

.pbc-staff-actions__inner {
  padding: 8px 12px;
  padding-bottom: max(8px, env(safe-area-inset-bottom));
}

.action-btn {
  border-radius: 8px;
}

.wait-copy {
  max-width: 240px;
  text-align: right;
  margin-right: auto;
}
</style>
