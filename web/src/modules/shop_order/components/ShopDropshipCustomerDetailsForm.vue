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
            v-model="form.recipientPhone"
            outlined
            dense
            hide-bottom-space
            :label="$t('shop.recipient_phone') + ' *'"
            hint="01XXXXXXXXX"
            @blur="$emit('phone-blur')"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.recipientName"
            outlined
            dense
            hide-bottom-space
            :label="$t('shop.recipient_name') + ' *'"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-input
            v-model="form.secondaryPhone"
            outlined
            dense
            hide-bottom-space
            :label="$t('shop.dropship_secondary_phone')"
          />
        </div>

        <div class="col-12 col-sm-6">
          <q-select
            v-model="form.district"
            outlined
            dense
            use-input
            fill-input
            hide-selected
            input-debounce="0"
            hide-bottom-space
            :label="$t('shop.dropship_district') + ' *'"
            :options="districtOptions"
            option-label="name"
            option-value="name"
            emit-value
            map-options
            @filter="(val, update) => $emit('filter-district', val, update)"
            @update:model-value="(val) => $emit('district-change', val)"
          >
            <template #no-option>
              <q-item>
                <q-item-section class="text-grey">No matching district</q-item-section>
              </q-item>
            </template>
            <template #option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section>
                  <q-item-label>{{ scope.opt.name }}</q-item-label>
                  <q-item-label v-if="scope.opt.bnName" caption>{{ scope.opt.bnName }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-select>
        </div>

        <div class="col-12 col-sm-6">
          <q-select
            v-model="form.thana"
            outlined
            dense
            use-input
            fill-input
            hide-selected
            input-debounce="0"
            hide-bottom-space
            :label="$t('shop.dropship_thana') + ' *'"
            :options="thanaOptions"
            option-label="name"
            option-value="name"
            emit-value
            map-options
            @filter="(val, update) => $emit('filter-thana', val, update)"
            @update:model-value="(val) => $emit('thana-change', val)"
          >
            <template #no-option>
              <q-item>
                <q-item-section class="text-grey">No matching thana/upazila</q-item-section>
              </q-item>
            </template>
            <template #option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section>
                  <q-item-label>{{ scope.opt.name }}</q-item-label>
                  <q-item-label v-if="scope.opt.bnName" caption>{{ scope.opt.bnName }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-select>
        </div>

        <div class="col-12 col-sm-6">
          <q-select
            v-model="form.postCode"
            outlined
            dense
            use-input
            fill-input
            hide-selected
            input-debounce="0"
            hide-bottom-space
            :label="$t('shop.dropship_post_code')"
            :options="postcodeOptions"
            option-label="displayLabel"
            option-value="postCode"
            emit-value
            map-options
            @filter="(val, update) => $emit('filter-postcode', val, update)"
            @new-value="(val, done) => $emit('create-postcode', val, done)"
          >
            <template #no-option>
              <q-item>
                <q-item-section class="text-grey">Type custom post code or office</q-item-section>
              </q-item>
            </template>
            <template #option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section>
                  <q-item-label>{{ scope.opt.postOffice }} - {{ scope.opt.postCode }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-select>
        </div>

        <div class="col-12">
          <q-input
            v-model="form.shippingAddress"
            outlined
            dense
            type="textarea"
            hide-bottom-space
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
            hide-bottom-space
            :label="$t('shop.delivery_instructions')"
            rows="2"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import type { BDLocationOption, BDPostcodeOption } from 'src/utils/bdAddressService';

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
  districtOptions: BDLocationOption[];
  thanaOptions: BDLocationOption[];
  postcodeOptions: (BDPostcodeOption & { displayLabel: string })[];
}>();

defineEmits<{
  (e: 'phone-blur'): void;
  (e: 'filter-district', val: string, update: (fn: () => void) => void): void;
  (e: 'filter-thana', val: string, update: (fn: () => void) => void): void;
  (e: 'filter-postcode', val: string, update: (fn: () => void) => void): void;
  (e: 'create-postcode', val: string, done: (item: unknown) => void): void;
  (e: 'district-change', val: string): void;
  (e: 'thana-change', val: string): void;
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
