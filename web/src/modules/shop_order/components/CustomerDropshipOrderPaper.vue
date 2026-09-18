<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { CustomerOrderDetailOrder, ShopOrderItem } from '../types';
import {
  buildSummaryChargeRows,
  computeRecipientGrandTotal,
  createDropshipInvoiceSummaryFromOrder,
} from '../utils/dropshipInvoiceSummary';
import {
  formatCustomerOrderStatusLabel,
  getCustomerOrderFocusedSteps,
  getCustomerOrderStatusColor,
  getCustomerOrderStatusIcon,
} from '../utils/customerOrderStatusUi';

const props = defineProps<{
  order: CustomerOrderDetailOrder;
  orderItems: ShopOrderItem[];
  isNegotiationOpen?: boolean;
  normalizedStatus: string;
  statusSequence: string[];
}>();

const { t } = useI18n();

const currencySymbol = computed(() => props.order.shop_sell_currency_symbol?.trim() || '৳');

const formatMoney = (amount: number) =>
  `${currencySymbol.value}${amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

const orderDateLabel = computed(() => {
  const raw = props.order.placed_at || props.order.created_at;
  if (!raw) return null;
  return new Date(raw).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
});

const statusLabel = computed(() =>
  formatCustomerOrderStatusLabel(props.normalizedStatus, props.order.shop_type_snapshot),
);

const statusColor = computed(() => getCustomerOrderStatusColor(props.normalizedStatus));

const statusIcon = computed(() => getCustomerOrderStatusIcon(props.normalizedStatus));

const focusedSteps = computed(() =>
  getCustomerOrderFocusedSteps(props.normalizedStatus, props.statusSequence),
);

const nextStatusLabel = computed(() =>
  focusedSteps.value.next
    ? formatCustomerOrderStatusLabel(focusedSteps.value.next, props.order.shop_type_snapshot)
    : null,
);

const paymentLabel = computed(() =>
  props.order.is_prepaid_snapshot
    ? t('shop_admin.payment_prepaid')
    : t('shop_admin.payment_cod'),
);

const recipientAddressLines = computed(() => {
  const order = props.order;
  const lines: string[] = [];
  if (order.shipping_address?.trim()) lines.push(order.shipping_address.trim());
  const locality = [order.shipping_thana, order.shipping_district]
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

const itemRows = computed(() =>
  props.orderItems.map((item) => {
    const resell = Number(item.customer_sell_price_amount ?? item.final_price_amount ?? 0);
    const quantity = item.quantity;
    return {
      id: item.id,
      productId: item.product_id,
      imageUrl: item.image_url,
      name: item.name,
      quantity,
      resell,
      lineResell: resell * quantity,
      item,
    };
  }),
);

const totals = computed(() =>
  itemRows.value.reduce(
    (acc, row) => {
      acc.quantity += row.quantity;
      acc.resell += row.lineResell;
      return acc;
    },
    { quantity: 0, resell: 0 },
  ),
);

const summaryState = computed(() => createDropshipInvoiceSummaryFromOrder(props.order));

const hideCourierCharges = computed(() =>
  ['confirmed', 'processing'].includes(props.normalizedStatus),
);

const summaryChargeRows = computed(() =>
  buildSummaryChargeRows(summaryState.value)
    .filter((row) => row.amount > 0)
    .filter((row) => !hideCourierCharges.value || !['delivery', 'cod'].includes(row.key)),
);

const recipientGrandTotal = computed(() => {
  if (hideCourierCharges.value) {
    return computeRecipientGrandTotal(totals.value.resell, {
      ...summaryState.value,
      delivery_charge_amount: 0,
      cod_charge_amount: 0,
    });
  }
  return computeRecipientGrandTotal(totals.value.resell, summaryState.value);
});

const accountingSubtotal = computed(() =>
  props.orderItems.reduce((sum, item) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return sum + price * item.quantity;
  }, 0),
);

const middlemanTotalCost = computed(() => {
  const order = props.order;
  const deliveryCharge = hideCourierCharges.value ? 0 : Number(order.delivery_charge_amount || 0);
  const codCharge = hideCourierCharges.value ? 0 : Number(order.cod_charge_amount || 0);
  return (
    accountingSubtotal.value +
    (order.deduct_print_from_margin ? Number(order.print_charge_amount || 0) : 0) +
    (order.deduct_packing_from_margin ? Number(order.packing_charge_amount || 0) : 0) +
    (order.deduct_delivery_from_margin ? deliveryCharge : 0) +
    (order.deduct_cod_from_margin ? codCharge : 0)
  );
});

const estimatedProfit = computed(() => {
  const discount = Number(props.order.discount_amount || 0);
  return totals.value.resell - discount - middlemanTotalCost.value;
});

const isBeforePickup = computed(() => hideCourierCharges.value);

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
    <!-- Editorial Status Masthead Strip -->
    <div
      class="dropship-invoice-paper__status-strip"
      :class="`dropship-invoice-paper__status-strip--${statusColor}`"
    >
      <div class="dropship-invoice-paper__status-main">
        <q-icon :name="statusIcon" size="24px" class="dropship-invoice-paper__status-icon" />
        <div class="dropship-invoice-paper__status-copy">
          <span class="dropship-invoice-paper__status-kicker">Dropship Order Status</span>
          <span class="dropship-invoice-paper__status-value">{{ statusLabel }}</span>
        </div>
      </div>
      <div v-if="nextStatusLabel" class="dropship-invoice-paper__status-next">
        <span class="dropship-invoice-paper__status-next-label">Next Step</span>
        <span class="dropship-invoice-paper__status-next-value">{{ nextStatusLabel }}</span>
      </div>
    </div>

    <!-- Editorial Hero Header -->
    <header class="dropship-invoice-paper__header">
      <div class="dropship-invoice-paper__brand">
        <div class="dropship-invoice-paper__doc-type">Dropship Dispatch Dossier</div>
        <div class="dropship-invoice-paper__order-no">{{ order.order_no }}</div>
        <div v-if="order.shop_name" class="dropship-invoice-paper__merchant">
          <q-icon name="ph ph-storefront" size="14px" class="q-mr-xs text-grey-6" />
          {{ order.shop_name }}
        </div>
      </div>
      <div class="dropship-invoice-paper__meta">
        <div v-if="orderDateLabel" class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">Date Placed</span>
          <span class="text-weight-bold">{{ orderDateLabel }}</span>
        </div>
        <div class="dropship-invoice-paper__meta-row">
          <span class="dropship-invoice-paper__meta-label">{{ t('shop_admin.payment_mode') }}</span>
          <span class="text-weight-bold">{{ paymentLabel }}</span>
        </div>
      </div>
    </header>

    <div class="dropship-invoice-paper__divider" />

    <!-- 2-Column Magazine Grid Spread -->
    <div class="row q-col-gutter-lg">
      <!-- Main Content Column: Recipient Dossier & Items List -->
      <div class="col-12 col-md-7 col-lg-8 column q-gutter-y-md">
        <!-- Deliver To / Recipient Dossier -->
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

        <!-- Items Catalog Table -->
        <section>
          <div class="dropship-invoice-paper__section-label q-mb-sm">
            <q-icon name="ph ph-package" size="14px" />
            <span>{{ t('shop_admin.items_in_order') }} ({{ totals.quantity }})</span>
          </div>

          <!-- Desktop Table -->
          <div class="dropship-invoice-paper__table-wrap dropship-invoice-paper__table-wrap--desktop">
            <table class="dropship-invoice-paper__table">
              <thead>
                <tr>
                  <th class="col-thumb"></th>
                  <th class="col-item">Item</th>
                  <th class="col-qty">{{ t('shop_admin.quantity') }}</th>
                  <th class="col-money">{{ t('shop_admin.recipient_price') }}</th>
                  <th v-if="isNegotiationOpen" class="col-money">{{ t('shop_admin.your_counter') }}</th>
                  <th class="col-money">{{ t('shop_admin.line_total') }}</th>
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
                  </td>
                  <td class="col-qty text-weight-bold">{{ row.quantity }}</td>
                  <td class="col-money">{{ formatMoney(row.resell) }}</td>
                  <td v-if="isNegotiationOpen" class="col-money">
                    <q-input
                      v-model.number="row.item.customer_offer_amount"
                      type="number"
                      dense
                      outlined
                      hide-bottom-space
                      class="dropship-invoice-paper__counter-input"
                      :prefix="currencySymbol"
                    />
                  </td>
                  <td class="col-money text-weight-bolder text-grey-9">{{ formatMoney(row.lineResell) }}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr>
                  <td class="col-thumb" />
                  <td class="col-item text-weight-bold">Totals</td>
                  <td class="col-qty text-weight-bold">{{ totals.quantity }}</td>
                  <td class="col-money" />
                  <td v-if="isNegotiationOpen" class="col-money" />
                  <td class="col-money text-weight-bolder text-primary">{{ formatMoney(totals.resell) }}</td>
                </tr>
              </tfoot>
            </table>
          </div>

          <!-- Mobile Cards -->
          <div class="dropship-invoice-paper__mobile-items">
            <article
              v-for="row in itemRows"
              :key="`mobile-${row.id}`"
              class="dropship-invoice-paper__mobile-item"
            >
              <div class="dropship-invoice-paper__mobile-item-top">
                <div class="dropship-invoice-paper__thumb dropship-invoice-paper__thumb--sm">
                  <SmartImage
                    :src="row.imageUrl"
                    :alt="row.name"
                    :product-id="row.productId"
                    img-class="dropship-invoice-paper__thumb-img"
                    fallback-class="dropship-invoice-paper__thumb-fallback"
                  />
                </div>
                <div class="dropship-invoice-paper__mobile-item-body">
                  <div class="dropship-invoice-paper__item-name">{{ row.name }}</div>
                  <div class="dropship-invoice-paper__mobile-meta">
                    <span>{{ t('shop_admin.quantity') }} {{ row.quantity }}</span>
                    <span>{{ formatMoney(row.resell) }} {{ t('shop.each') }}</span>
                  </div>
                </div>
              </div>

              <div
                v-if="isNegotiationOpen"
                class="dropship-invoice-paper__mobile-counter row items-center q-gutter-x-sm"
              >
                <span class="text-caption text-grey-7">{{ t('shop_admin.your_counter') }}</span>
                <q-input
                  v-model.number="row.item.customer_offer_amount"
                  type="number"
                  dense
                  outlined
                  hide-bottom-space
                  class="dropship-invoice-paper__counter-input col"
                  :prefix="currencySymbol"
                />
              </div>

              <div class="dropship-invoice-paper__mobile-line-total row items-center justify-between">
                <span class="text-caption text-grey-7">{{ t('shop_admin.line_total') }}</span>
                <span class="text-body2 text-weight-bold">{{ formatMoney(row.lineResell) }}</span>
              </div>
            </article>

            <div class="dropship-invoice-paper__mobile-total row items-center justify-between">
              <span class="text-weight-bold">
                Totals
                <span class="text-caption text-grey-7">({{ totals.quantity }})</span>
              </span>
              <span class="text-subtitle2 text-weight-bolder text-primary">{{ formatMoney(totals.resell) }}</span>
            </div>
          </div>
        </section>
      </div>

      <!-- Right Column: Financial Statement & Logistics Sidebar -->
      <div class="col-12 col-md-5 col-lg-4 column q-gutter-y-md">
        <!-- Financial Ledger Statement -->
        <section class="dropship-invoice-paper__summary-grid full-width">
          <div class="dropship-invoice-paper__section-label q-mb-md">
            <q-icon name="ph ph-receipt" size="14px" />
            <span>Financial Ledger</span>
          </div>

          <div class="dropship-invoice-paper__summary-row">
            <div class="dropship-invoice-paper__summary-label">
              <span>{{ t('shop.items_subtotal') }}</span>
              <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--recipient">
                Recipient
              </span>
            </div>
            <span class="text-weight-medium">{{ formatMoney(totals.resell) }}</span>
          </div>

          <div
            v-for="row in summaryChargeRows"
            :key="row.key"
            class="dropship-invoice-paper__summary-row"
          >
            <div class="dropship-invoice-paper__summary-label">
              <span>{{ row.label }}</span>
              <span
                class="dropship-invoice-paper__paid-by"
                :class="
                  row.payer === 'recipient'
                    ? 'dropship-invoice-paper__paid-by--recipient'
                    : 'dropship-invoice-paper__paid-by--merchant'
                "
              >
                {{ row.payerLabel }}
              </span>
            </div>
            <span class="text-weight-medium">{{ formatMoney(row.amount) }}</span>
          </div>

          <div
            v-if="summaryState.discount_amount > 0"
            class="dropship-invoice-paper__summary-row"
          >
            <div class="dropship-invoice-paper__summary-label">
              <span>{{ t('shop_admin.discount') }}</span>
            </div>
            <span class="text-negative text-weight-medium">-{{ formatMoney(summaryState.discount_amount) }}</span>
          </div>

          <!-- Recipient Grand Total -->
          <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--grand">
            <div class="dropship-invoice-paper__summary-label">
              <span>{{ t('shop_admin.recipient_pays') }}</span>
              <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">
                {{ paymentLabel }}
              </span>
            </div>
            <span class="text-primary text-h6 text-weight-bolder">{{ formatMoney(recipientGrandTotal) }}</span>
          </div>

          <!-- Accounting Cost Breakdown -->
          <div class="dropship-invoice-paper__summary-row q-mt-sm">
            <div class="dropship-invoice-paper__summary-label">
              <span>{{ t('shop_admin.your_cost') }}</span>
              <span class="dropship-invoice-paper__paid-by dropship-invoice-paper__paid-by--muted">
                Dossier Cost
              </span>
            </div>
            <span class="text-weight-medium">{{ formatMoney(middlemanTotalCost) }}</span>
          </div>

          <!-- Estimated Profit Highlight Banner -->
          <div class="dropship-invoice-paper__summary-row dropship-invoice-paper__summary-row--profit">
            <div class="dropship-invoice-paper__summary-label">
              <q-icon name="ph ph-trend-up" size="18px" class="q-mr-xs" />
              <span>{{ t('shop_admin.your_profit') }}</span>
            </div>
            <span class="text-h6 text-weight-bolder">{{ formatMoney(estimatedProfit) }}</span>
          </div>
        </section>

        <!-- Courier & Logistics Dossier (if assigned or tracked) -->
        <section
          v-if="order.tracking_url || order.courier_name"
          class="dropship-invoice-paper__address-block full-width"
        >
          <div class="dropship-invoice-paper__section-label q-mb-sm">
            <q-icon name="ph ph-truck" size="14px" />
            <span>Courier &amp; Delivery</span>
          </div>
          <div v-if="order.courier_name" class="dropship-invoice-paper__recipient-name">
            {{ order.courier_name }}
          </div>
          <div v-if="order.courier_awb_number" class="dropship-invoice-paper__line font-mono text-weight-bold text-primary">
            AWB {{ order.courier_awb_number }}
          </div>
          <q-btn
            v-if="order.tracking_url"
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-arrow-square-out"
            :label="t('shop_admin.track_parcel')"
            type="a"
            :href="order.tracking_url"
            target="_blank"
            rel="noopener noreferrer"
            class="dropship-invoice-paper__track-btn q-mt-sm"
          />
        </section>

        <p v-if="isBeforePickup" class="dropship-invoice-paper__footnote text-caption text-grey-6 q-px-xs q-mb-none">
          <q-icon name="ph ph-info" size="14px" class="q-mr-xs" />
          {{ t('shop_admin.charges_update_before_pickup') }}
        </p>
      </div>
    </div>
  </article>
</template>

<script lang="ts">
export default {
  name: 'CustomerDropshipOrderPaper',
};
</script>

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
