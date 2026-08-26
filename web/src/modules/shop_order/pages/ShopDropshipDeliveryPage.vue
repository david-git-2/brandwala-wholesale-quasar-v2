<template>
  <q-page class="q-pa-md shop-commerce-page">
    <div class="q-gutter-y-md">
      <section class="dropship-delivery-header">
        <div class="text-subtitle1 text-weight-bold text-grey-9 q-my-none">
          {{ $t('shop.dropship_delivery_title') }}
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          {{ $t('shop.dropship_delivery_subtitle') }}
        </div>
      </section>

      <ShopCartSkeleton v-if="isLoading" />

      <q-card v-else-if="isError" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-grey-8 text-weight-bold q-mb-xs">
            {{ $t('shop.cart_load_error') }}
          </div>
          <div class="text-grey-6 q-mb-md">
            {{ $t('shop.cart_load_error_desc') }}
          </div>
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            :label="$t('shop.cart_retry')"
            @click="() => refetch()"
          />
        </q-card-section>
      </q-card>

      <q-card v-else-if="!shopId || items.length === 0" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-shopping-cart" size="64px" color="grey-4" class="q-mb-md" />
          <div class="text-h6 text-grey-7 text-weight-bold">{{ $t('shop.cart_empty') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm q-mb-md">
            {{ $t('shop.cart_empty_desc') }}
          </p>
          <q-btn
            color="primary"
            no-caps
            unelevated
            :label="$t('shop.continue_shopping')"
            @click="goBackToCart"
          />
        </q-card-section>
      </q-card>

      <div v-else class="row q-col-gutter-lg">
        <div class="col-xs-12 col-lg-8 column q-gutter-y-md">
          <ShopDropshipCustomerDetailsForm
            :form="customerForm"
            :district-options="districtOptions"
            :thana-options="thanaOptions"
            :postcode-options="postcodeOptions"
            @phone-blur="onRecipientPhoneBlur"
            @filter-district="filterDistrict"
            @filter-thana="filterThana"
            @filter-postcode="filterPostcode"
            @create-postcode="createPostcode"
            @district-change="onDistrictChange"
            @thana-change="onThanaChange"
          />
          <ShopDropshipChargeOptionsCard
            v-model:recipient-pays-delivery="recipientPaysDelivery"
            v-model:recipient-pays-cod="recipientPaysCod"
            :charges="chargePreview"
            :currency-symbol="currencySymbol"
          />
        </div>

        <div class="col-xs-12 col-lg-4">
          <ShopDropshipDeliverySummaryCard
            :summary="summary"
            :can-submit="canSubmit"
            :is-submitting="isSubmitting"
            :currency-symbol="currencySymbol"
            @place-order="onPlaceOrder"
          />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import { useBDAddressOptions } from '../composables/useBDAddressOptions';
import { useDropshipReviewCartQuery } from '../composables/useDropshipReviewCartQuery';
import { useSubmitDropshipOrderMutation } from '../composables/useSubmitDropshipOrderMutation';
import { resolveCartShopId, shopCartPath } from '../utils/catalogShop';
import ShopCartSkeleton from '../components/ShopCartSkeleton.vue';
import ShopDropshipCustomerDetailsForm from '../components/ShopDropshipCustomerDetailsForm.vue';
import ShopDropshipChargeOptionsCard from '../components/ShopDropshipChargeOptionsCard.vue';
import ShopDropshipDeliverySummaryCard from '../components/ShopDropshipDeliverySummaryCard.vue';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const recipientProfileStore = useRecipientProfileStore();
const lastLookupPhone = ref('');

const {
  districtOptions,
  thanaOptions,
  postcodeOptions,
  loadInitialDistricts,
  updateThanaList,
  updatePostcodeList,
  filterDistrict,
  filterThana,
  filterPostcode,
  createPostcode,
} = useBDAddressOptions();

const shopId = computed(() =>
  resolveCartShopId(authStore.tenantId, [], route.query.shopId),
);

const {
  cart,
  items,
  currencySymbol,
  resellSubtotal,
  chargeEstimates,
  reviewSummary,
  isLoading,
  isError,
  refetch,
} = useDropshipReviewCartQuery(shopId);

const submitOrderMutation = useSubmitDropshipOrderMutation();
const isSubmitting = computed(() => submitOrderMutation.isPending.value);

const recipientPaysDelivery = ref(true);
const recipientPaysCod = ref(true);

const customerForm = reactive({
  recipientName: '',
  recipientPhone: '',
  secondaryPhone: '',
  district: '',
  thana: '',
  postCode: '',
  shippingAddress: '',
  deliveryInstructions: '',
});

const deliveryCharge = computed(() => chargeEstimates.value?.delivery_mid ?? 0);
const codCharge = computed(() => chargeEstimates.value?.cod_charge_preview ?? 0);
const printCharge = computed(() => cart.value?.charges.print_charge_amount ?? 0);
const packingCharge = computed(() => cart.value?.charges.packing_charge_amount ?? 0);

const chargePreview = computed(() => ({
  deliveryCharge: deliveryCharge.value,
  codCharge: codCharge.value,
  printCharge: printCharge.value,
  packingCharge: packingCharge.value,
  recipientPaysDelivery: recipientPaysDelivery.value,
  recipientPaysCod: recipientPaysCod.value,
}));

const summary = computed(() => {
  const recipientDeliveryCharge = recipientPaysDelivery.value ? deliveryCharge.value : 0;
  const recipientCodCharge = recipientPaysCod.value ? codCharge.value : 0;
  const merchantDelivery = recipientPaysDelivery.value ? 0 : deliveryCharge.value;
  const merchantCod = recipientPaysCod.value ? 0 : codCharge.value;
  const merchantDeductions = merchantDelivery + merchantCod + printCharge.value + packingCharge.value;
  const baseResellTotal = resellSubtotal.value;
  const recipientGrandTotal =
    baseResellTotal + recipientDeliveryCharge + recipientCodCharge;

  return {
    resellTotal: baseResellTotal,
    recipientDeliveryCharge,
    recipientCodCharge,
    recipientGrandTotal,
    merchantDeductions,
  };
});

const canSubmit = computed(() => {
  if (reviewSummary.value?.has_floor_violation) return false;
  const phone = customerForm.recipientPhone.trim();
  return (
    customerForm.recipientName.trim().length > 0 &&
    /^01[3-9]\d{8}$/.test(phone) &&
    customerForm.district.trim().length > 0 &&
    customerForm.thana.trim().length > 0 &&
    customerForm.shippingAddress.trim().length > 0 &&
    !isSubmitting.value
  );
});

const formatShippingAddress = () => {
  let formattedAddress = customerForm.shippingAddress.trim();
  const district = customerForm.district.trim();
  const thana = customerForm.thana.trim();
  const postCode = customerForm.postCode.trim();

  const parts = [
    thana ? `Thana: ${thana}` : '',
    district ? `District: ${district}` : '',
    postCode ? `Post Code: ${postCode}` : '',
  ].filter(Boolean);
  const locationPart = parts.join(', ');

  if (formattedAddress && district && !formattedAddress.toLowerCase().includes(district.toLowerCase())) {
    formattedAddress = `${formattedAddress}\n${locationPart}`;
  } else if (!formattedAddress) {
    formattedAddress = locationPart;
  }

  return formattedAddress;
};

const onDistrictChange = async (newDistrict: string) => {
  customerForm.thana = '';
  customerForm.postCode = '';
  await updateThanaList(newDistrict);
};

const onThanaChange = async (newThana: string) => {
  customerForm.postCode = '';
  await updatePostcodeList(customerForm.district, newThana);
};

const onRecipientPhoneBlur = async () => {
  const phone = customerForm.recipientPhone.replace(/\D/g, '');
  const tenantId = cart.value?.tenant_id;
  if (!tenantId || !/^01\d{9}$/.test(phone)) return;
  if (phone === lastLookupPhone.value) return;
  lastLookupPhone.value = phone;

  const profile = await recipientProfileStore.getByPhone(tenantId, phone);
  if (!profile) return;

  if (!customerForm.recipientName.trim()) customerForm.recipientName = profile.name || '';
  if (!customerForm.secondaryPhone.trim() && profile.secondary_phone) {
    customerForm.secondaryPhone = profile.secondary_phone;
  }

  let baseAddress = profile.address || '';
  let extractedPostcode = '';
  const postCodeMatch = baseAddress.match(/Post\s*Code:\s*([^\n,]+)/i);
  if (postCodeMatch) {
    extractedPostcode = postCodeMatch[1]?.trim() || '';
  }
  baseAddress = baseAddress.replace(/\n?(?:Thana|District|Post\s*Code):.*$/gi, '').trim();

  if (!customerForm.shippingAddress.trim() && baseAddress) {
    customerForm.shippingAddress = baseAddress;
  }
  if (profile.district) {
    customerForm.district = profile.district;
    await updateThanaList(profile.district);
  }
  if (profile.thana) {
    customerForm.thana = profile.thana;
    await updatePostcodeList(customerForm.district, profile.thana);
  }
  if (extractedPostcode) {
    customerForm.postCode = extractedPostcode;
    await updatePostcodeList(customerForm.district, customerForm.thana, extractedPostcode);
  }
};

onMounted(async () => {
  await loadInitialDistricts();
});

const tenantSlugParam = () =>
  route.params.tenantSlug ? String(route.params.tenantSlug) : null;

const goBackToCart = () => {
  void router.push(shopCartPath(tenantSlugParam(), shopId.value));
};

const onPlaceOrder = async () => {
  if (!canSubmit.value || !shopId.value) return;

  const result = await submitOrderMutation.mutateAsync({
    shopId: shopId.value,
    recipientName: customerForm.recipientName.trim(),
    recipientPhone: customerForm.recipientPhone.trim(),
    shippingAddress: formatShippingAddress(),
    recipientPhoneSecondary: customerForm.secondaryPhone.trim() || null,
    shippingDistrict: customerForm.district.trim() || null,
    shippingThana: customerForm.thana.trim() || null,
    shippingPostCode: customerForm.postCode.trim() || null,
    deliveryInstructions: customerForm.deliveryInstructions.trim() || null,
    isPrepaid: cart.value?.charges.is_prepaid ?? false,
    codChargeAmount: codCharge.value,
    deliveryChargeAmount: deliveryCharge.value,
    printChargeAmount: printCharge.value,
    packingChargeAmount: packingCharge.value,
    discountAmount: cart.value?.charges.discount_amount ?? 0,
    recipientPaysDelivery: recipientPaysDelivery.value,
    recipientPaysCod: recipientPaysCod.value,
  });

  const slug = tenantSlugParam();
  void router.push(`${slug ? `/${slug}` : ''}/shop/orders/${result.data.order_id}`);
};
</script>

<script lang="ts">
export default {
  name: 'ShopDropshipDeliveryPage',
};
</script>

<style scoped>
.dropship-delivery-header {
  min-height: 40px;
}
</style>
