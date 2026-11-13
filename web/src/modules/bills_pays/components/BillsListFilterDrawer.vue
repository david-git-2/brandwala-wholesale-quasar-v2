<template>
  <q-dialog
    :model-value="modelValue"
    position="right"
    full-height
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <q-card class="column no-wrap bills-filter-drawer">
      <q-card-section class="row items-center q-pb-sm">
        <div class="text-subtitle1 text-weight-bold">Filters</div>
        <q-space />
        <q-btn v-close-popup flat round dense icon="ph ph-x" aria-label="Close" />
      </q-card-section>
      <q-separator />
      <q-card-section class="col scroll">
        <div class="text-caption text-weight-bold text-slate-500 q-mb-sm">Status</div>
        <TfDrawerSectionTabs
          :model-value="draftStatus"
          :tabs="statusTabs"
          aria-label="Bill status"
          @update:model-value="onStatusTab"
        />

        <div class="text-caption text-weight-bold text-slate-500 q-mt-lg q-mb-sm">From profile</div>
        <q-select
          v-model="draftFromProfileId"
          outlined
          dense
          emit-value
          map-options
          clearable
          :options="fromOptions"
          label="All profiles"
          option-value="id"
          option-label="name"
        />
      </q-card-section>
      <q-separator />
      <q-card-actions align="between" class="q-pa-md">
        <q-btn flat no-caps label="Clear" @click="onClear" />
        <q-btn unelevated no-caps color="primary" label="Apply" @click="onApply" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import type { StatusPill } from '../types/billList';
import type { DeskBillPartyOption } from '../composables/useDeskBillPartyOptions';

const props = defineProps<{
  modelValue: boolean;
  status: StatusPill;
  fromProfileId: number | null;
  fromOptions: DeskBillPartyOption[];
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  apply: [payload: { status: StatusPill; fromProfileId: number | null }];
}>();

const statusTabs = [
  { name: 'all', label: 'All' },
  { name: 'draft', label: 'Draft' },
  { name: 'due', label: 'Due' },
  { name: 'partial', label: 'Partial' },
  { name: 'paid', label: 'Paid' },
  { name: 'voided', label: 'Voided' },
] as const;

const draftStatus = ref<StatusPill>(props.status);
const draftFromProfileId = ref<number | null>(props.fromProfileId);

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    draftStatus.value = props.status;
    draftFromProfileId.value = props.fromProfileId;
  },
);

const onStatusTab = (value: string | number) => {
  draftStatus.value = value as StatusPill;
};

const onClear = () => {
  draftStatus.value = 'all';
  draftFromProfileId.value = null;
  emit('apply', { status: 'all', fromProfileId: null });
  emit('update:modelValue', false);
};

const onApply = () => {
  emit('apply', {
    status: draftStatus.value,
    fromProfileId: draftFromProfileId.value,
  });
  emit('update:modelValue', false);
};
</script>

<style scoped lang="scss">
.bills-filter-drawer {
  width: min(360px, 92vw);
  max-width: 360px;
}
</style>
