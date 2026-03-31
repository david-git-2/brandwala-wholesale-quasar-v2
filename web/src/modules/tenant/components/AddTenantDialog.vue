<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 400px; max-width: 90vw;">
      <q-card-section>
        <div class="text-h6">Add Tenant</div>
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
        <q-btn flat label="Cancel" v-close-popup @click="onCancel" />
        <q-btn color="primary" label="Save" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

type TenantForm = {
  name: string
  slug: string
  is_active: boolean
}

const props = defineProps<{
  modelValue: boolean
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
  name: '',
  slug: '',
  is_active: true
})

const form = reactive<TenantForm>(getDefaultForm())

watch(
  () => props.modelValue,
  (opened) => {
    if (opened) {
      Object.assign(form, getDefaultForm())
    }
  }
)

const onCancel = () => {
  localModelValue.value = false
}

const onSave = () => {
  emit('save', {
    name: form.name,
    slug: form.slug,
    is_active: form.is_active
  })
  localModelValue.value = false
}
</script>
