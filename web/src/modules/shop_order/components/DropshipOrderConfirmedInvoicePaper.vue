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
    showStockPickActions?: boolean;
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
    showStockPickActions: false,
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
  (e: 'pick-stock', itemId: number): void;
  (e: 'mark-unavailable', itemId: number): void;
  (e: 'clear-unavailable', itemId: number): void;
  (e: 'remove-pick', pickId: number): void;
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
    const deliveredQuantity = props.showStockPickActions
      ? item.is_fulfillment_unavailable
        ? 0
        : (item.confirmed_quantity ?? 0)
      : (deliveredQuantities.value?.[item.id] ?? item.confirmed_quantity ?? 0);
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
      isUnavailable: item.is_fulfillment_unavailable === true,
      unavailableReason: item.unavailable_reason,
      fulfillmentResolved: item.fulfillment_resolved === true,
      stockPicks: item.stock_picks ?? [],
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

const editableDeliveredQuantities = computed(
  () =>
    props.showFulfillmentBlocks &&
    !!deliveredQuantities.value &&
    !props.readonly &&
    !props.showStockPickActions,
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

type NumericChargeKey = 'delivery_charge_amount' | 'cod_charge_amount' | 'print_charge_amount' | 'packing_charge_amount';
type BooleanChargeKey = 'deduct_delivery_from_margin' | 'deduct_cod_from_margin' | 'deduct_print_from_margin' | 'deduct_packing_from_margin';

const chargeAmountField: Record<EditableChargeKey, NumericChargeKey> = {
  delivery: 'delivery_charge_amount',
  cod: 'cod_charge_amount',
  print: 'print_charge_amount',
  packing: 'packing_charge_amount',
};

const chargeDeductField: Record<EditableChargeKey, BooleanChargeKey> = {
  delivery: 'deduct_delivery_from_margin',
  cod: 'deduct_cod_from_margin',
  print: 'deduct_print_from_margin',
  packing: 'deduct_packing_from_margin',
};

const updateChargeAmount = (key: EditableChargeKey, value: string | number | null) => {
  if (!summary.value) return;
  const parsed = Number(value);
  const field = chargeAmountField[key];
  summary.value[field] = Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
};

const updateChargeDeduct = (key: EditableChargeKey, deductFromMargin: boolean) => {
  if (!summary.value) return;
  const field = chargeDeductField[key];
  summary.value[field] = deductFromMargin;
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
  <article class="dropship-invoice-paper dropship-magazine-spread">
    <!-- Editorial Hero Header -->
    <header class="dropship-invoice-paper__header">
      <div class="dropship-invoice-paper__brand">
        <div class="dropship-invoice-paper__doc-type">Dropship Operations Dossier</div>
        <div class="dropship-invoice-paper__order-no">{{ order.order_no }}</div>
        <div v-if="order.customer_group_name" class="dropship-invoice-paper__merchant">
          <q-icon name="ph ph-users" size="14px" class="q-mr-xs text-grey-6" />
          {{ order.customer_group_name }}
        </div>
      </div>
      <div class="dropship-invoice-paper__meta">
        <div v-if="orderDateLabel" class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Date</span>
          <span class="text-weight-bold">{{ orderDateLabel }}</span>
        </div>
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Status</span>
          <q-badge color="primary" class="text-capitalize text-weight-bold">
            {{ order.status.replace(/_/g, ' ') }}
          </q-badge>
        </div>
        <div v-if="order.shop_name" class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Shop</span>
          <span class="text-weight-medium">{{ order.shop_name }}</span>
        </div>
      </div>
    </header>

    <div class="dropship-invoice-paper__divider" />

    <!-- 2-Column Responsive Spread -->
    <div class="row q-col-gutter-lg">
      <!-- Left / Main Operations Column -->
      <div class="col-12 col-lg-8 column q-gutter-y-md">
        <!-- Recipient & Dispatch Address Dossier -->
        <section class="dropship-invoice-paper__address-block">
          <div class="dropship-invoice-paper__section-label q-mb-sm">
            <q-icon name="ph ph-map-pin" size="14px" />
            <span>Deliver to Recipient</span>
          </div>

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
              <span class="text-weight-medium">{{ phone }}</span>
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
              <span class="text-weight-bold text-caption text-grey-7 q-mr-xs">Note:</span>
              {{ order.delivery_instructions.trim() }}
            </div>
          </div>
        </section>

        <!-- Ordered Items Fulfillment Table -->
        <section>
          <div class="dropship-invoice-paper__section-label q-mb-sm">
            <q-icon name="ph ph-package" size="14px" />
            <span>Ordered Items ({{ totals.orderedQty }})</span>
          </div>

          <div class="dropship-invoice-paper__table-wrap">
            <table class="dropship-invoice-paper__table">
              <thead>
                <tr>
                  <th class="col-thumb"></th>
                  <th class="col-item">Item</th>
                  <th class="col-qty dropship-invoice-paper__internal-col">Ordered</th>
                  <th v-if="showDeliveredQuantities" class="col-qty">Delivered</th>
                  <th class="col-money dropship-invoice-paper__internal-col">Cost</th>
                  <th class="col-money dropship-invoice-paper__internal-col">Sell</th>
                  <th class="col-money">Resell</th>
                  <th class="col-money">Line Resell</th>
                  <th v-if="showStockPickActions && !readonly" class="col-actions text-right">Actions</th>
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
                    <div class="dropship-invoice-paper__item-name row items-center q-gutter-x-xs">
                      <span>{{ row.name }}</span>
                      <q-badge v-if="row.isUnavailable" color="negative" label="Unavailable" />
                      <q-badge
                        v-else-if="props.showStockPickActions && row.fulfillmentResolved && row.deliveredQuantity === row.orderedQuantity"
                        color="positive"
                        label="Picked"
                      />
                      <q-badge
                        v-else-if="props.showStockPickActions && row.fulfillmentResolved"
                        color="orange-8"
                        label="Resolved"
                      />
                    </div>
                    <div v-if="row.code || row.barcode || row.stockId" class="dropship-invoice-paper__item-meta dropship-invoice-paper__internal-col">
                      <span v-if="row.code">SKU: {{ row.code }}</span>
                      <span v-if="row.barcode"> · Barcode: {{ row.barcode }}</span>
                      <span v-if="row.stockId != null"> · Stock: #{{ row.stockId }}</span>
                    </div>
                    <div v-if="row.isUnavailable && row.unavailableReason" class="text-caption text-negative q-mt-xs">
                      {{ row.unavailableReason }}
                    </div>
                    <ul v-if="row.stockPicks.length" class="dropship-invoice-paper__pick-list q-mt-xs q-pl-md">
                      <li v-for="pick in row.stockPicks" :key="pick.id" class="text-caption text-grey-8 row items-center q-gutter-x-sm">
                        <span>{{ pick.shipment_name || 'Shipment' }} · stock {{ pick.global_stock_id }} · qty {{ pick.quantity }}</span>
                        <q-btn
                          v-if="showStockPickActions && !readonly"
                          flat
                          dense
                          round
                          size="xs"
                          icon="ph ph-x"
                          color="grey-7"
                          aria-label="Remove pick"
                          @click="emit('remove-pick', pick.id)"
                        />
                      </li>
                    </ul>
                  </td>
                  <td class="col-qty dropship-invoice-paper__internal-col text-weight-medium">{{ row.orderedQuantity }}</td>
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
                    <span v-else class="text-weight-bold">{{ row.deliveredQuantity }}</span>
                  </td>
                  <td class="col-money dropship-invoice-paper__internal-col">{{ formatMoney(row.cost) }}</td>
                  <td class="col-money dropship-invoice-paper__internal-col">{{ formatMoney(row.sell) }}</td>
                  <td class="col-money">{{ formatMoney(row.resell) }}</td>
                  <td class="col-money text-weight-bold">
                    {{ formatMoney(row.lineResell) }}
                  </td>
                  <td v-if="showStockPickActions && !readonly" class="col-actions text-right">
                    <div v-if="!row.isUnavailable" class="row items-center justify-end no-wrap q-gutter-xs">
                      <q-btn
                        unelevated
                        dense
                        no-caps
                        color="primary"
                        icon="ph ph-package"
                        label="Pick stock"
                        class="dropship-invoice-paper__action-btn"
                        @click="emit('pick-stock', row.id)"
                      />
                      <q-btn
                        v-if="row.stockPicks.length === 0"
                        flat
                        dense
                        round
                        color="negative"
                        icon="ph ph-prohibit"
                        aria-label="Mark unavailable"
                        @click="emit('mark-unavailable', row.id)"
                      >
                        <q-tooltip>Mark unavailable</q-tooltip>
                      </q-btn>
                    </div>
                    <div v-else class="row items-center justify-end no-wrap">
                      <q-btn
                        flat
                        dense
                        no-caps
                        color="primary"
                        icon="ph ph-arrow-counter-clockwise"
                        label="Undo"
                        class="dropship-invoice-paper__action-btn"
                        @click="emit('clear-unavailable', row.id)"
                      />
                    </div>
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
                  <td class="col-money text-weight-bold text-primary">
                    {{ formatMoney(totals.resell) }}
                  </td>
                  <td v-if="showStockPickActions && !readonly" class="col-actions" />
                </tr>
              </tfoot>
            </table>
          </div>
        </section>

        <!-- Sender Pickup Location Block (Fulfillment Phase) -->
        <section
          v-if="showFulfillmentBlocks && pickup"
          class="dropship-invoice-paper__address-block"
        >
          <div class="dropship-invoice-paper__section-label q-mb-sm">
            <q-icon name="ph ph-buildings" size="14px" />
            <span>Sender Pickup Location</span>
          </div>

          <template v-if="readonly">
            <div v-if="merchantProfileLabel" class="dropship-invoice-paper__readonly-field">
              <span class="dropship-invoice-paper__meta-label">Merchant profile:</span>
              <span class="text-weight-bold q-ml-xs">{{ merchantProfileLabel }}</span>
            </div>
            <div class="dropship-invoice-paper__recipient-name q-mt-sm">{{ pickup.sender_name || '—' }}</div>
            <div class="dropship-invoice-paper__line">{{ pickup.pickup_phone || '—' }}</div>
            <div class="dropship-invoice-paper__line dropship-invoice-paper__line--wrap">
              {{ pickup.pickup_address || '—' }}
            </div>
          </template>

          <template v-else>
            <div class="row q-col-gutter-sm q-mt-xs">
              <div class="col-12 col-sm-6">
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
                  class="dropship-invoice-paper__field-input full-width"
                  @update:model-value="onMerchantProfileChange"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  :model-value="pickup.sender_name"
                  dense
                  outlined
                  hide-bottom-space
                  label="Sender name"
                  class="dropship-invoice-paper__field-input full-width"
                  @update:model-value="(val) => updatePickupField('sender_name', String(val ?? ''))"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  :model-value="pickup.pickup_phone"
                  dense
                  outlined
                  hide-bottom-space
                  label="Pickup phone"
                  class="dropship-invoice-paper__field-input full-width"
                  @update:model-value="(val) => updatePickupField('pickup_phone', String(val ?? ''))"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  :model-value="pickup.pickup_address"
                  dense
                  outlined
                  hide-bottom-space
                  type="textarea"
                  autogrow
                  label="Pickup address"
                  class="dropship-invoice-paper__field-input full-width"
                  @update:model-value="(val) => updatePickupField('pickup_address', String(val ?? ''))"
                />
              </div>
            </div>
          </template>
        </section>
      </div>

      <!-- Right Column: Financial Breakdown & Courier Assignment -->
      <div class="col-12 col-lg-4 column q-gutter-y-md">
        <!-- Financial Statement Card -->
        <section
          class="dropship-invoice-paper__summary-grid full-width"
          :class="{ 'dropship-invoice-paper__summary--editable': isEditableSummary }"
        >
          <div class="dropship-invoice-paper__section-label q-mb-md">
            <q-icon name="ph ph-receipt" size="14px" />
            <span>Financial Statement</span>
          </div>

          <div class="dropship-invoice-paper__summary-row">
            <div class="dropship-invoice-paper__summary-label">
              <span>Items (Resell)</span>
              <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--recipient">
                Recipient
              </span>
            </div>
            <span class="text-weight-bold">
              {{ formatMoney(totals.resell) }}
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
                    { label: 'Recipient', value: false },
                    { label: 'Merchant', value: true },
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
            <span v-else class="text-weight-medium">{{ formatMoney(row.amount) }}</span>
          </div>

          <div
            v-if="isEditableSummary || summaryState.discount_amount > 0"
            class="dropship-invoice-paper__summary-row"
            :class="{ 'dropship-invoice-paper__summary-row--editable': isEditableSummary }"
          >
            <div class="dropship-invoice-paper__summary-label">
              <span>Discount</span>
              <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--merchant">
                Merchant
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
            <span v-else class="text-negative text-weight-medium">-{{ formatMoney(summaryState.discount_amount) }}</span>
          </div>

          <!-- Recipient Total -->
          <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--grand">
            <div class="dropship-invoice-paper__summary-label">
              <span>Recipient Total</span>
              <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">
                Due from Recipient
              </span>
            </div>
            <span class="text-primary text-h6 text-weight-bolder">
              {{ formatMoney(recipientGrandTotal) }}
            </span>
          </div>

          <!-- COD Collect Field -->
          <div
            v-if="!showFulfillmentBlocks && (isEditableSummary || summaryState.cod_collect_amount > 0)"
            class="dropship-invoice-paper__summary-row"
            :class="{ 'dropship-invoice-paper__summary-row--editable': isEditableSummary }"
          >
            <div class="dropship-invoice-paper__summary-label">
              <span>COD Collect</span>
              <q-btn
                v-if="isEditableSummary"
                flat
                dense
                no-caps
                size="xs"
                color="primary"
                class="dropship-invoice-paper__sync-btn"
                label="Match Recipient Total"
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
            <span v-else class="text-weight-bold">{{ formatMoney(summaryState.cod_collect_amount) }}</span>
          </div>
        </section>

        <!-- Courier Partner & Consignment Dossier (Fulfillment Phase) -->
        <section
          v-if="showFulfillmentBlocks && courier"
          class="dropship-invoice-paper__address-block full-width"
        >
          <div class="dropship-invoice-paper__section-label q-mb-sm">
            <q-icon name="ph ph-truck" size="14px" />
            <span>Courier Partner</span>
          </div>

          <template v-if="readonly">
            <div class="dropship-invoice-paper__recipient-name">
              {{ selectedCourierName || '—' }}
            </div>
            <div v-if="courier.courier_awb_number" class="dropship-invoice-paper__line font-mono text-weight-bold text-primary">
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
            <div class="column q-gutter-y-xs q-mt-xs">
              <q-select
                :model-value="courier.courier_service_id"
                :options="courierOptions"
                emit-value
                map-options
                dense
                outlined
                hide-bottom-space
                label="Courier partner"
                class="dropship-invoice-paper__field-input full-width"
                @update:model-value="onCourierPartnerChange"
              />

              <q-input
                :model-value="courier.courier_awb_number"
                dense
                outlined
                hide-bottom-space
                label="Consignment / AWB"
                class="dropship-invoice-paper__field-input full-width"
                @update:model-value="(val) => updateCourierField('courier_awb_number', String(val ?? ''))"
              />

              <q-input
                :model-value="courier.tracking_url"
                dense
                outlined
                hide-bottom-space
                label="Tracking URL"
                class="dropship-invoice-paper__field-input full-width"
                @update:model-value="(val) => updateCourierField('tracking_url', String(val ?? ''))"
              />

              <div
                v-if="selectedCourierName"
                class="dropship-invoice-paper__note dropship-invoice-paper__courier-note q-mt-xs"
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
                class="dropship-invoice-paper__track-btn q-mt-xs"
              />
            </div>
          </template>
        </section>
      </div>
    </div>
  </article>
</template>

<style scoped lang="scss">
@import '../styles/dropship-invoice-paper.scss';

.dropship-magazine-spread {
  animation: fadeIn 0.25s ease-in-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(4px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
