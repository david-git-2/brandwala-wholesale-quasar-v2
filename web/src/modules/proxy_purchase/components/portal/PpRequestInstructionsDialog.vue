<template>
  <FilterSidebar
    :model-value="modelValue"
    title="Order instructions"
    width="min(420px, 92vw)"
    :resizable="false"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="text-caption text-grey-7 q-mb-sm">Notes for your admin about this request</div>
    <q-input
      v-model="text"
      outlined
      dense
      hide-bottom-space
      type="textarea"
      autogrow
      label="Instructions"
      :rows="8"
      autofocus
    />
    <template #footer>
      <div class="row justify-end q-gutter-sm">
        <TfBtn variant="tertiary" size="md" label="Cancel" @click="$emit('update:modelValue', false)" />
        <TfBtn
          variant="primary"
          size="md"
          label="Save"
          :loading="loading"
          @click="submit"
        />
      </div>
    </template>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';

const props = defineProps<{
  modelValue: boolean;
  initialText?: string | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [bucketDescription: string];
}>();

const text = ref('');

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      text.value = props.initialText?.trim() ?? '';
    }
  },
);

const submit = () => {
  emit('submit', text.value.trim());
};
</script>