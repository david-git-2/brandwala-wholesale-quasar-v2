<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: min(480px, 92vw)">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Record vendor refund</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="close" />
      </q-card-section>
      <q-card-section class="q-pt-sm">
        <VendorCreditRefundForm
          ref="formRef"
          :page-layout="false"
          :credit-note-id="creditNoteId"
          :parent-bill-id="parentBillId"
          :open-credit="openCredit"
          :books-tenant-id="booksTenantId"
          :from-profile-name="fromProfileName"
          :tenant-label="tenantLabel"
          :channel-meta="channelMeta"
          :active="modelValue"
          @submit="(p) => emit('submit', p)"
        />
      </q-card-section>
      <q-card-actions align="right" class="q-pa-md q-pt-none">
        <q-btn flat no-caps label="Cancel" @click="close" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Record refund"
          :loading="loading"
          @click="formRef?.trySubmit()"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import VendorCreditRefundForm from './VendorCreditRefundForm.vue';
import type { PostVendorCreditRefundInput } from '../composables/usePostVendorCreditRefundMutation';

defineProps<{
  modelValue: boolean;
  creditNoteId: number;
  parentBillId: number | null;
  openCredit: number;
  booksTenantId: number;
  fromProfileName: string;
  tenantLabel: string;
  channelMeta?: Record<string, unknown> | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: PostVendorCreditRefundInput];
}>();

const formRef = ref<InstanceType<typeof VendorCreditRefundForm> | null>(null);

function close() {
  emit('update:modelValue', false);
}
</script>