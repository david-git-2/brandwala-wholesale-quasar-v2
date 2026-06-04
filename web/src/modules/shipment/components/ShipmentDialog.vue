<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 400px; max-width: 90vw">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="text-h6">
          {{ initialData ? 'Edit Shipment' : 'Create Shipment' }}
        </div>
        <q-btn icon="close" flat round dense @click="emit('update:modelValue', false)" />
      </q-card-section>

      <q-card-section class="q-gutter-y-md">
        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
          autofocus
          @keyup.enter="onSubmit"
        />

        <div class="row items-center justify-between q-py-xs">
          <div class="text-subtitle2 text-grey-8">Pricing Mode:</div>
          <q-btn-toggle
            v-model="form.is_gbp"
            dense
            unelevated
            no-caps
            :disable="!!initialData"
            toggle-color="primary"
            color="white"
            text-color="primary"
            :options="[
              { label: 'GBP Pricing', value: true },
              { label: 'Direct BDT Cost', value: false },
            ]"
          />
        </div>
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
    is_gbp?: boolean
  } | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'submit', value: { name: string; is_gbp: boolean }): void
}>()

const form = reactive({
  name: '',
  is_gbp: true,
})

watch(
  () => props.modelValue,
  (value) => {
    if (value) {
      form.name = props.initialData?.name ?? ''
      form.is_gbp = props.initialData?.is_gbp ?? true
    }
  },
  { immediate: true }
)

const onSubmit = () => {
  emit('submit', { name: form.name, is_gbp: form.is_gbp })
  emit('update:modelValue', false)
}
</script>
