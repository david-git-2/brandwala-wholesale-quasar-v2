<template>
  <q-page class="q-pa-md vendor-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm row items-center no-wrap">
            <q-btn flat round dense icon="arrow_back" @click="$router.back()" class="q-mr-sm flex-shrink-0" />
            <div style="min-width: 0;">
              <div class="text-h6 text-weight-bold text-ellipsis overflow-hidden" style="white-space: nowrap;">
                {{ isEdit ? 'Edit Vendor Details' : 'Loading...' }}
              </div>
              <div class="text-caption text-grey-8 text-ellipsis overflow-hidden" v-if="vendorData" style="white-space: nowrap;">
                {{ form.name }} ({{ form.code }})
              </div>
            </div>
          </div>
          <div class="col-12 col-sm-auto row items-center justify-end q-gutter-x-sm q-mt-xs q-mt-sm-none">
            <q-btn color="negative" no-caps size="sm" class="pill-btn slim-btn" label="Delete Vendor" @click="openDeleteDialog = true" v-if="vendorData" />
            <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Changes" :disable="Boolean(validationMessage) || checkingCode || codeAvailable === false" @click="onSave" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <div v-if="loading" class="text-center q-pa-xl">
      <q-spinner color="primary" size="3em" />
    </div>

    <div v-else-if="vendorData" class="row q-col-gutter-md">
      <!-- Top Section: Details -->
      <div class="col-12">
        <q-card flat class="floating-surface shadow-1">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-md">Vendor Information</div>
            
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6 col-md-4">
                <q-input v-model="form.name" label="Name" outlined dense>
                  <template #prepend><q-icon name="storefront" /></template>
                </q-input>
              </div>

              <div class="col-12 col-sm-6 col-md-4">
                <q-input
                  v-model="form.code"
                  label="Code"
                  outlined
                  dense
                  maxlength="40"
                  hint="Code must be unique."
                  :loading="checkingCode"
                  @update:model-value="onCodeInput"
                >
                  <template #prepend><q-icon name="badge" /></template>
                  <template #append>
                    <q-icon v-if="normalizedCode && !checkingCode && codeAvailable === true" name="check_circle" color="positive" />
                    <q-icon v-else-if="normalizedCode && !checkingCode && codeAvailable === false" name="error" color="negative" />
                  </template>
                </q-input>
                <div v-if="normalizedCode && !checkingCode && codeAvailable === false" class="text-negative text-caption q-mt-xs" style="margin-top: -10px;">
                  This vendor code is already in use.
                </div>
              </div>

              <div class="col-12 col-sm-6 col-md-4">
                <q-select
                  v-model="form.market_code"
                  outlined
                  dense
                  emit-value
                  map-options
                  label="Market"
                  :options="marketOptions"
                >
                  <template #prepend><q-icon name="public" /></template>
                </q-select>
              </div>

              <div class="col-12 col-sm-6 col-md-4">
                <q-input v-model="form.email" label="Email" outlined dense>
                  <template #prepend><q-icon name="mail" /></template>
                </q-input>
              </div>

              <div class="col-12 col-sm-6 col-md-4">
                <q-input v-model="form.phone" label="Phone" outlined dense>
                  <template #prepend><q-icon name="call" /></template>
                </q-input>
              </div>

              <div class="col-12 col-sm-6 col-md-4">
                <q-input v-model="form.website" label="Website" outlined dense>
                  <template #prepend><q-icon name="language" /></template>
                </q-input>
              </div>

              <div class="col-12">
                <q-input v-model="form.address" label="Address" type="textarea" autogrow outlined>
                  <template #prepend><q-icon name="location_on" /></template>
                </q-input>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Bottom Section: Brands and Categories -->
      <!-- Brands -->
      <div class="col-12 col-md-6">
        <q-card flat class="floating-surface shadow-1 full-height">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-md">Associated Brands</div>
            
            <div class="row q-col-gutter-sm q-mb-md items-center">
              <div class="col">
                <q-input v-model="newBrandName" label="New Brand Name" outlined dense @keyup.enter="addBrand" />
              </div>
              <div class="col-auto">
                <q-btn color="primary" label="Add" :disable="!newBrandName.trim() || isAddingBrand" @click="addBrand" :loading="isAddingBrand" />
              </div>
            </div>

            <div v-if="loadingBrands" class="text-grey-7">Loading brands...</div>
            <div v-else-if="brands.length === 0" class="text-grey-7">No brands associated yet.</div>
            <q-list v-else bordered separator class="rounded-borders" style="max-height: 250px; overflow-y: auto;">
              <q-item v-for="brand in brands" :key="brand.id">
                <q-item-section>
                  <q-item-label>{{ brand.name }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn flat round dense color="negative" icon="o_delete" @click="deleteBrand(brand.id)" />
                </q-item-section>
              </q-item>
            </q-list>
          </q-card-section>
        </q-card>
      </div>

      <!-- Categories -->
      <div class="col-12 col-md-6">
        <q-card flat class="floating-surface shadow-1 full-height">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-md">Associated Categories</div>
            
            <div class="row q-col-gutter-sm q-mb-md items-center">
              <div class="col">
                <q-input v-model="newCategoryName" label="New Category Name" outlined dense @keyup.enter="addCategory" />
              </div>
              <div class="col-auto">
                <q-btn color="primary" label="Add" :disable="!newCategoryName.trim() || isAddingCategory" @click="addCategory" :loading="isAddingCategory" />
              </div>
            </div>

            <div v-if="loadingCategories" class="text-grey-7">Loading categories...</div>
            <div v-else-if="categories.length === 0" class="text-grey-7">No categories associated yet.</div>
            <q-list v-else bordered separator class="rounded-borders" style="max-height: 250px; overflow-y: auto;">
              <q-item v-for="cat in categories" :key="cat.id">
                <q-item-section>
                  <q-item-label>{{ cat.name }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn flat round dense color="negative" icon="o_delete" @click="deleteCategory(cat.id)" />
                </q-item-section>
              </q-item>
            </q-list>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Delete Dialog -->
    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete vendor <strong>{{ vendorData?.name }}</strong>?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteVendor" :loading="isDeletingVendor" />
        </q-card-actions>
      </q-card>
    </q-dialog>

  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useVendorStore } from '../stores/vendorStore'
import { productService } from 'src/modules/products/services/productService'
import type { Vendor, VendorUpdateInput, VendorDeleteInput } from '../types'
import type { ProductBrand, ProductCategory } from 'src/modules/products/types'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'

const authStore = useAuthStore()
const vendorStore = useVendorStore()
const route = useRoute()
const router = useRouter()
const { markets } = storeToRefs(vendorStore)

const vendorId = Number(route.params.id)
const resolvedTenantId = computed(() => authStore.scope === 'platform' ? null : authStore.tenantId)

const loading = ref(true)
const error = ref<string | null>(null)
const vendorData = ref<Vendor | null>(null)

// Details Form State
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
const form = reactive<VendorForm>({
  name: '', code: '', market_code: '', tenant_id: resolvedTenantId.value,
  email: null, phone: null, address: null, website: null,
})
const checkingCode = ref(false)
const codeAvailable = ref<boolean | null>(null)
const originalNormalizedCode = ref('')
let debounceTimer: ReturnType<typeof setTimeout> | null = null

const isEdit = computed(() => typeof form.id === 'number')
const normalizedCode = computed(() => form.code.trim().toUpperCase())
const marketOptions = computed(() => markets.value.map((market) => ({
  label: `${market.name} (${market.code})`,
  value: market.code,
})))

const validationMessage = computed(() => {
  if (!form.name.trim()) return 'Name is required.'
  if (!normalizedCode.value) return 'Code is required.'
  if (!form.market_code.trim()) return 'Market is required.'
  return ''
})

const normalizeCode = (value: string) => value.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, '')

const onCodeInput = () => { form.code = normalizeCode(form.code) }

const runCodeCheck = () => {
  if (!normalizedCode.value) { codeAvailable.value = null; return }
  if (isEdit.value && normalizedCode.value === originalNormalizedCode.value) { codeAvailable.value = true; return }
  if (debounceTimer) clearTimeout(debounceTimer)

  debounceTimer = setTimeout(() => {
    void (async () => {
      checkingCode.value = true
      try {
        const result = await vendorStore.checkCodeAvailability(normalizedCode.value, resolvedTenantId.value, form.id ?? null)
        codeAvailable.value = Boolean(result.success && result.data)
      } finally {
        checkingCode.value = false
      }
    })()
  }, 320)
}

watch(() => form.code, () => runCodeCheck())

// Delete State
const openDeleteDialog = ref(false)
const isDeletingVendor = ref(false)

// Brands State
const brands = ref<ProductBrand[]>([])
const loadingBrands = ref(false)
const newBrandName = ref('')
const isAddingBrand = ref(false)

// Categories State
const categories = ref<ProductCategory[]>([])
const loadingCategories = ref(false)
const newCategoryName = ref('')
const isAddingCategory = ref(false)

const loadData = async () => {
  loading.value = true
  error.value = null

  if (markets.value.length === 0) {
    await vendorStore.fetchMarkets()
  }

  const result = await vendorStore.getVendorById(vendorId, resolvedTenantId.value)
  if (!result.success || !result.data) {
    error.value = result.error ?? 'Failed to load vendor.'
    loading.value = false
    return
  }

  vendorData.value = result.data
  Object.assign(form, {
    id: result.data.id,
    name: result.data.name,
    code: normalizeCode(result.data.code),
    market_code: result.data.market_code,
    tenant_id: result.data.tenant_id,
    email: result.data.email,
    phone: result.data.phone,
    address: result.data.address,
    website: result.data.website,
  })
  originalNormalizedCode.value = normalizeCode(result.data.code)
  codeAvailable.value = true
  
  loading.value = false

  // Fetch lookups
  void loadBrands()
  void loadCategories()
}

const loadBrands = async () => {
  if (!vendorData.value) return
  loadingBrands.value = true
  const res = await productService.listProductBrands({ vendorId: vendorData.value.id })
  if (res.success && res.data) {
    brands.value = res.data
  }
  loadingBrands.value = false
}

const addBrand = async () => {
  const name = newBrandName.value.trim()
  if (!name || !vendorData.value) return

  isAddingBrand.value = true
  const res = await productService.createProductBrand({
    name,
    vendor_code: vendorData.value.code,
    vendor_id: vendorData.value.id,
    tenant_id: vendorData.value.tenant_id,
  })
  if (res.success && res.data) {
    brands.value.push(res.data)
    newBrandName.value = ''
    showSuccessNotification('Brand added successfully.')
  } else {
    handleApiFailure(res, res.error ?? 'Failed to add brand.')
  }
  isAddingBrand.value = false
}

const deleteBrand = async (id: number) => {
  const res = await productService.deleteProductBrand({ id })
  if (res.success) {
    brands.value = brands.value.filter(b => b.id !== id)
    showSuccessNotification('Brand deleted.')
  } else {
    handleApiFailure(res, res.error ?? 'Failed to delete brand.')
  }
}

const loadCategories = async () => {
  if (!vendorData.value) return
  loadingCategories.value = true
  const res = await productService.listProductCategories({ vendorId: vendorData.value.id })
  if (res.success && res.data) {
    categories.value = res.data
  }
  loadingCategories.value = false
}

const addCategory = async () => {
  const name = newCategoryName.value.trim()
  if (!name || !vendorData.value) return

  isAddingCategory.value = true
  const res = await productService.createProductCategory({
    name,
    vendor_code: vendorData.value.code,
    vendor_id: vendorData.value.id,
    tenant_id: vendorData.value.tenant_id,
  })
  if (res.success && res.data) {
    categories.value.push(res.data)
    newCategoryName.value = ''
    showSuccessNotification('Category added successfully.')
  } else {
    handleApiFailure(res, res.error ?? 'Failed to add category.')
  }
  isAddingCategory.value = false
}

const deleteCategory = async (id: number) => {
  const res = await productService.deleteProductCategory({ id })
  if (res.success) {
    categories.value = categories.value.filter(c => c.id !== id)
    showSuccessNotification('Category deleted.')
  } else {
    handleApiFailure(res, res.error ?? 'Failed to delete category.')
  }
}

const onSave = async () => {
  if (validationMessage.value || checkingCode.value || codeAvailable.value === false) return

  const payload: VendorUpdateInput = {
    id: vendorId,
    name: form.name.trim(),
    code: normalizedCode.value,
    market_code: form.market_code.trim().toUpperCase(),
    tenant_id: form.tenant_id,
    email: form.email?.trim() || null,
    phone: form.phone?.trim() || null,
    address: form.address?.trim() || null,
    website: form.website?.trim() || null,
  }

  const result = await vendorStore.updateVendor(payload)
  if (result.success && result.data) {
    vendorData.value = result.data
    originalNormalizedCode.value = normalizeCode(result.data.code)
    
    void loadBrands()
    void loadCategories()
  }
}

const confirmDeleteVendor = async () => {
  if (!vendorData.value) return

  isDeletingVendor.value = true
  const payload: VendorDeleteInput = {
    id: vendorId,
    tenant_id: resolvedTenantId.value,
  }

  const result = await vendorStore.deleteVendor(payload)
  isDeletingVendor.value = false

  if (result.success) {
    openDeleteDialog.value = false
    router.back()
  }
}

onMounted(() => {
  void loadData()
})
</script>

<style scoped>
</style>

