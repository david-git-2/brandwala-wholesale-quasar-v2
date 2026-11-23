<template>
  <ShopDropshipCustomerDetailsForm
    :form="customerForm"
    :district-options="districtOptions"
    :thana-options="thanaOptions"
    :postcode-options="postcodeOptions"
    :phone-lookup-loading="isPhoneProfileLoading"
    @phone-blur="onRecipientPhoneBlur"
    @filter-district="filterDistrict"
    @filter-thana="filterThana"
    @filter-postcode="filterPostcode"
    @create-postcode="createPostcode"
    @district-change="onDistrictChange"
    @thana-change="onThanaChange"
  />
</template>

<script setup lang="ts">
import ShopDropshipCustomerDetailsForm from '../ShopDropshipCustomerDetailsForm.vue';

defineProps<{
  customerForm: {
    recipientName: string;
    recipientPhone: string;
    secondaryPhone: string;
    district: string;
    thana: string;
    postCode: string;
    shippingAddress: string;
    deliveryInstructions: string;
  };
  districtOptions: { name: string }[];
  thanaOptions: { name: string }[];
  postcodeOptions: { name: string }[];
  isPhoneProfileLoading: boolean;
  onRecipientPhoneBlur: () => Promise<void>;
  onDistrictChange: (district: string) => Promise<void>;
  onThanaChange: (thana: string) => Promise<void>;
  filterDistrict: (val: string, update: (fn: () => void) => void) => void;
  filterThana: (val: string, update: (fn: () => void) => void) => void;
  filterPostcode: (val: string, update: (fn: () => void) => void) => void;
  createPostcode: (val: string) => void;
}>();
</script>