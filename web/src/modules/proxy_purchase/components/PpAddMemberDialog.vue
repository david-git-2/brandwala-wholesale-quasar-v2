<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 360px; max-width: 92vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold">Add member</div>
        <q-space />
        <q-btn v-close-popup flat round dense icon="ph ph-x" :ripple="false" />
      </q-card-section>

      <q-card-section class="q-pt-sm q-gutter-y-sm">
        <q-input
          v-model="name"
          outlined
          dense
          hide-bottom-space
          label="Name *"
          autofocus
        />
        <q-input
          v-model="email"
          outlined
          dense
          hide-bottom-space
          type="email"
          label="Email *"
          @keyup.enter="submit"
        />
        <q-select
          v-model="role"
          outlined
          dense
          hide-bottom-space
          emit-value
          map-options
          label="Role *"
          :options="roleOptions"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none q-pa-md">
        <q-btn flat no-caps label="Cancel" :ripple="false" v-close-popup />
        <TfBtn
          variant="primary"
          size="md"
          label="Add"
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
import type { PpPeopleMemberRole } from '../types/ppPeople';

const props = defineProps<{
  modelValue: boolean;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: { name: string; email: string; role: PpPeopleMemberRole }];
}>();

const name = ref('');
const email = ref('');
const role = ref<PpPeopleMemberRole>('staff');

const roleOptions = [
  { label: 'Admin', value: 'admin' as const },
  { label: 'Staff', value: 'staff' as const },
];

const reset = () => {
  name.value = '';
  email.value = '';
  role.value = 'staff';
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) reset();
  },
);

const canSubmit = computed(
  () => name.value.trim().length > 0 && email.value.trim().length > 0,
);

const submit = () => {
  if (!canSubmit.value) return;
  emit('submit', {
    name: name.value.trim(),
    email: email.value.trim(),
    role: role.value,
  });
};
</script>