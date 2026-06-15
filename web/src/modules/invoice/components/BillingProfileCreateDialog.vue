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

        <q-select
          v-model="form.customerGroupId"
          :options="customerGroupOptions"
          label="Customer Group"
          outlined
          dense
          emit-value
          map-options
          option-value="value"
          option-label="label"
        />

        <q-input
          v-model="form.color"
          outlined
          dense
          label="Color (Hex)"
          placeholder="#B45F34"
          clearable
        >
          <template #append>
            <q-icon
              name="palette"
              class="cursor-pointer"
              :style="{ color: form.color || '#cccccc' }"
            >
              <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                <q-card flat bordered>
                  <q-card-section class="q-pa-sm">
                    <q-color
                      v-model="form.color"
                      default-view="palette"
                      format-model="hex"
                      no-header-tabs
                      no-footer
                    />
                  </q-card-section>
                </q-card>
              </q-popup-proxy>
            </q-icon>
          </template>
        </q-input>

        <div class="row q-gutter-xs q-mb-sm justify-center">
          <button
            v-for="swatch in colorPresets"
            :key="swatch"
            type="button"
            class="swatch-btn"
            :class="{ 'swatch-btn--active': form.color === swatch }"
            :style="{ backgroundColor: swatch }"
            @click="form.color = swatch"
          />
        </div>

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
import { computed, reactive, watch, onMounted } from 'vue'
import { showWarningDialog } from 'src/utils/appFeedback'
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore'
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

const customerGroupStore = useCustomerGroupStore()

const form = reactive({
  name: '',
  email: '',
  customerGroupId: null as number | null,
  color: '',
  phone: '',
  address: '',
})

const colorPresets = [
  '#B45F34', // Orange/Brown
  '#8E4B2B',
  '#C46A3C',
  '#6F7C4F', // Sage
  '#2F6E73', // Teal
  '#7D4E8B', // Purple
  '#2E7D32', // Green
  '#C62828', // Red
  '#1565C0', // Blue
] as const

const customerGroupOptions = computed(() => {
  const activeGroups = customerGroupStore.groups
    .filter((g) => g.is_active)
    .map((g) => ({
      label: g.name,
      value: g.id,
    }))
  return [
    { label: 'Others (None)', value: null },
    ...activeGroups,
  ]
})

const nameRules = [(value: string) => (value?.trim()?.length ? true : 'Name is required')]

const loadCustomerGroups = () => {
  if (props.tenantId) {
    void customerGroupStore.fetchCustomerGroupsByTenant(props.tenantId)
  }
}

onMounted(loadCustomerGroups)

watch(
  () => props.tenantId,
  (newTenantId) => {
    if (newTenantId) {
      loadCustomerGroups()
    }
  }
)

const reset = () => {
  form.name = ''
  form.email = ''
  form.customerGroupId = null
  form.color = ''
  form.phone = ''
  form.address = ''
}

watch(
  () => props.modelValue,
  (isOpen) => {
    if (!isOpen) {
      reset()
    } else {
      loadCustomerGroups()
    }
  }
)

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
    customer_group_id: form.customerGroupId,
    color: form.color.trim() || null,
    phone: form.phone.trim() || null,
    address: form.address.trim() || null,
  })
}
</script>

<style scoped>
.swatch-btn {
  width: 24px;
  height: 24px;
  border-radius: 4px;
  cursor: pointer;
  padding: 0;
  border: 1px solid rgba(0, 0, 0, 0.15);
  transition: transform 0.1s ease;
}
.swatch-btn:hover {
  transform: scale(1.15);
}
.swatch-btn--active {
  box-shadow: 0 0 0 2px var(--q-primary);
  border: 2px solid white;
}
</style>

