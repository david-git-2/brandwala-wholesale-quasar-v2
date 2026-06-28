<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card style="width: 700px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div>
          <div class="text-h6 text-weight-bold">Garment Measurements</div>
          <div class="text-caption text-grey-8">{{ stock.name || 'Thrift Item' }} ({{ stock.barcode }})</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>
      <q-separator />

      <q-card-section class="q-py-md scroll" style="max-height: 70vh;">
        <q-form @submit="onSubmit" class="q-gutter-sm">
          <!-- Size field (updates thrift_stocks size directly) -->
          <div class="row q-col-gutter-sm items-center">
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.size"
                outlined
                dense
                label="Size (Tag / Label)"
                class="soft-input"
                placeholder="e.g. M, 10, 38, 32x30"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.fabric_stretch"
                :options="['none', 'low', 'medium', 'high']"
                outlined
                dense
                label="Fabric Stretch"
                class="soft-input"
                clearable
              />
            </div>
          </div>

          <div class="text-subtitle2 text-weight-bold q-mt-md text-primary">Core Fit (inches)</div>
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-3">
              <q-input v-model.number="form.bust_in" type="number" step="0.1" min="0" outlined dense label="Bust (in)" class="soft-input" />
            </div>
            <div class="col-6 col-sm-3">
              <q-input v-model.number="form.waist_in" type="number" step="0.1" min="0" outlined dense label="Waist (in)" class="soft-input" />
            </div>
            <div class="col-6 col-sm-3">
              <q-input v-model.number="form.hips_in" type="number" step="0.1" min="0" outlined dense label="Hips (in)" class="soft-input" />
            </div>
            <div class="col-6 col-sm-3">
              <q-input v-model.number="form.length_in" type="number" step="0.1" min="0" outlined dense label="Length (in)" class="soft-input" />
            </div>
          </div>

          <div class="text-subtitle2 text-weight-bold q-mt-md text-primary">Sleeves & Structure (inches)</div>
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-4">
              <q-input v-model.number="form.shoulder_width_in" type="number" step="0.1" min="0" outlined dense label="Shoulder Width (in)" class="soft-input" />
            </div>
            <div class="col-6 col-sm-4">
              <q-input v-model.number="form.sleeve_length_in" type="number" step="0.1" min="0" outlined dense label="Sleeve Length (in)" class="soft-input" />
            </div>
            <div class="col-6 col-sm-4">
              <q-input v-model.number="form.arm_circumference_in" type="number" step="0.1" min="0" outlined dense label="Arm Circum. (in)" class="soft-input" />
            </div>
          </div>

          <div class="text-subtitle2 text-weight-bold q-mt-md text-primary">Style-dependent Dimensions (inches)</div>
          <div class="row q-col-gutter-sm">
            <div class="col-6 col-sm-6">
              <q-input v-model.number="form.hem_width_in" type="number" step="0.1" min="0" outlined dense label="Hem Width (in)" class="soft-input" />
            </div>
            <div class="col-6 col-sm-6">
              <q-input v-model.number="form.neck_opening_in" type="number" step="0.1" min="0" outlined dense label="Neck Opening (in)" class="soft-input" />
            </div>
          </div>

          <div class="text-subtitle2 text-weight-bold q-mt-md text-primary">Style & Details</div>
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input v-model="form.sleeve_type" outlined dense label="Sleeve Type" class="soft-input" placeholder="e.g. Raglan, Sleeveless" />
            </div>
            <div class="col-12 col-sm-4">
              <q-input v-model="form.neckline" outlined dense label="Neckline" class="soft-input" placeholder="e.g. V-neck, Crew" />
            </div>
            <div class="col-12 col-sm-4">
              <q-input v-model="form.dress_style" outlined dense label="Dress/Garment Style" class="soft-input" placeholder="e.g. A-line, Bodycon" />
            </div>
          </div>

          <div class="row q-col-gutter-sm items-center q-mt-xs">
            <div class="col-12 col-sm-6">
              <q-input v-model="form.closure_type" outlined dense label="Closure Type" class="soft-input" placeholder="e.g. Zipper, Button-down" />
            </div>
            <div class="col-12 col-sm-6">
              <q-checkbox v-model="form.lining" label="Has Lining" class="q-ml-sm" />
            </div>
          </div>

          <q-input
            v-model="form.measurement_notes"
            type="textarea"
            rows="2"
            outlined
            dense
            label="Notes"
            class="soft-input q-mt-md"
            placeholder="Any specific fit details or comments..."
          />

          <div class="row justify-end q-gutter-sm q-mt-lg">
            <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
            <q-btn unelevated no-caps label="Save Measurements" color="primary" type="submit" :loading="saving" />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script lang="ts">
import { defineComponent, ref, computed } from 'vue';
import type { PropType } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import type { ThriftStock, ThriftStockMeasurements } from '../types';
import { thriftStockRepository } from '../repositories/thriftStockRepository';

export default defineComponent({
  name: 'ThriftStockMeasurementsDialog',
  props: {
    stock: {
      type: Object as PropType<ThriftStock>,
      required: true,
    },
  },
  emits: [
    ...useDialogPluginComponent.emits,
  ],
  setup(props) {
    const $q = useQuasar();
    const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

    const saving = ref(false);

    const initialMeasurements = props.stock.measurements || {} as ThriftStockMeasurements;

    const form = ref({
      size: props.stock.size || '',
      bust_in: initialMeasurements.bust_in ?? null,
      waist_in: initialMeasurements.waist_in ?? null,
      hips_in: initialMeasurements.hips_in ?? null,
      length_in: initialMeasurements.length_in ?? null,
      shoulder_width_in: initialMeasurements.shoulder_width_in ?? null,
      sleeve_length_in: initialMeasurements.sleeve_length_in ?? null,
      arm_circumference_in: initialMeasurements.arm_circumference_in ?? null,
      hem_width_in: initialMeasurements.hem_width_in ?? null,
      neck_opening_in: initialMeasurements.neck_opening_in ?? null,
      sleeve_type: initialMeasurements.sleeve_type || null,
      neckline: initialMeasurements.neckline || null,
      dress_style: initialMeasurements.dress_style || null,
      fabric_stretch: initialMeasurements.fabric_stretch || null,
      lining: initialMeasurements.lining ?? false,
      closure_type: initialMeasurements.closure_type || null,
      measurement_notes: initialMeasurements.measurement_notes || null,
    });

    const hasAnyMeasurement = computed(() => {
      const f = form.value;
      return (
        f.bust_in !== null ||
        f.waist_in !== null ||
        f.hips_in !== null ||
        f.length_in !== null ||
        f.shoulder_width_in !== null ||
        f.sleeve_length_in !== null ||
        f.arm_circumference_in !== null ||
        f.hem_width_in !== null ||
        f.neck_opening_in !== null ||
        f.sleeve_type !== null ||
        f.neckline !== null ||
        f.dress_style !== null ||
        f.fabric_stretch !== null ||
        f.closure_type !== null ||
        f.measurement_notes !== null ||
        f.lining
      );
    });

    async function onSubmit() {
      saving.value = true;
      try {
        // Update stock size first if modified
        if (form.value.size !== props.stock.size) {
          await thriftStockRepository.updateStock(props.stock.id, { size: form.value.size }, {
            cost_of_goods_sold: props.stock.pricing?.cost_of_goods_sold || 0,
            target_price: props.stock.pricing?.target_price || 0,
            listed_unit_price: props.stock.pricing?.listed_unit_price || 0,
            is_listed_price_manual: props.stock.pricing?.is_listed_price_manual,
            extra_expense_cost: props.stock.pricing?.extra_expense_cost,
          });
        }

        let updatedMeasurements: ThriftStockMeasurements | null = null;

        if (hasAnyMeasurement.value) {
          updatedMeasurements = await thriftStockRepository.upsertStockMeasurements(
            props.stock.id,
            {
              bust_in: form.value.bust_in,
              waist_in: form.value.waist_in,
              hips_in: form.value.hips_in,
              length_in: form.value.length_in,
              shoulder_width_in: form.value.shoulder_width_in,
              sleeve_length_in: form.value.sleeve_length_in,
              arm_circumference_in: form.value.arm_circumference_in,
              hem_width_in: form.value.hem_width_in,
              neck_opening_in: form.value.neck_opening_in,
              sleeve_type: form.value.sleeve_type,
              neckline: form.value.neckline,
              dress_style: form.value.dress_style,
              fabric_stretch: form.value.fabric_stretch,
              lining: form.value.lining,
              closure_type: form.value.closure_type,
              measurement_notes: form.value.measurement_notes,
            },
            props.stock.tenant_id
          );
        } else {
          await thriftStockRepository.deleteStockMeasurements(props.stock.id);
        }

        $q.notify({
          type: 'positive',
          message: 'Measurements saved successfully',
          position: 'top-right',
        });

        onDialogOK({
          size: form.value.size,
          measurements: updatedMeasurements,
        });
      } catch (err: unknown) {
        $q.notify({
          type: 'negative',
          message: (err as Error).message || 'Failed to save measurements',
          position: 'top-right',
        });
      } finally {
        saving.value = false;
      }
    }

    return {
      dialogRef,
      onDialogHide,
      form,
      saving,
      onSubmit,
    };
  },
});
</script>
