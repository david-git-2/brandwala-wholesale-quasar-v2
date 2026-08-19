<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="onDialogUpdate">
    <q-card style="width: 960px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold text-primary">Add Product</div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-separator class="q-my-md" />

      <q-card-section class="q-pa-none">
        <q-form ref="createFormRef">
          <div class="row q-col-gutter-lg">
            <!-- Left Column (Image & Identification) -->
            <div class="col-12 col-md-5 q-gutter-y-md">
              <div
                class="image-preview-container border rounded-borders q-pa-sm bg-grey-1 text-center"
                style="border: 1px dashed #cfd8dc; border-radius: 8px; min-height: 200px"
              >
                <div
                  v-if="createForm.image_url"
                  style="
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 200px;
                  "
                >
                  <SmartImage
                    :src="createForm.image_url"
                    style="
                      max-height: 200px;
                      max-width: 100%;
                      object-fit: contain;
                      margin: 0 auto;
                    "
                  />
                </div>
                <div v-else class="flex flex-center text-grey-6" style="height: 200px">
                  <div class="column items-center">
                    <q-icon name="ph ph-image" size="48px" />
                    <div class="text-caption q-mt-sm">No Image Preview</div>
                  </div>
                </div>
              </div>

              <q-input
                v-model="createForm.image_url"
                label="Image URL"
                outlined
                dense
                class="soft-input"
              >
                <template #prepend>
                  <q-icon name="ph ph-image" />
                </template>
              </q-input>

              <q-input
                v-model="createForm.name"
                label="Name *"
                type="textarea"
                autogrow
                outlined
                dense
                class="soft-input"
                :rules="[(val) => !!val || 'Name is required']"
              >
                <template #prepend>
                  <q-icon name="ph ph-archive-box" />
                </template>
              </q-input>

              <q-input
                v-model="createForm.barcode"
                label="Barcode"
                outlined
                dense
                class="soft-input"
              >
                <template #prepend>
                  <q-icon name="ph ph-qr-code" />
                </template>
              </q-input>

              <q-input
                v-model="createForm.product_code"
                label="Product Code"
                outlined
                dense
                class="soft-input"
              >
                <template #prepend>
                  <q-icon name="ph ph-identification-badge" />
                </template>
              </q-input>
            </div>

            <!-- Right Column (Metadata, Parameters & Options) -->
            <div class="col-12 col-md-7 q-gutter-y-md">
              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="createForm.vendor_code"
                    :options="dialogVendorOptions"
                    emit-value
                    map-options
                    label="Vendor"
                    outlined
                    dense
                    clearable
                    class="soft-input"
                    @update:model-value="onVendorOrMarketChange"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-storefront" />
                    </template>
                  </q-select>
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="createForm.market_code"
                    :options="dialogMarketOptions"
                    emit-value
                    map-options
                    label="Market"
                    outlined
                    dense
                    clearable
                    class="soft-input"
                    @update:model-value="onVendorOrMarketChange"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-globe" />
                    </template>
                  </q-select>
                </div>
              </div>

              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <div class="row items-center q-col-gutter-sm no-wrap">
                    <div class="col">
                      <q-select
                        v-model="createForm.brand"
                        :options="dialogBrandOptions"
                        use-input
                        fill-input
                        hide-selected
                        input-debounce="0"
                        clearable
                        emit-value
                        map-options
                        label="Brand"
                        outlined
                        dense
                        :disable="!canPickBrandCategory"
                        @filter="filterBrandOptions"
                        @input-value="onBrandInputValue"
                        class="soft-input"
                      >
                        <template #prepend>
                          <q-icon name="ph ph-tag" />
                        </template>
                      </q-select>
                    </div>
                    <div class="col-auto">
                      <q-btn
                        color="primary"
                        no-caps
                        outline
                        label="Add"
                        :disable="!canAddBrand"
                        @click="addBrandOption"
                        style="height: 40px"
                        class="pill-btn"
                      />
                    </div>
                  </div>
                </div>

                <div class="col-12 col-sm-6">
                  <div class="row items-center q-col-gutter-sm no-wrap">
                    <div class="col">
                      <q-select
                        v-model="createForm.category"
                        :options="dialogCategoryOptions"
                        use-input
                        fill-input
                        hide-selected
                        input-debounce="0"
                        clearable
                        emit-value
                        map-options
                        label="Category"
                        outlined
                        dense
                        :disable="!canPickBrandCategory"
                        @filter="filterCategoryOptions"
                        @input-value="onCategoryInputValue"
                        class="soft-input"
                      >
                        <template #prepend>
                          <q-icon name="ph ph-squares-four" />
                        </template>
                      </q-select>
                    </div>
                    <div class="col-auto">
                      <q-btn
                        color="primary"
                        no-caps
                        outline
                        label="Add"
                        :disable="!canAddCategory"
                        @click="addCategoryOption"
                        style="height: 40px"
                        class="pill-btn"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="createForm.list_price_amount"
                    label="List Price"
                    type="number"
                    step="0.01"
                    outlined
                    dense
                    class="soft-input"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="createForm.list_price_currency_id"
                    :options="currencies"
                    label="List Price Currency"
                    outlined
                    dense
                    emit-value
                    map-options
                    class="soft-input"
                  />
                </div>
              </div>

              <div class="row q-col-gutter-sm q-mt-xs">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="createForm.reference_cost_amount"
                    label="Reference Cost"
                    type="number"
                    step="0.01"
                    outlined
                    dense
                    class="soft-input"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="createForm.reference_cost_currency_id"
                    :options="currencies"
                    label="Reference Cost Currency"
                    outlined
                    dense
                    emit-value
                    map-options
                    class="soft-input"
                  />
                </div>
              </div>

              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="createForm.product_weight"
                    label="Product Weight"
                    type="number"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-scales" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="createForm.package_weight"
                    label="Package Weight"
                    type="number"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-barbell" />
                    </template>
                  </q-input>
                </div>
              </div>

              <div class="row items-center q-pl-xs">
                <q-toggle
                  v-model="createForm.is_available"
                  label="Is Available"
                  color="primary"
                />
              </div>
            </div>
          </div>
        </q-form>
      </q-card-section>

      <q-separator class="q-my-md" />

      <q-card-actions align="right" class="q-pa-none">
        <q-btn
          flat
          label="Cancel"
          no-caps
          class="pill-btn slim-btn"
          v-close-popup
          :disable="isCreatingProduct"
        />
        <q-btn
          color="primary"
          label="Save Product"
          no-caps
          class="pill-btn slim-btn"
          :loading="isCreatingProduct"
          @click="onCreateProduct"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, reactive, watch } from 'vue';
import type { QForm } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalMarketsQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import {
  useProductBrandsQuery,
  useProductCategoriesQuery,
} from '../composables/useProductQuery';
import {
  useCreateProductMutation,
  useCreateProductBrandMutation,
  useCreateProductCategoryMutation,
} from '../composables/useProductMutations';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

interface CurrencyOption {
  label: string;
  value: number;
}

const props = defineProps<{
  modelValue: boolean;
  currencies: CurrencyOption[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'success'): void;
}>();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const { data: marketsData } = useGlobalMarketsQuery();

const createFormRef = ref<QForm | null>(null);

const createForm = reactive({
  name: '',
  product_code: '',
  barcode: '',
  brand: null as string | null,
  category: null as string | null,
  list_price_amount: null as number | null,
  list_price_currency_id: null as number | null,
  reference_cost_amount: null as number | null,
  reference_cost_currency_id: null as number | null,
  image_url: '',
  vendor_code: null as string | null,
  market_code: 'GB',
  is_available: true,
  product_weight: null as number | null,
  package_weight: null as number | null,
});

// Dialog filter lookups via TanStack Query
const dialogLookupParams = computed(() => ({
  vendorCode: createForm.vendor_code,
  tenantId: authStore.tenantId ?? null,
}));

const { data: dialogBrandsData } = useProductBrandsQuery(dialogLookupParams);
const { data: dialogCategoriesData } = useProductCategoriesQuery(dialogLookupParams);

const brandNames = computed(() => dialogBrandsData.value ?? []);
const categoryNames = computed(() => dialogCategoriesData.value ?? []);
const filteredBrandNames = ref<string[]>([]);
const filteredCategoryNames = ref<string[]>([]);
const brandInputValue = ref('');
const categoryInputValue = ref('');

watch(brandNames, (newVal) => {
  filteredBrandNames.value = [...newVal];
}, { immediate: true });

watch(categoryNames, (newVal) => {
  filteredCategoryNames.value = [...newVal];
}, { immediate: true });

const dialogBrandOptions = computed(() => {
  const seen = new Set<string>();
  const options = filteredBrandNames.value
    .map((item) => (item ?? '').trim())
    .filter((item) => item.length > 0)
    .filter((item) => item.toLowerCase() !== 'other')
    .filter((item) => {
      const key = item.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .map((item) => ({
      label: item,
      value: item,
    }));

  return [{ label: 'Other', value: null as string | null }, ...options];
});

const dialogCategoryOptions = computed(() => {
  const seen = new Set<string>();
  const options = filteredCategoryNames.value
    .map((item) => (item ?? '').trim())
    .filter((item) => item.length > 0)
    .filter((item) => item.toLowerCase() !== 'other')
    .filter((item) => {
      const key = item.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .map((item) => ({
      label: item,
      value: item,
    }));

  return [{ label: 'Other', value: null as string | null }, ...options];
});

const dialogVendorOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...vendorStore.items.map((vendor) => ({
    label: `${vendor.name} (${vendor.code})`,
    value: vendor.code,
  })),
]);

const dialogMarketOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...(marketsData.value ?? []).map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
]);

const canPickBrandCategory = computed(
  () => Boolean(createForm.vendor_code) && Boolean(createForm.market_code),
);

const normalized = (value: string | null | undefined) => (value ?? '').trim();

const normalizeKey = (value: string | null | undefined) => normalized(value).toLowerCase();

const lastTypedBrand = ref('');
const lastTypedCategory = ref('');

const canAddBrand = computed(() => {
  if (!canPickBrandCategory.value || !createForm.vendor_code) return false;
  const candidate = normalized(lastTypedBrand.value || brandInputValue.value || createForm.brand);
  if (!candidate || candidate.toLowerCase() === 'other') return false;
  return !brandNames.value.some((item) => normalizeKey(item) === normalizeKey(candidate));
});

const canAddCategory = computed(() => {
  if (!canPickBrandCategory.value || !createForm.vendor_code) return false;
  const candidate = normalized(
    lastTypedCategory.value || categoryInputValue.value || createForm.category,
  );
  if (!candidate || candidate.toLowerCase() === 'other') return false;
  return !categoryNames.value.some((item) => normalizeKey(item) === normalizeKey(candidate));
});

const filterBrandOptions = (val: string, update: (callback: () => void) => void) => {
  const needle = normalizeKey(val);
  update(() => {
    if (!needle) {
      filteredBrandNames.value = [...brandNames.value];
      return;
    }
    filteredBrandNames.value = brandNames.value.filter((item) =>
      normalizeKey(item).includes(needle),
    );
  });
};

const filterCategoryOptions = (val: string, update: (callback: () => void) => void) => {
  const needle = normalizeKey(val);
  update(() => {
    if (!needle) {
      filteredCategoryNames.value = [...categoryNames.value];
      return;
    }
    filteredCategoryNames.value = categoryNames.value.filter((item) =>
      normalizeKey(item).includes(needle),
    );
  });
};

const onBrandInputValue = (value: string) => {
  const cleaned = (value || '').trim();
  if (cleaned && cleaned.toLowerCase() !== 'other') {
    lastTypedBrand.value = cleaned;
  }
  brandInputValue.value = value;
};

const onCategoryInputValue = (value: string) => {
  const cleaned = (value || '').trim();
  if (cleaned && cleaned.toLowerCase() !== 'other') {
    lastTypedCategory.value = cleaned;
  }
  categoryInputValue.value = value;
};

// Mutations
const createProductMutation = useCreateProductMutation();
const createBrandMutation = useCreateProductBrandMutation();
const createCategoryMutation = useCreateProductCategoryMutation();

const isCreatingProduct = computed(() => createProductMutation.isPending.value);

const addBrandOption = () => {
  const name = normalized(lastTypedBrand.value || brandInputValue.value || createForm.brand);
  if (!name || name.toLowerCase() === 'other' || !createForm.vendor_code) return;

  const selectedVendor = vendorStore.items.find((v) => v.code === createForm.vendor_code);
  createBrandMutation.mutate(
    {
      name,
      value: name.toLowerCase(),
      vendor_code: createForm.vendor_code,
      vendor_id: selectedVendor ? selectedVendor.id : null,
      tenant_id: authStore.tenantId ?? null,
    },
    {
      onSuccess: (data) => {
        showSuccessNotification('Brand added successfully.');
        createForm.brand = data?.name || name.toUpperCase();
        brandInputValue.value = '';
        lastTypedBrand.value = '';
      },
      onError: (err) => {
        showErrorNotification(err instanceof Error ? err.message : 'Failed to add brand.');
      },
    },
  );
};

const addCategoryOption = () => {
  const name = normalized(
    lastTypedCategory.value || categoryInputValue.value || createForm.category,
  );
  if (!name || name.toLowerCase() === 'other' || !createForm.vendor_code) return;

  const selectedVendor = vendorStore.items.find((v) => v.code === createForm.vendor_code);
  createCategoryMutation.mutate(
    {
      name,
      value: name.toLowerCase(),
      vendor_code: createForm.vendor_code,
      vendor_id: selectedVendor ? selectedVendor.id : null,
      tenant_id: authStore.tenantId ?? null,
    },
    {
      onSuccess: (data) => {
        showSuccessNotification('Category added successfully.');
        createForm.category = data?.name || name;
        categoryInputValue.value = '';
        lastTypedCategory.value = '';
      },
      onError: (err) => {
        showErrorNotification(err instanceof Error ? err.message : 'Failed to add category.');
      },
    },
  );
};

const onVendorOrMarketChange = () => {
  createForm.brand = null;
  createForm.category = null;
};

const resetForm = () => {
  createForm.name = '';
  createForm.product_code = '';
  createForm.barcode = '';
  createForm.brand = null;
  createForm.category = null;
  createForm.list_price_amount = null;
  createForm.list_price_currency_id =
    props.currencies.find((c) => c.label.startsWith('GBP'))?.value ?? null;
  createForm.reference_cost_amount = null;
  createForm.reference_cost_currency_id =
    props.currencies.find((c) => c.label.startsWith('GBP'))?.value ?? null;
  createForm.image_url = '';
  createForm.vendor_code = null;
  createForm.market_code = 'GB';
  createForm.is_available = true;
  createForm.product_weight = null;
  createForm.package_weight = null;

  brandInputValue.value = '';
  categoryInputValue.value = '';
  lastTypedBrand.value = '';
  lastTypedCategory.value = '';
};

watch(
  () => props.modelValue,
  (newVal) => {
    if (newVal) {
      resetForm();
    }
  },
);

const onDialogUpdate = (val: boolean) => {
  emit('update:modelValue', val);
};

const cleanNumber = (val: number | string | null | undefined): number | null => {
  if (val === '' || val == null) return null;
  const parsed = Number(val);
  return Number.isFinite(parsed) ? parsed : null;
};

const onCreateProduct = async () => {
  if (createFormRef.value) {
    const isValid = await createFormRef.value.validate();
    if (!isValid) return;
  }

  createProductMutation.mutate(
    {
      inserted_by_tenant_id: authStore.tenantId ?? null,
      name: createForm.name.trim(),
      product_code: createForm.product_code.trim() || null,
      barcode: createForm.barcode.trim() || null,
      brand: createForm.brand?.trim() || null,
      category: createForm.category?.trim() || null,
      list_price_amount: cleanNumber(createForm.list_price_amount),
      list_price_currency_id: createForm.list_price_currency_id,
      reference_cost_amount: cleanNumber(createForm.reference_cost_amount),
      reference_cost_currency_id: createForm.reference_cost_currency_id,
      image_url: createForm.image_url.trim() || null,
      vendor_code: createForm.vendor_code?.trim() || null,
      market_code: createForm.market_code?.trim() || null,
      is_available: createForm.is_available,
      product_weight: cleanNumber(createForm.product_weight),
      package_weight: cleanNumber(createForm.package_weight),
      available_units: null,
      expire_date: null,
      minimum_order_quantity: null,
      languages: null,
      batch_code_manufacture_date: null,
    },
    {
      onSuccess: () => {
        showSuccessNotification('Product created successfully.');
        emit('update:modelValue', false);
        emit('success');
      },
      onError: (err) => {
        showErrorNotification(err instanceof Error ? err.message : 'Failed to create product.');
      },
    },
  );
};
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
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
