<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 600px; max-width: 90vw;">
      <q-form @submit="onSubmit">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-primary text-weight-bold">
            {{ isEdit ? 'Edit Shipment Item' : 'Add Item to Shipment' }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-md q-gutter-y-md">
          <q-banner v-if="error" class="bg-negative text-white rounded-borders q-py-sm">
            {{ error }}
          </q-banner>

          <!-- Product Catalog Selection (Only in Create Mode) -->
          <div v-if="!isEdit" class="q-mb-md">
            <q-toggle
              v-model="manualMode"
              label="Manually type product details (Skip Catalog Search)"
              color="primary"
            />
          </div>

          <div v-if="!manualMode && !isEdit" class="q-mb-md">
            <q-select
              v-model="selectedProduct"
              use-input
              fill-input
              hide-selected
              input-debounce="300"
              :options="productOptions"
              label="Search Product Catalog (by Name, Barcode, Code)"
              filled
              dense
              @filter="onFilterProducts"
              @update:model-value="onSelectProduct"
              clearable
              :loading="searchingProducts"
            >
              <template #no-option>
                <q-item>
                  <q-item-section class="text-grey">
                    No products found
                  </q-item-section>
                </q-item>
              </template>
            </q-select>
          </div>

          <!-- Product Core Fields -->
          <q-input
            v-model="form.name"
            label="Product Name *"
            filled
            dense
            :rules="[val => !!val || 'Product name is required', val => val.trim().length > 0 || 'Product name cannot be blank']"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.vendor_id"
                :options="vendorOptions"
                label="Vendor"
                filled
                dense
                emit-value
                map-options
                clearable
                :loading="vendorStore.loading"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.product_code"
                label="Product Code"
                filled
                dense
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12">
              <q-input
                v-model="form.barcode"
                label="Barcode"
                filled
                dense
              />
            </div>
          </div>

          <!-- Quantity and Price -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.ordered_quantity"
                type="number"
                label="Ordered Quantity *"
                filled
                dense
                :rules="[
                  val => val !== null && val !== undefined || 'Quantity is required',
                  val => Number.isInteger(val) && val >= 0 || 'Must be a positive integer'
                ]"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.purchase_price"
                type="number"
                step="0.01"
                label="Purchase Price *"
                filled
                dense
                :rules="[
                  val => val !== null && val !== undefined || 'Price is required',
                  val => val >= 0 || 'Must be >= 0'
                ]"
              />
            </div>
          </div>

          <!-- Weights -->
          <div class="text-subtitle2 text-grey-8 q-mt-md q-mb-xs">Weights (Grams)</div>
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.product_weight"
                type="number"
                label="Product Weight (g)"
                filled
                dense
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="form.package_weight"
                type="number"
                label="Package Weight (g)"
                filled
                dense
                :rules="[val => val >= 0 || 'Must be >= 0']"
              />
            </div>
          </div>

          <!-- Image Preview -->
          <div v-if="form.image_url" class="row items-center q-col-gutter-md q-mt-sm">
            <div class="col-auto">
              <q-img :src="form.image_url" spinner-color="white" style="height: 60px; max-width: 60px; border-radius: 4px;" />
            </div>
            <div class="col">
              <span class="text-caption text-grey-7">Image URL configured from product catalog.</span>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
          <q-btn
            type="submit"
            color="primary"
            unelevated
            :label="isEdit ? 'Save Changes' : 'Add Item'"
            :loading="submitting"
            no-caps
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useDialogPluginComponent } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { productRepository } from 'src/modules/products/repositories/productRepository'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository'

const props = defineProps<{
  shipmentId: number
  item?: GlobalShipmentItem
}>()

defineEmits([
  ...useDialogPluginComponent.emits
])

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent()

const authStore = useAuthStore()
const vendorStore = useVendorStore()
const shipmentStore = useGlobalShipmentStore()

const isEdit = computed(() => !!props.item)
const manualMode = ref(false)
const submitting = ref(false)
const error = ref<string | null>(null)

const form = ref({
  shipment_id: props.shipmentId,
  product_id: null as number | null,
  vendor_id: null as number | null,
  name: '',
  ordered_quantity: 0,
  purchase_price: 0,
  product_weight: 0,
  package_weight: 0,
  barcode: null as string | null,
  product_code: null as string | null,
  image_url: null as string | null,
  add_method: 'manual' as 'order' | 'costing' | 'manual',
  source_child_tenant_id: null as number | null,
  source_type: null as string | null,
  source_id: null as number | null,
})

// Autocomplete product catalog states
interface ProductItem {
  id: number
  name: string
  product_code: string | null
  barcode: string | null
  price_gbp: number | null
  product_weight: number | null
  package_weight: number | null
  image_url: string | null
}
const selectedProduct = ref<ProductItem | null>(null)
const productOptions = ref<Array<{ label: string; value: ProductItem }>>([])
const searchingProducts = ref(false)

const vendorOptions = computed(() => {
  return vendorStore.items.map((v) => ({
    label: v.name,
    value: v.id,
  }))
})

onMounted(() => {
  if (authStore.tenantId) {
    void vendorStore.fetchVendors(authStore.tenantId)
  }

  if (props.item) {
    form.value = {
      shipment_id: props.item.shipment_id,
      product_id: props.item.product_id,
      vendor_id: props.item.vendor_id,
      name: props.item.name,
      ordered_quantity: props.item.ordered_quantity,
      purchase_price: props.item.purchase_price,
      product_weight: props.item.product_weight,
      package_weight: props.item.package_weight,
      barcode: props.item.barcode,
      product_code: props.item.product_code,
      image_url: props.item.image_url,
      add_method: props.item.add_method,
      source_child_tenant_id: props.item.source_child_tenant_id,
      source_type: props.item.source_type,
      source_id: props.item.source_id,
    }
  }
})

const onFilterProducts = async (
  val: string,
  update: (callback: () => void) => void,
) => {
  if (val.trim().length < 2) {
    update(() => {
      productOptions.value = []
    })
    return
  }

  searchingProducts.value = true
  try {
    const res = await productRepository.listProducts({
      page: 1,
      pageSize: 30,
      search: val,
      searchField: 'name',
      tenantId: authStore.tenantId,
    })

    update(() => {
      productOptions.value = res.data.map((p) => ({
        label: `${p.name} ${p.product_code ? `[Code: ${p.product_code}]` : ''} ${p.barcode ? `[Barcode: ${p.barcode}]` : ''}`,
        value: p as ProductItem,
      }))
    })
  } catch (err: unknown) {
    console.error('Failed to search products', err)
  } finally {
    searchingProducts.value = false
  }
}

const onSelectProduct = (option: { label: string; value: ProductItem } | null) => {
  if (option) {
    const prod = option.value
    form.value.product_id = prod.id
    form.value.name = prod.name
    form.value.product_code = prod.product_code
    form.value.barcode = prod.barcode
    form.value.purchase_price = prod.price_gbp || 0
    form.value.product_weight = prod.product_weight || 0
    form.value.package_weight = prod.package_weight || 0
    form.value.image_url = prod.image_url
  } else {
    form.value.product_id = null
    form.value.name = ''
    form.value.product_code = null
    form.value.barcode = null
    form.value.purchase_price = 0
    form.value.product_weight = 0
    form.value.package_weight = 0
    form.value.image_url = null
  }
}

const onSubmit = async () => {
  submitting.value = ref(true).value
  error.value = null

  try {
    if (isEdit.value && props.item) {
      const updated = await shipmentStore.updateShipmentItem(props.item.id, form.value)
      onDialogOK(updated)
    } else {
      const created = await shipmentStore.addShipmentItem(form.value)
      onDialogOK(created)
    }
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to save item.'
  } finally {
    submitting.value = false
  }
}
</script>
