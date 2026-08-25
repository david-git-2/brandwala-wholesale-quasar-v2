<template>
  <q-card flat bordered class="pbc-staff-actions q-pa-md">
    <div class="row items-center justify-between q-col-gutter-sm">
      <div class="col-auto">
        <q-btn
          v-if="showCancel"
          outline
          color="negative"
          no-caps
          icon="ph ph-x-circle"
          :label="$t('product_based_costing.cancel_file')"
          class="text-weight-bold action-btn square-btn"
          :loading="isCancelling"
          @click="emit('cancel-file')"
        />
      </div>

      <div class="col row items-center justify-end q-gutter-sm">
        <span v-if="waitMessage" class="text-caption text-grey-7 text-right wait-copy">
          {{ waitMessage }}
        </span>
        <q-btn
          v-if="primaryAction"
          unelevated
          color="primary"
          no-caps
          icon-right="ph ph-arrow-right"
          class="text-weight-bold q-px-lg action-btn square-btn"
          :label="primaryActionLabel"
          :loading="isPrimaryLoading"
          :disable="primaryDisabled"
          @click="emit('primary-action', primaryAction)"
        >
          <q-tooltip v-if="primaryDisabledReason">{{ primaryDisabledReason }}</q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>
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
  box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.06);
  border-radius: 10px 10px 0 0;
}

.action-btn {
  border-radius: 8px;
}

.wait-copy {
  max-width: 280px;
}
</style>
