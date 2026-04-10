<template>
  <q-dialog v-model="localOpen" persistent @hide="onDialogHide">
    <q-card style="min-width: 500px; max-width: 90vw;">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6">
          {{ isEditMode ? 'Edit Costing File' : 'Create Costing File' }}
        </div>

        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-separator />

      <q-card-section>
        <q-form
          ref="formRef"
          @submit.prevent="handleSubmit"
          class="q-gutter-md"
        >
          <q-input
            v-model="form.name"
            label="Name"
            outlined
            dense
            clearable
            :rules="[val => !!val || 'Name is required']"
          />

          <q-input
            v-model="form.order_for"
            label="Created For"
            outlined
            dense
            clearable
            :rules="[val => !!val || 'Created For is required']"
          />

          <q-input
            v-model="form.note"
            label="Note"
            type="textarea"
            autogrow
            outlined
            dense
          />
        </q-form>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right">
        <q-btn flat label="Cancel" color="grey-7" v-close-popup />
        <q-btn
          unelevated
          color="primary"
          :label="isEditMode ? 'Update' : 'Create'"
          @click="handleSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { computed, reactive, watch, ref } from 'vue'

const props = defineProps({
  modelValue: Boolean,
  data: Object
})

const emit = defineEmits(['update:modelValue', 'submit'])

const formRef = ref(null)

const emptyForm = () => ({
  id: null,
  name: '',
  order_for: '',
  note: ''
})

const form = reactive(emptyForm())

const isEditMode = computed(() => !!props.data?.id)

const localOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v)
})

function fillForm(source) {
  const values = source || emptyForm()

  form.id = values.id ?? null
  form.name = values.name ?? ''
  form.order_for = values.order_for ?? ''
  form.note = values.note ?? ''
}

watch(
  () => props.data,
  (val) => fillForm(val),
  { immediate: true }
)

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) fillForm(props.data)
  }
)

async function handleSubmit() {
  const isValid = await formRef.value?.validate()

  if (!isValid) return

  emit('submit', {
    id: form.id,
    name: form.name,
    order_for: form.order_for,
    note: form.note
  })

  emit('update:modelValue', false)
}

function onDialogHide() {
  fillForm(props.data)
}
</script>
