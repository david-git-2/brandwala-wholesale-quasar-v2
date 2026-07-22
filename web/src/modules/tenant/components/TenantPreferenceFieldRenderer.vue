<template>
  <div class="tenant-preference-field q-mb-md">
    <q-select
      v-if="field.type === 'currency_select'"
      :model-value="modelValue"
      outlined
      dense
      :label="field.label"
      :hint="field.hint"
      :options="currencies"
      option-value="id"
      :option-label="currencyOptionLabel"
      emit-value
      map-options
      class="soft-input"
      :rules="field.required ? [requiredRule] : undefined"
      @update:model-value="emit('update:modelValue', $event)"
    />

    <q-toggle
      v-else-if="field.type === 'boolean'"
      :model-value="Boolean(modelValue)"
      :label="field.label"
      @update:model-value="emit('update:modelValue', $event)"
    />

    <q-input
      v-else-if="field.type === 'text'"
      :model-value="String(modelValue ?? '')"
      outlined
      dense
      :label="field.label"
      :hint="field.hint"
      class="soft-input"
      :rules="field.required ? [requiredRule] : undefined"
      @update:model-value="emit('update:modelValue', $event)"
    />

    <q-input
      v-else-if="field.type === 'number'"
      :model-value="numberValue"
      type="number"
      outlined
      dense
      :label="field.label"
      :hint="field.hint"
      class="soft-input"
      :rules="field.required ? [requiredRule] : undefined"
      @update:model-value="
        emit('update:modelValue', $event === '' || $event === null ? null : Number($event))
      "
    />

    <q-select
      v-else-if="field.type === 'select'"
      :model-value="modelValue"
      outlined
      dense
      :label="field.label"
      :hint="field.hint"
      :options="field.options ?? []"
      option-value="value"
      option-label="label"
      emit-value
      map-options
      class="soft-input"
      :rules="field.required ? [requiredRule] : undefined"
      @update:model-value="emit('update:modelValue', $event)"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import type { PreferenceFieldDefinition } from '../types/preferenceFields';

const props = defineProps<{
  field: PreferenceFieldDefinition;
  modelValue: unknown;
}>();

const numberValue = computed(() => props.modelValue as number | null);

const emit = defineEmits<{
  'update:modelValue': [value: unknown];
}>();

const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);

function currencyOptionLabel(option: ThriftCurrency) {
  return `${option.code} (${option.symbol}) — ${option.name}`;
}

function requiredRule(value: unknown) {
  return value !== null && value !== undefined && value !== '' ? true : 'Required';
}
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
