<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 500px; max-width: 90vw;">
      <q-card-section>
        <div class="text-h6">
          {{ isEdit ? 'Edit Module' : 'Add Module' }}
        </div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input
          v-model="form.key"
          label="Key"
          outlined
          dense
        />

        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
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
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

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
  id: undefined,
  key: '',
  name: '',
  description: '',
  is_active: true
})

const form = reactive<ModuleForm>(getDefaultForm())

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
    key: form.key,
    name: form.name,
    description: form.description,
    is_active: form.is_active,
  })
  localModelValue.value = false
}
</script>
