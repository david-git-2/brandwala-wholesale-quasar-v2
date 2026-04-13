<template>
  <q-dialog :model-value="open" @update:model-value="handleDialogToggle">
    <q-card style="min-width: 400px; max-width: 90vw">
      <q-card-section>
        <div class="text-h6">
          {{ isEdit ? 'Edit Store' : 'Create Store' }}
        </div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
        />
        <q-select
          :options="vendorStore.items"
          option-label="name"
          option-value="code"
          emit-value
          v-model="form.vendor_code"
          label="Vendor Code"
          outlined
          dense
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="handleClose" />
        <q-btn
          color="primary"
          :label="isEdit ? 'Update' : 'Save'"
          @click="handleSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { computed, reactive, watch } from 'vue'
const vendorStore = useVendorStore()

type StoreFormData = {
  id?: number | string |undefined
  name: string
  vendor_code: string
}

const props = defineProps<{
  open: boolean
  data?: StoreFormData | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', payload: StoreFormData): void
}>()

const form = reactive<StoreFormData>({
  id: undefined,
  name: '',
  vendor_code: '',
})

const isEdit = computed(() => !!props.data)

const resetForm = () => {
  form.id = undefined
  form.name = ''
  form.vendor_code = ''
}

watch(
  () => [props.open, props.data],
  () => {
    if (props.open) {
      form.id = props.data?.id
      form.name = props.data?.name ?? ''
      form.vendor_code = props.data?.vendor_code ?? ''
    }
  },
  { immediate: true }
)

const handleClose = () => {
  resetForm()
  emit('close')
}

const handleDialogToggle = (value: boolean) => {
  if (!value) {
    handleClose()
  }
}

const handleSave = () => {
  const payload: StoreFormData = {
    id: form.id,
    name: form.name.trim(),
    vendor_code: form.vendor_code,
  }

  if (!payload.name || !payload.vendor_code) return

  emit('save', payload)
  handleClose()
}
</script>
