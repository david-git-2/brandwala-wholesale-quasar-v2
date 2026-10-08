<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';
import type { DropshipManagementOrderView } from '../types/dropshipManagementOrder';
import {
  buildSettlementDraftPayload,
  getChargeLineAmount,
  settlementToFormState,
  type DropshipSettlementFormState,
} from '../utils/dropshipManagementOrderMapper';
import type { DropshipSettlementChargePayer } from '../types/dropshipManagementOrder';

const chargePayerOptions = [
  { label: 'Recipient pays', value: 'recipient' as const },
  { label: 'Merchant pays', value: 'merchant' as const },
  { label: 'Company pays', value: 'company' as const },
];

const chargePayerToggleOptions = [
  { label: 'Recipient', value: 'recipient' as const },
  { label: 'Merchant', value: 'merchant' as const },
  { label: 'Company', value: 'company' as const },
];

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

const orderItemRows = computed(() =>
  props.data.items.map((item) => {
    const isWarehouseGift = item.is_gift && item.gift_source === 'stock';
    const resell = isWarehouseGift ? 0 : (item.customer_sell_price_amount ?? 0);
    const qty = Math.max(item.quantity, 0);
    const giftCost = isWarehouseGift ? (item.gift_cost_amount ?? 0) : 0;
    return {
      id: item.id,
      name: item.name,
      quantity: qty,
      resell,
      lineResell: resell * qty,
      imageUrl: item.image_url,
      productCode: item.product_code,
      isWarehouseGift,
      giftCost,
      giftChargedTo: item.gift_cost_charged_to,
    };
  }),
);

const giftCostMerchantTotal = computed(() => props.data.settlement.gift_cost_merchant_total);
const giftCostTenantTotal = computed(() => props.data.settlement.gift_cost_tenant_total);

const resellerPurchaseCost = computed(() => props.data.settlement.reseller_purchase_cost);

watch(
  () => props.data,
  (nextData) => {
    Object.assign(form, structuredClone(settlementToFormState(nextData.settlement)));
  },
  { immediate: true, deep: true },
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

const formatPayerLabel = (payer: DropshipSettlementChargePayer) =>
  chargePayerOptions.find((o) => o.value === payer)?.label ?? payer;

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

function num(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function getDraftPayload() {
  return buildSettlementDraftPayload(form);
}

defineExpose({ getDraftPayload });
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
          <span class="dropship-invoice-paper__meta-label">Merchant bill</span>
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

    <section class="dropship-invoice-paper__addresses">
      <div class="dropship-invoice-paper__address-block">
        <div class="dropship-invoice-paper__section-label">Deliver to</div>
        <div class="dropship-invoice-paper__recipient-name">{{ data.order.recipient_name || '—' }}</div>
        <div class="dropship-invoice-paper__line">{{ data.order.recipient_phone || '—' }}</div>
      </div>
    </section>

    <div class="dropship-invoice-paper__divider" />

    <section v-if="orderItemRows.length > 0" class="dropship-mgmt-settlement-paper__items">
      <div class="dropship-invoice-paper__section-label q-mb-sm">Ordered items</div>
      <div class="dropship-mgmt-settlement-paper__items-list">
        <div
          v-for="item in orderItemRows"
          :key="item.id"
          class="dropship-mgmt-settlement-paper__item-row"
        >
          <div class="dropship-mgmt-settlement-paper__item-thumb">
            <SmartImage
              :src="item.imageUrl"
              :alt="item.name"
              img-class="dropship-mgmt-settlement-paper__item-thumb-img"
              fallback-class="dropship-mgmt-settlement-paper__item-thumb-fallback"
            />
          </div>
          <div class="dropship-mgmt-settlement-paper__item-body">
            <div class="dropship-invoice-paper__recipient-name">
              {{ item.name }}
              <q-badge
                v-if="item.isWarehouseGift"
                color="secondary"
                class="q-ml-xs text-weight-bold"
                label="Gift"
              />
            </div>
            <div v-if="item.productCode" class="dropship-invoice-paper__line text-grey-7">
              Code {{ item.productCode }}
            </div>
            <div v-if="item.isWarehouseGift" class="dropship-invoice-paper__line text-grey-7">
              Qty {{ item.quantity }}
              <template v-if="item.giftCost > 0">
                · Gift cost {{ formatMoney(item.giftCost) }}
                <span v-if="item.giftChargedTo === 'reseller'">· Merchant bill</span>
                <span v-else-if="item.giftChargedTo === 'tenant'">· Company</span>
              </template>
            </div>
            <div v-else class="dropship-invoice-paper__line text-grey-7">
              Qty {{ item.quantity }} · Resell {{ formatMoney(item.resell) }} · Line
              {{ formatMoney(item.lineResell) }}
            </div>
          </div>
        </div>
      </div>
    </section>

    <div v-if="orderItemRows.length > 0" class="dropship-invoice-paper__divider" />

    <section class="dropship-mgmt-settlement-paper__cost-block">
      <div class="dropship-invoice-paper__summary-grid dropship-mgmt-settlement-paper__summary-grid">
        <div class="dropship-invoice-paper__section-label q-mb-md">
          <q-icon name="ph ph-receipt" size="14px" />
          <span>Cost breakdown</span>
        </div>
        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Total calculated COD</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-medium">{{ formatMoney(calculatedCod) }}</span>
        </div>

        <div
          class="dropship-invoice-paper__summary-row"
          :class="{ 'dropship-invoice-paper__summary-row--editable': !readonly }"
        >
          <div class="dropship-invoice-paper__summary-label dropship-mgmt-settlement-paper__charge-label">
            <span>Total collected COD</span>
            <span
              v-if="codVarianceLabel && !readonly"
              class="dropship-mgmt-settlement-paper__variance"
              :class="codVariance < 0 ? 'text-negative' : 'text-warning'"
            >
              {{ codVarianceLabel }}
            </span>
          </div>
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
          v-for="chargeRow in standardChargeRows"
          :key="chargeRow.key"
          class="dropship-invoice-paper__summary-row"
          :class="{ 'dropship-invoice-paper__summary-row--editable': !readonly }"
        >
          <div class="dropship-invoice-paper__summary-label dropship-mgmt-settlement-paper__charge-label">
            <span>{{ chargeRow.label }}</span>
            <q-btn-toggle
              v-if="!readonly"
              v-model="form[chargeRow.field].payer"
              dense
              no-caps
              unelevated
              spread
              toggle-color="primary"
              color="grey-3"
              text-color="grey-8"
              class="dropship-invoice-paper__payer-toggle dropship-mgmt-settlement-paper__payer-toggle"
              :options="chargePayerToggleOptions"
            />
            <span
              v-else
              class="dropship-invoice-paper__paid-by"
              :class="{
                'dropship-invoice-paper__paid-by--recipient': form[chargeRow.field].payer === 'recipient',
                'dropship-invoice-paper__paid-by--merchant': form[chargeRow.field].payer === 'merchant',
                'dropship-invoice-paper__paid-by--company': form[chargeRow.field].payer === 'company',
              }"
            >
              {{ formatPayerLabel(form[chargeRow.field].payer) }}
            </span>
          </div>
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
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
          />
        </div>

        <div
          class="dropship-invoice-paper__summary-row"
          :class="{ 'dropship-invoice-paper__summary-row--editable': !readonly }"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>Discount (company pay)</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--company">
              Deduct from company profit
            </span>
          </div>
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
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
          />
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Reseller purchase cost</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">
              Calculated sell total{{ itemQuantity > 0 ? ` · ${itemQuantity} units` : '' }}
            </span>
          </div>
          <span class="text-weight-medium">{{ formatMoney(resellerPurchaseCost) }}</span>
        </div>

        <div
          v-if="giftCostMerchantTotal > 0"
          class="dropship-invoice-paper__summary-row"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>Warehouse gift cost (merchant)</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--merchant">
              On merchant bill
            </span>
          </div>
          <span class="text-weight-medium">{{ formatMoney(giftCostMerchantTotal) }}</span>
        </div>

        <div
          v-if="giftCostTenantTotal > 0"
          class="dropship-invoice-paper__summary-row"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>Warehouse gift cost (company)</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--company">
              Deduct from company profit
            </span>
          </div>
          <span class="text-weight-medium">{{ formatMoney(giftCostTenantTotal) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Company procurement cost</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-medium">{{ formatMoney(companyProcurementCost) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Reseller margin (recap)</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">Auto</span>
          </div>
          <span class="text-weight-bold text-primary">{{ formatMoney(resellerProfit) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Total cost</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">
              Procurement + charges
            </span>
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

        <div v-if="returnSectionMode !== 'hidden'" class="dropship-mgmt-settlement-paper__return-section">
          <div class="dropship-invoice-paper__section-label q-mb-xs">Return (recipient refused parcel)</div>

          <template v-if="returnSectionMode === 'readonly'">
            <div v-if="data.order.returned_at" class="dropship-invoice-paper__summary-row">
              <div class="dropship-invoice-paper__summary-label">
                <span>Returned at</span>
              </div>
              <span class="text-weight-medium">{{ formatDate(data.order.returned_at) }}</span>
            </div>
            <div class="dropship-invoice-paper__summary-row">
              <div class="dropship-invoice-paper__summary-label">
                <span>{{ returnChargeRow.label }}</span>
              </div>
              <span class="text-weight-medium">
                {{ formatMoney(readonlyReturnChargeAmount) }}
                <span class="text-caption text-grey-7 q-ml-xs">({{ formatPayerLabel(readonlyReturnPayer) }})</span>
              </span>
            </div>
            <div
              v-if="data.order.deduct_return_charge_from_middle_man"
              class="dropship-invoice-paper__summary-row"
            >
              <div class="dropship-invoice-paper__summary-label">
                <span>Merchant wallet debit</span>
              </div>
              <span class="text-weight-medium text-negative">Yes</span>
            </div>
            <div class="dropship-invoice-paper__summary-row">
              <div class="dropship-invoice-paper__summary-label">
                <span>Return reason note</span>
              </div>
              <span class="text-weight-medium">{{ data.settlement.return_reason_note || '—' }}</span>
            </div>
          </template>

          <template v-else>
            <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--editable">
              <div class="dropship-invoice-paper__summary-label dropship-mgmt-settlement-paper__charge-label">
                <span>{{ returnChargeRow.label }}</span>
                <q-btn-toggle
                  v-model="form[returnChargeRow.field].payer"
                  dense
                  no-caps
                  unelevated
                  spread
                  toggle-color="primary"
                  color="grey-3"
                  text-color="grey-8"
                  class="dropship-invoice-paper__payer-toggle dropship-mgmt-settlement-paper__payer-toggle"
                  :disable="readonly"
                  :options="chargePayerToggleOptions"
                />
              </div>
              <q-input
                v-model.number="form[returnChargeRow.field].amount"
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
          </template>
        </div>
      </div>
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

.dropship-mgmt-settlement-paper__summary-grid {
  width: min(100%, 500px);
  max-width: 500px;
}

.dropship-mgmt-settlement-paper__charge-label {
  flex-direction: column;
  align-items: flex-start;
  gap: 0.3rem;
  flex: 1 1 auto;
  min-width: 0;
  max-width: calc(100% - 9rem);
}

.dropship-mgmt-settlement-paper__payer-toggle {
  width: 100%;
  max-width: 17.5rem;
}

.dropship-mgmt-settlement-paper__payer-toggle :deep(.q-btn) {
  min-height: 1.45rem;
  padding: 0 0.3rem;
  font-size: 0.62rem;
  font-weight: 700;
  letter-spacing: 0.01em;
}

.dropship-mgmt-settlement-paper__summary-grid .dropship-invoice-paper__summary-row {
  gap: 0.65rem;
}

.dropship-mgmt-settlement-paper__summary-grid .dropship-invoice-paper__amount-input {
  width: 7.5rem;
}

.dropship-mgmt-settlement-paper__return-section {
  margin-top: 0.75rem;
  padding: 0.35rem 0;
  border-top: 1px dotted #dc2626;
  border-bottom: 1px dotted #dc2626;
}

.dropship-mgmt-settlement-paper__variance {
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: none;
  letter-spacing: normal;
}

.dropship-mgmt-settlement-paper__note-row {
  align-items: flex-start;
}

.dropship-mgmt-settlement-paper__note-input {
  width: min(100%, 24rem);
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

.dropship-mgmt-settlement-paper__items-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.dropship-mgmt-settlement-paper__item-row {
  display: flex;
  gap: 0.75rem;
  align-items: flex-start;
}

.dropship-mgmt-settlement-paper__item-thumb {
  width: 3rem;
  height: 3rem;
  flex: 0 0 auto;
  border-radius: 4px;
  overflow: hidden;
  background: #f3f4f6;
}

.dropship-mgmt-settlement-paper__item-thumb-img,
.dropship-mgmt-settlement-paper__item-thumb-fallback {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.dropship-mgmt-settlement-paper__item-body {
  min-width: 0;
  flex: 1;
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
