<script setup lang="ts">
import { computed } from 'vue';
import { copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { ShopOrder, ShopOrderItem } from '../types';
import {
  buildSummaryChargeRows,
  computeRecipientGrandTotal,
  createDropshipInvoiceSummaryFromOrder,
  type DropshipInvoiceSummaryState,
} from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoiceDeliveredQuantitiesState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';

const props = withDefaults(
  defineProps<{
    order: ShopOrder;
    orderItems: ShopOrderItem[];
    editableSummary?: boolean;
    readonly?: boolean;
    showDeliveredQuantities?: boolean;
    showFulfillmentBlocks?: boolean;
    merchantOptions?: { label: string; value: string }[];
    courierOptions?: { label: string; value: string }[];
    deliveryZoneLabel?: string;
    suggestedDeliveryFee?: number;
    codRateLabel?: string;
  }>(),
  {
    editableSummary: false,
    readonly: false,
    showDeliveredQuantities: false,
    showFulfillmentBlocks: false,
    merchantOptions: () => [],
    courierOptions: () => [],
    deliveryZoneLabel: '—',
    suggestedDeliveryFee: 0,
    codRateLabel: '—',
  },
);

const summary = defineModel<DropshipInvoiceSummaryState>('summary', { required: false });
const pickup = defineModel<DropshipInvoicePickupState>('pickup', { required: false });
const courier = defineModel<DropshipInvoiceCourierState>('courier', { required: false });
const deliveredQuantities = defineModel<DropshipInvoiceDeliveredQuantitiesState>(
  'deliveredQuantities',
  { required: false },
);

const emit = defineEmits<{
  (e: 'merchant-select', merchantId: string | null): void;
  (e: 'courier-change'): void;
}>();

type ItemPricing = {
  cost: number;
  sell: number;
  resell: number;
};

const currencySymbol = computed(() => props.order.shop_sell_currency_symbol?.trim() || '৳');

const formatMoney = (amount: number) =>
  `${currencySymbol.value}${amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

const resolveItemPricing = (item: ShopOrderItem): ItemPricing => ({
  cost: item.cost_price_amount ?? item.unit_list_price_amount ?? 0,
  sell: item.unit_sell_price_amount ?? 0,
  resell: item.customer_sell_price_amount ?? item.final_price_amount ?? 0,
});

const itemRows = computed(() =>
  props.orderItems.map((item) => {
    const pricing = resolveItemPricing(item);
    const orderedQuantity = item.quantity;
    const deliveredQuantity = deliveredQuantities.value?.[item.id] ?? 0;
    return {
      id: item.id,
      productId: item.product_id,
      imageUrl: item.image_url,
      name: item.name,
      code: item.sku?.trim() || null,
      barcode: item.barcode?.trim() || null,
      stockId: item.global_stock_id,
      orderedQuantity,
      deliveredQuantity,
      cost: pricing.cost,
      sell: pricing.sell,
      resell: pricing.resell,
      lineCost: pricing.cost * orderedQuantity,
      lineSell: pricing.sell * orderedQuantity,
      lineResell: pricing.resell * orderedQuantity,
      lineResellDelivered: pricing.resell * deliveredQuantity,
    };
  }),
);

const isEditableSummary = computed(() => props.editableSummary && !props.readonly);

const totals = computed(() =>
  itemRows.value.reduce(
    (acc, row) => {
      acc.orderedQty += row.orderedQuantity;
      acc.deliveredQty += row.deliveredQuantity;
      acc.cost += row.lineCost;
      acc.sell += row.lineSell;
      acc.resell += row.lineResell;
      acc.deliveredResell += row.lineResellDelivered;
      return acc;
    },
    { orderedQty: 0, deliveredQty: 0, cost: 0, sell: 0, resell: 0, deliveredResell: 0 },
  ),
);

const customerRecipientTotal = computed(() =>
  computeRecipientGrandTotal(totals.value.deliveredResell, summaryState.value),
);

const editableDeliveredQuantities = computed(
  () => props.showFulfillmentBlocks && !!deliveredQuantities.value && !props.readonly,
);

const merchantProfileLabel = computed(() => {
  if (!pickup.value?.merchant_id) return null;
  return props.merchantOptions.find((option) => option.value === pickup.value?.merchant_id)?.label ?? null;
});

const updateDeliveredQuantity = (itemId: number, value: string | number | null) => {
  if (!deliveredQuantities.value) return;
  const parsed = Number(value);
  const row = itemRows.value.find((item) => item.id === itemId);
  const maxQty = row?.orderedQuantity ?? 0;
  const next = Number.isFinite(parsed) ? Math.max(0, Math.min(maxQty, Math.trunc(parsed))) : 0;
  deliveredQuantities.value[itemId] = next;
};

const orderDateLabel = computed(() => {
  const raw = props.order.placed_at || props.order.created_at;
  if (!raw) return null;
  return new Date(raw).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
});

const recipientAddressLines = computed(() => {
  const order = props.order as ShopOrder & {
    shipping_post_code?: string | null;
    post_code?: string | null;
  };
  const lines: string[] = [];
  if (order.shipping_address?.trim()) lines.push(order.shipping_address.trim());
  const locality = [order.shipping_thana, order.shipping_district, order.shipping_post_code || order.post_code]
    .map((part) => part?.trim())
    .filter(Boolean)
    .join(', ');
  if (locality) lines.push(locality);
  return lines;
});

const phoneLines = computed(() =>
  [props.order.recipient_phone, props.order.recipient_phone_secondary]
    .map((phone) => phone?.trim())
    .filter(Boolean),
);

const summaryState = computed((): DropshipInvoiceSummaryState => {
  if (props.editableSummary && summary.value) {
    return summary.value;
  }
  return createDropshipInvoiceSummaryFromOrder(props.order);
});

const summaryChargeRows = computed(() =>
  buildSummaryChargeRows(summaryState.value, {
    includeZeroAmounts: isEditableSummary.value,
  }),
);

const recipientGrandTotal = computed(() =>
  computeRecipientGrandTotal(totals.value.resell, summaryState.value),
);

const syncCodCollectToRecipientTotal = () => {
  if (!summary.value) return;
  summary.value.cod_collect_amount = recipientGrandTotal.value;
};

type EditableChargeKey = 'delivery' | 'cod' | 'print' | 'packing';

const chargeAmountField: Record<EditableChargeKey, keyof DropshipInvoiceSummaryState> = {
  delivery: 'delivery_charge_amount',
  cod: 'cod_charge_amount',
  print: 'print_charge_amount',
  packing: 'packing_charge_amount',
};

const chargeDeductField: Record<EditableChargeKey, keyof DropshipInvoiceSummaryState> = {
  delivery: 'deduct_delivery_from_margin',
  cod: 'deduct_cod_from_margin',
  print: 'deduct_print_from_margin',
  packing: 'deduct_packing_from_margin',
};

const updateChargeAmount = (key: EditableChargeKey, value: string | number | null) => {
  if (!summary.value) return;
  const parsed = Number(value);
  summary.value[chargeAmountField[key]] = Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
};

const updateChargeDeduct = (key: EditableChargeKey, deductFromMargin: boolean) => {
  if (!summary.value) return;
  summary.value[chargeDeductField[key]] = deductFromMargin;
};

const updateDiscountAmount = (value: string | number | null) => {
  if (!summary.value) return;
  const parsed = Number(value);
  summary.value.discount_amount = Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
};

const updateCodCollectAmount = (value: string | number | null) => {
  if (!summary.value) return;
  const parsed = Number(value);
  summary.value.cod_collect_amount = Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
};

const selectedCourierName = computed(() => {
  if (!courier.value?.courier_service_id) return null;
  return props.courierOptions.find((option) => option.value === courier.value?.courier_service_id)?.label ?? null;
});

const updatePickupField = <K extends keyof NonNullable<typeof pickup.value>>(
  key: K,
  value: NonNullable<typeof pickup.value>[K],
) => {
  if (!pickup.value) return;
  pickup.value[key] = value;
};

const updateCourierField = <K extends keyof NonNullable<typeof courier.value>>(
  key: K,
  value: NonNullable<typeof courier.value>[K],
) => {
  if (!courier.value) return;
  courier.value[key] = value;
};

const onMerchantProfileChange = (merchantId: string | null) => {
  if (!pickup.value) return;
  pickup.value.merchant_id = merchantId;
  emit('merchant-select', merchantId);
};

const onCourierPartnerChange = (courierServiceId: string | null) => {
  if (!courier.value) return;
  courier.value.courier_service_id = courierServiceId;
  emit('courier-change');
};

const copyDetail = (text: string | null | undefined, label: string) => {
  const value = text?.trim();
  if (!value) {
    showErrorNotification(`No ${label.toLowerCase()} to copy`);
    return;
  }
  void copyToClipboard(value)
    .then(() => {
      showSuccessNotification(`${label} copied`);
    })
    .catch(() => {
      showErrorNotification(`Failed to copy ${label.toLowerCase()}`);
    });
};
</script>

<template>
  <article class="dropship-invoice-paper">
    <header class="dropship-invoice-paper__header">
      <div class="dropship-invoice-paper__brand">
        <div class="dropship-invoice-paper__doc-type">Dropship order</div>
        <div class="dropship-invoice-paper__order-no">{{ order.order_no }}</div>
        <div v-if="order.customer_group_name" class="dropship-invoice-paper__merchant">
          {{ order.customer_group_name }}
        </div>
      </div>
      <div class="dropship-invoice-paper__meta">
        <div v-if="orderDateLabel" class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Date</span>
          <span>{{ orderDateLabel }}</span>
        </div>
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Status</span>
          <span class="text-capitalize">{{ order.status.replace(/_/g, ' ') }}</span>
        </div>
        <div v-if="order.shop_name" class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Shop</span>
          <span>{{ order.shop_name }}</span>
        </div>
      </div>
    </header>

    <div class="dropship-invoice-paper__divider" />

    <section class="dropship-invoice-paper__addresses">
      <div class="dropship-invoice-paper__address-block">
        <div class="dropship-invoice-paper__section-label">Deliver to</div>
        <div class="dropship-invoice-paper__copy-row dropship-invoice-paper__recipient-name">
          <q-btn
            flat
            dense
            round
            size="xs"
            icon="ph ph-copy"
            color="grey-7"
            class="dropship-invoice-paper__copy-btn"
            aria-label="Copy recipient name"
            @click="copyDetail(order.recipient_name, 'Recipient name')"
          >
            <q-tooltip>Copy name</q-tooltip>
          </q-btn>
          <span>{{ order.recipient_name || '—' }}</span>
        </div>
        <div
          v-for="(phone, idx) in phoneLines"
          :key="`phone-${idx}`"
          class="dropship-invoice-paper__line dropship-invoice-paper__copy-row"
        >
          <q-btn
            flat
            dense
            round
            size="xs"
            icon="ph ph-copy"
            color="grey-7"
            class="dropship-invoice-paper__copy-btn"
            :aria-label="idx === 0 ? 'Copy phone' : 'Copy secondary phone'"
            @click="copyDetail(phone, idx === 0 ? 'Phone' : 'Secondary phone')"
          >
            <q-tooltip>{{ idx === 0 ? 'Copy phone' : 'Copy secondary phone' }}</q-tooltip>
          </q-btn>
          <span class="dropship-invoice-paper__phone-line">
            <span>{{ phone }}</span>
            <span v-if="idx === 0" class="dropship-invoice-paper__field-tag">Primary</span>
          </span>
        </div>
        <div
          v-for="(line, idx) in recipientAddressLines"
          :key="`addr-${idx}`"
          class="dropship-invoice-paper__line dropship-invoice-paper__line--wrap dropship-invoice-paper__copy-row"
        >
          <q-btn
            flat
            dense
            round
            size="xs"
            icon="ph ph-copy"
            color="grey-7"
            class="dropship-invoice-paper__copy-btn"
            :aria-label="idx === 0 ? 'Copy address line' : 'Copy locality'"
            @click="copyDetail(line, idx === 0 ? 'Address' : 'Locality')"
          >
            <q-tooltip>{{ idx === 0 ? 'Copy address' : 'Copy locality' }}</q-tooltip>
          </q-btn>
          <span>{{ line }}</span>
        </div>
        <div
          v-if="order.delivery_instructions?.trim()"
          class="dropship-invoice-paper__note dropship-invoice-paper__copy-row q-mt-sm"
        >
          <q-btn
            flat
            dense
            round
            size="xs"
            icon="ph ph-copy"
            color="grey-7"
            class="dropship-invoice-paper__copy-btn"
            aria-label="Copy delivery note"
            @click="copyDetail(order.delivery_instructions, 'Delivery note')"
          >
            <q-tooltip>Copy note</q-tooltip>
          </q-btn>
          <div class="dropship-invoice-paper__note-content">
            <span class="dropship-invoice-paper__meta-label">Note</span>
            {{ order.delivery_instructions.trim() }}
          </div>
        </div>
      </div>
    </section>

    <div class="dropship-invoice-paper__divider" />

    <section>
      <div class="dropship-invoice-paper__section-label q-mb-sm">Ordered items</div>
      <div class="dropship-invoice-paper__table-wrap">
        <table class="dropship-invoice-paper__table">
          <thead>
            <tr>
              <th class="col-thumb"></th>
              <th class="col-item">Item</th>
              <th class="col-qty dropship-invoice-paper__internal-col">Ordered qty</th>
              <th v-if="showDeliveredQuantities" class="col-qty">Delivered qty</th>
              <th class="col-money dropship-invoice-paper__internal-col">Cost</th>
              <th class="col-money dropship-invoice-paper__internal-col">Sell</th>
              <th class="col-money">Resell</th>
              <th class="col-money">Line resell</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in itemRows" :key="row.id">
              <td class="col-thumb">
                <div class="dropship-invoice-paper__thumb">
                  <SmartImage
                    :src="row.imageUrl"
                    :alt="row.name"
                    :product-id="row.productId"
                    img-class="dropship-invoice-paper__thumb-img"
                    fallback-class="dropship-invoice-paper__thumb-fallback"
                  />
                </div>
              </td>
              <td class="col-item">
                <div class="dropship-invoice-paper__item-name">{{ row.name }}</div>
                <div v-if="row.code || row.barcode || row.stockId" class="dropship-invoice-paper__item-meta dropship-invoice-paper__internal-col">
                  <span v-if="row.code">Code {{ row.code }}</span>
                  <span v-if="row.barcode"> · Barcode {{ row.barcode }}</span>
                  <span v-if="row.stockId != null"> · Stock {{ row.stockId }}</span>
                </div>
              </td>
              <td class="col-qty dropship-invoice-paper__internal-col">{{ row.orderedQuantity }}</td>
              <td v-if="showDeliveredQuantities" class="col-qty">
                <q-input
                  v-if="editableDeliveredQuantities"
                  :model-value="row.deliveredQuantity"
                  type="number"
                  min="0"
                  :max="row.orderedQuantity"
                  step="1"
                  dense
                  outlined
                  hide-bottom-space
                  class="dropship-invoice-paper__qty-input"
                  input-class="text-center"
                  @update:model-value="(val) => updateDeliveredQuantity(row.id, val)"
                />
                <span v-else>{{ row.deliveredQuantity }}</span>
              </td>
              <td class="col-money dropship-invoice-paper__internal-col">{{ formatMoney(row.cost) }}</td>
              <td class="col-money dropship-invoice-paper__internal-col">{{ formatMoney(row.sell) }}</td>
              <td class="col-money">{{ formatMoney(row.resell) }}</td>
              <td class="col-money text-weight-bold">
                <span class="dropship-invoice-paper__screen-value">{{ formatMoney(row.lineResell) }}</span>
                <span class="dropship-invoice-paper__print-customer-value">{{ formatMoney(row.lineResellDelivered) }}</span>
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="dropship-invoice-paper__totals-row">
              <td class="col-thumb" />
              <td class="col-item text-weight-bold">Totals</td>
              <td class="col-qty text-weight-bold dropship-invoice-paper__internal-col">{{ totals.orderedQty }}</td>
              <td v-if="showDeliveredQuantities" class="col-qty text-weight-bold">{{ totals.deliveredQty }}</td>
              <td class="col-money text-weight-bold dropship-invoice-paper__internal-col">{{ formatMoney(totals.cost) }}</td>
              <td class="col-money text-weight-bold dropship-invoice-paper__internal-col">{{ formatMoney(totals.sell) }}</td>
              <td class="col-money text-weight-bold">{{ formatMoney(totals.resell) }}</td>
              <td class="col-money text-weight-bold">
                <span class="dropship-invoice-paper__screen-value">{{ formatMoney(totals.resell) }}</span>
                <span class="dropship-invoice-paper__print-customer-value">{{ formatMoney(totals.deliveredResell) }}</span>
              </td>
            </tr>
          </tfoot>
        </table>
      </div>
    </section>

    <div class="dropship-invoice-paper__divider" />

    <section
      class="dropship-invoice-paper__summary"
      :class="{ 'dropship-invoice-paper__summary--editable': isEditableSummary }"
    >
      <div class="dropship-invoice-paper__summary-grid">
        <div class="dropship-invoice-paper__summary-row">
          <div class="dropship-invoice-paper__summary-label">
            <span>Items (resell)</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--recipient">
              Recipient pays
            </span>
          </div>
          <span>
            <span class="dropship-invoice-paper__screen-value">{{ formatMoney(totals.resell) }}</span>
            <span class="dropship-invoice-paper__print-customer-value">{{ formatMoney(totals.deliveredResell) }}</span>
          </span>
        </div>

        <div
          v-for="row in summaryChargeRows"
          :key="row.key"
          class="dropship-invoice-paper__summary-row"
          :class="{
            'dropship-invoice-paper__summary-row--editable': isEditableSummary,
            'dropship-invoice-paper__internal-col': !row.countsTowardRecipientTotal,
          }"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>{{ row.label }}</span>
            <template v-if="isEditableSummary">
              <q-btn-toggle
                :model-value="row.payer === 'merchant'"
                dense
                no-caps
                unelevated
                toggle-color="primary"
                color="grey-3"
                text-color="grey-8"
                class="dropship-invoice-paper__payer-toggle"
                :options="[
                  { label: 'Recipient pays', value: false },
                  { label: 'Merchant pays', value: true },
                ]"
                @update:model-value="(val) => updateChargeDeduct(row.key, val)"
              />
            </template>
            <span
              v-else
              class="dropship-invoice-paper__paid-by"
              :class="{
                'dropship-invoice-paper__paid-by--recipient': row.payer === 'recipient',
                'dropship-invoice-paper__paid-by--merchant': row.payer === 'merchant',
              }"
            >
              {{ row.payerLabel }}
            </span>
          </div>
          <q-input
            v-if="isEditableSummary"
            :model-value="row.amount"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
            @update:model-value="(val) => updateChargeAmount(row.key, val)"
          />
          <span v-else>{{ formatMoney(row.amount) }}</span>
        </div>

        <div
          v-if="isEditableSummary || summaryState.discount_amount > 0"
          class="dropship-invoice-paper__summary-row"
          :class="{ 'dropship-invoice-paper__summary-row--editable': isEditableSummary }"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>Discount</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--merchant">
              Merchant discount
            </span>
          </div>
          <q-input
            v-if="isEditableSummary"
            :model-value="summaryState.discount_amount"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
            @update:model-value="updateDiscountAmount"
          />
          <span v-else>-{{ formatMoney(summaryState.discount_amount) }}</span>
        </div>

        <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--grand">
          <div class="dropship-invoice-paper__summary-label">
            <span>Recipient total</span>
            <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">
              Amount due from recipient
            </span>
          </div>
          <span>
            <span class="dropship-invoice-paper__screen-value">{{ formatMoney(recipientGrandTotal) }}</span>
            <span class="dropship-invoice-paper__print-customer-value">{{ formatMoney(customerRecipientTotal) }}</span>
          </span>
        </div>

        <div
          v-if="!showFulfillmentBlocks && (isEditableSummary || summaryState.cod_collect_amount > 0)"
          class="dropship-invoice-paper__summary-row"
          :class="{ 'dropship-invoice-paper__summary-row--editable': isEditableSummary }"
        >
          <div class="dropship-invoice-paper__summary-label">
            <span>COD collect</span>
            <q-btn
              v-if="isEditableSummary"
              flat
              dense
              no-caps
              size="sm"
              color="primary"
              class="dropship-invoice-paper__sync-btn"
              label="Match recipient total"
              @click="syncCodCollectToRecipientTotal"
            />
          </div>
          <q-input
            v-if="isEditableSummary"
            :model-value="summaryState.cod_collect_amount"
            type="number"
            min="0"
            step="0.01"
            dense
            outlined
            hide-bottom-space
            class="dropship-invoice-paper__amount-input"
            input-class="text-right"
            @update:model-value="updateCodCollectAmount"
          />
          <span v-else>{{ formatMoney(summaryState.cod_collect_amount) }}</span>
        </div>
      </div>
    </section>

    <template v-if="showFulfillmentBlocks && pickup && courier">
      <div class="dropship-invoice-paper__divider" />

      <section
        class="dropship-invoice-paper__addresses dropship-invoice-paper__addresses--two-col dropship-invoice-paper__fulfillment"
      >
        <div class="dropship-invoice-paper__address-block">
          <div class="dropship-invoice-paper__section-label">Sender pickup location</div>

          <template v-if="readonly">
            <div v-if="merchantProfileLabel" class="dropship-invoice-paper__readonly-field">
              <span class="dropship-invoice-paper__meta-label">Merchant profile</span>
              {{ merchantProfileLabel }}
            </div>
            <div class="dropship-invoice-paper__recipient-name q-mt-sm">{{ pickup.sender_name || '—' }}</div>
            <div class="dropship-invoice-paper__line">{{ pickup.pickup_phone || '—' }}</div>
            <div class="dropship-invoice-paper__line dropship-invoice-paper__line--wrap">
              {{ pickup.pickup_address || '—' }}
            </div>
          </template>

          <template v-else>
            <q-select
              :model-value="pickup.merchant_id"
              :options="merchantOptions"
              emit-value
              map-options
              clearable
              dense
              outlined
              hide-bottom-space
              label="Merchant profile"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="onMerchantProfileChange"
            />

            <q-input
              :model-value="pickup.sender_name"
              dense
              outlined
              hide-bottom-space
              label="Sender name"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="(val) => updatePickupField('sender_name', String(val ?? ''))"
            />

            <q-input
              :model-value="pickup.pickup_phone"
              dense
              outlined
              hide-bottom-space
              label="Pickup phone"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="(val) => updatePickupField('pickup_phone', String(val ?? ''))"
            />

            <q-input
              :model-value="pickup.pickup_address"
              dense
              outlined
              hide-bottom-space
              type="textarea"
              autogrow
              label="Pickup address"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="(val) => updatePickupField('pickup_address', String(val ?? ''))"
            />
          </template>
        </div>

        <div class="dropship-invoice-paper__address-block">
          <div class="dropship-invoice-paper__section-label">Courier</div>

          <template v-if="readonly">
            <div class="dropship-invoice-paper__recipient-name q-mt-sm">
              {{ selectedCourierName || '—' }}
            </div>
            <div v-if="courier.courier_awb_number" class="dropship-invoice-paper__line">
              AWB {{ courier.courier_awb_number }}
            </div>
            <div v-if="courier.tracking_url" class="dropship-invoice-paper__line dropship-invoice-paper__line--wrap">
              {{ courier.tracking_url }}
            </div>
            <div
              v-if="selectedCourierName"
              class="dropship-invoice-paper__note dropship-invoice-paper__courier-note q-mt-sm"
            >
              <div class="dropship-invoice-paper__line">
                Zone: {{ deliveryZoneLabel }} · Delivery: {{ formatMoney(suggestedDeliveryFee) }}
              </div>
              <div class="dropship-invoice-paper__line">
                COD rate: {{ codRateLabel }} · COD fee: {{ formatMoney(courier.cod_charge) }}
              </div>
              <div class="dropship-invoice-paper__line">
                Open box: {{ courier.allow_open_box ? 'Yes' : 'No' }}
              </div>
            </div>
          </template>

          <template v-else>
            <q-select
              :model-value="courier.courier_service_id"
              :options="courierOptions"
              emit-value
              map-options
              dense
              outlined
              hide-bottom-space
              label="Courier partner"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="onCourierPartnerChange"
            />

            <q-input
              :model-value="courier.courier_awb_number"
              dense
              outlined
              hide-bottom-space
              label="Consignment / AWB"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="(val) => updateCourierField('courier_awb_number', String(val ?? ''))"
            />

            <q-input
              :model-value="courier.tracking_url"
              dense
              outlined
              hide-bottom-space
              label="Tracking URL"
              class="dropship-invoice-paper__field-input q-mt-sm"
              @update:model-value="(val) => updateCourierField('tracking_url', String(val ?? ''))"
            />

            <div
              v-if="selectedCourierName"
              class="dropship-invoice-paper__note dropship-invoice-paper__courier-note q-mt-sm"
            >
              <div class="dropship-invoice-paper__recipient-name dropship-invoice-paper__courier-name">
                {{ selectedCourierName }}
              </div>
              <div class="dropship-invoice-paper__line">
                Zone: {{ deliveryZoneLabel }} · Delivery: {{ formatMoney(suggestedDeliveryFee) }}
              </div>
              <div class="dropship-invoice-paper__line">
                COD rate: {{ codRateLabel }} · Suggested COD fee: {{ formatMoney(courier.cod_charge) }}
              </div>
              <div class="dropship-invoice-paper__line">
                Open box: {{ courier.allow_open_box ? 'Yes' : 'No' }}
              </div>
            </div>

            <q-btn
              v-if="courier.tracking_url"
              flat
              dense
              no-caps
              color="primary"
              icon="ph ph-arrow-square-out"
              label="Open tracking link"
              type="a"
              :href="courier.tracking_url"
              target="_blank"
              rel="noopener noreferrer"
              class="dropship-invoice-paper__track-btn q-mt-sm"
            />
          </template>
        </div>
      </section>
    </template>
  </article>
</template>

<style scoped>
.dropship-invoice-paper {
  max-width: 920px;
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

.dropship-invoice-paper__recipient-name {
  margin-top: 0.35rem;
  font-size: 1.05rem;
  font-weight: 700;
  color: #111827;
}

.dropship-invoice-paper__copy-row {
  display: flex;
  align-items: flex-start;
  gap: 0.35rem;
}

.dropship-invoice-paper__copy-row > span,
.dropship-invoice-paper__note-content {
  min-width: 0;
  flex: 1 1 auto;
}

.dropship-invoice-paper__copy-btn {
  flex: 0 0 auto;
  opacity: 0.55;
}

.dropship-invoice-paper__copy-row:hover .dropship-invoice-paper__copy-btn,
.dropship-invoice-paper__copy-btn:focus-visible {
  opacity: 1;
}

.dropship-invoice-paper__line {
  margin-top: 0.2rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.82rem;
  color: #374151;
}

.dropship-invoice-paper__phone-line {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.dropship-invoice-paper__field-tag {
  font-size: 0.62rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #6b7280;
}

.dropship-invoice-paper__line--wrap {
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.dropship-invoice-paper__note {
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.78rem;
  color: #4b5563;
}

.dropship-invoice-paper__table-wrap {
  overflow-x: auto;
}

.dropship-invoice-paper__table {
  width: 100%;
  border-collapse: collapse;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.78rem;
}

.dropship-invoice-paper__table th,
.dropship-invoice-paper__table td {
  padding: 0.45rem 0.5rem;
  border-bottom: 1px solid rgba(15, 23, 42, 0.1);
  vertical-align: top;
}

.dropship-invoice-paper__table th {
  font-size: 0.65rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #6b7280;
  background: rgba(15, 23, 42, 0.03);
}

.dropship-invoice-paper__table tfoot td {
  border-top: 2px solid rgba(15, 23, 42, 0.16);
  border-bottom: none;
}

.col-thumb {
  width: 1.15in;
  text-align: center;
  vertical-align: top;
}

.dropship-invoice-paper__thumb {
  width: 1in;
  height: 1in;
  margin: 0 auto;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 6px;
  overflow: hidden;
  background: #fff;
}

.dropship-invoice-paper__thumb :deep(.dropship-invoice-paper__thumb-img),
.dropship-invoice-paper__thumb :deep(.dropship-invoice-paper__thumb-fallback) {
  width: 1in;
  height: 1in;
  display: block;
  object-fit: contain;
}

.dropship-invoice-paper__thumb :deep(.dropship-invoice-paper__thumb-fallback) {
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f3f4f6;
  color: #9ca3af;
  font-size: 0.65rem;
}

.col-item {
  width: 34%;
  text-align: left;
}

.col-qty {
  width: 7%;
}

.dropship-invoice-paper__table th.col-qty,
.dropship-invoice-paper__table td.col-qty {
  text-align: center;
  vertical-align: middle;
}

.dropship-invoice-paper__qty-input {
  width: 3.25rem;
  display: inline-flex;
  vertical-align: middle;
  font-family: ui-sans-serif, system-ui, sans-serif;
}

.dropship-invoice-paper__qty-input :deep(.q-field__control) {
  min-height: 30px;
}

.dropship-invoice-paper__qty-input :deep(.q-field__native) {
  text-align: center;
}

.col-money {
  width: 13%;
  white-space: nowrap;
}

.dropship-invoice-paper__table th.col-money,
.dropship-invoice-paper__table td.col-money {
  text-align: center;
  vertical-align: middle;
}

.dropship-invoice-paper__item-name {
  font-weight: 600;
  color: #111827;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.3;
}

.dropship-invoice-paper__item-meta {
  margin-top: 0.2rem;
  font-size: 0.68rem;
  color: #6b7280;
  overflow-wrap: anywhere;
}

.dropship-invoice-paper__summary {
  display: flex;
  justify-content: flex-end;
}

.dropship-invoice-paper__summary-grid {
  width: min(100%, 320px);
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.8rem;
}

.dropship-invoice-paper__summary--editable .dropship-invoice-paper__summary-grid {
  width: min(100%, 440px);
}

.dropship-invoice-paper__summary-row--editable {
  align-items: center;
}

.dropship-invoice-paper__amount-input {
  width: 7.5rem;
  flex: 0 0 auto;
  font-family: ui-sans-serif, system-ui, sans-serif;
}

.dropship-invoice-paper__amount-input :deep(.q-field__control) {
  min-height: 32px;
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

.dropship-invoice-paper__sync-btn {
  align-self: flex-start;
  margin-top: 0.05rem;
  padding: 0;
  min-height: 1.25rem;
  font-size: 0.62rem;
  font-weight: 600;
}

.dropship-invoice-paper__addresses--two-col {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1.5rem;
}

.dropship-invoice-paper__field-input {
  font-family: ui-sans-serif, system-ui, sans-serif;
}

.dropship-invoice-paper__field-input :deep(.q-field__control) {
  min-height: 34px;
  background: rgba(255, 255, 255, 0.72);
}

.dropship-invoice-paper__field-input :deep(.q-field__label) {
  font-size: 0.72rem;
  color: #6b7280;
}

.dropship-invoice-paper__courier-note {
  padding: 0.55rem 0.65rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.55);
}

.dropship-invoice-paper__courier-name {
  margin-top: 0;
  margin-bottom: 0.15rem;
  font-size: 0.92rem;
}

.dropship-invoice-paper__track-btn {
  padding: 0.15rem 0.35rem;
  min-height: 1.6rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.72rem;
  font-weight: 600;
}

.dropship-invoice-paper__print-customer-value {
  display: none;
}

.dropship-invoice-paper__readonly-field {
  margin-top: 0.35rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
  font-size: 0.82rem;
  color: #374151;
}

.dropship-invoice-paper__summary-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  padding: 0.25rem 0;
  color: #374151;
}

.dropship-invoice-paper__summary-label {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
  min-width: 0;
}

.dropship-invoice-paper__paid-by {
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

.dropship-invoice-paper__paid-by--muted {
  color: #6b7280;
  text-transform: none;
  font-weight: 500;
  font-size: 0.65rem;
}

.dropship-invoice-paper__summary-row--grand {
  margin-top: 0.35rem;
  padding-top: 0.45rem;
  border-top: 1px solid rgba(15, 23, 42, 0.14);
  font-size: 0.92rem;
  font-weight: 700;
  color: #111827;
}

@media (max-width: 767px) {
  .dropship-invoice-paper {
    padding: 1rem;
  }

  .dropship-invoice-paper__addresses--two-col {
    grid-template-columns: 1fr;
  }

  .dropship-invoice-paper__table {
    min-width: 700px;
  }
}
</style>
