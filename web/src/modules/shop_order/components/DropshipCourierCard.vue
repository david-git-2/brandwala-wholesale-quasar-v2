<script setup lang="ts">
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';

const props = defineProps<{
  form: {
    courier_service_id: string | null;
    courier_awb_number: string;
    tracking_url: string;
    allow_open_box: boolean;
    cod_charge: number;
  };
  courierOptions: { label: string; value: string }[];
  selectedCourier: CourierServiceRow | undefined;
  deliveryZoneLabel: string;
  suggestedDeliveryFee: number;
  codRateLabel: string;
  formatBdt: (amount: number) => string;
}>();

const emit = defineEmits<{
  (e: 'courier-change'): void;
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
        <q-icon name="ph ph-truck" size="18px" class="q-mr-xs text-primary" />
        Block E: Courier &amp; Tracking Assignment
      </div>
    </q-card-section>
    <q-card-section>
      <div class="row q-col-gutter-md">
        <div class="col-12">
          <q-select
            :model-value="props.form.courier_service_id"
            :options="courierOptions"
            emit-value
            map-options
            label="Select Courier Partner *"
            outlined
            dense
            hide-bottom-space
            @update:model-value="(val) => { updateField('courier_service_id', val); emit('courier-change'); }"
          />
        </div>
        <div class="col-12">
          <q-input
            :model-value="props.form.courier_awb_number"
            label="Consignment / AWB Number"
            outlined
            dense
            hide-bottom-space
            @update:model-value="(val) => updateField('courier_awb_number', val)"
          />
        </div>
        <div class="col-12">
          <q-input
            :model-value="props.form.tracking_url"
            label="Courier Tracking URL"
            outlined
            dense
            hide-bottom-space
            @update:model-value="(val) => updateField('tracking_url', val)"
          />
        </div>

        <!-- Track Shipment Link -->
        <div v-if="selectedCourier && props.form.tracking_url" class="col-12">
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-arrow-square-out"
            label="Track Parcel / Open Tracking Link"
            type="a"
            :href="props.form.tracking_url"
            target="_blank"
            rel="noopener noreferrer"
            class="full-width bg-blue-1 text-weight-medium rounded-borders q-py-xs"
          />
        </div>

        <!-- Return Policy Chip Summary -->
        <div v-if="selectedCourier" class="col-12">
          <div class="q-pa-sm bg-blue-50 rounded-borders text-caption text-grey-8" style="border: 1px solid #d0e7ff">
            <div class="text-weight-bold text-primary q-mb-xs">Selected Courier: {{ selectedCourier.name }}</div>
            <div>Zone: {{ deliveryZoneLabel }} | Delivery: {{ formatBdt(suggestedDeliveryFee) }}</div>
            <div>COD Rate: {{ codRateLabel }} | Suggested COD Fee: {{ formatBdt(props.form.cod_charge) }}</div>
            <div>Inside Dhaka Return: {{ selectedCourier.inside_dhaka_return_fee }} BDT | Outside: {{ selectedCourier.outside_dhaka_return_fee }} BDT</div>
            <div>Max Attempts: {{ selectedCourier.delivery_attempt_count }} | Open Box: {{ props.form.allow_open_box ? 'Yes' : 'No' }}</div>
          </div>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>
