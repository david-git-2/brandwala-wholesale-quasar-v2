<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    form: {
      sender_name: string;
      pickup_phone: string;
      pickup_address: string;
    };
    selectedMerchantId: string | null;
    merchantOptions: { label: string; value: string }[];
    blockCExpanded: boolean;
    title?: string;
  }>(),
  {
    title: 'Block C: Merchant Sender Pickup Info',
  },
);

const emit = defineEmits<{
  (e: 'update:selectedMerchantId', val: string | null): void;
  (e: 'update:blockCExpanded', val: boolean): void;
  (e: 'merchant-select', val: string | null): void;
  (e: 'update:form-field', key: string, val: any): void;
}>();

const updateField = (key: string, val: any) => {
  emit('update:form-field', key, val);
};
</script>

<template>
  <q-card flat bordered class="form-card">
    <q-expansion-item
      :model-value="props.blockCExpanded"
      header-class="border-bottom"
      @update:model-value="(v) => emit('update:blockCExpanded', v)"
    >
      <template #header>
        <div class="row items-center justify-between full-width">
          <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
            <q-icon name="ph ph-storefront" size="18px" class="q-mr-xs text-primary" />
            {{ props.title }}
          </div>
          <div v-if="props.selectedMerchantId" class="text-caption text-grey-7 q-mr-sm">
            <q-chip dense color="blue-1" text-color="primary" size="sm">
              {{ props.form.sender_name || 'Merchant Selected' }}
            </q-chip>
          </div>
        </div>
      </template>
      <q-card-section>
        <div class="row q-col-gutter-md">
          <div class="col-12">
            <q-select
              :model-value="props.selectedMerchantId"
              :options="merchantOptions"
              emit-value
              map-options
              clearable
              label="Select Merchant Profile *"
              outlined
              dense
              hide-bottom-space
              @update:model-value="(val) => { emit('update:selectedMerchantId', val); emit('merchant-select', val); }"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              :model-value="props.form.sender_name"
              label="Sender Name *"
              outlined
              dense
              hide-bottom-space
              @update:model-value="(val) => updateField('sender_name', val)"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-input
              :model-value="props.form.pickup_phone"
              label="Sender Pickup Phone *"
              outlined
              dense
              hide-bottom-space
              @update:model-value="(val) => updateField('pickup_phone', val)"
            />
          </div>
          <div class="col-12">
            <q-input
              :model-value="props.form.pickup_address"
              label="Sender Pickup Address *"
              outlined
              dense
              hide-bottom-space
              type="textarea"
              rows="2"
              @update:model-value="(val) => updateField('pickup_address', val)"
            />
          </div>
        </div>
      </q-card-section>
    </q-expansion-item>
  </q-card>
</template>
