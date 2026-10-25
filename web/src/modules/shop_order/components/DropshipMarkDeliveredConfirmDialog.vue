<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 520px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-sm">
        <div class="text-h6 text-weight-bold">{{ title }}</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none q-gutter-y-md">
        <p v-if="intro" class="text-body2 q-ma-none">
          {{ intro }}
          <span v-if="orderNo" class="text-weight-medium"> ({{ orderNo }})</span>
        </p>
        <p v-else class="text-body2 q-ma-none">
          Mark this parcel as delivered?
          <span v-if="orderNo" class="text-weight-medium"> ({{ orderNo }})</span>
        </p>
        <p v-if="!intro" class="text-caption text-grey-7 q-ma-none">
          The customer invoice was issued at ship. Cash is recorded when the courier remits.
        </p>

        <div
          v-if="settlementSummary"
          class="bg-grey-2 q-pa-sm rounded-borders q-gutter-y-xs"
        >
          <div class="text-subtitle2 text-weight-bold q-mb-xs">After pay in</div>
          <div class="row items-center justify-between text-caption">
            <span>Net received</span>
            <span class="text-weight-medium">{{ formatBdt(settlementSummary.netAmount) }}</span>
          </div>
          <div class="row items-center justify-between text-caption text-grey-8">
            <span>Customer bill cleared</span>
            <span>{{ formatBdt(settlementSummary.invoiceAllocated) }}</span>
          </div>
          <div class="row items-center justify-between text-caption text-grey-8">
            <span>Courier AP settled (retained)</span>
            <span>{{ formatBdt(settlementSummary.courierApSettled) }}</span>
          </div>
          <q-separator />
          <div class="row items-center justify-between text-caption">
            <span class="text-weight-medium">Dropshipper receives</span>
            <span class="text-positive text-subtitle2 text-weight-bold">
              {{ formatBdt(settlementSummary.merchantRemainder) }}
            </span>
          </div>
        </div>

        <q-banner
          v-if="previewWarning"
          dense
          rounded
          class="bg-orange-1 text-orange-10"
        >
          {{ previewWarning }}
        </q-banner>

        <q-banner
          v-else-if="!hasAdjustments"
          dense
          rounded
          class="bg-grey-2 text-grey-9"
        >
          No credit or debit notes are needed on the issued bills.
        </q-banner>

        <div v-else class="column q-gutter-y-sm">
          <div class="text-subtitle2 text-weight-bold">Bill notes to issue</div>

          <q-card
            v-for="adj in adjustments"
            :key="`${adj.bill_id}-${adj.adjustment_kind}`"
            flat
            bordered
            class="dropship-deliver-confirm__bill-card"
          >
            <q-card-section class="q-pb-sm">
              <div class="text-subtitle2 text-weight-bold">
                {{ billHeading(adj) }}
              </div>
              <div class="text-caption text-grey-7">
                {{ adj.display_name }}
                <span v-if="adj.invoice_no"> · {{ adj.invoice_no }}</span>
              </div>
            </q-card-section>

            <q-separator />

            <q-card-section class="q-gutter-y-sm q-pt-sm">
              <div class="row items-center q-gutter-sm">
                <q-badge
                  :color="adj.adjustment_kind === 'debit_note' ? 'red-1' : 'green-1'"
                  :text-color="adj.adjustment_kind === 'debit_note' ? 'red-10' : 'green-10'"
                  class="text-weight-bold"
                >
                  {{ adjustmentKindLabel(adj.adjustment_kind) }}
                </q-badge>
                <span class="text-h6 text-weight-bold">{{ formatBdt(adj.amount) }}</span>
              </div>

              <div v-if="adj.detail_parts?.length" class="column q-gutter-y-xs">
                <div class="text-caption text-weight-medium text-grey-8">Charge changes</div>
                <ul class="q-ma-none q-pl-md text-body2">
                  <li v-for="(line, idx) in adj.detail_parts" :key="idx">{{ line }}</li>
                </ul>
              </div>

              <div class="text-caption text-grey-8">
                Bill net after note:
                <span class="text-weight-medium">{{ formatBdt(adj.current_net) }}</span>
                →
                <span class="text-weight-medium">{{ formatBdt(adj.wanted_net) }}</span>
              </div>

              <div class="text-caption text-grey-7">
                Note reason: {{ adj.reason }}
              </div>
            </q-card-section>
          </q-card>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps color="grey-7" label="Cancel" @click="onCancel" />
        <q-btn
          outline
          no-caps
          color="primary"
          :label="confirmLabel"
          class="text-weight-bold"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, withDefaults } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { DROPSHIP_TERM } from '../constants/dropshipTerminology';
import {
  type DropshipBillNoteAdjustmentPreview,
  type DropshipDeliverBillNotesPreview,
  listDropshipDeliverBillNoteAdjustments,
} from '../utils/dropshipDeliverBillNotesPreview';

export type DropshipPayInSettlementSummaryProps = {
  netAmount: number;
  courierCharge: number;
  invoiceAllocated: number;
  courierApSettled: number;
  merchantRemainder: number;
};

const props = withDefaults(
  defineProps<{
    preview: DropshipDeliverBillNotesPreview | null;
    orderNo?: string | null;
    title?: string;
    confirmLabel?: string;
    intro?: string | null;
    settlementSummary?: DropshipPayInSettlementSummaryProps | null;
  }>(),
  {
    title: 'Mark as delivered',
    confirmLabel: 'Mark delivered',
    intro: null,
    settlementSummary: null,
  },
);

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK, onDialogCancel } = useDialogPluginComponent();

const adjustments = computed(() => listDropshipDeliverBillNoteAdjustments(props.preview));

const hasAdjustments = computed(() => adjustments.value.length > 0);

const previewWarning = computed(() => {
  if (!props.preview?.success) {
    return 'Could not load bill note preview. You can still mark delivered if charges are correct.';
  }
  if (props.preview.skipped) {
    return 'No credit or debit notes will be added (customer invoice is not issued yet).';
  }
  return null;
});

function formatBdt(amount: number): string {
  return `৳${amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function adjustmentKindLabel(kind: 'debit_note' | 'credit_note'): string {
  return kind === 'debit_note' ? 'Debit note' : 'Credit note';
}

function billHeading(adj: DropshipBillNoteAdjustmentPreview): string {
  if (adj.label === 'courier_ap') return 'Courier payable bill (AP)';
  return `${DROPSHIP_TERM.customerInvoice} (AR)`;
}

function onConfirm() {
  onDialogOK();
}

function onCancel() {
  onDialogCancel();
}
</script>

<style scoped lang="scss">
.dropship-deliver-confirm__bill-card {
  border-radius: 8px;
}
</style>
