<template>
  <q-dialog :model-value="modelValue" @update:model-value="onDialogToggle">
    <q-card style="min-width: 420px; max-width: 96vw">
      <q-card-section class="text-h6">Create Billing Profile</q-card-section>

      <q-card-section class="column q-gutter-sm">
        <q-input
          v-model="form.name"
          outlined
          dense
          label="Name *"
          :rules="nameRules"
          lazy-rules
        />
        <q-input v-model="form.email" outlined dense label="Email" />
        <q-input v-model="form.phone" outlined dense label="Phone" />
        <q-input v-model="form.address" outlined dense type="textarea" label="Address" autogrow />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" @click="emit('update:modelValue', false)" />
        <q-btn color="primary" no-caps label="Create" :loading="saving" @click="onSubmit" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive } from 'vue'
import { showWarningDialog } from 'src/utils/appFeedback'
import type { CreateBillingProfileInput } from '../types/billingProfile'

const props = defineProps<{
  modelValue: boolean
  tenantId: number | null
  saving?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'submit', payload: CreateBillingProfileInput): void
}>()

const form = reactive({
  name: '',
  email: '',
  phone: '',
  address: '',
})

const nameRules = [(value: string) => (value?.trim()?.length ? true : 'Name is required')]

const reset = () => {
  form.name = ''
  form.email = ''
  form.phone = ''
  form.address = ''
}

const onDialogToggle = (next: boolean) => {
  emit('update:modelValue', next)
  if (!next) reset()
}

const onSubmit = () => {
  const tenantId = props.tenantId
  if (!tenantId) {
    showWarningDialog('Tenant is missing.')
    return
  }

  if (!form.name.trim()) {
    showWarningDialog('Name is required.')
    return
  }

  emit('submit', {
    tenant_id: tenantId,
    name: form.name.trim(),
    email: form.email.trim() || null,
    customer_group_id: null,
    phone: form.phone.trim() || null,
    address: form.address.trim() || null,
  })
}
</script>
