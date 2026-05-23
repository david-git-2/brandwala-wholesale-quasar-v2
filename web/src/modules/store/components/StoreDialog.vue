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
        <div>
          <div class="row items-center justify-between q-mb-xs">
            <div class="text-caption text-grey-8">Vendor</div>
            <q-btn
              flat
              dense
              no-caps
              size="xs"
              icon="add"
              label="Add New"
              class="quick-add-btn"
              @click="emit('add-vendor')"
            />
          </div>
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
        </div>
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
  id: number | string | null
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
  (e: 'add-vendor'): void
}>()

const form = reactive<StoreFormData>({
  id: null,
  name: '',
  vendor_code: '',
})

const isEdit = computed(() => !!props.data)

const resetForm = () => {
  form.id = null
  form.name = ''
  form.vendor_code = ''
}

watch(
  () => [props.open, props.data],
  () => {
    if (props.open) {
      form.id = props.data?.id ?? null
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
    id: form.id ?? null,
    name: form.name.trim(),
    vendor_code: form.vendor_code,
  }

  if (!payload.name || !payload.vendor_code) return

  emit('save', payload)
  handleClose()
}
</script>

<style scoped>
.quick-add-btn {
  min-height: 22px;
  padding: 0 4px;
}
</style>
