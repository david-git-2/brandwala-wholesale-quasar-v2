<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 400px; max-width: 90vw">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="text-h6">
          {{ initialData ? 'Edit Shipment' : 'Create Shipment' }}
        </div>
        <q-btn icon="close" flat round dense @click="emit('update:modelValue', false)" />
      </q-card-section>

      <q-card-section>
        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
          autofocus
          @keyup.enter="onSubmit"
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="emit('update:modelValue', false)" />
        <q-btn
          color="primary"
          :label="initialData ? 'Update' : 'Create'"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue'

const props = defineProps<{
  modelValue: boolean
  initialData?: {
    name?: string
  } | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'submit', value: { name: string }): void
}>()

const form = reactive({
  name: '',
})

watch(
  () => props.modelValue,
  (value) => {
    if (value) {
      form.name = props.initialData?.name ?? ''
    }
  },
  { immediate: true }
)

const onSubmit = () => {
  emit('submit', { name: form.name })
  emit('update:modelValue', false)
}
</script>
