<template>
  <q-card flat bordered class="remittance-header-card">
    <q-card-section class="q-pb-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="text-subtitle1 text-weight-bold text-primary flex items-center gap-2">
          <q-icon name="payments" size="20px" />
          <span>Statement & Bank Details</span>
        </div>
        <div v-if="readOnly" class="badge-readonly">
          <q-chip color="grey-3" text-color="grey-8" dense icon="lock" size="sm">
            Read-Only Batch
          </q-chip>
        </div>
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="q-pt-md">
      <div class="row q-col-gutter-md">
        <!-- Courier Service Dropdown -->
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-select
            :model-value="courierServiceId"
            :options="courierOptions"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            outlined
            dense
            label="Courier Service *"
            placeholder="Select Courier"
            :disable="readOnly || disableCourierSelect"
            :rules="[(val) => !!val || 'Courier service is required']"
            @update:model-value="onUpdateCourierService"
          >
            <template #prepend>
              <q-icon name="local_shipping" size="18px" />
            </template>
          </q-select>
        </div>

        <!-- Statement ID / Batch No -->
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-input
            :model-value="batchNo"
            outlined
            dense
            label="Statement ID / Batch No *"
            placeholder="e.g. PATHAO-REMIT-2026-001"
            :readonly="readOnly"
            :rules="[(val) => !!val || 'Statement ID is required']"
            @update:model-value="$emit('update:batchNo', String($event ?? ''))"
          >
            <template #prepend>
              <q-icon name="tag" size="18px" />
            </template>
          </q-input>
        </div>

        <!-- Bank TRX ID -->
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-input
            :model-value="bankTrxId"
            outlined
            dense
            label="Bank TRX ID / Ref"
            placeholder="e.g. TRX-99384721"
            :readonly="readOnly"
            @update:model-value="$emit('update:bankTrxId', String($event ?? ''))"
          >
            <template #prepend>
              <q-icon name="account_balance" size="18px" />
            </template>
          </q-input>
        </div>

        <!-- Payment Date -->
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-input
            :model-value="paymentDate"
            type="date"
            outlined
            dense
            label="Payment Date *"
            :readonly="readOnly"
            :rules="[(val) => !!val || 'Payment date is required']"
            @update:model-value="$emit('update:paymentDate', String($event ?? ''))"
          >
            <template #prepend>
              <q-icon name="event" size="18px" />
            </template>
          </q-input>
        </div>

        <!-- Total Bank Deposit Net -->
        <div class="col-xs-12 col-sm-6 col-md-4">
          <q-input
            :model-value="netDepositedAmount"
            type="number"
            step="0.01"
            outlined
            dense
            label="Bank Net Deposit (৳) *"
            placeholder="0.00"
            :readonly="readOnly"
            :rules="[
              (val) => val !== null && val !== '' || 'Deposit amount is required',
              (val) => Number(val) >= 0 || 'Must be non-negative',
            ]"
            @update:model-value="$emit('update:netDepositedAmount', Number($event))"
          >
            <template #prepend>
              <q-icon name="attach_money" size="18px" />
            </template>
          </q-input>
        </div>

        <!-- Gross COD (Optional override or statement value) -->
        <div class="col-xs-12 col-sm-6 col-md-2">
          <q-input
            :model-value="grossCodAmount"
            type="number"
            step="0.01"
            outlined
            dense
            label="Gross COD (৳)"
            placeholder="0.00"
            :readonly="readOnly"
            @update:model-value="$emit('update:grossCodAmount', Number($event))"
          />
        </div>

        <!-- Courier Charges (Optional override) -->
        <div class="col-xs-12 col-sm-6 col-md-2">
          <q-input
            :model-value="courierChargesAmount"
            type="number"
            step="0.01"
            outlined
            dense
            label="Courier Fees (৳)"
            placeholder="0.00"
            :readonly="readOnly"
            @update:model-value="$emit('update:courierChargesAmount', Number($event))"
          />
        </div>
      </div>

      <!-- Note / Remarks field -->
      <div class="row q-mt-xs">
        <div class="col-12">
          <q-input
            :model-value="note"
            outlined
            dense
            rows="2"
            type="textarea"
            label="Notes / Remarks"
            placeholder="Optional internal notes about this remittance batch..."
            :readonly="readOnly"
            @update:model-value="$emit('update:note', String($event ?? ''))"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';

defineProps<{
  courierServiceId: string | null;
  batchNo: string;
  bankTrxId: string;
  paymentDate: string;
  netDepositedAmount: number;
  grossCodAmount: number;
  courierChargesAmount: number;
  note: string;
  courierOptions: CourierServiceRow[];
  readOnly?: boolean;
  disableCourierSelect?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:courierServiceId', value: string | null): void;
  (e: 'update:batchNo', value: string): void;
  (e: 'update:bankTrxId', value: string): void;
  (e: 'update:paymentDate', value: string): void;
  (e: 'update:netDepositedAmount', value: number): void;
  (e: 'update:grossCodAmount', value: number): void;
  (e: 'update:courierChargesAmount', value: number): void;
  (e: 'update:note', value: string): void;
}>();

function onUpdateCourierService(val: any) {
  emit('update:courierServiceId', (val as string | null) ?? null);
}
</script>

<style scoped lang="scss">
.remittance-header-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  border: 1px solid var(--bw-theme-border);
}
</style>
