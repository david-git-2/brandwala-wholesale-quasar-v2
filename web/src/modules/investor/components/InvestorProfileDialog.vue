<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 520px; max-width: 95vw;">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Investor Profile' : 'Add Investor Profile' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input v-model="form.name" label="Name" outlined dense />
        <q-input v-model="form.phone" label="Phone" outlined dense />
        <q-input v-model="form.email" label="Email" outlined dense />
        <q-input v-model="form.address" label="Address" type="textarea" autogrow outlined />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="localModelValue = false" />
        <q-btn color="primary" :disable="!form.name.trim()" :label="isEdit ? 'Update' : 'Save'" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

import type { Investor } from '../types'

type InvestorForm = {
  id?: number
  tenant_id: number
  name: string
  phone: string | null
  email: string | null
  address: string | null
}

const props = defineProps<{
  modelValue: boolean
  initialData?: Investor | null
  tenantId: number
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: InvestorForm): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const getDefaultForm = (): InvestorForm => ({
  tenant_id: props.tenantId,
  name: '',
  phone: null,
  email: null,
  address: null,
})

const form = reactive<InvestorForm>(getDefaultForm())

const isEdit = computed(() => typeof form.id === 'number')

watch(
  [() => props.modelValue, () => props.initialData, () => props.tenantId],
  ([opened, initialData, tenantId]) => {
    if (!opened) {
      return
    }

    const next = initialData
      ? {
          id: initialData.id,
          tenant_id: initialData.tenant_id,
          name: initialData.name,
          phone: initialData.phone,
          email: initialData.email,
          address: initialData.address,
        }
      : {
          ...getDefaultForm(),
          tenant_id: tenantId,
        }

    Object.assign(form, next)
  },
  { immediate: true },
)

const onSave = () => {
  if (!form.name.trim()) {
    return
  }

  const payload: InvestorForm = {
    tenant_id: form.tenant_id,
    name: form.name.trim(),
    phone: form.phone?.trim() || null,
    email: form.email?.trim() || null,
    address: form.address?.trim() || null,
  }

  if (typeof form.id === 'number') {
    payload.id = form.id
  }

  emit('save', payload)
  localModelValue.value = false
}
</script>
