<template>
  <q-card flat bordered class="dropship-customer-form">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
        <q-icon name="ph ph-user" size="18px" class="q-mr-xs text-primary" />
        {{ $t('shop.dropship_customer_details') }}
      </div>
    </q-card-section>

    <q-card-section>
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.recipientName"
            outlined
            dense
            :label="$t('shop.recipient_name') + ' *'"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.recipientPhone"
            outlined
            dense
            :label="$t('shop.recipient_phone') + ' *'"
            hint="01XXXXXXXXX"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.secondaryPhone"
            outlined
            dense
            :label="$t('shop.dropship_secondary_phone')"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.district"
            outlined
            dense
            :label="$t('shop.dropship_district') + ' *'"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.thana"
            outlined
            dense
            :label="$t('shop.dropship_thana') + ' *'"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.postCode"
            outlined
            dense
            :label="$t('shop.dropship_post_code')"
          />
        </div>

        <div class="col-12">
          <q-input
            v-model="form.shippingAddress"
            outlined
            dense
            type="textarea"
            :label="$t('shop.shipping_address') + ' *'"
            rows="3"
          />
        </div>

        <div class="col-12">
          <q-input
            v-model="form.deliveryInstructions"
            outlined
            dense
            type="textarea"
            :label="$t('shop.delivery_instructions')"
            rows="2"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
export interface DropshipCustomerForm {
  recipientName: string;
  recipientPhone: string;
  secondaryPhone: string;
  district: string;
  thana: string;
  postCode: string;
  shippingAddress: string;
  deliveryInstructions: string;
}

defineProps<{
  form: DropshipCustomerForm;
}>();
</script>

<style scoped>
.dropship-customer-form {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}
</style>
