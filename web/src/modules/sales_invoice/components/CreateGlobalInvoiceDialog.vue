<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 440px; max-width: 95vw" class="floating-surface shadow-2 q-pa-sm">
      <q-card-section class="text-h6 text-weight-bold text-black">Create Wholesale Invoice</q-card-section>

      <q-card-section>
        <q-form class="q-gutter-y-md" @submit.prevent="onSubmit">
          <q-select
            v-if="allIssuingOptions.length > 1"
            v-model="form.tenant_id"
            :options="allIssuingOptions"
            label="Sister Concern *"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
            :rules="[(value: number | null) => value != null || 'Sister concern is required']"
            @update:model-value="onIssuingTenantChange"
          />

          <q-select
            v-model="form.billing_profile_id"
            :options="billingProfileOptions"
            label="Billing Profile *"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
            :loading="loadingProfiles"
            :rules="[(value: number | null) => value != null || 'Billing profile is required']"
          />

          <q-input
            v-model="form.invoice_no"
            label="Invoice Number *"
            outlined
            dense
            class="soft-input"
            :rules="[(value: string) => Boolean(value?.trim()) || 'Invoice number is required']"
          />

          <q-input
            v-model="form.note"
            label="Note"
            type="textarea"
            outlined
            dense
            autogrow
            class="soft-input"
          />

          <div class="text-caption text-grey-7">
            Wholesale invoices bill the selected profile. Recipient details are copied from the profile.
          </div>

          <div class="row justify-end q-gutter-sm q-mt-lg">
            <q-btn flat no-caps label="Cancel" class="text-black text-weight-bold" @click="onCancel" />
            <q-btn
              color="primary"
              class="pill-btn slim-btn"
              no-caps
              label="Create Invoice"
              type="submit"
              :loading="globalInvoiceStore.saving"
              :disable="!canSubmit"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'

import { useBillingProfileStore } from 'src/modules/sales_invoice/stores/billingProfileStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { showWarningDialog } from 'src/utils/appFeedback'

import { useInvoiceStore } from '../stores/invoiceStore'
import type { GlobalInvoiceCreated } from '../types'

const props = defineProps<{
  modelValue: boolean
  parentTenantId: number | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'created', invoice: GlobalInvoiceCreated): void
}>()

const globalInvoiceStore = useInvoiceStore()
const billingProfileStore = useBillingProfileStore()
const tenantStore = useTenantStore()

const loadingProfiles = ref(false)

const form = reactive({
  tenant_id: null as number | null,
  billing_profile_id: null as number | null,
  invoice_no: '',
  note: '',
})

/** Sister concerns only — parent company cannot issue for itself. */
const issuingTenantOptions = computed(() => {
  const parentId = props.parentTenantId
  if (!parentId) return []

  const tenants =
    tenantStore.availableAdminTenants.length > 0
      ? tenantStore.availableAdminTenants
      : tenantStore.items

  return tenants
    .filter((tenant) => tenant.parent_id === parentId)
    .map((tenant) => ({
      label: `${tenant.name} (Sister concern)`,
      value: tenant.id,
    }))
})

const selfIssuingOption = computed(() => {
  const parentId = props.parentTenantId
  if (!parentId) return null
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === tenantStore.selectedTenantId) ??
    null
  if (!current || current.parent_id !== parentId) return null
  return { label: current.name, value: current.id }
})

const allIssuingOptions = computed(() => {
  if (issuingTenantOptions.value.length > 0) return issuingTenantOptions.value
  if (selfIssuingOption.value) return [selfIssuingOption.value]
  return []
})

const resolveDefaultIssuingTenantId = () => allIssuingOptions.value[0]?.value ?? null

const billingProfileOptions = computed(() =>
  billingProfileStore.items.map((profile) => ({
    label: profile.name,
    value: profile.id,
  })),
)

const canSubmit = computed(
  () =>
    Boolean(form.tenant_id && form.billing_profile_id && form.invoice_no.trim()) &&
    !globalInvoiceStore.saving,
)

const buildDefaultInvoiceNo = (tenantId: number | null) => {
  const tenant =
    issuingTenantOptions.value.find((option) => option.value === tenantId)?.label ??
    'Wholesale Invoice'
  const monthYear = new Date().toLocaleString('en-GB', { month: 'short', year: 'numeric' })
  return `Invoice - ${tenant} - ${monthYear}`
}

const resetForm = (tenantId: number | null) => {
  form.tenant_id = tenantId
  form.billing_profile_id = null
  form.invoice_no = buildDefaultInvoiceNo(tenantId)
  form.note = ''
}

const loadBillingProfiles = async (tenantId: number | null) => {
  if (!tenantId) {
    billingProfileStore.items = []
    return
  }

  loadingProfiles.value = true
  try {
    await billingProfileStore.fetchBillingProfiles({ tenant_id: tenantId, page_size: 200 })
  } finally {
    loadingProfiles.value = false
  }
}

const onIssuingTenantChange = async (tenantId: number | null) => {
  form.invoice_no = buildDefaultInvoiceNo(tenantId)
  form.billing_profile_id = null
  await loadBillingProfiles(tenantId)
}

const onCancel = () => {
  emit('update:modelValue', false)
}

const onSubmit = async () => {
  if (!form.tenant_id || !form.billing_profile_id || !form.invoice_no.trim()) return

  const result = await globalInvoiceStore.createInvoice({
    tenant_id: form.tenant_id,
    invoice_no: form.invoice_no.trim(),
    billing_profile_id: form.billing_profile_id,
    invoice_type: 'wholesale',
    note: form.note.trim() || null,
  })

  if (!result.success || !result.data) {
    showWarningDialog(result.error ?? 'Failed to create invoice.')
    return
  }

  emit('created', result.data)
  emit('update:modelValue', false)
}

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return

    const defaultTenantId = resolveDefaultIssuingTenantId()

    resetForm(defaultTenantId)
    await loadBillingProfiles(defaultTenantId)
  },
)
</script>
