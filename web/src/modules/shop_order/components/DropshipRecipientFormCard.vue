<script setup lang="ts">
import type { BDLocationOption, BDPostcodeOption } from 'src/utils/bdAddressService';

const props = withDefaults(
  defineProps<{
    form: {
      recipient_name: string;
      recipient_phone: string;
      secondary_phone: string;
      district: string;
      thana: string;
      post_code: string;
      shipping_address: string;
    };
    districtOptions: BDLocationOption[];
    thanaOptions: BDLocationOption[];
    postcodeOptions: (BDPostcodeOption & { displayLabel: string })[];
    readonly?: boolean;
  }>(),
  {
    readonly: false,
  },
);

const emit = defineEmits<{
  (e: 'copy', text: string | null | undefined, label: string): void;
  (e: 'phone-blur'): void;
  (e: 'filter-district', val: string, update: (fn: () => void) => void): void;
  (e: 'filter-thana', val: string, update: (fn: () => void) => void): void;
  (e: 'filter-postcode', val: string, update: (fn: () => void) => void): void;
  (e: 'create-postcode', val: string, done: (item: any) => void): void;
  (e: 'district-change', newDist: string): void;
  (e: 'thana-change', newThana: string): void;
  (e: 'update:form-field', key: string, val: any): void;
}>();

const updateField = (key: string, val: any) => {
  emit('update:form-field', key, val);
};
</script>

<template>
  <q-card flat bordered class="form-card">
    <q-card-section class="border-bottom row items-center justify-between">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
        <q-icon name="ph ph-user" size="18px" class="q-mr-xs text-primary" />
        Block A: Recipient Delivery Information
      </div>
      <div class="row items-center q-gutter-x-sm">
        <q-chip dense :color="props.readonly ? 'grey-3' : 'blue-1'" :text-color="props.readonly ? 'grey-8' : 'primary'" size="sm">
          {{ props.readonly ? 'View Mode' : 'Editable at Desk' }}
        </q-chip>
      </div>
    </q-card-section>
    <q-card-section>
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-6">
          <q-input
            :model-value="props.form.recipient_name"
            label="Recipient Name *"
            outlined
            dense
            hide-bottom-space
            :readonly="props.readonly"
            @update:model-value="(val) => updateField('recipient_name', val)"
          />
        </div>
        <div class="col-12 col-sm-6">
          <q-input
            :model-value="props.form.recipient_phone"
            label="Recipient Phone *"
            outlined
            dense
            hide-bottom-space
            :readonly="props.readonly"
            @blur="emit('phone-blur')"
            @update:model-value="(val) => updateField('recipient_phone', val)"
          >
            <template #append>
              <q-btn
                flat
                round
                dense
                icon="ph ph-copy"
                size="xs"
                color="grey-7"
                @click.stop="emit('copy', props.form.recipient_phone, 'Phone')"
              >
                <q-tooltip>Copy Phone</q-tooltip>
              </q-btn>
            </template>
          </q-input>
        </div>
        <div class="col-12 col-sm-6">
          <q-input
            :model-value="props.form.secondary_phone"
            label="Secondary Phone"
            outlined
            dense
            hide-bottom-space
            :readonly="props.readonly"
            @update:model-value="(val) => updateField('secondary_phone', val)"
          />
        </div>
        <div class="col-12 col-sm-6">
          <q-select
            :model-value="props.form.district"
            outlined
            dense
            use-input
            input-debounce="0"
            label="District *"
            :options="districtOptions"
            option-label="name"
            option-value="name"
            emit-value
            map-options
            hide-bottom-space
            :disable="props.readonly"
            @filter="(v, u) => emit('filter-district', v, u)"
            @update:model-value="(v) => { updateField('district', v); emit('district-change', v); }"
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
            :model-value="props.form.thana"
            outlined
            dense
            use-input
            input-debounce="0"
            label="Thana / Upazila *"
            :options="thanaOptions"
            option-label="name"
            option-value="name"
            emit-value
            map-options
            hide-bottom-space
            :disable="props.readonly"
            @filter="(v, u) => emit('filter-thana', v, u)"
            @update:model-value="(v) => { updateField('thana', v); emit('thana-change', v); }"
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
            :model-value="props.form.post_code"
            outlined
            dense
            use-input
            input-debounce="0"
            label="Post Code / Post Office"
            :options="postcodeOptions"
            option-label="displayLabel"
            option-value="postCode"
            emit-value
            map-options
            hide-bottom-space
            :disable="props.readonly"
            @filter="(v, u) => emit('filter-postcode', v, u)"
            @new-value="(v, d) => emit('create-postcode', v, d)"
            @update:model-value="(val) => updateField('post_code', val)"
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
            :model-value="props.form.shipping_address"
            label="Shipping Address *"
            outlined
            dense
            hide-bottom-space
            type="textarea"
            rows="2"
            :readonly="props.readonly"
            @update:model-value="(val) => updateField('shipping_address', val)"
          >
            <template #append>
              <q-btn
                flat
                round
                dense
                icon="ph ph-copy"
                size="xs"
                color="grey-7"
                @click.stop="emit('copy', props.form.shipping_address, 'Address')"
              >
                <q-tooltip>Copy Address</q-tooltip>
              </q-btn>
            </template>
          </q-input>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>
