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

      <div class="row q-col-gutter-lg">
        <div class="col-xs-12 col-lg-8 column q-gutter-y-md">
          <ShopDropshipCustomerDetailsForm :form="customerForm" />
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
            :currency-symbol="currencySymbol"
            @place-order="onPlaceOrder"
          />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import {
  DROPSHIP_CART_UI_MOCK_SHOP,
  DROPSHIP_REVIEW_UI_MOCK_ITEMS,
  DROPSHIP_UI_MOCK_CHARGES,
} from '../mocks/dropshipCartUiMocks';
import ShopDropshipCustomerDetailsForm from '../components/ShopDropshipCustomerDetailsForm.vue';
import ShopDropshipChargeOptionsCard from '../components/ShopDropshipChargeOptionsCard.vue';
import ShopDropshipDeliverySummaryCard from '../components/ShopDropshipDeliverySummaryCard.vue';

const currencySymbol = DROPSHIP_CART_UI_MOCK_SHOP.currency_symbol;

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

const resellTotal = computed(() =>
  DROPSHIP_REVIEW_UI_MOCK_ITEMS.reduce(
    (sum, item) => sum + item.resellPrice * item.quantity,
    0,
  ),
);

const totalUnits = computed(() =>
  DROPSHIP_REVIEW_UI_MOCK_ITEMS.reduce((sum, item) => sum + item.quantity, 0),
);

const deliveryCharge = computed(
  () =>
    (DROPSHIP_UI_MOCK_CHARGES.deliveryChargeMin +
      DROPSHIP_UI_MOCK_CHARGES.deliveryChargeMax) /
    2,
);

const codCharge = computed(
  () => (resellTotal.value * DROPSHIP_UI_MOCK_CHARGES.codPercent) / 100,
);

const printCharge = computed(() => DROPSHIP_UI_MOCK_CHARGES.printCharge);
const packingCharge = computed(
  () => DROPSHIP_UI_MOCK_CHARGES.packingChargePerItem * totalUnits.value,
);

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

  return {
    resellTotal: resellTotal.value,
    recipientDeliveryCharge,
    recipientCodCharge,
    recipientGrandTotal: resellTotal.value + recipientDeliveryCharge + recipientCodCharge,
    merchantDeductions,
  };
});

const canSubmit = computed(() => {
  const phone = customerForm.recipientPhone.trim();
  return (
    customerForm.recipientName.trim().length > 0 &&
    /^01[3-9]\d{8}$/.test(phone) &&
    customerForm.district.trim().length > 0 &&
    customerForm.thana.trim().length > 0 &&
    customerForm.shippingAddress.trim().length > 0
  );
});

const onPlaceOrder = () => {
  if (!canSubmit.value) return;
  // UI-only placeholder — backend wiring comes later.
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
