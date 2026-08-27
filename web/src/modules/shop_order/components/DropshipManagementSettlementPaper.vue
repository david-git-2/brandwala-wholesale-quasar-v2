<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import type { DropshipManagementOrderView } from '../types/dropshipManagementOrder';
import {
  buildSettlementDraftPayload,
  settlementToFormState,
} from '../utils/dropshipManagementOrderMapper';

const chargePayerOptions = [
  { label: 'Recipient pays', value: 'recipient' as const },
  { label: 'Merchant pays', value: 'merchant' as const },
  { label: 'Company pays', value: 'company' as const },
];

const props = defineProps<{
  data: DropshipManagementOrderView;
  readonly?: boolean;
}>();

type SettlementFormState = ReturnType<typeof settlementToFormState>;

const form = reactive<SettlementFormState>({
  totalCollectedCod: 0,
  delivery: { amount: 0, payer: 'recipient' },
  print: { amount: 0, payer: 'merchant' },
  packing: { amount: 0, payer: 'merchant' },
  returnCost: { amount: 0, payer: 'company' },
  returnReasonNote: '',
  discountCompanyPay: 0,
  resellerPurchaseCost: 0,
});

watch(
  () => props.data,
  (nextData) => {
    Object.assign(form, structuredClone(settlementToFormState(nextData.settlement)));
  },
  { immediate: true, deep: true },
);

const chargeRows: Array<{
  key: string;
  label: string;
  field: 'delivery' | 'print' | 'packing' | 'returnCost';
}> = [
  { key: 'delivery', label: 'Delivery', field: 'delivery' },
  { key: 'print', label: 'Print', field: 'print' },
  { key: 'packing', label: 'Packing', field: 'packing' },
  { key: 'return_cost', label: 'Return cost', field: 'returnCost' },
];

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

const chargeLines = computed(() => [form.delivery, form.print, form.packing, form.returnCost]);

const totalCost = computed(() =>
  form.resellerPurchaseCost + chargeLines.value.reduce((sum, line) => sum + Number(line.amount || 0), 0),
);

const merchantPaidCharges = computed(() =>
  chargeLines.value
    .filter((line) => line.payer === 'merchant')
    .reduce((sum, line) => sum + Number(line.amount || 0), 0),
);

const resellerProfit = computed(
  () => form.totalCollectedCod - form.resellerPurchaseCost - merchantPaidCharges.value,
);

const companyProfit = computed(() => resellerProfit.value - form.discountCompanyPay);

const statusLabel = computed(
  () => props.data.order.status.charAt(0).toUpperCase() + props.data.order.status.slice(1),
);

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

function getDraftPayload() {
  return buildSettlementDraftPayload(form);
}

defineExpose({ getDraftPayload });
</script>

<template>
  <article class="dropship-invoice-paper">
    <header class="dropship-invoice-paper__header">
      <div class="dropship-invoice-paper__brand">
        <div class="dropship-invoice-paper__doc-type">Dropship settlement</div>
        <div class="dropship-invoice-paper__order-no">{{ data.order.order_no }}</div>
        <div class="dropship-invoice-paper__merchant">{{ data.order.customer_group_name || '—' }}</div>
      </div>
      <div class="dropship-invoice-paper__meta">
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Date</span>
          <span>{{ orderDateLabel }}</span>
        </div>
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Status</span>
          <span class="text-capitalize">{{ statusLabel }}</span>
        </div>
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">AWB</span>
          <span>{{ data.order.courier_awb_number || '—' }}</span>
        </div>
      </div>
    </header>

    <div class="dropship-invoice-paper__divider" />

    <section class="dropship-invoice-paper__addresses dropship-invoice-paper__addresses--two-col">
      <div class="dropship-invoice-paper__address-block">
        <div class="dropship-invoice-paper__section-label">Deliver to</div>
        <div class="dropship-invoice-paper__recipient-name">{{ data.order.recipient_name || '—' }}</div>
        <div class="dropship-invoice-paper__line">{{ data.order.recipient_phone || '—' }}</div>
      </div>
      <div class="dropship-invoice-paper__address-block">
        <div class="dropship-invoice-paper__section-label">Courier</div>
        <div class="dropship-invoice-paper__recipient-name">{{ data.order.courier_name || '—' }}</div>
        <div class="dropship-invoice-paper__line">Tracking: {{ data.order.courier_awb_number || '—' }}</div>
      </div>
    </section>

    <div class="dropship-invoice-paper__divider" />

    <section
      class="dropship-invoice-paper__summary dropship-invoice-paper__summary--editable dropship-mgmt-settlement-paper__summary"
    >
      <div class="dropship-invoice-paper__section-label q-mb-sm">Cost breakdown</div>
      <div class="dropship-invoice-paper__summary-grid">
        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Total calculated COD</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-medium">{{ formatMoney(calculatedCod) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--editable">
          <div class="dropship-invoice-paper__summary-label">
            <span>Total collected COD</span>
            <span
              v-if="codVarianceLabel"
              class="dropship-mgmt-settlement-paper__variance"
              :class="codVariance < 0 ? 'text-negative' : 'text-warning'"
            >
              {{ codVarianceLabel }}
            </span>
          </div>
          <q-input
            v-model.number="form.totalCollectedCod"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            :disable="readonly"
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
          />
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Recipient pays</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--recipient">
              Recipient pays
            </span>
          </div>
          <span>{{ formatMoney(recipientPay) }}</span>
        </div>

        <div
          v-for="chargeRow in chargeRows"
          :key="chargeRow.key"
          class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--editable"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>{{ chargeRow.label }}</span>
            <q-btn-toggle
              v-model="form[chargeRow.field].payer"
              dense
              no-caps
              unelevated
              toggle-color="primary"
              color="grey-3"
              text-color="grey-8"
              class="dropship-invoice-paper__payer-toggle"
              :disable="readonly"
              :options="chargePayerOptions"
            />
          </div>
          <q-input
            v-model.number="form[chargeRow.field].amount"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            :disable="readonly"
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
          />
        </div>

        <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--editable dropship-mgmt-settlement-paper__note-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Return reason note</span>
          </div>
          <q-input
            v-model="form.returnReasonNote"
            type="textarea"
            autogrow
            dense
            outlined
            hide-bottom-space
            :disable="readonly"
            placeholder="Why was return cost applied?"
            class="dropship-invoice-paper__field-input dropship-mgmt-settlement-paper__note-input"
          />
        </div>

        <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--editable">
          <div class="dropship-invoice-paper__summary-label">
            <span>Discount (company pay)</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--company">
              Deduct from company profit
            </span>
          </div>
          <q-input
            v-model.number="form.discountCompanyPay"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            :disable="readonly"
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
          />
        </div>

        <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--editable">
          <div class="dropship-invoice-paper__summary-label">
            <span>Reseller purchase cost</span>
          </div>
          <q-input
            v-model.number="form.resellerPurchaseCost"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            :disable="readonly"
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
          />
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Reseller profit</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-bold text-primary">{{ formatMoney(resellerProfit) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Total cost</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-bold">{{ formatMoney(totalCost) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--grand">
          <div class="dropship-invoice-paper__summary-label">
            <span>Company profit</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-bold text-positive">{{ formatMoney(companyProfit) }}</span>
        </div>
      </div>
    </section>
  </article>
</template>

<style scoped>
.dropship-invoice-paper {
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  padding: 1.5rem 1.75rem 1.75rem;
  background: #fffdf8;
  color: #1f2937;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 2px;
  box-shadow:
    0 1px 2px rgba(15, 23, 42, 0.06),
    0 12px 28px rgba(15, 23, 42, 0.08);
  font-family: Georgia, 'Times New Roman', Times, serif;
}

.dropship-invoice-paper__header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
}

.dropship-invoice-paper__doc-type {
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #6b7280;
}

.dropship-invoice-paper__order-no {
  margin-top: 0.25rem;
  font-size: 1.45rem;
  font-weight: 700;
  line-height: 1.2;
  color: #111827;
}

.dropship-invoice-paper__merchant {
  margin-top: 0.35rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.85rem;
  color: #4b5563;
}

.dropship-invoice-paper__meta {
  min-width: 160px;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.78rem;
}

.dropship-invoice-paper__meta-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.15rem 0;
}

.dropship-invoice-paper__meta-label {
  color: #6b7280;
  font-weight: 600;
}

.dropship-invoice-paper__divider {
  margin: 1rem 0;
  border-top: 1px dashed rgba(15, 23, 42, 0.18);
}

.dropship-invoice-paper__section-label {
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #6b7280;
}

.dropship-invoice-paper__addresses--two-col {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1.5rem;
}

.dropship-invoice-paper__recipient-name {
  margin-top: 0.35rem;
  font-size: 1.05rem;
  font-weight: 700;
  color: #111827;
}

.dropship-invoice-paper__line {
  margin-top: 0.2rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.82rem;
  color: #374151;
}

.dropship-invoice-paper__paid-by {
  display: inline-block;
  margin-top: 0.15rem;
  font-size: 0.62rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.dropship-invoice-paper__paid-by--recipient {
  color: #1d4ed8;
}

.dropship-invoice-paper__paid-by--merchant {
  color: #b45309;
}

.dropship-invoice-paper__paid-by--company {
  color: #047857;
}

.dropship-invoice-paper__paid-by--muted {
  color: #6b7280;
  text-transform: none;
  font-weight: 500;
  font-size: 0.65rem;
}

.dropship-mgmt-settlement-paper__variance {
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: none;
  letter-spacing: normal;
}

.dropship-invoice-paper__summary {
  display: flex;
  flex-direction: column;
  align-items: stretch;
}

.dropship-mgmt-settlement-paper__summary {
  width: 100%;
}

.dropship-invoice-paper__summary-grid {
  width: 100%;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.8rem;
}

.dropship-invoice-paper__summary-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  padding: 0.25rem 0;
  color: #374151;
}

.dropship-invoice-paper__summary-row--editable {
  align-items: center;
}

.dropship-invoice-paper__summary-label {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  min-width: 0;
}

.dropship-invoice-paper__summary-row--grand {
  margin-top: 0.35rem;
  padding-top: 0.45rem;
  border-top: 1px solid rgba(15, 23, 42, 0.14);
  font-size: 0.92rem;
  font-weight: 700;
  color: #111827;
}

.dropship-invoice-paper__amount-input {
  width: 10rem;
  flex: 0 0 auto;
  font-family: ui-sans-serif, system-ui, sans-serif;
}

.dropship-invoice-paper__amount-input :deep(.q-field__control) {
  min-height: 32px;
}

.dropship-invoice-paper__field-input {
  width: 10rem;
  flex: 0 0 auto;
  font-family: ui-sans-serif, system-ui, sans-serif;
}

.dropship-invoice-paper__field-input :deep(.q-field__control) {
  min-height: 34px;
  background: rgba(255, 255, 255, 0.72);
}

.dropship-mgmt-settlement-paper__note-row {
  align-items: flex-start;
}

.dropship-mgmt-settlement-paper__note-input {
  width: min(100%, 24rem);
}

.dropship-invoice-paper__payer-toggle {
  margin-top: 0.15rem;
  font-size: 0.58rem;
}

.dropship-invoice-paper__payer-toggle :deep(.q-btn) {
  min-height: 1.35rem;
  padding: 0 0.35rem;
  font-size: 0.58rem;
  font-weight: 600;
  letter-spacing: 0.01em;
}

@media (max-width: 767px) {
  .dropship-invoice-paper {
    padding: 1rem;
  }

  .dropship-invoice-paper__addresses--two-col {
    grid-template-columns: 1fr;
  }

  .dropship-invoice-paper__summary-grid {
    width: 100%;
  }
}
</style>

<script lang="ts">
export default {
  name: 'DropshipManagementSettlementPaper',
};
</script>
