<template>
  <q-dialog v-model="localOpen" persistent>
    <q-card style="min-width: 480px; max-width: 90vw">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Unit' : 'Add Unit' }}</div>
      </q-card-section>
      <q-card-section class="q-gutter-md">
        <q-input v-model="form.code" label="Code" outlined dense />
        <q-input v-model="form.name" label="Name" outlined dense />
        <q-select v-model="form.unit_type" :options="unitTypeOptions" label="Unit type" outlined dense emit-value map-options />
        <q-input v-model="form.symbol" label="Symbol" outlined dense />
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
import { computed, ref, watch } from 'vue'
import { UNIT_TYPES, type UnitOfMeasure, type UnitOfMeasureCreateInput } from '../types'

const props = defineProps<{ modelValue: boolean; initialData?: UnitOfMeasure | null }>()
const emit = defineEmits<{ 'update:modelValue': [value: boolean]; save: [payload: UnitOfMeasureCreateInput & { id?: number }] }>()

const localOpen = computed({ get: () => props.modelValue, set: (v) => emit('update:modelValue', v) })
const isEdit = computed(() => Boolean(props.initialData?.id))
const unitTypeOptions = UNIT_TYPES.map((o) => ({ label: o.label, value: o.value }))

const form = ref({
  id: undefined as number | undefined,
  code: '',
  name: '',
  unit_type: 'count',
  symbol: '',
  sort_order: 0,
  is_active: true,
})

watch(() => props.initialData, (value) => {
  form.value = value
    ? { id: value.id, code: value.code, name: value.name, unit_type: value.unit_type, symbol: value.symbol ?? '', sort_order: value.sort_order, is_active: value.is_active }
    : { id: undefined, code: '', name: '', unit_type: 'count', symbol: '', sort_order: 0, is_active: true }
}, { immediate: true })

const save = () => {
  const payload: UnitOfMeasureCreateInput & { id?: number } = {
    code: form.value.code,
    name: form.value.name,
    unit_type: form.value.unit_type,
    symbol: form.value.symbol || null,
    sort_order: form.value.sort_order,
    is_active: form.value.is_active,
  }
  if (form.value.id !== undefined) payload.id = form.value.id
  emit('save', payload)
}
</script>
