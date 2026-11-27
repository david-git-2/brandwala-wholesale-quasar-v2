<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 440px; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">
          {{ initialForm?.id ? 'Edit Customer Group Member' : 'Add Customer Group Member' }}
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-py-md q-gutter-md">
        <q-input
          v-model="form.email"
          label="Email"
          outlined
          dense
          class="soft-input"
          :disable="!!form.id"
        />
        <q-input
          v-model="form.name"
          label="Name (Optional)"
          outlined
          dense
          class="soft-input"
        />

        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-grey-8">Status</div>
          <q-toggle
            v-model="form.isActive"
            :label="form.isActive ? 'Active' : 'Inactive'"
            color="positive"
            keep-color
          />
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          class="pill-btn"
          no-caps
          label="Save"
          @click="handleSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

export interface CustomerMemberFormData {
  id: number | null;
  email: string;
  name: string;
  isActive: boolean;
}

const props = defineProps<{
  modelValue: boolean;
  initialForm?: CustomerMemberFormData | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', form: CustomerMemberFormData): void;
}>();

const form = ref<CustomerMemberFormData>({
  id: null,
  email: '',
  name: '',
  isActive: true,
});

watch(
  () => props.modelValue,
  (val) => {
    if (val && props.initialForm) {
      form.value = { ...props.initialForm };
    } else {
      form.value = {
        id: null,
        email: '',
        name: '',
        isActive: true,
      };
    }
  },
);

const handleSave = () => {
  emit('save', form.value);
};
</script>
