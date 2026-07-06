<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 440px; max-width: 95vw" class="floating-surface shadow-2 q-pa-sm">
      <q-card-section class="text-h6 text-weight-bold text-black">Create Dropship Invoice</q-card-section>
      <q-card-section>
        <q-form class="q-gutter-y-md" @submit.prevent="onSubmit">
          <q-select
            v-if="allIssuingOptions.length > 1"
            v-model="form.tenant_id"
            :options="allIssuingOptions"
            label="Sister Concern *"
            outlined dense emit-value map-options class="soft-input"
            @update:model-value="onIssuingTenantChange"
          />
          <q-select
            v-model="form.billing_profile_id"
            :options="billingProfileOptions"
            label="Middle Man (Billing Profile) *"
            outlined dense emit-value map-options class="soft-input" :loading="loadingProfiles"
          />
          <q-input v-model="form.invoice_no" label="Invoice Number *" outlined dense class="soft-input" />

          <!-- Saved Recipient Profile Picker -->
          <q-select
            v-model="form.recipient_profile_id"
            :options="recipientProfileOptions"
            label="Load Saved Recipient (Optional)"
            outlined
            dense
            emit-value
            map-options
            clearable
            class="soft-input"
            :loading="loadingRecipients"
            @update:model-value="onRecipientProfileChange"
          />

          <q-input v-model="form.recipient_name" label="Recipient Name *" outlined dense class="soft-input" />
          <q-input v-model="form.recipient_phone" label="Recipient Phone *" outlined dense class="soft-input" />
          <q-input v-model="form.recipient_address" label="Recipient Address *" type="textarea" outlined dense autogrow class="soft-input" />
          <q-input v-model.number="form.middle_man_payout_amount" type="number" label="Middle-man payout (optional override)" outlined dense class="soft-input" min="0" />
          <q-input v-model="form.note" label="Note" type="textarea" outlined dense autogrow class="soft-input" />
          <div class="text-caption text-grey-7">Invoice face bills the recipient. Accounting uses sell price per line.</div>
          <div class="row justify-end q-gutter-sm">
            <q-btn flat no-caps label="Cancel" @click="onCancel" />
            <q-btn color="primary" class="pill-btn slim-btn" no-caps label="Create" type="submit" :loading="globalInvoiceStore.saving" :disable="!canSubmit" />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useBillingProfileStore } from 'src/modules/sales_invoice/stores/billingProfileStore'
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { showWarningDialog } from 'src/utils/appFeedback'
import { useInvoiceStore } from '../stores/invoiceStore'
import type { GlobalInvoiceCreated } from '../types'

const props = defineProps<{ modelValue: boolean; parentTenantId: number | null }>()
const emit = defineEmits<{ (e: 'update:modelValue', value: boolean): void; (e: 'created', invoice: GlobalInvoiceCreated): void }>()

const globalInvoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()
const recipientProfileStore = useRecipientProfileStore()
const tenantStore = useTenantStore()

const loadingProfiles = ref(false)
const loadingRecipients = ref(false)

const form = reactive({
  tenant_id: null as number | null,
  billing_profile_id: null as number | null,
  recipient_profile_id: null as number | null,
  invoice_no: '',
  recipient_name: '',
  recipient_phone: '',
  recipient_address: '',
  middle_man_payout_amount: 0,
  note: '',
})

const issuingTenantOptions = computed(() => {
  const parentId = props.parentTenantId
  if (!parentId) return []
  const tenants = tenantStore.availableAdminTenants.length > 0 ? tenantStore.availableAdminTenants : tenantStore.items
  return tenants.filter((t) => t.parent_id === parentId).map((t) => ({ label: `${t.name} (Sister concern)`, value: t.id }))
})
const selfIssuingOption = computed(() => {
  const parentId = props.parentTenantId
  if (!parentId) return null
  const current = tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === tenantStore.selectedTenantId) ?? null
  if (!current || current.parent_id !== parentId) return null
  return { label: current.name, value: current.id }
})
const allIssuingOptions = computed(() => issuingTenantOptions.value.length > 0 ? issuingTenantOptions.value : selfIssuingOption.value ? [selfIssuingOption.value] : [])
const billingProfileOptions = computed(() => billingProfileStore.items.map((p) => ({ label: p.name, value: p.id })))
const recipientProfileOptions = computed(() => recipientProfileStore.items.map((p) => ({ label: `${p.name} (${p.phone})`, value: p.id })))
const canSubmit = computed(() => Boolean(form.tenant_id && form.billing_profile_id && form.invoice_no.trim() && form.recipient_name.trim() && form.recipient_phone.trim() && form.recipient_address.trim()) && !globalInvoiceStore.saving)

const resetForm = (tenantId: number | null) => {
  form.tenant_id = tenantId
  form.billing_profile_id = null
  form.recipient_profile_id = null
  form.invoice_no = `Dropship - ${tenantId ?? ''} - ${new Date().toLocaleString('en-GB', { month: 'short', year: 'numeric' })}`
  form.recipient_name = ''
  form.recipient_phone = ''
  form.recipient_address = ''
  form.middle_man_payout_amount = 0
  form.note = ''
}
const loadBillingProfiles = async (tenantId: number | null) => {
  if (!tenantId) return
  loadingProfiles.value = true
  try { await billingProfileStore.fetchBillingProfiles({ tenant_id: tenantId, page_size: 200 }) } finally { loadingProfiles.value = false }
}
const loadRecipientProfiles = async (tenantId: number | null) => {
  if (!tenantId) return
  loadingRecipients.value = true
  try { await recipientProfileStore.fetchRecipientProfiles(tenantId) } finally { loadingRecipients.value = false }
}
const onIssuingTenantChange = async (tenantId: number | null) => {
  form.billing_profile_id = null;
  form.recipient_profile_id = null;
  await Promise.all([
    loadBillingProfiles(tenantId),
    loadRecipientProfiles(tenantId)
  ])
}
const onRecipientProfileChange = (profileId: number | null) => {
  if (!profileId) return
  const profile = recipientProfileStore.items.find((p) => p.id === profileId)
  if (profile) {
    form.recipient_name = profile.name
    form.recipient_phone = profile.phone
    form.recipient_address = profile.address
  }
}
const onCancel = () => emit('update:modelValue', false)
const onSubmit = async () => {
  if (!form.tenant_id || !form.billing_profile_id) return
  const result = await globalInvoiceStore.createInvoice({
    tenant_id: form.tenant_id,
    invoice_no: form.invoice_no.trim(),
    billing_profile_id: form.billing_profile_id,
    recipient_profile_id: form.recipient_profile_id,
    invoice_type: 'dropship',
    recipient_name: form.recipient_name.trim(),
    recipient_phone: form.recipient_phone.trim(),
    recipient_address: form.recipient_address.trim(),
    middle_man_payout_amount: form.middle_man_payout_amount || null,
    note: form.note.trim() || null,
  })
  if (!result.success || !result.data) { showWarningDialog(result.error ?? 'Failed.'); return }
  emit('created', result.data)
  emit('update:modelValue', false)
}
watch(() => props.modelValue, async (open) => {
  if (!open) return
  const defaultTenantId = allIssuingOptions.value[0]?.value ?? null
  resetForm(defaultTenantId)
  await Promise.all([
    loadBillingProfiles(defaultTenantId),
    loadRecipientProfiles(defaultTenantId)
  ])
})
</script>
