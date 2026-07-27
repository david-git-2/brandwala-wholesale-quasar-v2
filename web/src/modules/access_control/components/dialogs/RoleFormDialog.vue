<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 380px; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">{{ isEdit ? 'Edit Role' : 'Create Role' }}</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-py-md">
        <q-input
          v-model="form.name"
          label="Role Name"
          outlined
          dense
          class="q-mb-md soft-input"
          :rules="[(val) => !!val || 'Name is required']"
        />

        <q-input
          v-model="form.slug"
          label="Role Slug"
          outlined
          dense
          class="q-mb-md soft-input"
          hint="Lowercase alphanumeric and hyphens only (e.g. tech-staff)"
          :disable="isEdit"
          :rules="[
            (val) => !!val || 'Slug is required',
            (val) => /^[a-z0-9-]+$/.test(val) || 'Invalid slug format',
          ]"
        />

        <q-toggle
          v-model="form.is_admin"
          label="Administrator Role (Implicit Full Access)"
          color="purple"
          class="q-mb-sm"
          :disable="isEdit && selectedRole?.is_system"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          class="pill-btn"
          no-caps
          :label="isEdit ? 'Save' : 'Create'"
          :loading="submitting"
          @click="$emit('save', form)"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

const props = defineProps<{
  modelValue: boolean;
  isEdit: boolean;
  selectedRole?: any;
  submitting: boolean;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', form: { name: string; slug: string; is_admin: boolean }): void;
}>();

const form = ref({
  name: '',
  slug: '',
  is_admin: false,
});

watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      if (props.isEdit && props.selectedRole) {
        form.value = {
          name: props.selectedRole.name,
          slug: props.selectedRole.slug,
          is_admin: props.selectedRole.is_admin,
        };
      } else {
        form.value = {
          name: '',
          slug: '',
          is_admin: false,
        };
      }
    }
  },
);
</script>
