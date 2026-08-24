<template>
  <q-card flat bordered class="catalog-staff-actions q-pa-md">
    <div class="row items-center justify-between q-col-gutter-sm">
      <div class="col-auto">
        <q-btn
          v-if="showCancel"
          outline
          color="negative"
          no-caps
          icon="ph ph-trash"
          label="Cancel order"
          class="text-weight-bold action-btn"
          :loading="isDeleting"
          @click="emit('cancel-order')"
        />
      </div>

      <div class="col row items-center justify-end q-gutter-sm">
        <span v-if="waitMessage" class="text-caption text-grey-7 text-right wait-copy">{{ waitMessage }}</span>
        <q-btn
          v-if="primaryAction"
          unelevated
          color="primary"
          no-caps
          icon-right="ph ph-arrow-right"
          class="text-weight-bold q-px-lg action-btn"
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
import {
  getStaffCatalogPrimaryAction,
  getStaffCatalogPrimaryActionLabel,
  getStaffCatalogStatusLabel,
  normalizeCatalogOrderStatus,
  type StaffCatalogPrimaryAction,
} from '../utils/catalogOrderStatus';

const props = defineProps<{
  status: string;
  isDeleting?: boolean;
  isPrimaryLoading?: boolean;
  primaryDisabled?: boolean;
  primaryDisabledReason?: string;
  showCancel?: boolean;
}>();

const emit = defineEmits<{
  (e: 'primary-action', action: StaffCatalogPrimaryAction): void;
  (e: 'cancel-order'): void;
}>();

const primaryAction = computed(() => getStaffCatalogPrimaryAction(props.status));

const primaryActionLabel = computed(() =>
  primaryAction.value ? getStaffCatalogPrimaryActionLabel(primaryAction.value) : '',
);

const waitMessage = computed(() => {
  const st = normalizeCatalogOrderStatus(props.status);
  if (st === 'priced' || st === 'final_offered') {
    return getStaffCatalogStatusLabel(st);
  }
  if (st === 'delivered' || st === 'cancelled') {
    return getStaffCatalogStatusLabel(st);
  }
  return '';
});
</script>

<style scoped>
.catalog-staff-actions {
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
  max-width: 260px;
}
</style>
