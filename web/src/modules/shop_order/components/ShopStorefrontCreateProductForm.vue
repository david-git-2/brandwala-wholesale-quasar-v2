<template>
  <div class="shop-storefront-create-product-form column q-gutter-y-md">
    <div class="row q-col-gutter-md">
      <div class="col-12 q-gutter-y-md">
        <div
          class="image-preview-container border rounded-borders q-pa-sm bg-grey-1 text-center"
          style="border: 1px dashed #cfd8dc; border-radius: 8px; min-height: 160px"
        >
          <div
            v-if="form.image_url"
            class="flex flex-center"
            style="height: 160px"
          >
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
        :label="$t('shop_admin.storefront_product_save')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';

const props = defineProps<{
  initialName?: string | undefined;
}>();

const emit = defineEmits<{
  (event: 'cancel'): void;
}>();

const vendorOptions = [
  { label: 'BrandWala', value: 'BW' },
  { label: 'SoundMax', value: 'SM' },
];

const marketOptions = [
  { label: 'Bangladesh', value: 'BD' },
  { label: 'International', value: 'INT' },
];

const brandOptions = [
  { label: 'BrandWala', value: 'BrandWala' },
  { label: 'Generic', value: 'Generic' },
];

const categoryOptions = [
  { label: 'Apparel', value: 'Apparel' },
  { label: 'Electronics', value: 'Electronics' },
];

const currencyOptions = [
  { label: 'BDT', value: 1 },
  { label: 'USD', value: 2 },
];

const defaultForm = () => ({
  image_url: '',
  name: '',
  barcode: '',
  product_code: '',
  vendor_code: null as string | null,
  market_code: null as string | null,
  brand: null as string | null,
  category: null as string | null,
  list_price_amount: null as number | null,
  list_price_currency_id: 1 as number | null,
  reference_cost_amount: null as number | null,
  reference_cost_currency_id: 1 as number | null,
  product_weight: null as number | null,
  package_weight: null as number | null,
  is_available: true,
});

const form = reactive(defaultForm());

const resetForm = (name = '') => {
  Object.assign(form, defaultForm());
  form.name = name;
};

watch(
  () => props.initialName,
  (name) => {
    resetForm(name?.trim() ?? '');
  },
  { immediate: true },
);
</script>
