<template>
  <q-dialog v-model="localOpen" persistent>
    <q-card style="min-width: 480px; max-width: 90vw">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Currency' : 'Add Currency' }}</div>
      </q-card-section>
      <q-card-section class="q-gutter-md">
        <q-input v-model="form.code" label="Code" outlined dense :rules="[(v) => !!v || 'Required']" />
        <q-input v-model="form.symbol" label="Symbol" outlined dense :rules="[(v) => !!v || 'Required']" />
        <q-input v-model="form.name" label="Name" outlined dense :rules="[(v) => !!v || 'Required']" />
        <q-input v-model="form.country" label="Country" outlined dense :rules="[(v) => !!v || 'Required']" />
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
import type { GlobalCurrency, GlobalCurrencyCreateInput } from '../types'

const props = defineProps<{
  modelValue: boolean
  initialData?: GlobalCurrency | null
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  save: [payload: GlobalCurrencyCreateInput & { id?: number }]
}>()

const localOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const isEdit = computed(() => Boolean(props.initialData?.id))

const form = ref({
  id: undefined as number | undefined,
  code: '',
  symbol: '',
  name: '',
  country: '',
  is_active: true,
})

watch(
  () => props.initialData,
  (value) => {
    form.value = value
      ? { id: value.id, code: value.code, symbol: value.symbol, name: value.name, country: value.country, is_active: value.is_active }
      : { id: undefined, code: '', symbol: '', name: '', country: '', is_active: true }
  },
  { immediate: true },
)

const save = () => {
  const payload: GlobalCurrencyCreateInput & { id?: number } = {
    code: form.value.code,
    symbol: form.value.symbol,
    name: form.value.name,
    country: form.value.country,
    is_active: form.value.is_active,
  }
  if (form.value.id !== undefined) payload.id = form.value.id
  emit('save', payload)
}
</script>
