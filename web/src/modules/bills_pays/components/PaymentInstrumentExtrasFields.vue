<template>
  <div class="row q-col-gutter-sm">
    <div v-if="methodFieldFlags.showBank" class="col-12">
      <q-select
        :model-value="bdBankId"
        :options="bdBankOptions"
        emit-value
        map-options
        outlined
        dense
        :clearable="!methodFieldFlags.bankRequired"
        :label="methodFieldFlags.bankLabel"
        :loading="loading"
        :rules="methodFieldFlags.bankRequired ? [(v) => v != null || 'Required'] : undefined"
        hide-bottom-space
        @update:model-value="emit('update:bdBankId', $event)"
      />
    </div>
    <div v-if="methodFieldFlags.showChequeNumber" class="col-12 col-sm-6">
      <q-input
        :model-value="chequeNumber"
        outlined
        dense
        :clearable="!methodFieldFlags.chequeNumberRequired"
        label="Cheque number"
        :rules="methodFieldFlags.chequeNumberRequired ? [(v) => !!String(v || '').trim() || 'Required'] : undefined"
        hide-bottom-space
        @update:model-value="emit('update:chequeNumber', String($event ?? ''))"
      />
    </div>
    <div v-if="methodFieldFlags.showInstrumentDate" class="col-12 col-sm-6">
      <q-input
        :model-value="instrumentDate"
        outlined
        dense
        :clearable="!methodFieldFlags.instrumentDateRequired"
        readonly
        :label="methodFieldFlags.instrumentDateLabel"
        :rules="methodFieldFlags.instrumentDateRequired ? [(v) => !!String(v || '').trim() || 'Required'] : undefined"
        hide-bottom-space
        @update:model-value="emit('update:instrumentDate', String($event ?? ''))"
      >
        <template #append>
          <q-icon name="ph ph-calendar" class="cursor-pointer">
            <q-popup-proxy cover transition-show="scale" transition-hide="scale">
              <q-date
                :model-value="instrumentDate"
                mask="YYYY-MM-DD"
                @update:model-value="emit('update:instrumentDate', String($event ?? ''))"
              >
                <div class="row items-center justify-end">
                  <q-btn v-close-popup label="Done" color="primary" flat no-caps />
                </div>
              </q-date>
            </q-popup-proxy>
          </q-icon>
        </template>
      </q-input>
    </div>
    <div v-if="methodFieldFlags.showInstrumentReference" class="col-12">
      <q-input
        :model-value="instrumentReference"
        outlined
        dense
        clearable
        :label="methodFieldFlags.instrumentReferenceLabel"
        :hint="
          methodFieldFlags.bankOrReferenceRequired && bdBankId == null && !instrumentReference.trim()
            ? 'Bank or transaction reference is required'
            : undefined
        "
        @update:model-value="emit('update:instrumentReference', String($event ?? ''))"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { paymentMethodFieldFlags } from '../utils/paymentInstrumentFields';

const props = defineProps<{
  methodCode: string;
  methodOptions: Array<{ label: string; value: string; code: string; category: string }>;
  bdBankOptions: Array<{ label: string; value: number }>;
  loading?: boolean;
  bdBankId: number | null;
  chequeNumber: string;
  instrumentDate: string;
  instrumentReference: string;
}>();

const emit = defineEmits<{
  'update:bdBankId': [value: number | null];
  'update:chequeNumber': [value: string];
  'update:instrumentDate': [value: string];
  'update:instrumentReference': [value: string];
}>();

const selectedMethodMeta = computed(() => {
  const row = props.methodOptions.find((m) => m.value === props.methodCode);
  if (!row) return null;
  return { code: row.code, category: row.category };
});

const methodFieldFlags = computed(() => paymentMethodFieldFlags(selectedMethodMeta.value));
</script>
