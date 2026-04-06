<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 500px; max-width: 90vw;">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Market' : 'Add Market' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-banner
          v-if="isSystemMarket"
          rounded
          class="market-dialog__banner market-dialog__banner--system"
        >
          This market is system managed and cannot be edited.
        </q-banner>

        <q-banner
          v-if="validationMessage"
          rounded
          class="market-dialog__banner market-dialog__banner--warning"
        >
          {{ validationMessage }}
        </q-banner>

        <q-input
          v-model="form.name"
          label="Market Name"
          outlined
          dense
          :readonly="isSystemMarket"
          :rules="nameRules"
        />

        <q-input
          v-model="form.code"
          label="ISO Code"
          outlined
          dense
          maxlength="2"
          :readonly="isSystemMarket"
          hint="Use 2-letter uppercase code (for example: US, BD, GB)."
          :rules="codeRules"
          @update:model-value="onCodeInput"
        />

        <q-input
          v-model="form.region"
          label="Region"
          outlined
          dense
          :readonly="isSystemMarket"
          :rules="regionRules"
        />

        <div class="row items-center justify-between">
          <div class="text-subtitle2">Status</div>

          <q-toggle
            v-model="form.is_active"
            :disable="isSystemMarket"
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
          :disable="Boolean(validationMessage) || isSystemMarket"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

import type { Market } from '../types'

type MarketForm = {
  id?: number
  name: string
  code: string
  is_active: boolean
  is_system: boolean
  region: string
}

const props = defineProps<{
  modelValue: boolean
  initialData?: MarketForm | null
  existingMarkets?: Market[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: MarketForm): void
}>()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const getDefaultForm = (): MarketForm => ({
  name: '',
  code: '',
  is_active: true,
  is_system: false,
  region: '',
})

const form = reactive<MarketForm>(getDefaultForm())

const isEdit = computed(() => typeof props.initialData?.id === 'number')
const isSystemMarket = computed(() => Boolean(form.is_system))
const normalizedCode = computed(() => normalizeCode(form.code))

const duplicateMarket = computed(
  () =>
    props.existingMarkets?.find(
      (market) =>
        market.id !== props.initialData?.id &&
        market.code.trim().toUpperCase() === normalizedCode.value,
    ) ?? null,
)

const nameRules = [(value: string) => !!String(value ?? '').trim() || 'Name is required']
const regionRules = [
  (value: string) => !!String(value ?? '').trim() || 'Region is required',
]
const codeRules = [
  (value: string) => !!normalizeCode(value) || 'ISO code is required',
  (value: string) =>
    /^[A-Z]{2}$/.test(normalizeCode(value)) ||
    'Code must be exactly 2 uppercase letters',
  () => !duplicateMarket.value || 'This market code already exists',
]

const validationMessage = computed(() => {
  if (!form.name.trim()) {
    return 'Add a market name before saving.'
  }

  if (!/^[A-Z]{2}$/.test(normalizedCode.value)) {
    return 'Market code must be exactly 2 uppercase letters.'
  }

  if (!form.region.trim()) {
    return 'Add a region before saving.'
  }

  if (duplicateMarket.value) {
    return `The code "${normalizedCode.value}" is already used by ${duplicateMarket.value.name}.`
  }

  return ''
})

function normalizeCode(value: string): string {
  return value
    .trim()
    .toUpperCase()
    .replace(/[^A-Z]/g, '')
    .slice(0, 2)
}

watch(
  [() => props.modelValue, () => props.initialData],
  ([opened, data]) => {
    if (opened) {
      Object.assign(form, data ?? getDefaultForm())
      form.code = normalizeCode(form.code)
    }
  },
  { immediate: true },
)

const onCodeInput = () => {
  form.code = normalizeCode(form.code)
}

const onCancel = () => {
  localModelValue.value = false
}

const onSave = () => {
  if (validationMessage.value || isSystemMarket.value) {
    return
  }

  const payload: MarketForm = {
    name: form.name.trim(),
    code: normalizedCode.value,
    is_active: form.is_active,
    is_system: form.is_system,
    region: form.region.trim(),
  }

  if (form.id !== undefined) {
    payload.id = form.id
  }

  emit('save', payload)
  localModelValue.value = false
}
</script>

<style scoped>
.market-dialog__banner {
  line-height: 1.5;
}

.market-dialog__banner--system {
  background: rgb(47 125 87 / 0.1);
  color: #1f6a48;
  border: 1px solid rgb(47 125 87 / 0.14);
}

.market-dialog__banner--warning {
  background: rgb(242 192 55 / 0.16);
  color: #8a5412;
  border: 1px solid rgb(242 192 55 / 0.2);
}
</style>
