<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 400px; max-width: 90vw;">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Tenant' : 'Add Tenant' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
        />

        <q-input
          v-model="form.slug"
          label="Slug"
          outlined
          dense
        />

        <q-toggle
          v-model="form.is_active"
          label="Is Active"
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="onCancel" />
        <q-btn color="primary" :label="isEdit ? 'Update' : 'Save'" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

type TenantForm = {
  id?: number
  name: string
  slug: string
  is_active: boolean
}

const props = defineProps<{
  modelValue: boolean
  initialData?: TenantForm | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: TenantForm): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value)
})

const getDefaultForm = (): TenantForm => ({
  id: undefined,
  name: '',
  slug: '',
  is_active: true
})

const form = reactive<TenantForm>(getDefaultForm())

const isEdit = computed(() => !!props.initialData?.id)

watch(
  [() => props.modelValue, () => props.initialData],
  ([opened, data]) => {
    if (opened) {
      Object.assign(form, data ?? getDefaultForm())
    }
  },
  { immediate: true }
)

const onCancel = () => {
  localModelValue.value = false
}

const onSave = () => {
  emit('save', {
    id: form.id,
    name: form.name,
    slug: form.slug,
    is_active: form.is_active
  })
  localModelValue.value = false
}
</script>
