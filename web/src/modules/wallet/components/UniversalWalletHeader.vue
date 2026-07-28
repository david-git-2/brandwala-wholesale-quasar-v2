<template>
  <div class="row items-center justify-between q-col-gutter-sm">
    <div>
      <div class="text-caption text-uppercase text-weight-bold text-muted overline-text">
        {{ overlineLabel }}
      </div>
      <div class="text-h5 text-weight-bolder text-ink row items-center q-gutter-x-sm">
        <span>{{ displayTitle }}</span>
        <q-chip
          dense
          square
          size="sm"
          class="entity-chip text-weight-bold"
        >
          ID #{{ entityId }}
        </q-chip>
      </div>
    </div>
    <div class="row items-center q-gutter-x-sm">
      <slot name="actions">
        <q-btn
          v-if="allowAdjustment"
          label="Adjust Balance"
          icon="tune"
          color="primary"
          unelevated
          dense
          class="q-px-sm"
          @click="$emit('open-adjustment')"
        />
      </slot>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { UniversalWalletEntityType } from '../types';

const props = withDefaults(
  defineProps<{
    entityType: UniversalWalletEntityType;
    entityId: number;
    entityName?: string;
    allowAdjustment?: boolean;
  }>(),
  {
    entityName: '',
    allowAdjustment: false,
  },
);

defineEmits<{
  (e: 'open-adjustment'): void;
}>();

const overlineLabel = computed(() => {
  switch (props.entityType) {
    case 'customer':
      return 'Customer Wallet';
    case 'vendor':
      return 'Vendor Wallet';
    case 'courier':
      return 'Courier Wallet';
    case 'middleman':
      return 'Middleman Wallet';
    case 'tenant':
      return 'Tenant Ledger';
    default:
      return 'Wallet Ledger';
  }
});

const displayTitle = computed(() => {
  if (props.entityName) return props.entityName;
  return `${props.entityType.charAt(0).toUpperCase() + props.entityType.slice(1)} Account`;
});
</script>

<style scoped>
.overline-text {
  color: var(--bw-theme-muted);
  letter-spacing: 0.05em;
}

.text-ink {
  color: var(--bw-theme-ink);
}

.entity-chip {
  background: var(--bw-theme-primary-soft);
  color: var(--bw-theme-primary);
}
</style>
