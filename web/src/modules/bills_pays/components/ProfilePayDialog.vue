<template>
  <PayTransferDialog
    :model-value="modelValue"
    :tenant-id="tenantId"
    :books-tenant-id="booksTenantId"
    :tenant-name="tenantName"
    :initial-from-key="initialFromKey"
    :initial-to-key="initialToKey"
    :seed-parties="seedParties"
    @update:model-value="emit('update:modelValue', $event)"
    @posted="emit('posted')"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import PayTransferDialog from './PayTransferDialog.vue';
import {
  type PayTransferEntityType,
  type PayTransferParty,
  payTransferPartyKey,
} from '../types/payTransferParty';

const props = defineProps<{
  modelValue: boolean;
  direction: 'in' | 'out';
  entityType: PayTransferEntityType;
  partyName: string;
  partyId: number;
  tenantId: number;
  booksTenantId: number;
  tenantName: string;
  available: number;
  dueTotal: number;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  posted: [];
}>();

const tenantKey = computed(() => payTransferPartyKey('tenant', props.booksTenantId));
const profileKey = computed(() => payTransferPartyKey(props.entityType, props.partyId));

const seedParties = computed((): PayTransferParty[] => {
  if (props.entityType === 'tenant') return [];
  return [
    {
      key: profileKey.value,
      entityType: props.entityType,
      entityId: props.partyId,
      name: props.partyName,
      availableBalance: props.available,
      dueTotal: props.dueTotal,
    },
  ];
});

const initialFromKey = computed(() =>
  props.direction === 'out' ? tenantKey.value : profileKey.value,
);
const initialToKey = computed(() =>
  props.direction === 'out' ? profileKey.value : tenantKey.value,
);
</script>
