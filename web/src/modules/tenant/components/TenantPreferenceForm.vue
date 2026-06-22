<template>
  <div class="tenant-preference-form">
    <q-card
      v-for="section in groupedSections"
      :key="section.name"
      flat
      class="q-mb-md floating-surface shadow-1"
    >
      <q-card-section>
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ section.name }}</div>
      </q-card-section>

      <q-separator />

      <q-card-section>
        <TenantPreferenceFieldRenderer
          v-for="field in section.fields"
          :key="field.key"
          :field="field"
          :model-value="localState[field.key]"
          @update:model-value="updateField(field.key, $event)"
        />
      </q-card-section>
    </q-card>

    <div class="row justify-end">
      <q-btn
        color="primary"
        no-caps
        size="sm"
        class="pill-btn slim-btn"
        label="Save preferences"
        :loading="saving"
        @click="emit('save', localState)"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

import { TENANT_PREFERENCE_FIELDS } from '../config/tenantPreferenceFields'
import TenantPreferenceFieldRenderer from './TenantPreferenceFieldRenderer.vue'

const props = defineProps<{
  modelValue: Record<string, unknown>
  saving?: boolean
}>()

const emit = defineEmits<{
  save: [formState: Record<string, unknown>]
}>()

const localState = reactive<Record<string, unknown>>({ ...props.modelValue })

watch(
  () => props.modelValue,
  (value) => {
    Object.keys(localState).forEach((key) => {
      delete localState[key]
    })
    Object.assign(localState, value)
  },
  { deep: true },
)

const groupedSections = computed(() => {
  const sections = new Map<string, typeof TENANT_PREFERENCE_FIELDS>()

  for (const field of TENANT_PREFERENCE_FIELDS) {
    const existing = sections.get(field.section) ?? []
    existing.push(field)
    sections.set(field.section, existing)
  }

  return Array.from(sections.entries()).map(([name, fields]) => ({
    name,
    fields,
  }))
})

function updateField(key: string, value: unknown) {
  localState[key] = value
}
</script>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}
</style>
