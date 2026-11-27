<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card
      flat
      bordered
      class="dropship-discount-dialog"
      style="min-width: min(420px, 92vw); width: 100%; max-width: 480px"
    >
      <q-card-section class="row items-start justify-between q-pa-md q-pb-sm">
        <div class="min-width-0 col">
          <div class="text-subtitle2 text-weight-bold text-grey-9">
            {{ $t('shop.dropship_request_discount') }}
          </div>
          <div v-if="productName" class="text-caption text-grey-7 q-mt-xs ellipsis-2-lines">
            {{ productName }}
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" color="grey-7" :ripple="false" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none q-px-md q-pb-md column q-gutter-y-sm">
        <q-input
          v-model="requestedPrice"
          type="number"
          outlined
          dense
          hide-bottom-space
          :label="$t('shop.dropship_request_discount_resell_label')"
          :prefix="currencySymbol"
          min="0"
          :error="priceInvalid"
          :error-message="priceInvalid ? $t('shop.dropship_request_discount_price_required') : undefined"
        />
        <q-input
          v-model="reason"
          type="textarea"
          outlined
          dense
          class="dropship-discount-dialog__reason"
          :label="$t('shop.dropship_request_discount_reason_label')"
          :rows="6"
          :error="reasonInvalid"
          :error-message="reasonInvalid ? $t('shop.dropship_request_discount_reason_required') : undefined"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md q-pt-none q-gutter-sm">
        <TfBtn
          variant="tertiary"
          size="md"
          class="dropship-discount-dialog__action-btn"
          :label="$t('shop_admin.cancel')"
          :disable="loading"
          v-close-popup
        />
        <TfBtn
          size="md"
          class="dropship-discount-dialog__action-btn"
          :label="$t('shop.dropship_request_discount_submit')"
          :loading="loading"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    productName?: string;
    currencySymbol?: string;
    initialRequestedPrice?: number | null;
    initialReason?: string | null;
    loading?: boolean;
  }>(),
  {
    productName: '',
    currencySymbol: '৳',
    initialRequestedPrice: null,
    initialReason: null,
    loading: false,
  },
);

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'submit', payload: { requestedPrice: number; reason: string }): void;
}>();

const requestedPrice = ref<string | number | null>(null);
const reason = ref('');
const priceInvalid = ref(false);
const reasonInvalid = ref(false);

const applyInitialValues = () => {
  requestedPrice.value =
    props.initialRequestedPrice != null ? props.initialRequestedPrice : null;
  reason.value = props.initialReason?.trim() ?? '';
  priceInvalid.value = false;
  reasonInvalid.value = false;
};

const resetForm = () => {
  requestedPrice.value = null;
  reason.value = '';
  priceInvalid.value = false;
  reasonInvalid.value = false;
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      applyInitialValues();
      return;
    }
    resetForm();
  },
);

const onSubmit = () => {
  const price = Number(requestedPrice.value);
  const trimmedReason = reason.value.trim();
  priceInvalid.value = requestedPrice.value === '' || requestedPrice.value === null || Number.isNaN(price) || price < 0;
  reasonInvalid.value = trimmedReason.length === 0;
  if (priceInvalid.value || reasonInvalid.value) return;
  emit('submit', { requestedPrice: price, reason: trimmedReason });
};
</script>

<style scoped>
.dropship-discount-dialog {
  border-radius: var(--tf-radius-md, 12px);
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.dropship-discount-dialog__reason :deep(textarea) {
  min-height: 148px;
  line-height: 1.45;
}

.dropship-discount-dialog__action-btn {
  min-width: 104px;
  min-height: 40px;
  padding-left: 16px;
  padding-right: 16px;
}
</style>