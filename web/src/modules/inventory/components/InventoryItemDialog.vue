<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 560px; max-width: 95vw;">
      <q-card-section>
        <div class="text-h6">Add Inventory Item</div>
      </q-card-section>

      <q-card-section>
        <q-form ref="formRef" class="q-gutter-md">
          <q-input
            v-model="form.name"
            label="Name *"
            outlined
            dense
            :rules="nameRules"
            lazy-rules
          />

          <q-input v-model="form.image_url" label="Image URL" outlined dense />

          <q-input
            v-model.number="form.cost"
            label="Cost"
            outlined
            dense
            type="number"
            min="0"
            step="0.01"
            :rules="costRules"
            lazy-rules
          />

          <q-input
            v-model.number="form.available_quantity"
            label="Available Unit"
            outlined
            dense
            type="number"
            min="0"
            step="1"
            :rules="availableUnitRules"
            lazy-rules
          />

          <q-input
            v-model="form.manufacturing_date"
            label="Manufacturing Date"
            outlined
            dense
            readonly
          >
            <template #append>
              <q-icon name="event" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="form.manufacturing_date" mask="YYYY-MM-DD">
                    <div class="row items-center justify-end">
                      <q-btn v-close-popup label="Close" color="primary" flat />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>

          <q-input
            v-model="form.expire_date"
            label="Expire Date"
            outlined
            dense
            readonly
          >
            <template #append>
              <q-icon name="event" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="form.expire_date" mask="YYYY-MM-DD">
                    <div class="row items-center justify-end">
                      <q-btn v-close-popup label="Close" color="primary" flat />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </q-form>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="localModelValue = false" />
        <q-btn color="primary" label="Save" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import type { QForm } from 'quasar'

import type { CreateInventoryItemInput } from '../types'

type InventoryItemForm = {
  name: string
  image_url: string
  barcode: string
  product_code: string
  cost: number | null
  available_quantity: number
  manufacturing_date: string
  expire_date: string
}

const props = defineProps<{
  modelValue: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (
    e: 'save',
    value: Omit<CreateInventoryItemInput, 'tenant_id' | 'source_type' | 'source_id' | 'status'> & {
      available_quantity: number
    },
  ): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const getDefaultForm = (): InventoryItemForm => ({
  name: '',
  image_url: '',
  barcode: '',
  product_code: '',
  cost: null,
  available_quantity: 0,
  manufacturing_date: '',
  expire_date: '',
})

const form = reactive<InventoryItemForm>(getDefaultForm())
const formRef = ref<QForm | null>(null)

const nameRules = [(value: string) => !!value?.trim() || 'Name is required']
const costRules = [(value: number | null) => value == null || value >= 0 || 'Cost cannot be negative']
const availableUnitRules = [
  (value: number) =>
    (Number.isFinite(value) && value >= 0) || 'Available unit must be 0 or greater',
]

watch(
  () => props.modelValue,
  (opened) => {
    if (opened) {
      Object.assign(form, getDefaultForm())
    }
  },
)

const onSave = async () => {
  const isValid = await formRef.value?.validate()
  if (!isValid) return

  emit('save', {
    name: form.name.trim(),
    image_url: form.image_url.trim() || null,
    barcode: form.barcode.trim() || null,
    product_code: form.product_code.trim() || null,
    cost: form.cost,
    available_quantity: Math.floor(form.available_quantity),
    manufacturing_date: form.manufacturing_date || null,
    expire_date: form.expire_date || null,
  })

  localModelValue.value = false
}
</script>
