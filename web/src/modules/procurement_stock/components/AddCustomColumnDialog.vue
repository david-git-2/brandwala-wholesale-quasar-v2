<template>
  <q-dialog :model-value="modelValue" @update:model-value="(val) => emit('update:modelValue', val)">
    <q-card style="width: 420px; max-width: 95vw; border-radius: 12px" class="bg-white">
      <q-form @submit="handleSubmit">
        <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
          <div class="row items-center q-gutter-x-sm">
            <q-icon name="ph ph-columns" size="20px" color="primary" />
            <div class="text-subtitle1 text-weight-bold text-grey-9">Add Custom Column</div>
          </div>
          <q-btn flat round dense icon="ph ph-x" size="sm" color="grey-7" v-close-popup />
        </div>

        <div class="q-pa-md column q-gutter-y-sm">
          <q-input
            v-model="columnName"
            label="Column Name / Header *"
            outlined
            dense
            placeholder="e.g. Fabric Details / Color Code"
            :rules="[(val) => !!val?.trim() || 'Column name is required']"
            autofocus
          >
            <template #prepend>
              <q-icon name="ph ph-text-t" size="18px" color="grey-6" />
            </template>
          </q-input>

          <q-select
            v-model="columnType"
            label="Data Type"
            :options="[
              { label: 'Text', value: 'text' },
              { label: 'Number / Currency', value: 'number' },
              { label: 'Date', value: 'date' }
            ]"
            emit-value
            map-options
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="ph ph-faders" size="18px" color="grey-6" />
            </template>
          </q-select>
        </div>

        <div class="row justify-end q-pa-md border-top bg-grey-1 q-gutter-x-sm">
          <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
          <q-btn
            type="submit"
            unelevated
            no-caps
            label="Add Column"
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-md"
            style="border-radius: 8px"
          />
        </div>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'add-column', col: { name: string; label: string; type: string }): void;
}>();

const columnName = ref('');
const columnType = ref('text');

const handleSubmit = () => {
  const trimmed = columnName.value.trim();
  if (!trimmed) return;
  emit('add-column', {
    name: `custom_${Date.now()}`,
    label: trimmed,
    type: columnType.value,
  });
  columnName.value = '';
  columnType.value = 'text';
  emit('update:modelValue', false);
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-top {
  border-top: 1px solid #e2e8f0;
}
</style>
