<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 500px; max-width: 90vw;">
      <q-card-section>
        <div class="text-h6">
          {{ isEdit ? 'Edit Module' : 'Add Module' }}
        </div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-banner
          v-if="seededModuleDefinition"
          rounded
          class="module-dialog__banner module-dialog__banner--seeded"
        >
          This is a seeded catalog module. Its key and label are locked to the shared module
          contract used by navigation and tenant-module access.
        </q-banner>

        <q-banner
          v-if="validationMessage"
          rounded
          class="module-dialog__banner module-dialog__banner--warning"
        >
          {{ validationMessage }}
        </q-banner>

        <q-input
          v-model="form.key"
          label="Key"
          outlined
          dense
          :readonly="isSeededModule"
          hint="Use lowercase snake_case keys that stay stable across DB, tenant modules, and frontend registry."
          :rules="keyRules"
          @update:model-value="onKeyInput"
        />

        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
          :readonly="isSeededModule"
          :hint="
            isSeededModule
              ? 'Seeded module labels stay aligned with the shared module registry.'
              : 'Use a short label shown to superadmins and future tenant feature screens.'
          "
          :rules="nameRules"
        />

        <q-input
          v-model="form.description"
          label="Description"
          outlined
          type="textarea"
          autogrow
        />

        <div class="row items-center justify-between">
          <div class="text-subtitle2">Status</div>

          <q-toggle
            v-model="form.is_active"
            :label="form.is_active ? 'Active' : 'Inactive'"
            color="positive"
            keep-color
          />
        </div>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="onCancel" />
        <q-btn
          color="primary"
          :label="isEdit ? 'Update' : 'Save'"
          :disable="Boolean(validationMessage)"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

import { getSeededModuleDefinition } from '../catalogContract'
import type { Module } from '../types'

type ModuleForm = {
  id?: number
  key: string
  name: string
  description: string
  is_active: boolean
}

const props = defineProps<{
  modelValue: boolean
  initialData?: ModuleForm | null
  existingModules?: Module[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: ModuleForm): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value)
})

const getDefaultForm = (): ModuleForm => ({
  key: '',
  name: '',
  description: '',
  is_active: true
})

const form = reactive<ModuleForm>(getDefaultForm())

const isEdit = computed(() => !!props.initialData?.id)
const normalizedKey = computed(() => normalizeKey(form.key))
const seededModuleDefinition = computed(() =>
  getSeededModuleDefinition(normalizedKey.value || props.initialData?.key),
)
const isSeededModule = computed(
  () =>
    Boolean(props.initialData?.id) &&
    Boolean(seededModuleDefinition.value) &&
    props.initialData?.key === seededModuleDefinition.value?.key,
)

const duplicateModule = computed(() =>
  props.existingModules?.find(
    (module) =>
      module.id !== props.initialData?.id &&
      module.key.trim().toLowerCase() === normalizedKey.value,
  ) ?? null,
)

const keyRules = [
  (value: string) => !!normalizeKey(value) || 'Key is required',
  (value: string) =>
    /^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(normalizeKey(value)) ||
    'Use lowercase letters, numbers, and underscores only',
  () => !duplicateModule.value || 'This module key already exists',
]

const nameRules = [
  (value: string) => !!String(value ?? '').trim() || 'Name is required',
]

const validationMessage = computed(() => {
  if (!normalizedKey.value) {
    return 'Add a stable module key before saving.'
  }

  if (!/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(normalizedKey.value)) {
    return 'Module keys must use lowercase letters, numbers, and underscores only.'
  }

  if (duplicateModule.value) {
    return `The key "${normalizedKey.value}" is already used by ${duplicateModule.value.name}.`
  }

  if (!form.name.trim()) {
    return 'Add a module name before saving.'
  }

  return ''
})

function normalizeKey(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/_{2,}/g, '_')
}

watch(
  [() => props.modelValue, () => props.initialData],
  ([opened, data]) => {
    if (opened) {
      Object.assign(form, data ?? getDefaultForm())
    }
  },
  { immediate: true }
)

watch(
  seededModuleDefinition,
  (definition) => {
    if (!definition) {
      return
    }

    if (!form.name.trim() || isSeededModule.value) {
      form.name = definition.name
    }

    if (!form.description.trim()) {
      form.description = definition.description
    }
  },
  { immediate: true },
)

const onCancel = () => {
  localModelValue.value = false
}

const onKeyInput = () => {
  if (isSeededModule.value) {
    form.key = props.initialData?.key ?? form.key
    return
  }

  form.key = normalizeKey(form.key)
}

const onSave = () => {
  if (validationMessage.value) {
    return
  }

  const definition = seededModuleDefinition.value
  const payload: ModuleForm = {
    key: isSeededModule.value ? (props.initialData?.key ?? normalizedKey.value) : normalizedKey.value,
    name: definition && isSeededModule.value ? definition.name : form.name.trim(),
    description: form.description.trim(),
    is_active: form.is_active,
  }

  if (form.id !== undefined) {
    payload.id = form.id
  }

  emit('save', payload)
  localModelValue.value = false
}
</script>

<style scoped>
.module-dialog__banner {
  line-height: 1.5;
}

.module-dialog__banner--seeded {
  background: rgb(47 125 87 / 0.1);
  color: #1f6a48;
  border: 1px solid rgb(47 125 87 / 0.14);
}

.module-dialog__banner--warning {
  background: rgb(242 192 55 / 0.16);
  color: #8a5412;
  border: 1px solid rgb(242 192 55 / 0.2);
}
</style>
