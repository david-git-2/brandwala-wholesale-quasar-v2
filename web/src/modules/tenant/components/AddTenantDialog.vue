<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 400px; max-width: 90vw;">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Tenant' : 'Add Tenant' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input
          v-model="form.name"
          label="Name"
          outlined
          dense
          :rules="[(value) => !!String(value ?? '').trim() || 'Name is required']"
        />

        <q-input
          v-model="form.slug"
          label="Slug"
          outlined
          dense
          hint="Used in URLs and tenant identification."
          :rules="[
            (value) => !!String(value ?? '').trim() || 'Slug is required',
            (value) =>
              /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(String(value ?? '').trim()) ||
              'Use lowercase letters, numbers, and hyphens only'
          ]"
          @update:model-value="onSlugInput"
        />

        <q-input
          v-model="form.public_domain"
          label="Public Domain"
          outlined
          dense
          hint="Optional. Example: wholesale.tradeflowbd.com"
          :rules="[
            (value) =>
              !String(value ?? '').trim() ||
              /^[a-z0-9.-]+$/.test(normalizePublicDomain(String(value))) ||
              'Use a valid hostname or domain'
          ]"
          @update:model-value="onPublicDomainInput"
        />

        <q-select
          v-model="form.parent_id"
          :options="parentOptions"
          label="Parent Tenant"
          outlined
          dense
          emit-value
          map-options
          class="q-mt-sm"
        />

        <q-toggle
          v-model="form.is_active"
          label="Is Active"
        />

        <div v-if="isEdit" class="tenant-meta">
          <div class="text-subtitle2">Tenant Details</div>

          <q-input
            :model-value="form.id ?? ''"
            label="Tenant ID"
            outlined
            dense
            readonly
          />

          <q-input
            :model-value="formatDate(form.created_at)"
            label="Created At"
            outlined
            dense
            readonly
          />

          <q-input
            :model-value="formatDate(form.updated_at)"
            label="Updated At"
            outlined
            dense
            readonly
          />
        </div>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="onCancel" />
        <q-btn color="primary" :label="isEdit ? 'Update' : 'Save'" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { formatAppDateTime } from 'src/utils/dateTime'
import { useTenantStore } from '../stores/tenantStore'
import type { Tenant } from '../types'

type TenantForm = {
  id?: number
  name: string
  slug: string
  public_domain: string | null
  is_active: boolean
  parent_id: number | null
  created_at?: string
  updated_at?: string
}

const props = defineProps<{
  modelValue: boolean
  initialData?: TenantForm | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: TenantForm): void
}>()

const tenantStore = useTenantStore()

const localModelValue = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value)
})

const getDefaultForm = (): TenantForm => ({
  name: '',
  slug: '',
  public_domain: null,
  is_active: true,
  parent_id: null
})

const form = reactive<TenantForm>(getDefaultForm())
const slugEditedManually = ref(false)

const isEdit = computed(() => !!props.initialData?.id)

const getDescendants = (tenantId: number, tenants: Tenant[]): Set<number> => {
  const descendants = new Set<number>()
  const visit = (id: number) => {
    tenants.forEach(t => {
      if (t.parent_id === id) {
        if (!descendants.has(t.id)) {
          descendants.add(t.id)
          visit(t.id)
        }
      }
    })
  }
  visit(tenantId)
  return descendants
}

const selectableParents = computed(() => {
  const allTenants = tenantStore.items
  if (!isEdit.value || form.id === undefined) {
    return allTenants
  }
  const descendants = getDescendants(form.id, allTenants)
  return allTenants.filter(t => t.id !== form.id && !descendants.has(t.id))
})

const parentOptions = computed(() => {
  const options = selectableParents.value.map(t => ({
    label: `${t.name} (${t.slug})`,
    value: t.id
  }))
  return [
    { label: 'None (Root Tenant)', value: null },
    ...options
  ]
})

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-')

const normalizePublicDomain = (value: string): string =>
  (value
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, '')
    .split('/')[0] ?? '')
    .replace(/:\d+$/, '')

watch(
  [() => props.modelValue, () => props.initialData],
  ([opened, data]) => {
    if (opened) {
      Object.assign(form, data ?? getDefaultForm())
      slugEditedManually.value = Boolean(data?.slug)
    }
  },
  { immediate: true }
)

watch(
  () => form.name,
  (value) => {
    if (slugEditedManually.value) return
    form.slug = slugify(value)
  }
)

const onCancel = () => {
  localModelValue.value = false
}

const onSlugInput = () => {
  slugEditedManually.value = true
  form.slug = slugify(form.slug)
}

const onPublicDomainInput = () => {
  form.public_domain = normalizePublicDomain(form.public_domain ?? '') || null
}

const formatDate = (value?: string) => {
  return formatAppDateTime(value, '')
}

const onSave = () => {
  const payload: TenantForm = {
    name: form.name.trim(),
    slug: slugify(form.slug),
    public_domain: normalizePublicDomain(form.public_domain ?? '') || null,
    is_active: form.is_active,
    parent_id: form.parent_id
  }

  if (form.id !== undefined) {
    payload.id = form.id
  }

  emit('save', payload)
  localModelValue.value = false
}
</script>

<style scoped>
.tenant-meta {
  display: grid;
  gap: 12px;
  padding-top: 4px;
}
</style>
