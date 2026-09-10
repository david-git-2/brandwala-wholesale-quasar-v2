<template>
  <q-card
    flat
    :bordered="variant !== 'footer'"
    :class="variant === 'footer' ? 'catalog-staff-actions catalog-staff-actions--footer q-px-md q-py-xs' : 'catalog-staff-actions q-pa-md'"
  >
    <div class="row items-center justify-between no-wrap q-gutter-x-sm">
      <div class="col-auto row items-center q-gutter-sm no-wrap">
        <q-btn
          v-if="primaryAction"
          unelevated
          dense
          color="primary"
          no-caps
          icon-right="ph ph-arrow-right"
          class="text-weight-bold q-px-md action-btn"
          :label="primaryActionLabel"
          :loading="isPrimaryLoading"
          :disable="primaryDisabled"
          @click="emit('primary-action', primaryAction)"
        >
          <q-tooltip v-if="primaryDisabledReason">{{ primaryDisabledReason }}</q-tooltip>
        </q-btn>
      </div>

      <div class="col row items-center justify-end min-width-0">
        <slot />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  getStaffCatalogPrimaryAction,
  getStaffCatalogPrimaryActionLabel,
  type StaffCatalogPrimaryAction,
} from '../utils/catalogOrderStatus';

const props = withDefaults(
  defineProps<{
    status: string;
    isDeleting?: boolean;
    isPrimaryLoading?: boolean;
    primaryDisabled?: boolean;
    primaryDisabledReason?: string;
    showCancel?: boolean;
    variant?: 'card' | 'footer';
  }>(),
  { variant: 'card' },
);

const emit = defineEmits<{
  (e: 'primary-action', action: StaffCatalogPrimaryAction): void;
  (e: 'cancel-order'): void;
}>();

const primaryAction = computed(() => getStaffCatalogPrimaryAction(props.status));

const primaryActionLabel = computed(() =>
  primaryAction.value ? getStaffCatalogPrimaryActionLabel(primaryAction.value) : '',
);
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

.catalog-staff-actions--footer {
  position: static;
  box-shadow: none;
  border-radius: 0;
}

.min-width-0 {
  min-width: 0;
}

.action-btn {
  border-radius: 8px;
}
</style>
