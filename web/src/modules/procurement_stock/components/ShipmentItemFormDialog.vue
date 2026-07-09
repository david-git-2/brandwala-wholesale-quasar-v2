<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card style="width: 750px; max-width: 95vw">
      <q-form @submit="onSubmitSingle">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-primary text-weight-bold">
            {{ isEdit ? 'Edit Shipment Item' : 'Add Manual Shipment Item' }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator class="q-my-sm" />

        <q-card-section class="q-pa-md">
          <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mb-md q-py-sm">
            {{ error }}
          </q-banner>

          <div class="row q-col-gutter-md">
            <!-- Left Column: Image Preview & URL -->
            <div class="col-12 col-sm-4 column items-center q-gutter-y-md">
              <div
                class="image-preview-container flex flex-center bg-grey-1"
                style="
                  width: 1.5in;
                  height: 1.5in;
                  border: 1px dashed #cfd8dc;
                  border-radius: 8px;
                  overflow: hidden;
                "
              >
                <SmartImage
                  v-if="form.image_url"
                  :src="form.image_url"
                  style="max-width: 100%; max-height: 100%; object-fit: contain"
                />
                <div v-else class="column items-center text-grey-6">
                  <q-icon name="image" size="32px" />
                  <div class="text-caption">No Image</div>
                </div>
              </div>
              <q-input
                v-model="form.image_url"
                label="Image URL"
                filled
                dense
                clearable
                class="full-width"
                :disable="isReceived"
              >
                <template #prepend>
                  <q-icon name="link" />
                </template>
              </q-input>
            </div>

            <!-- Right Column: Fields -->
            <div class="col-12 col-sm-8 q-gutter-y-sm">
              <q-select
                v-model="form.product_id"
                label="Link Catalog Product (Search by Name/Code/Barcode)"
                filled
                dense
                use-input
                fill-input
                hide-selected
                input-debounce="300"
                :options="productOptions"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                clearable
                class="full-width"
                @filter="filterProducts"
                @update:model-value="onProductSelected"
              >
                <template #no-option>
                  <q-item>
                    <q-item-section class="text-grey">
                      No products found
                    </q-item-section>
                  </q-item>
                </template>
              </q-select>
              <div class="row justify-end q-mt-xs q-mb-xs">
                <q-btn
                  flat
                  dense
                  color="primary"
                  icon="add"
                  label="Create New Catalog Product"
                  @click="openCreateProductDialog"
                  no-caps
                  class="text-caption text-weight-medium"
                />
              </div>

              <q-input
                v-model="form.name"
                label="Product Name *"
                filled
                dense
                :disable="isReceived"
                :rules="[
                  (val) => !!val || 'Product name is required',
                  (val) => val.trim().length > 0 || 'Product name cannot be blank',
                ]"
              />

              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-input v-model="form.product_code" label="Product Code" filled dense :disable="isReceived" />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input v-model="form.barcode" label="Barcode" filled dense :disable="isReceived" />
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
                    :disable="isReceived"
                    :rules="[
                      (val) => (val !== null && val !== undefined) || 'Quantity is required',
                      (val) => (Number.isInteger(val) && val >= 1) || 'Must be an integer >= 1',
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
                    :disable="isReceived"
                    :rules="[
                      (val) => (val !== null && val !== undefined) || 'Price is required',
                      (val) => val >= 0 || 'Must be >= 0',
                    ]"
                  />
                </div>
              </div>

              <!-- Weights -->
              <div class="text-subtitle2 text-grey-8 q-mt-sm q-mb-xs">Weights (Grams)</div>
              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.product_weight"
                    type="number"
                    label="Product Weight (g)"
                    filled
                    dense
                    :disable="isReceived"
                    :rules="[(val) => val >= 0 || 'Must be >= 0']"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.package_weight"
                    type="number"
                    label="Package Weight (g)"
                    filled
                    dense
                    :disable="isReceived"
                    :rules="[(val) => val >= 0 || 'Must be >= 0']"
                  />
                </div>
              </div>
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

    <q-dialog v-model="createProductDialogActive" persistent>
      <q-card style="width: 450px; max-width: 90vw">
        <q-form @submit="handleCreateProduct">
          <q-card-section class="row items-center">
            <div class="text-subtitle1 text-weight-bold text-primary">Create New Catalog Product</div>
            <q-space />
            <q-btn icon="close" flat round dense v-close-popup />
          </q-card-section>
          
          <q-separator />

          <q-card-section class="q-pa-md q-gutter-y-sm">
            <q-input
              v-model="newProductForm.name"
              label="Product Name *"
              filled
              dense
              :rules="[(val) => !!val?.trim() || 'Name is required']"
            />
            <q-input
              v-model="newProductForm.product_code"
              label="Product Code"
              filled
              dense
            />
            <q-input
              v-model="newProductForm.barcode"
              label="Barcode"
              filled
              dense
            />
            <div class="row q-col-gutter-xs">
              <div class="col-6">
                <q-input
                  v-model.number="newProductForm.product_weight"
                  type="number"
                  label="Product Weight (g)"
                  filled
                  dense
                  min="0"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model.number="newProductForm.package_weight"
                  type="number"
                  label="Package Weight (g)"
                  filled
                  dense
                  min="0"
                />
              </div>
            </div>
            <q-input
              v-model="newProductForm.image_url"
              label="Image URL"
              filled
              dense
            />
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md bg-grey-1">
            <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
            <q-btn
              type="submit"
              color="primary"
              unelevated
              label="Create & Link"
              :loading="creatingProduct"
              no-caps
            />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import { syncShipmentWeightToProduct } from '../utils/syncShipmentWeightToProduct';
import { productRepository } from 'src/modules/products/repositories/productRepository';

const props = withDefaults(
  defineProps<{
    shipmentId: number;
    item?: GlobalShipmentItem;
    isReceived?: boolean;
  }>(),
  {
    isReceived: false,
  },
);

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const $q = useQuasar();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();

const isEdit = computed(() => !!props.item);
const submitting = ref(false);
const error = ref<string | null>(null);

const createProductDialogActive = ref(false);
const creatingProduct = ref(false);
const newProductForm = ref({
  name: '',
  product_code: '',
  barcode: '',
  product_weight: 0,
  package_weight: 0,
  image_url: '',
});

const openCreateProductDialog = () => {
  newProductForm.value = {
    name: form.value.name || '',
    product_code: form.value.product_code || '',
    barcode: form.value.barcode || '',
    product_weight: form.value.product_weight || 0,
    package_weight: form.value.package_weight || 0,
    image_url: form.value.image_url || '',
  };
  createProductDialogActive.value = true;
};

const handleCreateProduct = async () => {
  creatingProduct.value = true;
  try {
    const created = await productRepository.createProduct({
      tenant_id: authStore.tenantId,
      name: newProductForm.value.name,
      product_code: newProductForm.value.product_code || null,
      barcode: newProductForm.value.barcode || null,
      product_weight: newProductForm.value.product_weight || 0,
      package_weight: newProductForm.value.package_weight || 0,
      image_url: newProductForm.value.image_url || null,
    });

    productOptions.value = [created, ...productOptions.value];

    form.value.product_id = created.id;
    form.value.name = created.name || '';
    form.value.barcode = created.barcode || null;
    form.value.product_code = created.product_code || null;
    form.value.product_weight = created.product_weight ?? 0;
    form.value.package_weight = created.package_weight ?? 0;
    form.value.image_url = created.image_url || null;

    createProductDialogActive.value = false;
  } catch (err: any) {
    $q.notify({
      type: 'negative',
      message: err.message || 'Failed to create product.',
    });
  } finally {
    creatingProduct.value = false;
  }
};

const form = ref({
  shipment_id: props.shipmentId,
  product_id: null as number | null,
  vendor_id: null as number | null,
  name: '',
  ordered_quantity: 1,
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
});

const productOptions = ref<any[]>([]);

const filterProducts = async (val: string, update: any) => {
  if (val.trim().length < 2) {
    update(() => {
      productOptions.value = [];
    });
    return;
  }

  try {
    const res = await productRepository.listProducts({
      search: val.trim(),
      searchField: 'name',
      tenantId: authStore.tenantId,
      pageSize: 30,
    });

    let data = res.data;
    if (data.length === 0) {
      const resCode = await productRepository.listProducts({
        search: val.trim(),
        searchField: 'product_code',
        tenantId: authStore.tenantId,
        pageSize: 30,
      });
      data = resCode.data;
    }
    if (data.length === 0) {
      const resBarcode = await productRepository.listProducts({
        search: val.trim(),
        searchField: 'barcode',
        tenantId: authStore.tenantId,
        pageSize: 30,
      });
      data = resBarcode.data;
    }

    update(() => {
      productOptions.value = data;
    });
  } catch (err) {
    console.error('Failed to search products', err);
    update(() => {
      productOptions.value = [];
    });
  }
};

const onProductSelected = (val: any) => {
  if (!val) {
    form.value.product_id = null;
    return;
  }
  const selected = productOptions.value.find((p) => p.id === val);
  if (selected) {
    form.value.product_id = selected.id;
    form.value.name = selected.name;
    form.value.barcode = selected.barcode || null;
    form.value.product_code = selected.product_code || null;
    form.value.product_weight = selected.product_weight ?? 0;
    form.value.package_weight = selected.package_weight ?? 0;
    form.value.image_url = selected.image_url || null;
  }
};

onMounted(async () => {
  if (authStore.tenantId) {
    void vendorStore.fetchVendors(authStore.tenantId);
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
    };

    if (props.item.product_id) {
      try {
        const prod = await productRepository.getProductById(props.item.product_id, authStore.tenantId);
        if (prod) {
          productOptions.value = [prod];
        }
      } catch (err) {
        console.error('Failed to fetch initial product details', err);
      }
    }
  }
});

const onSubmitSingle = async () => {
  submitting.value = true;
  error.value = null;

  try {
    if (isEdit.value) {
      const updated = await shipmentStore.updateShipmentItem(props.item!.id, form.value);
      const targetProductId = form.value.product_id;
      if (targetProductId != null) {
        const weightChanged =
          props.item?.product_weight !== form.value.product_weight ||
          props.item?.package_weight !== form.value.package_weight ||
          props.item?.product_id !== targetProductId;
        if (weightChanged) {
          await syncShipmentWeightToProduct(
            targetProductId,
            'product_weight',
            form.value.product_weight,
          );
          await syncShipmentWeightToProduct(
            targetProductId,
            'package_weight',
            form.value.package_weight,
          );
        }
      }
      onDialogOK(updated);
    } else {
      const payload: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at'> = {
        ...form.value,
        add_method: 'manual',
      };
      const created = await shipmentStore.addShipmentItem(payload);
      onDialogOK(created);
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    error.value = msg || 'Failed to save item.';
  } finally {
    submitting.value = false;
  }
};
</script>
