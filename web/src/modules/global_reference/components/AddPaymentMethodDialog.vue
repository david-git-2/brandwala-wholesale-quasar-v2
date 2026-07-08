<template>
  <q-dialog v-model="localOpen" persistent>
    <q-card style="min-width: 480px; max-width: 90vw">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Payment Method' : 'Add Payment Method' }}</div>
      </q-card-section>
      <q-card-section class="q-gutter-md">
        <q-input v-model="form.code" label="Code" outlined dense />
        <q-input v-model="form.name" label="Name" outlined dense />
        <q-select
          v-model="form.category"
          :options="categoryOptions"
          label="Category"
          outlined
          dense
          emit-value
          map-options
        />
        <q-select
          v-model="form.scope"
          :options="scopeOptions"
          label="Scope"
          outlined
          dense
          emit-value
          map-options
        />
        <q-input v-model.number="form.sort_order" type="number" label="Sort order" outlined dense />
        <q-toggle v-model="form.is_active" label="Active" color="positive" />
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="localOpen = false" />
        <q-btn color="primary" label="Save" @click="save" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  PAYMENT_METHOD_CATEGORIES,
  PAYMENT_METHOD_SCOPES,
  type PaymentMethod,
  type PaymentMethodCreateInput,
} from '../types';

const props = defineProps<{ modelValue: boolean; initialData?: PaymentMethod | null }>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  save: [payload: PaymentMethodCreateInput & { id?: number }];
}>();

const localOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});
const isEdit = computed(() => Boolean(props.initialData?.id));
const categoryOptions = PAYMENT_METHOD_CATEGORIES.map((o) => ({ label: o.label, value: o.value }));
const scopeOptions = PAYMENT_METHOD_SCOPES.map((o) => ({ label: o.label, value: o.value }));

const form = ref({
  id: undefined as number | undefined,
  code: '',
  name: '',
  category: 'bd_mobile_wallet',
  scope: 'bd',
  sort_order: 0,
  is_active: true,
});

watch(
  () => props.initialData,
  (value) => {
    form.value = value
      ? {
          id: value.id,
          code: value.code,
          name: value.name,
          category: value.category,
          scope: value.scope,
          sort_order: value.sort_order,
          is_active: value.is_active,
        }
      : {
          id: undefined,
          code: '',
          name: '',
          category: 'bd_mobile_wallet',
          scope: 'bd',
          sort_order: 0,
          is_active: true,
        };
  },
  { immediate: true },
);

const save = () => {
  const payload: PaymentMethodCreateInput & { id?: number } = {
    code: form.value.code,
    name: form.value.name,
    category: form.value.category,
    scope: form.value.scope,
    sort_order: form.value.sort_order,
    is_active: form.value.is_active,
  };
  if (form.value.id !== undefined) payload.id = form.value.id;
  emit('save', payload);
};
</script>
