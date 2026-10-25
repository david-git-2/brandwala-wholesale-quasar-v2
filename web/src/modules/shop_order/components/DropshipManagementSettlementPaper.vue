<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import type { DropshipManagementOrderView, DropshipSettlementDraftPayload } from '../types/dropshipManagementOrder';
import {
  buildSettlementDraftPayload,
  getChargeLineAmount,
  settlementToFormState,
  type DropshipSettlementFormState,
} from '../utils/dropshipManagementOrderMapper';
import type { DropshipSettlementChargePayer } from '../types/dropshipManagementOrder';
import { DROPSHIP_TERM } from '../constants/dropshipTerminology';

const props = withDefaults(
  defineProps<{
    data: DropshipManagementOrderView;
    readonly?: boolean;
    returnSectionMode?: 'hidden' | 'readonly';
  }>(),
  {
    readonly: false,
    returnSectionMode: 'hidden',
  },
);

const emit = defineEmits<{
  'dirty-change': [dirty: boolean];
}>();

type SettlementFormState = DropshipSettlementFormState;

const form = reactive<SettlementFormState>({
  totalCollectedCod: 0,
  delivery: { amount: 0, payer: 'recipient' },
  print: { amount: 0, payer: 'merchant' },
  packing: { amount: 0, payer: 'merchant' },
  returnCost: { amount: 0, payer: 'company' },
  codCharge: { amount: 0, payer: 'merchant' },
  returnReasonNote: '',
  discountCompanyPay: 0,
});

const itemQuantity = computed(() => Math.max(0, props.data.computed.order_item_quantity));

const giftCostMerchantTotal = computed(() => props.data.settlement.gift_cost_merchant_total);
const giftCostTenantTotal = computed(() => props.data.settlement.gift_cost_tenant_total);

const resellerPurchaseCost = computed(() => props.data.settlement.reseller_purchase_cost);

let savedPayloadJson = '';

function snapshotPayload(payload: DropshipSettlementDraftPayload): string {
  return JSON.stringify(payload);
}

function syncSavedBaselineFromSettlement(settlement: DropshipManagementOrderView['settlement']) {
  savedPayloadJson = snapshotPayload(buildSettlementDraftPayload(settlementToFormState(settlement)));
}

watch(
  () => props.data,
  (nextData) => {
    Object.assign(form, structuredClone(settlementToFormState(nextData.settlement)));
    syncSavedBaselineFromSettlement(nextData.settlement);
  },
  { immediate: true, deep: true },
);

const isDirty = computed(() => {
  if (props.readonly) return false;
  return snapshotPayload(buildSettlementDraftPayload(form)) !== savedPayloadJson;
});

watch(
  isDirty,
  (dirty) => {
    emit('dirty-change', dirty);
  },
  { immediate: true },
);

const standardChargeRows: Array<{
  key: string;
  label: string;
  field: 'codCharge' | 'delivery' | 'print' | 'packing';
}> = [
  { key: 'cod', label: 'Courier COD fee', field: 'codCharge' },
  { key: 'delivery', label: 'Delivery', field: 'delivery' },
  { key: 'print', label: 'Print', field: 'print' },
  { key: 'packing', label: 'Packing', field: 'packing' },
];

const returnChargeRow = {
  key: 'return_cost',
  label: 'Return cost',
  field: 'returnCost' as const,
};

const calculatedCod = computed(() => props.data.settlement.calculated_cod_amount);

const recipientPay = computed(() => props.data.computed.items_resell_total);

const codVariance = computed(() => form.totalCollectedCod - calculatedCod.value);

const codVarianceLabel = computed(() => {
  const diff = Math.abs(codVariance.value);
  if (codVariance.value < 0) {
    return `Collected ৳${diff.toLocaleString()} less than calculated COD.`;
  }
  if (codVariance.value > 0) {
    return `Collected ৳${diff.toLocaleString()} more than calculated COD.`;
  }
  return null;
});

const chargeLines = computed(() => {
  const lines = [form.codCharge, form.delivery, form.print, form.packing];
  if (props.returnSectionMode !== 'hidden') {
    lines.push(form.returnCost);
  }
  return lines;
});

const readonlyReturnChargeAmount = computed(() =>
  props.data.order.return_charge_amount
  || getChargeLineAmount(props.data.settlement.charge_lines, 'return').amount,
);

const readonlyReturnPayer = computed((): DropshipSettlementChargePayer => {
  const line = getChargeLineAmount(props.data.settlement.charge_lines, 'return');
  if (line.amount > 0) return line.payer;
  if (props.data.order.deduct_return_charge_from_middle_man) return 'merchant';
  return 'company';
});

function payerRoleLabel(payer: DropshipSettlementChargePayer): string {
  switch (payer) {
    case 'recipient':
      return DROPSHIP_TERM.endCustomer;
    case 'merchant':
      return DROPSHIP_TERM.dropshipper;
    case 'company':
      return DROPSHIP_TERM.supplier;
    default:
      return payer;
  }
}

const companyProcurementCost = computed(() => props.data.settlement.company_procurement_cost);

const chargeTotal = computed(() =>
  chargeLines.value.reduce((sum, line) => sum + Number(line.amount || 0), 0),
);

const totalCost = computed(() => companyProcurementCost.value + chargeTotal.value);

const orderDiscountAmount = computed(() => props.data.order.discount_amount);

const merchantPaidCharges = computed(() =>
  chargeLines.value
    .filter((line) => line.payer === 'merchant')
    .reduce((sum, line) => sum + Number(line.amount || 0), 0),
);

const resellerProfit = computed(
  () =>
    recipientPay.value
    - orderDiscountAmount.value
    - resellerPurchaseCost.value
    - merchantPaidCharges.value
    - giftCostMerchantTotal.value,
);

const companyProfit = computed(
  () =>
    resellerPurchaseCost.value
    - companyProcurementCost.value
    - form.discountCompanyPay
    - giftCostTenantTotal.value,
);

const showCreditedProfit = computed(
  () =>
    props.data.order.status === 'payment_received'
    && props.data.settlement.dropship_profit_credited > 0,
);

const dropshipProfitCredited = computed(() => props.data.settlement.dropship_profit_credited);

const courierRows = computed(() => [
  { label: 'Delivery zone', value: props.data.courier.delivery_zone_label || '—' },
  { label: 'AWB / consignment', value: props.data.courier.courier_awb_number || '—' },
]);

const orderDateLabel = computed(() => {
  const d = new Date(props.data.order.created_at);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
});

function formatMoney(amount: number): string {
  return `৳${Number(amount || 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function formatDate(value: string | null): string {
  if (!value) return '—';
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

function getDraftPayload() {
  return buildSettlementDraftPayload(form);
}

defineExpose({ getDraftPayload, isDirty });
</script>

<template>
  <article class="dropship-invoice-paper dropship-magazine-spread">
    <header class="dropship-invoice-paper__header">
      <div class="dropship-invoice-paper__brand">
        <div class="dropship-invoice-paper__doc-type">Dropship settlement recap</div>
        <div class="dropship-invoice-paper__order-no">{{ data.order.order_no }}</div>
        <div v-if="data.order.customer_group_name" class="dropship-invoice-paper__merchant">
          <q-icon name="ph ph-users" size="14px" class="q-mr-xs text-grey-6" />
          {{ data.order.customer_group_name }}
        </div>
      </div>
      <div class="dropship-invoice-paper__meta">
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Date</span>
          <span class="text-weight-bold">{{ orderDateLabel }}</span>
        </div>
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Status</span>
          <q-badge color="primary" class="text-capitalize text-weight-bold">
            {{ data.order.status.replace(/_/g, ' ') }}
          </q-badge>
        </div>
        <div v-if="data.invoice" class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">{{ DROPSHIP_TERM.customerInvoice }}</span>
          <span class="text-weight-medium">
            {{ data.invoice.invoice_no }} ·
            {{
              data.invoice.payment_status === 'paid' && Number(data.invoice.due_amount) <= 0
                ? 'Paid'
                : `Due ${formatMoney(data.invoice.due_amount)}`
            }}
          </span>
        </div>
      </div>
    </header>

    <div class="dropship-invoice-paper__divider" />

    <section class="dropship-mgmt-settlement-paper__cost-block">
      <div class="dropship-invoice-paper__section-label q-mb-sm">
        <q-icon name="ph ph-receipt" size="14px" />
        <span>Charges &amp; settlement</span>
      </div>

      <table class="dropship-mgmt-settlement-paper__table">
        <thead>
          <tr>
            <th scope="col">Charge</th>
            <th scope="col">Paid by</th>
            <th scope="col" class="dropship-mgmt-settlement-paper__amount-col">Amount</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Calculated COD</td>
            <td class="text-grey-7">—</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-medium">
              {{ formatMoney(calculatedCod) }}
            </td>
          </tr>
          <tr>
            <td>
              <span>Collected COD</span>
              <div
                v-if="codVarianceLabel && !readonly"
                class="dropship-mgmt-settlement-paper__variance"
                :class="codVariance < 0 ? 'text-negative' : 'text-warning'"
              >
                {{ codVarianceLabel }}
              </div>
            </td>
            <td class="text-grey-7">—</td>
            <td class="dropship-mgmt-settlement-paper__amount-col">
              <span v-if="readonly" class="text-weight-medium">{{ formatMoney(form.totalCollectedCod) }}</span>
              <q-input
                v-else
                v-model.number="form.totalCollectedCod"
                type="number"
                min="0"
                step="0.01"
                dense
                outlined
                hide-bottom-space
                class="dropship-mgmt-settlement-paper__amount-input"
                input-class="text-right"
              />
            </td>
          </tr>
          <tr>
            <td>Merchandise (resell)</td>
            <td>{{ DROPSHIP_TERM.endCustomer }}</td>
            <td class="dropship-mgmt-settlement-paper__amount-col">{{ formatMoney(recipientPay) }}</td>
          </tr>

          <tr v-for="chargeRow in standardChargeRows" :key="chargeRow.key">
            <td>{{ chargeRow.label }}</td>
            <td>{{ payerRoleLabel(form[chargeRow.field].payer) }}</td>
            <td class="dropship-mgmt-settlement-paper__amount-col">
              <span v-if="readonly" class="text-weight-medium">{{ formatMoney(form[chargeRow.field].amount) }}</span>
              <q-input
                v-else
                v-model.number="form[chargeRow.field].amount"
                type="number"
                min="0"
                step="0.01"
                dense
                outlined
                hide-bottom-space
                class="dropship-mgmt-settlement-paper__amount-input"
                input-class="text-right"
              />
            </td>
          </tr>

          <tr>
            <td>Discount (supplier absorbs)</td>
            <td>{{ DROPSHIP_TERM.supplier }}</td>
            <td class="dropship-mgmt-settlement-paper__amount-col">
              <span v-if="readonly" class="text-weight-medium">{{ formatMoney(form.discountCompanyPay) }}</span>
              <q-input
                v-else
                v-model.number="form.discountCompanyPay"
                type="number"
                min="0"
                step="0.01"
                dense
                outlined
                hide-bottom-space
                class="dropship-mgmt-settlement-paper__amount-input"
                input-class="text-right"
              />
            </td>
          </tr>

          <tr>
            <td>
              Dropshipper purchase
              <span v-if="itemQuantity > 0" class="text-grey-7 text-caption q-ml-xs">
                ({{ itemQuantity }} units)
              </span>
            </td>
            <td class="text-grey-7">—</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-medium">
              {{ formatMoney(resellerPurchaseCost) }}
            </td>
          </tr>

          <tr v-if="giftCostMerchantTotal > 0">
            <td>Warehouse gift</td>
            <td>{{ DROPSHIP_TERM.dropshipper }} · {{ DROPSHIP_TERM.customerInvoice }}</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-medium">
              {{ formatMoney(giftCostMerchantTotal) }}
            </td>
          </tr>

          <tr v-if="giftCostTenantTotal > 0">
            <td>Warehouse gift</td>
            <td>{{ DROPSHIP_TERM.supplier }}</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-medium">
              {{ formatMoney(giftCostTenantTotal) }}
            </td>
          </tr>

          <tr>
            <td>Supplier procurement</td>
            <td class="text-grey-7">—</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-medium">
              {{ formatMoney(companyProcurementCost) }}
            </td>
          </tr>

          <template v-if="returnSectionMode !== 'hidden'">
            <tr class="dropship-mgmt-settlement-paper__section-row">
              <td colspan="3">Return — {{ DROPSHIP_TERM.endCustomer }} refused parcel</td>
            </tr>
            <template v-if="returnSectionMode === 'readonly'">
              <tr v-if="data.order.returned_at">
                <td>Returned at</td>
                <td class="text-grey-7">—</td>
                <td class="dropship-mgmt-settlement-paper__amount-col">{{ formatDate(data.order.returned_at) }}</td>
              </tr>
              <tr>
                <td>{{ returnChargeRow.label }}</td>
                <td>{{ payerRoleLabel(readonlyReturnPayer) }}</td>
                <td class="dropship-mgmt-settlement-paper__amount-col text-weight-medium">
                  {{ formatMoney(readonlyReturnChargeAmount) }}
                </td>
              </tr>
              <tr v-if="data.order.deduct_return_charge_from_middle_man">
                <td>{{ DROPSHIP_TERM.dropshipperBalance }} debit</td>
                <td>{{ DROPSHIP_TERM.dropshipper }}</td>
                <td class="dropship-mgmt-settlement-paper__amount-col text-negative text-weight-medium">Yes</td>
              </tr>
              <tr>
                <td>Return reason</td>
                <td colspan="2">{{ data.settlement.return_reason_note || '—' }}</td>
              </tr>
            </template>
            <template v-else>
              <tr>
                <td>{{ returnChargeRow.label }}</td>
                <td>{{ payerRoleLabel(form[returnChargeRow.field].payer) }}</td>
                <td class="dropship-mgmt-settlement-paper__amount-col">
                  <q-input
                    v-model.number="form[returnChargeRow.field].amount"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    hide-bottom-space
                    :disable="readonly"
                    class="dropship-mgmt-settlement-paper__amount-input"
                    input-class="text-right"
                  />
                </td>
              </tr>
              <tr>
                <td>Return reason</td>
                <td colspan="2">
                  <q-input
                    v-model="form.returnReasonNote"
                    type="textarea"
                    autogrow
                    dense
                    outlined
                    hide-bottom-space
                    :disable="readonly"
                    placeholder="Why was return cost applied?"
                    class="dropship-mgmt-settlement-paper__note-input"
                  />
                </td>
              </tr>
            </template>
          </template>
        </tbody>
        <tfoot>
          <tr
            v-if="showCreditedProfit"
            class="dropship-mgmt-settlement-paper__total-row dropship-mgmt-settlement-paper__total-row--grand"
          >
            <td>Credited to dropshipper wallet</td>
            <td class="text-grey-7 text-caption">
              Net remittance minus customer B2B invoice cleared
            </td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-bold text-positive">
              {{ formatMoney(dropshipProfitCredited) }}
            </td>
          </tr>
          <tr class="dropship-mgmt-settlement-paper__total-row">
            <td>
              {{ showCreditedProfit ? 'COD margin (settlement paper)' : DROPSHIP_TERM.dropshipperProfit }}
            </td>
            <td class="text-grey-7">—</td>
            <td
              class="dropship-mgmt-settlement-paper__amount-col text-weight-bold"
              :class="showCreditedProfit ? 'text-grey-8' : 'text-primary'"
            >
              {{ formatMoney(resellerProfit) }}
            </td>
          </tr>
          <tr class="dropship-mgmt-settlement-paper__total-row">
            <td>Total cost</td>
            <td class="text-grey-7">Procurement + charges</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-bold">
              {{ formatMoney(totalCost) }}
            </td>
          </tr>
          <tr class="dropship-mgmt-settlement-paper__total-row dropship-mgmt-settlement-paper__total-row--grand">
            <td>Supplier profit</td>
            <td class="text-grey-7">—</td>
            <td class="dropship-mgmt-settlement-paper__amount-col text-weight-bold text-positive">
              {{ formatMoney(companyProfit) }}
            </td>
          </tr>
        </tfoot>
      </table>
    </section>

    <div class="dropship-invoice-paper__divider" />

    <section class="dropship-mgmt-settlement-paper__courier-section">
      <div class="dropship-mgmt-settlement-paper__courier-header">
        <div class="dropship-invoice-paper__section-label">Courier</div>
        <q-btn
          v-if="data.courier.tracking_url"
          flat
          dense
          no-caps
          color="primary"
          icon="ph ph-arrow-square-out"
          label="Track parcel"
          type="a"
          :href="data.courier.tracking_url"
          target="_blank"
          rel="noopener noreferrer"
          class="dropship-mgmt-settlement-paper__track-btn"
        />
      </div>

      <div class="dropship-invoice-paper__recipient-name q-mt-sm">
        {{ data.courier.courier_name || 'Not assigned' }}
      </div>

      <div class="dropship-mgmt-settlement-paper__courier-grid q-mt-sm">
        <div
          v-for="row in courierRows"
          :key="row.label"
          class="dropship-mgmt-settlement-paper__courier-row"
        >
          <div class="dropship-invoice-paper__meta-label">{{ row.label }}</div>
          <div class="dropship-invoice-paper__line">{{ row.value }}</div>
        </div>
      </div>
    </section>
  </article>
</template>

<style scoped lang="scss">
@import '../styles/dropship-invoice-paper.scss';

.dropship-mgmt-settlement-paper__cost-block {
  width: 100%;
  margin-top: 0.25rem;
}

.dropship-mgmt-settlement-paper__table {
  width: 100%;
  max-width: 42rem;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.dropship-mgmt-settlement-paper__table th {
  padding: 0.5rem 0.65rem;
  font-size: 0.62rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--tf-neutral-secondary, #64748b);
  text-align: left;
  border-bottom: 2px solid var(--tf-theme-border, #e2e8f0);
}

.dropship-mgmt-settlement-paper__table td {
  padding: 0.5rem 0.65rem;
  vertical-align: middle;
  border-bottom: 1px solid color-mix(in srgb, var(--tf-theme-border, #e2e8f0) 55%, transparent);
}

.dropship-mgmt-settlement-paper__amount-col {
  text-align: right;
  white-space: nowrap;
  width: 8.5rem;
}

.dropship-mgmt-settlement-paper__amount-input {
  width: 7.5rem;
  margin-left: auto;
}

.dropship-mgmt-settlement-paper__section-row td {
  padding-top: 0.85rem;
  font-size: 0.62rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #b91c1c;
  border-bottom-color: color-mix(in srgb, #dc2626 35%, transparent);
}

.dropship-mgmt-settlement-paper__total-row td {
  border-bottom: none;
  padding-top: 0.55rem;
}

.dropship-mgmt-settlement-paper__table tfoot tr:first-child td {
  border-top: 2px solid var(--tf-theme-border, #e2e8f0);
  padding-top: 0.75rem;
}

.dropship-mgmt-settlement-paper__total-row--grand td {
  padding-bottom: 0.25rem;
}

.dropship-mgmt-settlement-paper__variance {
  margin-top: 0.2rem;
  font-size: 0.65rem;
  font-weight: 600;
  line-height: 1.25;
}

.dropship-mgmt-settlement-paper__note-input {
  width: 100%;
  max-width: 24rem;
}

.dropship-mgmt-settlement-paper__courier-section {
  width: 100%;
}

.dropship-mgmt-settlement-paper__courier-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.dropship-mgmt-settlement-paper__courier-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem 1.5rem;
}

.dropship-mgmt-settlement-paper__courier-row {
  min-width: 0;
}

@media (max-width: 767px) {
  .dropship-mgmt-settlement-paper__courier-grid {
    grid-template-columns: 1fr;
  }
}
</style>

<script lang="ts">
export default {
  name: 'DropshipManagementSettlementPaper',
};
</script>
