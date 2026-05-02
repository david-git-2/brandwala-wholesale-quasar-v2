<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 420px; max-width: 96vw">
      <q-card-section class="text-h6">Edit Billing Profile</q-card-section>

      <q-card-section class="column q-gutter-sm">
        <q-input v-model="form.name" outlined dense label="Name *" :rules="nameRules" lazy-rules />
        <q-input v-model="form.email" outlined dense label="Email" />
        <q-input v-model="form.phone" outlined dense label="Phone" />
        <q-input v-model="form.address" outlined dense type="textarea" label="Address" autogrow />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" @click="emit('update:modelValue', false)" />
        <q-btn color="primary" no-caps label="Save" :loading="saving" @click="onSubmit" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue'
import { showWarningDialog } from 'src/utils/appFeedback'
import type { BillingProfile } from '../types/billingProfile'

const props = defineProps<{
  modelValue: boolean
  profile: BillingProfile | null
  saving?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'submit', payload: {
    id: number
    patch: {
      name: string
      email: string | null
      phone: string | null
      address: string | null
      customer_group_id: number | null
    }
  }): void
}>()

const form = reactive({
  name: '',
  email: '',
  phone: '',
  address: '',
})

watch(
  () => props.profile,
  (profile) => {
    form.name = profile?.name ?? ''
    form.email = profile?.email ?? ''
    form.phone = profile?.phone ?? ''
    form.address = profile?.address ?? ''
  },
  { immediate: true },
)

const nameRules = [(value: string) => (value?.trim()?.length ? true : 'Name is required')]

const onSubmit = () => {
  if (!props.profile) {
    showWarningDialog('Billing profile is missing.')
    return
  }

  if (!form.name.trim()) {
    showWarningDialog('Name is required.')
    return
  }

  emit('submit', {
    id: props.profile.id,
    patch: {
      name: form.name.trim(),
      email: form.email.trim() || null,
      phone: form.phone.trim() || null,
      address: form.address.trim() || null,
      customer_group_id: props.profile.customer_group_id ?? null,
    },
  })
}
</script>
