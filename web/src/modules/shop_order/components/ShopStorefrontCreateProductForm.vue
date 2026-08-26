<template>
  <div class="shop-storefront-create-product-form column q-gutter-y-md">
    <q-form ref="formRef" @submit.prevent="onSave">
      <div class="row q-col-gutter-md">
        <div class="col-12 q-gutter-y-md">
          <div
            class="image-preview-container border rounded-borders q-pa-sm bg-grey-1 text-center"
            style="border: 1px dashed #cfd8dc; border-radius: 8px; min-height: 160px"
          >
            <div v-if="form.image_url" class="flex flex-center" style="height: 160px">
              <SmartImage
                :src="form.image_url"
                style="max-height: 160px; max-width: 100%; object-fit: contain"
                :enable-edit="false"
                :enable-lightbox="false"
              />
            </div>
            <div v-else class="flex flex-center text-grey-6" style="height: 160px">
              <div class="column items-center">
                <q-icon name="ph ph-image" size="40px" />
                <div class="text-caption q-mt-sm">{{ $t('shop_admin.storefront_product_no_image') }}</div>
              </div>
            </div>
          </div>

          <q-input
            v-model="form.image_url"
            :label="$t('shop_admin.storefront_product_image_url')"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="ph ph-image" />
            </template>
          </q-input>

          <q-input
            v-model="form.name"
            :label="$t('shop_admin.storefront_product_name')"
            type="textarea"
            autogrow
            outlined
            dense
            :rules="[(val) => !!String(val ?? '').trim() || $t('shop_admin.storefront_product_name_required')]"
          >
            <template #prepend>
              <q-icon name="ph ph-archive-box" />
            </template>
          </q-input>

          <q-input
            v-model="form.barcode"
            :label="$t('shop_admin.storefront_product_barcode')"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="ph ph-qr-code" />
            </template>
          </q-input>

          <q-input
            v-model="form.product_code"
            :label="$t('shop_admin.storefront_product_code')"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="ph ph-identification-badge" />
            </template>
          </q-input>

          <q-select
            v-model="form.vendor_code"
            :options="vendorOptions"
            emit-value
            map-options
            :label="$t('shop_admin.storefront_product_vendor')"
            outlined
            dense
            clearable
          >
            <template #prepend>
              <q-icon name="ph ph-storefront" />
            </template>
          </q-select>

          <q-select
            v-model="form.market_code"
            :options="marketOptions"
            emit-value
            map-options
            :label="$t('shop_admin.storefront_product_market')"
            outlined
            dense
            clearable
          >
            <template #prepend>
              <q-icon name="ph ph-globe" />
            </template>
          </q-select>

          <q-select
            v-model="form.brand"
            :options="brandOptions"
            emit-value
            map-options
            :label="$t('shop_admin.storefront_product_brand')"
            outlined
            dense
            clearable
            use-input
            input-debounce="200"
            @filter="filterBrands"
          >
            <template #prepend>
              <q-icon name="ph ph-tag" />
            </template>
          </q-select>

          <q-select
            v-model="form.category"
            :options="categoryOptions"
            emit-value
            map-options
            :label="$t('shop_admin.storefront_product_category')"
            outlined
            dense
            clearable
            use-input
            input-debounce="200"
            @filter="filterCategories"
          >
            <template #prepend>
              <q-icon name="ph ph-squares-four" />
            </template>
          </q-select>

          <div class="row q-col-gutter-sm">
            <div class="col-7">
              <q-input
                v-model.number="form.list_price_amount"
                :label="$t('shop_admin.storefront_product_list_price')"
                type="number"
                step="0.01"
                outlined
                dense
              />
            </div>
            <div class="col-5">
              <q-select
                v-model="form.list_price_currency_id"
                :options="currencyOptions"
                :label="$t('shop_admin.storefront_product_currency')"
                outlined
                dense
                emit-value
                map-options
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-7">
              <q-input
                v-model.number="form.reference_cost_amount"
                :label="$t('shop_admin.storefront_product_reference_cost')"
                type="number"
                step="0.01"
                outlined
                dense
              />
            </div>
            <div class="col-5">
              <q-select
                v-model="form.reference_cost_currency_id"
                :options="currencyOptions"
                :label="$t('shop_admin.storefront_product_currency')"
                outlined
                dense
                emit-value
                map-options
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-6">
              <q-input
                v-model.number="form.product_weight"
                :label="$t('shop_admin.storefront_product_weight')"
                type="number"
                outlined
                dense
              >
                <template #prepend>
                  <q-icon name="ph ph-scales" />
                </template>
              </q-input>
            </div>
            <div class="col-6">
              <q-input
                v-model.number="form.package_weight"
                :label="$t('shop_admin.storefront_product_package_weight')"
                type="number"
                outlined
                dense
              >
                <template #prepend>
                  <q-icon name="ph ph-barbell" />
                </template>
              </q-input>
            </div>
          </div>

          <q-toggle
            v-model="form.is_available"
            :label="$t('shop_admin.storefront_product_is_available')"
            color="primary"
          />
        </div>
      </div>

      <div class="row items-center justify-end q-gutter-sm q-pt-sm">
        <q-btn
          flat
          no-caps
          color="grey-8"
          :label="$t('shop_admin.cancel')"
          @click="emit('cancel')"
        />
        <q-btn
          color="primary"
          unelevated
          no-caps
          type="submit"
          :label="$t('shop_admin.storefront_product_save')"
          :loading="isSaving"
        />
      </div>
    </q-form>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { QForm } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalMarketsQuery, useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import {
  useProductBrandsQuery,
  useProductCategoriesQuery,
} from 'src/modules/products/composables/useProductQuery';
import { useCreateProductMutation } from 'src/modules/products/composables/useProductMutations';
import type { Product } from 'src/modules/products/types';
import { showErrorNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  initialName?: string | undefined;
  tenantId?: number | null;
}>();

const emit = defineEmits<{
  (event: 'cancel'): void;
  (event: 'saved', product: Product): void;
}>();

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const formRef = ref<QForm | null>(null);

const { data: marketsData } = useGlobalMarketsQuery();
const { data: currenciesData } = useGlobalCurrenciesQuery();
const { mutate: createProduct, isPending: isSaving } = useCreateProductMutation();

const lookupParams = computed(() => ({
  vendorCode: form.vendor_code,
  tenantId: props.tenantId ?? authStore.tenantId ?? null,
}));

const { data: brandsData } = useProductBrandsQuery(lookupParams);
const { data: categoriesData } = useProductCategoriesQuery(lookupParams);

const filteredBrandNames = ref<string[]>([]);
const filteredCategoryNames = ref<string[]>([]);

watch(
  brandsData,
  (value) => {
    filteredBrandNames.value = [...(value ?? [])];
  },
  { immediate: true },
);

watch(
  categoriesData,
  (value) => {
    filteredCategoryNames.value = [...(value ?? [])];
  },
  { immediate: true },
);

const vendorOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...vendorStore.items.map((vendor) => ({
    label: `${vendor.name} (${vendor.code})`,
    value: vendor.code,
  })),
]);

const marketOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...(marketsData.value ?? []).map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
]);

const brandOptions = computed(() =>
  filteredBrandNames.value.map((item) => ({ label: item, value: item })),
);

const categoryOptions = computed(() =>
  filteredCategoryNames.value.map((item) => ({ label: item, value: item })),
);

const currencyOptions = computed(() =>
  (currenciesData.value ?? []).map((currency) => ({
    label: currency.code,
    value: currency.id,
  })),
);

const defaultForm = () => ({
  image_url: '',
  name: '',
  barcode: '',
  product_code: '',
  vendor_code: null as string | null,
  market_code: 'GB' as string | null,
  brand: null as string | null,
  category: null as string | null,
  list_price_amount: null as number | null,
  list_price_currency_id: null as number | null,
  reference_cost_amount: null as number | null,
  reference_cost_currency_id: null as number | null,
  product_weight: null as number | null,
  package_weight: null as number | null,
  is_available: true,
});

const form = reactive(defaultForm());

const resetForm = (name = '') => {
  Object.assign(form, defaultForm());
  form.name = name;
  const defaultCurrency = currenciesData.value?.[0]?.id ?? null;
  form.list_price_currency_id = defaultCurrency;
  form.reference_cost_currency_id = defaultCurrency;
};

watch(
  () => props.initialName,
  (name) => {
    resetForm(name?.trim() ?? '');
  },
  { immediate: true },
);

const filterBrands = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.trim().toLowerCase();
    const source = brandsData.value ?? [];
    filteredBrandNames.value = needle
      ? source.filter((item) => item.toLowerCase().includes(needle))
      : [...source];
  });
};

const filterCategories = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.trim().toLowerCase();
    const source = categoriesData.value ?? [];
    filteredCategoryNames.value = needle
      ? source.filter((item) => item.toLowerCase().includes(needle))
      : [...source];
  });
};

const cleanNumber = (val: number | string | null | undefined): number | null => {
  if (val === '' || val == null) return null;
  const parsed = Number(val);
  return Number.isFinite(parsed) ? parsed : null;
};

const onSave = async () => {
  if (formRef.value) {
    const valid = await formRef.value.validate();
    if (!valid) return;
  }

  createProduct(
    {
      inserted_by_tenant_id: props.tenantId ?? authStore.tenantId ?? null,
      name: form.name.trim(),
      product_code: form.product_code.trim() || null,
      barcode: form.barcode.trim() || null,
      brand: form.brand?.trim() || null,
      category: form.category?.trim() || null,
      list_price_amount: cleanNumber(form.list_price_amount),
      list_price_currency_id: form.list_price_currency_id,
      reference_cost_amount: cleanNumber(form.reference_cost_amount),
      reference_cost_currency_id: form.reference_cost_currency_id,
      image_url: form.image_url.trim() || null,
      vendor_code: form.vendor_code?.trim() || null,
      market_code: form.market_code?.trim() || null,
      is_available: form.is_available,
      product_weight: cleanNumber(form.product_weight),
      package_weight: cleanNumber(form.package_weight),
      available_units: null,
      expire_date: null,
      minimum_order_quantity: null,
      languages: null,
      batch_code_manufacture_date: null,
    },
    {
      onSuccess: (product) => {
        emit('saved', product);
      },
      onError: (err) => {
        showErrorNotification(err instanceof Error ? err.message : 'Failed to create product.');
      },
    },
  );
};
</script>
