<template>
  <q-select
    :model-value="modelValue"
    :options="filteredOptions"
    use-input
    fill-input
    hide-selected
    input-debounce="0"
    emit-value
    map-options
    outlined
    dense
    :clearable="clearable"
    :label="label"
    :loading="loading"
    :rules="rules"
    hide-bottom-space
    :data-test="dataTest"
    @filter="onFilter"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <slot />
  </q-select>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ValidationRule } from 'quasar';

const props = withDefaults(
  defineProps<{
    modelValue: number | null;
    options: Array<{ label: string; value: number }>;
    loading?: boolean;
    clearable?: boolean;
    label?: string;
    rules?: ValidationRule[];
    dataTest?: string;
  }>(),
  {
    loading: false,
    clearable: true,
    label: undefined,
    rules: undefined,
    dataTest: undefined,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: number | null];
}>();

const filterText = ref('');

const filteredOptions = computed(() => {
  const needle = filterText.value.trim().toLowerCase();
  if (!needle) return props.options;
  return props.options.filter((o) => o.label.toLowerCase().includes(needle));
});

function onFilter(val: string, update: (fn: () => void) => void) {
  update(() => {
    filterText.value = val;
  });
}

watch(
  () => props.options,
  () => {
    filterText.value = '';
  },
);
</script>