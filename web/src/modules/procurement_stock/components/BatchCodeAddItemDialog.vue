<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card style="width: 520px; max-width: 92vw; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <q-avatar color="primary" text-color="white" icon="ph ph-plus" size="32px" />
        <div class="q-ml-sm col">
          <div class="text-subtitle1 text-weight-bold">Add batch line</div>
          <div class="text-caption text-grey-7">Fill any fields you have; mfg without expire uses +36 months.</div>
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-form @submit.prevent="onSubmit">
        <q-card-section class="q-gutter-y-md q-pt-sm">
          <q-input v-model="form.barcode" label="Barcode" dense outlined />
          <q-input v-model="form.product_code" label="Product code" dense outlined />
          <q-input v-model="form.batch_id" label="Batch ID" dense outlined />
          <q-input v-model="form.manufacturing_date" label="Mfg date" dense outlined mask="##-##-####" placeholder="DD-MM-YYYY">
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy transition-show="scale" transition-hide="scale">
                  <q-date
                    v-model="form.manufacturing_date"
                    mask="DD-MM-YYYY"
                    default-view="Years"
                    years-in-month-view
                  >
                    <div class="row items-center justify-end q-pa-sm">
                      <q-btn v-close-popup label="Close" color="primary" flat dense />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <q-input v-model="form.expire_date" label="Expire date" dense outlined mask="##-##-####" placeholder="DD-MM-YYYY">
            <template #append>
              <q-icon name="ph ph-calendar" class="cursor-pointer">
                <q-popup-proxy transition-show="scale" transition-hide="scale">
                  <q-date
                    v-model="form.expire_date"
                    mask="DD-MM-YYYY"
                    default-view="Years"
                    years-in-month-view
                  >
                    <div class="row items-center justify-end q-pa-sm">
                      <q-btn v-close-popup label="Close" color="primary" flat dense />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Add line"
            type="submit"
            style="border-radius: 8px"
            :loading="saving"
            :disable="!hasContent"
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import { defaultExpireFromManufacturing, toIsoDate } from '../utils/batchCodeExpiry';
import type { BatchCodePasteRow } from '../repositories/batchCodeRepository';

const props = defineProps<{
  modelValue: boolean;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: BatchCodePasteRow];
}>();

const emptyForm = () => ({
  barcode: '',
  product_code: '',
  batch_id: '',
  manufacturing_date: '',
  expire_date: '',
});

const form = reactive(emptyForm());

const hasContent = computed(
  () =>
    Boolean(
      form.barcode.trim() ||
        form.product_code.trim() ||
        form.batch_id.trim() ||
        form.manufacturing_date.trim() ||
        form.expire_date.trim(),
    ),
);

watch(
  () => props.modelValue,
  (open) => {
    if (open) Object.assign(form, emptyForm());
  },
);

const onSubmit = () => {
  if (!hasContent.value) return;
  const manufacturingDate = toIsoDate(form.manufacturing_date);
  let expireDate = toIsoDate(form.expire_date);
  if (manufacturingDate && !expireDate) {
    expireDate = defaultExpireFromManufacturing(manufacturingDate) || null;
  }
  emit('submit', {
    barcode: form.barcode.trim() || null,
    product_code: form.product_code.trim() || null,
    batch_id: form.batch_id.trim() || null,
    manufacturing_date: manufacturingDate,
    expire_date: expireDate,
  });
};
</script>
