<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 560px; max-width: 95vw;">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Vendor' : 'Add Vendor' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input v-model="form.name" label="Name" outlined dense />

        <q-input
          v-model="form.code"
          label="Code"
          outlined
          dense
          maxlength="40"
          hint="Code must be unique. Availability is checked as you type."
          :loading="checkingCode"
          @update:model-value="onCodeInput"
        >
          <template #append>
            <q-icon
              v-if="normalizedCode && !checkingCode && codeAvailable === true"
              name="check_circle"
              color="positive"
            />
            <q-icon
              v-else-if="normalizedCode && !checkingCode && codeAvailable === false"
              name="error"
              color="negative"
            />
          </template>
        </q-input>

        <q-banner
          v-if="normalizedCode && !checkingCode && codeAvailable === false"
          rounded
          class="bg-negative text-white"
        >
          This vendor code is already in use.
        </q-banner>

        <q-select
          v-model="form.market_code"
          outlined
          dense
          emit-value
          map-options
          label="Market"
          :options="marketOptions"
        />

        <q-toggle
          v-if="allowGlobalOption"
          v-model="isGlobalVendor"
          :disable="isEdit && form.tenant_id !== null"
          label="Global vendor (tenant_id = null)"
          color="primary"
        />

        <q-input v-model="form.email" label="Email" outlined dense />
        <q-input v-model="form.phone" label="Phone" outlined dense />
        <q-input v-model="form.website" label="Website" outlined dense />
        <q-input v-model="form.address" label="Address" type="textarea" autogrow outlined />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="localModelValue = false" />
        <q-btn
          color="primary"
          :disable="Boolean(validationMessage) || checkingCode || codeAvailable === false"
          :label="isEdit ? 'Update' : 'Save'"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'

import type { Vendor, VendorMarket } from '../types'

type VendorForm = {
  id?: number
  name: string
  code: string
  market_code: string
  tenant_id: number | null
  email: string | null
  phone: string | null
  address: string | null
  website: string | null
}

const props = defineProps<{
  modelValue: boolean
  initialData?: Vendor | null
  markets: VendorMarket[]
  tenantId: number | null
  allowGlobalOption: boolean
  checkCodeAvailability: (code: string, excludeId?: number | null) => Promise<boolean>
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: VendorForm): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const getDefaultForm = (): VendorForm => ({
  name: '',
  code: '',
  market_code: '',
  tenant_id: props.tenantId,
  email: null,
  phone: null,
  address: null,
  website: null,
})

const form = reactive<VendorForm>(getDefaultForm())
const checkingCode = ref(false)
const codeAvailable = ref<boolean | null>(null)
let debounceTimer: ReturnType<typeof setTimeout> | null = null

const isEdit = computed(() => typeof form.id === 'number')
const normalizedCode = computed(() => form.code.trim().toUpperCase())
const isGlobalVendor = computed({
  get: () => form.tenant_id === null,
  set: (value: boolean) => {
    form.tenant_id = value ? null : props.tenantId
  },
})

const marketOptions = computed(() =>
  props.markets.map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
)

const validationMessage = computed(() => {
  if (!form.name.trim()) return 'Name is required.'
  if (!normalizedCode.value) return 'Code is required.'
  if (!form.market_code.trim()) return 'Market is required.'
  if (form.tenant_id === null && !props.allowGlobalOption) {
    return 'Global vendor access is not enabled for this tenant.'
  }
  return ''
})

const normalizeCode = (value: string) =>
  value
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_-]/g, '')

const onCodeInput = () => {
  form.code = normalizeCode(form.code)
}

const runCodeCheck = () => {
  if (!normalizedCode.value) {
    codeAvailable.value = null
    return
  }

  if (debounceTimer) {
    clearTimeout(debounceTimer)
  }

  debounceTimer = setTimeout(() => {
    void (async () => {
      checkingCode.value = true
      try {
        codeAvailable.value = await props.checkCodeAvailability(
          normalizedCode.value,
          form.id ?? null,
        )
      } finally {
        checkingCode.value = false
      }
    })()
  }, 320)
}

watch(
  () => form.code,
  () => {
    runCodeCheck()
  },
)

watch(
  [() => props.modelValue, () => props.initialData, () => props.tenantId],
  ([opened, initialData, tenantId]) => {
    if (!opened) {
      return
    }

    const next = initialData
      ? {
          ...initialData,
          code: normalizeCode(initialData.code),
        }
      : {
          ...getDefaultForm(),
          tenant_id: tenantId,
        }

    Object.assign(form, next)
    codeAvailable.value = null
    runCodeCheck()
  },
  { immediate: true },
)

const onSave = () => {
  if (validationMessage.value || checkingCode.value || codeAvailable.value === false) {
    return
  }

  const payload: VendorForm = {
    name: form.name.trim(),
    code: normalizedCode.value,
    market_code: form.market_code.trim().toUpperCase(),
    tenant_id: form.tenant_id,
    email: form.email?.trim() || null,
    phone: form.phone?.trim() || null,
    address: form.address?.trim() || null,
    website: form.website?.trim() || null,
  }

  if (typeof form.id === 'number') {
    payload.id = form.id
  }

  emit('save', payload)
  localModelValue.value = false
}
</script>
