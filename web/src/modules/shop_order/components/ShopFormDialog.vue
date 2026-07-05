<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 560px; max-width: 96vw;">
      <q-card-section>
        <div class="text-h6">{{ isEdit ? 'Edit Shop' : 'Create Shop' }}</div>
        <div v-if="isEdit" class="text-caption text-grey-6 q-mt-xs">
          Shop type is locked after creation.
        </div>
      </q-card-section>

      <q-card-section class="q-gutter-md">

        <!-- Name + Slug -->
        <div class="row q-col-gutter-md">
          <div class="col-7">
            <q-input
              v-model="form.name"
              label="Shop name *"
              outlined
              dense
              :error="!!errors.name"
              :error-message="errors.name"
              @update:model-value="syncSlug"
            />
          </div>
          <div class="col-5">
            <q-input
              v-model="form.slug"
              label="Slug *"
              outlined
              dense
              hint="URL-safe identifier"
              :error="!!errors.slug"
              :error-message="errors.slug"
              @update:model-value="() => { form.slug = form.slug.toLowerCase().replace(/[^a-z0-9-]/g, '-') }"
            />
          </div>
        </div>

        <!-- Shop type (create-only) -->
        <q-select
          v-if="!isEdit"
          v-model="form.shop_type"
          :options="shopTypeOptions"
          emit-value
          map-options
          label="Shop type *"
          outlined
          dense
          :error="!!errors.shop_type"
          :error-message="errors.shop_type"
        />

        <!-- vendor_code — only for vendor_catalog, create-only -->
        <q-input
          v-if="!isEdit && form.shop_type === 'vendor_catalog'"
          v-model="form.vendor_code"
          label="Vendor code *"
          outlined
          dense
          hint="Products will be filtered to this vendor_code"
          :error="!!errors.vendor_code"
          :error-message="errors.vendor_code"
        />

        <!-- Shop type locked label when editing -->
        <div v-if="isEdit && shopTypeLabel" class="row items-center q-col-gutter-sm">
          <div class="col">
            <div class="text-caption text-grey-6">Shop type</div>
            <div class="text-body2 text-weight-medium">{{ shopTypeLabel }}</div>
          </div>
        </div>

        <!-- Order mode -->
        <q-select
          v-model="form.order_mode"
          :options="orderModeOptions"
          emit-value
          map-options
          label="Order mode *"
          outlined
          dense
        />

        <!-- Flags row -->
        <div class="row q-col-gutter-md items-center">
          <div class="col-auto">
            <q-toggle
              v-model="form.is_negotiable"
              :disable="form.shop_type === 'dropship' || (isEdit && shopTypeSnapshot === 'dropship')"
              label="Negotiable"
              color="primary"
            />
          </div>
          <div class="col-auto">
            <q-toggle
              v-model="form.show_stock_quantity"
              label="Show stock qty"
              color="primary"
            />
          </div>
          <div class="col-auto">
            <q-toggle
              v-model="form.is_active"
              label="Active"
              color="positive"
            />
          </div>
        </div>

        <!-- Error banner -->
        <q-banner
          v-if="saveError"
          class="text-white bg-negative"
          rounded
          dense
        >
          {{ saveError }}
        </q-banner>

      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" :disable="saving" @click="localModelValue = false" />
        <q-btn
          color="primary"
          unelevated
          :label="isEdit ? 'Update' : 'Create Shop'"
          :loading="saving"
          :disable="saving"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import type { Shop, ShopType, ShopOrderMode } from 'src/modules/shop_order/types'

// ---- types ---------------------------------------------------------

type ShopForm = {
  id?: number
  tenant_id: number
  name: string
  slug: string
  shop_type: ShopType | null
  vendor_code: string
  order_mode: ShopOrderMode
  is_negotiable: boolean
  show_stock_quantity: boolean
  is_active: boolean
}

type FormErrors = {
  name?: string
  slug?: string
  shop_type?: string
  vendor_code?: string
}

// ---- props / emits -------------------------------------------------

const props = defineProps<{
  modelValue: boolean
  initialData?: Shop | null
  tenantId: number
  saving?: boolean
  saveError?: string | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: any): void
}>()

// ---- local state ---------------------------------------------------

const localModelValue = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
})

const errors = reactive<FormErrors>({})
// snapshot of shop_type on edit open (immutable field guard)
const shopTypeSnapshot = ref<ShopType | null>(null)

const defaultForm = (): ShopForm => ({
  tenant_id: props.tenantId,
  name: '',
  slug: '',
  shop_type: null,
  vendor_code: '',
  order_mode: 'procurement_intent',
  is_negotiable: false,
  show_stock_quantity: true,
  is_active: true,
})

const form = reactive<ShopForm>(defaultForm())

const isEdit = computed(() => typeof form.id === 'number')

// ---- label helpers -------------------------------------------------

const shopTypeOptions = [
  { value: 'vendor_catalog', label: 'Vendor Catalog' },
  { value: 'fixed_price',    label: 'Fixed Price' },
  { value: 'dropship',       label: 'Dropship' },
]

const orderModeOptions = [
  { value: 'procurement_intent',  label: 'Procurement Intent' },
  { value: 'checkout_fixed',      label: 'Checkout Fixed' },
  { value: 'checkout_wholesale',  label: 'Checkout Wholesale' },
]

const shopTypeLabel = computed(() => {
  const found = shopTypeOptions.find((o) => o.value === shopTypeSnapshot.value)
  return found?.label ?? shopTypeSnapshot.value ?? ''
})

// ---- slug auto-fill ------------------------------------------------

const syncSlug = (val: string) => {
  if (isEdit.value) return
  form.slug = val
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
}

// ---- watch open ----------------------------------------------------

watch(
  [() => props.modelValue, () => props.initialData, () => props.tenantId],
  ([opened, initialData, tenantId]) => {
    if (!opened) return

    Object.keys(errors).forEach((k) => delete (errors as any)[k])

    if (initialData) {
      shopTypeSnapshot.value = initialData.shop_type
      Object.assign(form, {
        id: initialData.id,
        tenant_id: initialData.tenant_id,
        name: initialData.name,
        slug: initialData.slug,
        shop_type: initialData.shop_type,
        vendor_code: initialData.vendor_code ?? '',
        order_mode: initialData.order_mode,
        is_negotiable: initialData.is_negotiable,
        show_stock_quantity: initialData.show_stock_quantity,
        is_active: initialData.is_active,
      })
    } else {
      shopTypeSnapshot.value = null
      Object.assign(form, { ...defaultForm(), tenant_id: tenantId })
    }
  },
  { immediate: true },
)

// ---- validation + save ---------------------------------------------

const validate = (): boolean => {
  Object.keys(errors).forEach((k) => delete (errors as any)[k])
  let ok = true

  if (!form.name.trim()) {
    errors.name = 'Name is required.'
    ok = false
  }
  if (!form.slug.trim()) {
    errors.slug = 'Slug is required.'
    ok = false
  }
  if (!isEdit.value && !form.shop_type) {
    errors.shop_type = 'Shop type is required.'
    ok = false
  }
  if (!isEdit.value && form.shop_type === 'vendor_catalog' && !form.vendor_code.trim()) {
    errors.vendor_code = 'Vendor code is required for vendor catalog shops.'
    ok = false
  }

  return ok
}

const onSave = () => {
  if (!validate()) return

  if (isEdit.value) {
    emit('save', {
      id:                  form.id,
      tenant_id:           form.tenant_id,
      name:                form.name.trim(),
      slug:                form.slug.trim(),
      order_mode:          form.order_mode,
      is_negotiable:       form.is_negotiable,
      show_stock_quantity: form.show_stock_quantity,
      is_active:           form.is_active,
    })
  } else {
    emit('save', {
      tenant_id:           form.tenant_id,
      name:                form.name.trim(),
      slug:                form.slug.trim(),
      shop_type:           form.shop_type,
      vendor_code:         form.shop_type === 'vendor_catalog' ? form.vendor_code.trim() : null,
      order_mode:          form.order_mode,
      is_negotiable:       form.is_negotiable,
      show_stock_quantity: form.show_stock_quantity,
      is_active:           form.is_active,
    })
  }
}
</script>
