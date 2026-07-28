<script setup lang="ts">
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';

const props = defineProps<{
  form: {
    delivery_charge: number;
    package_weight_band: string;
    cod_fee_percent: number;
    cod_charge: number;
  };
  selectedCourier: CourierServiceRow | undefined;
}>();

const emit = defineEmits<{
  (e: 'delivery-charge-edit'): void;
  (e: 'calculate-cod'): void;
  (e: 'recalculate-collect'): void;
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
        <q-icon name="ph ph-archive-box" size="18px" class="q-mr-xs text-primary" />
        Block B: Parcel Weight &amp; COD Collection
      </div>
    </q-card-section>
    <q-card-section>
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-3">
          <q-input
            :model-value="props.form.delivery_charge"
            type="number"
            label="Delivery Charge (BDT)"
            outlined
            dense
            hide-bottom-space
            @update:model-value="(val) => { updateField('delivery_charge', Number(val)); emit('delivery-charge-edit'); }"
          />
        </div>
        <div class="col-12 col-sm-3">
          <q-select
            :model-value="props.form.package_weight_band"
            :options="['under_1kg', '1_2kg', '2_3kg', 'over_3kg']"
            label="Parcel Weight Band *"
            outlined
            dense
            hide-bottom-space
            @update:model-value="(val) => updateField('package_weight_band', val)"
          />
        </div>
        <div class="col-12 col-sm-3">
          <q-input
            :model-value="props.form.cod_fee_percent"
            type="number"
            label="COD Fee (%)"
            outlined
            dense
            hide-bottom-space
            :readonly="selectedCourier?.cod_fee_mode !== 'percent_of_collect'"
            @update:model-value="(val) => { updateField('cod_fee_percent', Number(val)); emit('calculate-cod'); }"
          />
        </div>
        <div class="col-12 col-sm-3">
          <q-input
            :model-value="props.form.cod_charge"
            type="number"
            label="Courier COD Fee (BDT)"
            outlined
            dense
            hide-bottom-space
            hint="Editable; included in collect when not deducted from margin"
            @update:model-value="(val) => { updateField('cod_charge', Number(val)); emit('recalculate-collect'); }"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>
