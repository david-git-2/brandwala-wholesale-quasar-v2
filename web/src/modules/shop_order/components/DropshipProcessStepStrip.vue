<template>
  <q-card flat bordered class="q-pa-sm bg-blue-grey-1">
    <div class="row items-center justify-between q-px-sm q-py-xs">
      <div class="row items-center q-gutter-x-xs">
        <q-icon name="ph ph-steps" color="primary" size="20px" />
        <span class="text-subtitle2 text-weight-bold text-grey-9">Process Order Steps</span>
      </div>
      <div class="text-caption text-grey-7">
        Step {{ currentStepIndex + 1 }} of {{ steps.length }}:
        <strong class="text-primary">{{ currentStep.label }}</strong>
      </div>
    </div>

    <q-separator class="q-my-xs" />

    <div class="row items-center justify-between q-col-gutter-xs q-px-xs q-py-xs scroll-x">
      <div
        v-for="(step, idx) in steps"
        :key="step.id"
        class="col-auto row items-center cursor-pointer step-item"
        @click="emit('step-click', step.id)"
      >
        <q-chip
          dense
          no-caps
          size="sm"
          :color="step.status === 'completed' ? 'positive' : step.status === 'current' ? 'primary' : 'grey-4'"
          :text-color="step.status === 'completed' || step.status === 'current' ? 'white' : 'grey-8'"
          class="text-weight-bold"
        >
          <q-icon
            :name="step.status === 'completed' ? 'ph ph-check-circle' : step.status === 'current' ? 'ph ph-arrow-circle-right' : 'ph ph-circle'"
            size="14px"
            class="q-mr-xs"
          />
          {{ idx + 1 }}. {{ step.shortLabel }}
        </q-chip>

        <q-icon
          v-if="idx < steps.length - 1"
          name="ph ph-caret-right"
          color="grey-5"
          size="16px"
          class="q-mx-xs"
        />
      </div>
    </div>

    <div v-if="currentStepAction" class="q-px-sm q-pt-xs row items-center justify-between bg-white rounded-borders q-pa-xs q-mt-xs">
      <div class="row items-center q-gutter-x-xs">
        <q-icon name="ph ph-info" color="info" size="18px" />
        <span class="text-caption text-grey-8">{{ currentStepAction.instruction }}</span>
      </div>
      <q-btn
        v-if="currentStepAction.btnLabel"
        dense
        unelevated
        no-caps
        size="sm"
        color="primary"
        class="q-px-sm text-weight-bold"
        :icon="currentStepAction.btnIcon"
        :label="currentStepAction.btnLabel"
        @click="currentStepAction.action"
      />
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder } from '../types';

const props = defineProps<{
  order: ShopOrder | null;
  form: any;
  selectedCourier: any;
  hasItems: boolean;
}>();

const emit = defineEmits<{
  (e: 'step-click', stepId: string): void;
  (e: 'open-recipient-invoice'): void;
  (e: 'update-status', status: string): void;
  (e: 'open-dual-invoice'): void;
}>();

export interface ProcessStep {
  id: string;
  label: string;
  shortLabel: string;
  status: 'completed' | 'current' | 'upcoming';
}

const steps = computed<ProcessStep[]>(() => {
  const st = props.order?.status ?? 'draft';

  // 1. Recipient info confirmed
  const recipientComplete = !!(
    props.form.recipient_name &&
    props.form.recipient_phone &&
    props.form.shipping_address
  );

  // 2. Courier + tracking assigned
  const courierComplete = !!(props.form.courier_service_id || props.selectedCourier?.id);

  // 3. Parcel + COD set
  const parcelComplete = Number(props.form.cod_collect_amount) > 0 || st === 'ready_for_pickup' || st === 'shipped' || st === 'delivered';

  // 4. Print Recipient Invoice
  const invoicePrinted = st !== 'submitted' && st !== 'confirmed';

  // 5. Ready for pickup status
  const isReady = ['ready_for_pickup', 'shipped', 'delivered', 'returned'].includes(st);

  // 6. Accounting Invoice created
  const accountingInvoiceCreated = !!props.order?.global_invoice_id;

  const currentStepId = !recipientComplete
    ? 'recipient'
    : !courierComplete
    ? 'courier'
    : !parcelComplete
    ? 'parcel'
    : !invoicePrinted
    ? 'print_invoice'
    : !isReady
    ? 'ready_for_pickup'
    : 'accounting_invoice';

  return [
    {
      id: 'recipient',
      label: 'Recipient & Delivery Address',
      shortLabel: 'Recipient',
      status: recipientComplete ? 'completed' : currentStepId === 'recipient' ? 'current' : 'upcoming',
    },
    {
      id: 'courier',
      label: 'Courier & Tracking Assignment',
      shortLabel: 'Courier',
      status: courierComplete ? 'completed' : currentStepId === 'courier' ? 'current' : 'upcoming',
    },
    {
      id: 'parcel',
      label: 'Parcel & COD Collection',
      shortLabel: 'Parcel & COD',
      status: parcelComplete ? 'completed' : currentStepId === 'parcel' ? 'current' : 'upcoming',
    },
    {
      id: 'print_invoice',
      label: 'Print Recipient Invoice',
      shortLabel: 'Recipient Slip',
      status: invoicePrinted ? 'completed' : currentStepId === 'print_invoice' ? 'current' : 'upcoming',
    },
    {
      id: 'ready_for_pickup',
      label: 'Mark Ready for Pickup',
      shortLabel: 'Ready Pickup',
      status: isReady ? 'completed' : currentStepId === 'ready_for_pickup' ? 'current' : 'upcoming',
    },
    {
      id: 'accounting_invoice',
      label: 'Create Accounting Invoice',
      shortLabel: 'Accounting Inv',
      status: accountingInvoiceCreated ? 'completed' : currentStepId === 'accounting_invoice' ? 'current' : 'upcoming',
    },
  ];
});

const currentStepIndex = computed(() => {
  const idx = steps.value.findIndex((s) => s.status === 'current');
  return idx !== -1 ? idx : steps.value.length - 1;
});

const currentStep = computed(() => steps.value[currentStepIndex.value] || steps.value[0]);

const currentStepAction = computed(() => {
  const stepId = currentStep.value.id;
  if (stepId === 'recipient') {
    return {
      instruction: 'Verify and save recipient contact details & shipping address.',
      btnLabel: '',
      btnIcon: '',
      action: () => {},
    };
  }
  if (stepId === 'courier') {
    return {
      instruction: 'Select courier partner service and enter AWB tracking number.',
      btnLabel: '',
      btnIcon: '',
      action: () => {},
    };
  }
  if (stepId === 'parcel') {
    return {
      instruction: 'Confirm parcel weight band and cash-on-delivery (COD) collect amount.',
      btnLabel: '',
      btnIcon: '',
      action: () => {},
    };
  }
  if (stepId === 'print_invoice') {
    return {
      instruction: 'Print recipient slip/invoice before handing off consignment.',
      btnLabel: 'Print Invoice',
      btnIcon: 'ph ph-receipt',
      action: () => emit('open-recipient-invoice'),
    };
  }
  if (stepId === 'ready_for_pickup') {
    return {
      instruction: 'Advance order status to Ready for Pickup.',
      btnLabel: 'Mark Ready for Pickup',
      btnIcon: 'ph ph-check-circle',
      action: () => emit('update-status', 'ready_for_pickup'),
    };
  }
  if (stepId === 'accounting_invoice') {
    return {
      instruction: 'Generate B2B accounting invoice for customer billing & profit booking.',
      btnLabel: 'Create Accounting Invoice',
      btnIcon: 'ph ph-receipt',
      action: () => emit('open-dual-invoice'),
    };
  }
  return null;
});
</script>

<style scoped>
.scroll-x {
  overflow-x: auto;
  white-space: nowrap;
}
.step-item {
  flex-shrink: 0;
}
</style>
