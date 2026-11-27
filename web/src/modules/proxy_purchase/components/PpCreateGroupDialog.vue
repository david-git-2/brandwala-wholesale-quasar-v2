<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 360px; max-width: 92vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold">Create group</div>
        <q-space />
        <q-btn v-close-popup flat round dense icon="ph ph-x" :ripple="false" />
      </q-card-section>

      <q-card-section class="q-pt-sm q-gutter-y-sm">
        <q-input
          v-model="name"
          outlined
          dense
          hide-bottom-space
          label="Group name *"
          autofocus
          @keyup.enter="submit"
        />
        <q-select
          v-model="type"
          outlined
          dense
          hide-bottom-space
          emit-value
          map-options
          label="Type *"
          :options="typeOptions"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none q-pa-md">
        <q-btn flat no-caps label="Cancel" :ripple="false" v-close-popup />
        <TfBtn
          variant="primary"
          size="md"
          label="Create"
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
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PpPeopleGroupType } from '../types/ppPeople';

const props = defineProps<{
  modelValue: boolean;
  defaultType: PpPeopleGroupType;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: { name: string; type: PpPeopleGroupType }];
}>();

const name = ref('');
const type = ref<PpPeopleGroupType>('customer');

const typeOptions = [
  { label: 'Customer', value: 'customer' as const },
  { label: 'Supplier', value: 'supplier' as const },
];

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      name.value = '';
      type.value = props.defaultType;
    }
  },
);

const canSubmit = computed(() => name.value.trim().length > 0);

const submit = () => {
  if (!canSubmit.value) return;
  emit('submit', { name: name.value.trim(), type: type.value });
};
</script>