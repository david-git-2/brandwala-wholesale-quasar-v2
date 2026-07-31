<script setup lang="ts">
import { computed } from 'vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';

const props = defineProps<{
  modelValue: boolean;
  statusFilter: string | null;
  conditionFilter: string | null;
  statusOptions: Array<{ label: string; value: string }>;
  conditionOptions: Array<{ label: string; value: string }>;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update:statusFilter', val: string | null): void;
  (e: 'update:conditionFilter', val: string | null): void;
  (e: 'apply'): void;
  (e: 'reset'): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const status = computed({
  get: () => props.statusFilter,
  set: (val: string | null) => emit('update:statusFilter', val),
});

const condition = computed({
  get: () => props.conditionFilter,
  set: (val: string | null) => emit('update:conditionFilter', val),
});
</script>

<template>
  <FilterSidebar v-model="isOpen" title="Filters">
    <div class="q-gutter-y-md q-pa-sm">
      <q-select
        v-model="status"
        :options="statusOptions"
        outlined
        dense
        label="Status"
        emit-value
        map-options
        clearable
      />
      <q-select
        v-model="condition"
        :options="conditionOptions"
        outlined
        dense
        label="Condition"
        emit-value
        map-options
        clearable
      />
      <div class="row justify-end q-gutter-x-sm q-mt-md">
        <q-btn flat no-caps label="Reset" color="grey-7" @click="$emit('reset')" />
        <q-btn
          unelevated
          no-caps
          label="Apply Filters"
          color="primary"
          @click="$emit('apply')"
        />
      </div>
    </div>
  </FilterSidebar>
</template>
