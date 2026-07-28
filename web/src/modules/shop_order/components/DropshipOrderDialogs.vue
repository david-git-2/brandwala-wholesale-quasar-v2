<script setup lang="ts">
import type { ShopOrder } from '../types';

const props = defineProps<{
  order: ShopOrder | null;
  remittanceDialogOpen: boolean;
  remittanceForm: {
    remittance_ref: string;
    net_amount: number;
    bank_trx_id: string;
    note: string;
  };
  savingRemittance: boolean;
  canSaveOrderRemittance: boolean;

  dualInvoiceDialogOpen: boolean;
  creatingInvoice: boolean;

  confirmB2bInvoiceDialogOpen: boolean;
  confirmDeleteInvoiceDialogOpen: boolean;
  updatingStatus: boolean;

  recipientGrandTotal: number;
  deliveryChargeVal: number;
  codChargeVal: number;
  accountingSubtotal: number;
  printChargeVal: number;
  packingChargeVal: number;
  estimatedProfit: number;
  codCollectAmount: number;
  formatBdt: (amount: number) => string;
}>();

const emit = defineEmits<{
  (e: 'update:remittanceDialogOpen', val: boolean): void;
  (e: 'update:dualInvoiceDialogOpen', val: boolean): void;
  (e: 'update:confirmB2bInvoiceDialogOpen', val: boolean): void;
  (e: 'update:confirmDeleteInvoiceDialogOpen', val: boolean): void;
  (e: 'save-remittance'): void;
  (e: 'confirm-dual-invoice'): void;
  (e: 'execute-status-update', status: string): void;
  (e: 'update:remittance-field', key: string, val: any): void;
}>();

const updateRemittanceField = (key: string, val: any) => {
  emit('update:remittance-field', key, val);
};
</script>

<template>
  <div>
    <!-- Courier Remittance Dialog -->
    <q-dialog
      :model-value="props.remittanceDialogOpen"
      persistent
      @update:model-value="(v) => emit('update:remittanceDialogOpen', v)"
    >
      <q-card style="min-width: 440px; border-radius: 12px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">Record Courier Remittance</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>
        <q-card-section class="q-gutter-sm">
          <div class="text-body2 text-grey-8">
            Order <strong>{{ props.order?.order_no }}</strong> — net COD collection from courier.
          </div>
          <q-input
            :model-value="props.remittanceForm.remittance_ref"
            label="Remittance Batch / Statement ID *"
            outlined
            dense
            @update:model-value="(val) => updateRemittanceField('remittance_ref', val)"
          />
          <q-input
            :model-value="props.remittanceForm.net_amount"
            type="number"
            label="Net Remitted Amount (BDT) *"
            outlined
            dense
            @update:model-value="(val) => updateRemittanceField('net_amount', Number(val))"
          />
          <q-input
            :model-value="props.remittanceForm.bank_trx_id"
            label="Bank / MFS Transaction ID"
            outlined
            dense
            @update:model-value="(val) => updateRemittanceField('bank_trx_id', val)"
          />
          <q-input
            :model-value="props.remittanceForm.note"
            label="Notes"
            outlined
            dense
            type="textarea"
            rows="2"
            @update:model-value="(val) => updateRemittanceField('note', val)"
          />
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            label="Save Remittance"
            :loading="props.savingRemittance"
            :disable="!props.canSaveOrderRemittance"
            @click="emit('save-remittance')"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Create Dual Invoice Dialog -->
    <q-dialog
      :model-value="props.dualInvoiceDialogOpen"
      @update:model-value="(v) => emit('update:dualInvoiceDialogOpen', v)"
    >
      <q-card style="min-width: 440px; border-radius: 12px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">Create Dual Invoice</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>
        <q-card-section class="q-gutter-sm text-body2 text-grey-8">
          <p>Generate dual invoices for order <strong>{{ props.order?.order_no }}</strong>:</p>
          <div class="q-pa-sm bg-grey-2 rounded-borders">
            <div>1. <strong>Accounting Invoice</strong> (Merchant Cost + Margin Split)</div>
            <div>2. <strong>Recipient Invoice</strong> (Customer Face Prices: {{ props.codCollectAmount }} BDT)</div>
          </div>
          <p class="q-mt-sm text-caption text-grey-6">
            Posting dual invoice will commit books and stamp global_invoice_id on order.
          </p>
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="positive" label="Post Dual Invoice" :loading="props.creatingInvoice" @click="emit('confirm-dual-invoice')" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Confirm B2B Invoice Dialog -->
    <q-dialog
      :model-value="props.confirmB2bInvoiceDialogOpen"
      persistent
      @update:model-value="(v) => emit('update:confirmB2bInvoiceDialogOpen', v)"
    >
      <q-card style="min-width: 440px; border-radius: 12px">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="text-h6 text-weight-bold">Confirm B2B Invoice</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>
        <q-card-section class="q-pt-sm text-body2">
          <p class="text-grey-8 q-mb-md">
            Advancing to <strong>Ready for Pickup</strong> will automatically create the B2B Accounting Invoice for the middle man. Please review the financial breakdown before confirming.
          </p>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-card flat bordered class="q-pa-sm bg-grey-1">
                <div class="text-caption text-grey-7">Recipient Pays</div>
                <div class="text-weight-bold text-h6">{{ props.formatBdt(props.recipientGrandTotal) }}</div>
              </q-card>
            </div>
            <div class="col-12 col-sm-6">
              <q-card flat bordered class="q-pa-sm bg-grey-1">
                <div class="text-caption text-grey-7">Total Courier Cost</div>
                <div class="text-weight-bold text-h6">{{ props.formatBdt(props.deliveryChargeVal + props.codChargeVal) }}</div>
              </q-card>
            </div>
            <div class="col-12">
              <q-card flat bordered class="q-pa-sm bg-blue-1 border-blue">
                <div class="text-caption text-blue-9">B2B Invoice Entry (Brandwala Revenue)</div>
                <div class="text-weight-bold text-h6 text-blue-9">
                  {{ props.formatBdt(props.accountingSubtotal + props.printChargeVal + props.packingChargeVal) }}
                </div>
                <div class="text-caption text-blue-8">
                  Wholesale Items + Packing + Print
                </div>
              </q-card>
            </div>
            <div class="col-12">
              <q-card flat bordered class="q-pa-sm bg-green-1 border-green">
                <div class="text-caption text-green-9">Middle Man Profit (Ledger Payout)</div>
                <div class="text-weight-bold text-h6 text-green-9">
                  {{ props.formatBdt(props.estimatedProfit) }}
                </div>
              </q-card>
            </div>
          </div>
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" color="grey-8" no-caps v-close-popup />
          <q-btn
            color="primary"
            label="Confirm & Create Invoice"
            unelevated
            no-caps
            :loading="props.updatingStatus"
            @click="emit('execute-status-update', 'ready_for_pickup'); emit('update:confirmB2bInvoiceDialogOpen', false)"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Confirm Rollback Invoice Deletion Dialog -->
    <q-dialog
      :model-value="props.confirmDeleteInvoiceDialogOpen"
      persistent
      @update:model-value="(v) => emit('update:confirmDeleteInvoiceDialogOpen', v)"
    >
      <q-card style="min-width: 440px; border-radius: 12px">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="text-h6 text-weight-bold text-negative">Warning: Rollback Order</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>
        <q-card-section class="q-pt-sm text-body2">
          <q-banner class="bg-red-1 text-red-10 border-all-1 rounded-borders q-mb-md">
            <template #avatar>
              <q-icon name="ph ph-warning-circle" color="red-9" />
            </template>
            Rolling back to <strong>Processing</strong> will completely delete the associated B2B accounting invoice and restore the inventory stock.
          </q-banner>
          <p class="text-grey-8 q-mb-none">
            Are you sure you want to proceed?
          </p>
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" color="grey-8" no-caps v-close-popup />
          <q-btn
            color="negative"
            label="Yes, Delete Invoice & Rollback"
            unelevated
            no-caps
            :loading="props.updatingStatus"
            @click="emit('execute-status-update', 'processing'); emit('update:confirmDeleteInvoiceDialogOpen', false)"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>
