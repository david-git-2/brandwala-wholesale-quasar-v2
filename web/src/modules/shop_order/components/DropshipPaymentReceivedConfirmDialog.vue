<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 520px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-sm">
        <div class="text-h6 text-weight-bold">Payment received</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none q-gutter-y-md">
        <p class="text-body2 q-ma-none">
          Confirm courier remittance for
          <span class="text-weight-bold">{{ money.orderNo }}</span>
          (BDT).
        </p>

        <div class="bg-grey-2 q-pa-sm rounded-borders q-gutter-y-xs">
          <div class="row items-center justify-between text-caption">
            <span>Collected COD</span>
            <span class="text-weight-medium">{{ formatBdt(money.collectedCod) }}</span>
          </div>
          <div class="row items-center justify-between text-caption text-grey-8">
            <span>Delivery</span>
            <span>{{ formatBdt(money.delivery) }}</span>
          </div>
          <div class="row items-center justify-between text-caption text-grey-8">
            <span>COD rate</span>
            <span>{{ formatBdt(money.codRate) }}</span>
          </div>
          <q-separator />
          <div class="row items-center justify-between text-caption">
            <span class="text-weight-medium">Courier pays (to tenant)</span>
            <span class="text-positive text-subtitle2 text-weight-bold">
              {{ formatBdt(money.courierPaysTenant) }}
            </span>
          </div>
          <div class="row items-center justify-between text-caption text-grey-8">
            <span>Customer AR paid (from remittance)</span>
            <span>{{ formatBdt(money.customerArPaid) }}</span>
          </div>
          <q-separator />
          <div class="row items-center justify-between text-caption">
            <span class="text-weight-medium">Dropshipper profit credited</span>
            <span class="text-primary text-subtitle2 text-weight-bold">
              {{ formatBdt(money.dropshipperProfit) }}
            </span>
          </div>
        </div>

        <p class="text-caption text-grey-7 q-ma-none">
          Deposits to <span class="text-weight-medium">main</span> cashbook · ref
          {{ money.remittanceRef }}
        </p>
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Confirm"
          :loading="loading"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { useDialogPluginComponent } from 'quasar';
import type { DropshipMgmtPaymentReceivedMoney } from '../utils/dropshipManagementPaymentReceived';

defineProps<{
  money: DropshipMgmtPaymentReceivedMoney;
  loading?: boolean;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

function formatBdt(amount: number): string {
  if (!Number.isFinite(amount)) return '—';
  return `৳${amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function onConfirm() {
  onDialogOK(true);
}
</script>