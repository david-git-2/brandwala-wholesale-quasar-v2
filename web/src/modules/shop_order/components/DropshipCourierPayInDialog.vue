<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 560px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-sm">
        <div class="text-h6 text-weight-bold">Courier pay in</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none">
        <p class="text-caption text-grey-7 q-ma-none q-mb-md">
          Net bank in from the courier (COD minus their charges). Clears the customer invoice; dropshipper
          profit stays on cashbook until Pay out.
        </p>
        <FinanceHubStepRemittance
          :selected-order="selectedOrder"
          :loading="loading"
          variant="panel"
          context="payin"
          @submit="onSubmit"
        />
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { useDialogPluginComponent } from 'quasar';
import FinanceHubStepRemittance from './finance_hub/FinanceHubStepRemittance.vue';
import type { FinanceHubOrderQueueItem } from '../repositories/dropshipFinanceRepository';
import type { DropshipCourierPayInSubmitPayload } from '../utils/dropshipCourierPayInDialog';

defineProps<{
  selectedOrder: FinanceHubOrderQueueItem;
  loading?: boolean;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

function onSubmit(payload: DropshipCourierPayInSubmitPayload) {
  onDialogOK(payload);
}
</script>
