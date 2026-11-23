<template>
  <article class="dropship-order-doc">
    <header class="dropship-order-doc__header">
      <div class="dropship-order-doc__title text-subtitle1 text-weight-bold">
        {{ $t('shop.dropship_place_order_title') }}
      </div>
      <div class="text-caption text-grey-7 q-mt-xs">
        {{ $t('shop.dropship_order_review_subtitle') }}
      </div>
    </header>

    <div class="dropship-order-doc__rule" />

    <section class="dropship-order-doc__section">
      <h2 class="dropship-order-doc__section-title">
        {{ $t('shop.shipping_info') }}
      </h2>
      <dl class="dropship-order-doc__dl">
        <div class="dropship-order-doc__dl-row">
          <dt>{{ $t('shop.recipient_name') }}</dt>
          <dd>{{ customerForm.recipientName }}</dd>
        </div>
        <div class="dropship-order-doc__dl-row">
          <dt>{{ $t('shop.recipient_phone') }}</dt>
          <dd>{{ customerForm.recipientPhone }}</dd>
        </div>
        <div v-if="customerForm.secondaryPhone?.trim()" class="dropship-order-doc__dl-row">
          <dt>{{ $t('shop.dropship_secondary_phone') }}</dt>
          <dd>{{ customerForm.secondaryPhone }}</dd>
        </div>
        <div class="dropship-order-doc__dl-row dropship-order-doc__dl-row--stack">
          <dt>{{ $t('shop.shipping_address') }}</dt>
          <dd>{{ customerForm.shippingAddress }}</dd>
          <dd v-if="locationLine" class="text-grey-7">{{ locationLine }}</dd>
        </div>
        <div
          v-if="customerForm.deliveryInstructions?.trim()"
          class="dropship-order-doc__dl-row dropship-order-doc__dl-row--stack"
        >
          <dt>{{ $t('shop.delivery_instructions') }}</dt>
          <dd>{{ customerForm.deliveryInstructions }}</dd>
        </div>
      </dl>
    </section>

    <div class="dropship-order-doc__rule" />

    <section class="dropship-order-doc__section">
      <h2 class="dropship-order-doc__section-title">
        {{ $t('shop.items') }}
        <span class="text-weight-medium text-grey-7">({{ itemCount }})</span>
      </h2>

      <div class="dropship-order-doc__items dropship-order-doc__items--mobile lt-md column q-gutter-y-sm">
        <div
          v-for="item in items"
          :key="item.id"
          class="dropship-order-doc__item-card"
        >
          <div class="text-body2 text-weight-bold text-grey-9">{{ item.name }}</div>
          <div class="text-caption text-grey-6 q-mt-xs">
            {{ $t('shop.qty') }}: {{ item.quantity }}
          </div>
          <div class="dropship-order-doc__item-grid q-mt-sm">
            <div>
              <div class="dropship-order-doc__cell-label">{{ $t('shop.dropship_col_purchase') }}</div>
              <div class="tf-num">{{ formatMoney(item.purchasePrice) }}</div>
            </div>
            <div>
              <div class="dropship-order-doc__cell-label">{{ $t('shop.dropship_col_resell') }}</div>
              <div class="tf-num">{{ formatMoney(item.resellPrice) }}</div>
            </div>
            <div v-if="showRequestedColumn && hasItemRequest(item)">
              <div class="dropship-order-doc__cell-label">{{ $t('shop.dropship_col_requested_resell') }}</div>
              <div class="tf-num dropship-order-doc__requested">
                {{ formatMoney(item.requestedResellDiscountPrice!) }}
              </div>
            </div>
          </div>
          <div class="row q-mt-sm q-col-gutter-md">
            <div class="col">
              <div class="dropship-order-doc__cell-label">{{ $t('shop.dropship_col_purchase_total') }}</div>
              <div class="text-body2 text-weight-medium tf-num">
                {{ formatMoney(item.purchasePrice * item.quantity) }}
              </div>
            </div>
            <div class="col text-right">
              <div class="dropship-order-doc__cell-label">{{ $t('shop.dropship_col_resell_total') }}</div>
              <div
                class="text-body2 text-weight-bold tf-num"
                :class="hasItemRequest(item) ? 'dropship-order-doc__resell-pending' : 'text-primary'"
              >
                {{ formatMoney(lineResellTotal(item)) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="dropship-order-doc__items dropship-order-doc__items--table gt-sm">
        <div
          class="dropship-order-doc__table-head"
          :class="{ 'dropship-order-doc__table-row--with-requested': showRequestedColumn }"
        >
          <div>{{ $t('shop.dropship_col_product') }}</div>
          <div class="text-center">{{ $t('shop.qty') }}</div>
          <div class="text-right">{{ $t('shop.dropship_col_purchase') }}</div>
          <div class="text-right">{{ $t('shop.dropship_col_resell') }}</div>
          <div v-if="showRequestedColumn" class="text-right">{{ $t('shop.dropship_col_requested_resell') }}</div>
          <div class="text-right">{{ $t('shop.dropship_col_purchase_total') }}</div>
          <div class="text-right">{{ $t('shop.dropship_col_resell_total') }}</div>
        </div>
        <div
          v-for="item in items"
          :key="item.id"
          class="dropship-order-doc__table-row"
          :class="{ 'dropship-order-doc__table-row--with-requested': showRequestedColumn }"
        >
          <div class="min-width-0">
            <div class="text-body2 text-weight-medium text-grey-9 ellipsis-2-lines">{{ item.name }}</div>
          </div>
          <div class="text-center tf-num">{{ item.quantity }}</div>
          <div class="text-right tf-num text-grey-8">{{ formatMoney(item.purchasePrice) }}</div>
          <div class="text-right tf-num">{{ formatMoney(item.resellPrice) }}</div>
          <div v-if="showRequestedColumn" class="text-right tf-num">
            <span v-if="hasItemRequest(item)" class="dropship-order-doc__requested">
              {{ formatMoney(item.requestedResellDiscountPrice!) }}
            </span>
            <span v-else class="text-grey-5">—</span>
          </div>
          <div class="text-right tf-num text-weight-medium">{{ formatMoney(item.purchasePrice * item.quantity) }}</div>
          <div
            class="text-right tf-num text-weight-bold"
            :class="hasItemRequest(item) ? 'dropship-order-doc__resell-pending' : 'text-primary'"
          >
            {{ formatMoney(lineResellTotal(item)) }}
          </div>
        </div>
      </div>

      <div class="dropship-order-doc__totals q-mt-md">
        <div class="row justify-end">
          <div class="dropship-order-doc__totals-inner column q-gutter-y-xs">
            <div class="row justify-between items-baseline q-gutter-x-lg">
              <span class="text-body2 text-grey-7">{{ $t('shop.dropship_col_purchase_total') }}</span>
              <span class="text-body2 text-weight-bold tf-num">{{ formatMoney(totals.purchaseTotal) }}</span>
            </div>
            <div class="row justify-between items-baseline q-gutter-x-lg">
              <span class="text-body2 text-grey-7">{{ $t('shop.dropship_col_resell_total') }}</span>
              <span
                class="text-body2 text-weight-bold tf-num"
                :class="costSummary.hasPendingDiscount ? 'dropship-order-doc__resell-pending' : 'text-primary'"
              >
                {{ formatMoney(totals.resellTotal) }}
              </span>
            </div>
            <div
              v-if="costSummary.hasPendingDiscount"
              class="text-caption dropship-order-doc__pending-note"
            >
              {{ $t('shop.dropship_totals_pending_discount_note') }}
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="dropship-order-doc__rule" />

    <section class="dropship-order-doc__section">
      <h2 class="dropship-order-doc__section-title">{{ $t('shop.dropship_charge_options') }}</h2>
      <dl class="dropship-order-doc__dl dropship-order-doc__dl--compact">
        <div class="dropship-order-doc__dl-row">
          <dt>{{ $t('shop.dropship_recipient_pays_delivery') }}</dt>
          <dd>
            {{
              recipientPaysDelivery
                ? $t('shop.dropship_paid_by_recipient')
                : $t('shop.dropship_deducted_from_profit')
            }}
          </dd>
        </div>
        <div class="dropship-order-doc__dl-row">
          <dt>{{ $t('shop.dropship_recipient_pays_cod') }}</dt>
          <dd>
            {{
              recipientPaysCod
                ? $t('shop.dropship_paid_by_recipient')
                : $t('shop.dropship_deducted_from_profit')
            }}
          </dd>
        </div>
      </dl>
      <div class="dropship-order-doc__grand row items-baseline justify-between q-mt-md">
        <span class="text-subtitle2 text-weight-bold">{{ $t('shop.recipient_pay_total') }}</span>
        <span class="text-h6 text-weight-bold text-primary tf-num">
          {{ formatMoney(costSummary.recipientGrandTotal) }}
        </span>
      </div>
      <div class="text-caption text-grey-6 q-mt-xs">{{ $t('shop.dropship_courier_added_later') }}</div>
    </section>

    <div class="dropship-order-doc__rule" />

    <section class="dropship-order-doc__section">
      <h2 class="dropship-order-doc__section-title">{{ $t('shop.dropship_terms_title') }}</h2>
      <div class="dropship-order-doc__terms text-body2 text-grey-8">
        {{ $t('shop.dropship_terms_body') }}
      </div>
      <div
        v-if="termsAccepted"
        class="dropship-order-doc__terms-accepted q-mt-md row items-center no-wrap q-gutter-x-sm"
        role="status"
      >
        <q-icon name="ph ph-check-circle" color="positive" size="20px" />
        <span class="text-body2 text-grey-9">{{ $t('shop.dropship_terms_checkbox') }}</span>
      </div>
    </section>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatCartMoney } from '../../utils/cartPriceUtils';
import {
  effectiveResellUnitPrice,
  hasPendingResellDiscount,
} from '../../utils/dropshipReviewPricingUtils';
import type { DropshipReviewListItem } from '../ShopDropshipReviewItemsList.vue';

const props = defineProps<{
  customerForm: {
    recipientName: string;
    recipientPhone: string;
    secondaryPhone?: string;
    shippingAddress: string;
    district: string;
    thana: string;
    postCode?: string;
    deliveryInstructions?: string;
  };
  recipientPaysDelivery: boolean;
  recipientPaysCod: boolean;
  items: DropshipReviewListItem[];
  itemCount: number;
  totals: { purchaseTotal: number; resellTotal: number };
  costSummary: {
    recipientGrandTotal: number;
    hasPendingDiscount?: boolean;
  };
  currencySymbol: string;
  termsAccepted: boolean;
}>();

const formatMoney = (amount: number) =>
  formatCartMoney(amount, props.currencySymbol?.trim() || '৳');

const locationLine = computed(() => {
  const parts = [props.customerForm.district, props.customerForm.thana, props.customerForm.postCode]
    .map((p) => p?.trim())
    .filter(Boolean);
  return parts.length ? parts.join(' · ') : '';
});

const showRequestedColumn = computed(() =>
  props.items.some((item) => hasPendingResellDiscount(item.requestedResellDiscountPrice)),
);

const hasItemRequest = (item: DropshipReviewListItem) =>
  hasPendingResellDiscount(item.requestedResellDiscountPrice);

const lineResellTotal = (item: DropshipReviewListItem) =>
  effectiveResellUnitPrice(item.resellPrice, item.requestedResellDiscountPrice) * item.quantity;
</script>

<style scoped>
.dropship-order-doc {
  max-width: 840px;
  margin: 0 auto;
  padding: 1.25rem 1.35rem 1.5rem;
  border: 1px solid var(--tf-neutral-border, rgba(34, 56, 101, 0.12));
  border-radius: var(--tf-radius-md, 12px);
  background: var(--tf-theme-surface, #fff);
  box-shadow: 0 2px 16px rgba(34, 56, 101, 0.04);
}

.dropship-order-doc__header {
  text-align: center;
}

.dropship-order-doc__title {
  letter-spacing: 0.02em;
}

.dropship-order-doc__rule {
  height: 1px;
  margin: 1rem 0;
  background: var(--tf-neutral-border, rgba(34, 56, 101, 0.1));
}

.dropship-order-doc__section-title {
  margin: 0 0 0.65rem;
  font-size: 0.8125rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted, #6b7280);
}

.dropship-order-doc__dl {
  margin: 0;
}

.dropship-order-doc__dl-row {
  display: grid;
  grid-template-columns: minmax(7rem, 38%) 1fr;
  gap: 0.35rem 1rem;
  padding: 0.35rem 0;
  font-size: 0.9375rem;
}

.dropship-order-doc__dl-row--stack dd + dd {
  margin-top: 0.15rem;
}

.dropship-order-doc__dl-row dt {
  margin: 0;
  color: var(--tf-neutral-muted, #6b7280);
  font-weight: 500;
}

.dropship-order-doc__dl-row dd {
  margin: 0;
  color: var(--tf-neutral-ink, #1f2937);
  word-break: break-word;
}

.dropship-order-doc__dl--compact .dropship-order-doc__dl-row {
  padding: 0.2rem 0;
}

.dropship-order-doc__item-card {
  padding: 0.75rem;
  border: 1px solid var(--tf-neutral-border, rgba(34, 56, 101, 0.08));
  border-radius: var(--tf-radius-sm, 8px);
  background: color-mix(in srgb, var(--tf-theme-surface, #fff) 92%, var(--tf-neutral-border));
}

.dropship-order-doc__item-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(5.5rem, 1fr));
  gap: 0.5rem 0.75rem;
}

.dropship-order-doc__cell-label {
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-muted, #6b7280);
  margin-bottom: 0.15rem;
}

.dropship-order-doc__table-head,
.dropship-order-doc__table-row {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) 3rem 5.5rem 5.5rem 6.5rem 6.5rem;
  gap: 0.5rem 0.75rem;
  align-items: start;
  padding: 0.5rem 0;
  font-size: 0.875rem;
}

.dropship-order-doc__table-row--with-requested,
.dropship-order-doc__table-head.dropship-order-doc__table-row--with-requested {
  grid-template-columns: minmax(0, 1.4fr) 3rem 4.75rem 4.75rem 5.5rem 5.25rem 5.25rem;
}

.dropship-order-doc__table-head {
  border-bottom: 1px solid var(--tf-neutral-border, rgba(34, 56, 101, 0.1));
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tf-neutral-muted, #6b7280);
  font-weight: 600;
}

.dropship-order-doc__table-row + .dropship-order-doc__table-row {
  border-top: 1px dashed rgba(34, 56, 101, 0.08);
}

.dropship-order-doc__totals-inner {
  min-width: min(100%, 280px);
}

.dropship-order-doc__requested,
.dropship-order-doc__resell-pending {
  color: color-mix(in srgb, var(--tf-warning, #d97706) 80%, var(--tf-neutral-ink, #1f2937));
}

.dropship-order-doc__pending-note {
  color: var(--tf-neutral-muted, #6b7280);
  text-align: right;
}

.dropship-order-doc__terms {
  white-space: pre-line;
  line-height: 1.55;
}

.dropship-order-doc__terms-accepted {
  padding: 0.65rem 0.75rem;
  border-radius: var(--tf-radius-sm, 8px);
  background: color-mix(in srgb, var(--q-positive, #21ba45) 8%, var(--tf-theme-surface, #fff));
  border: 1px solid color-mix(in srgb, var(--q-positive, #21ba45) 22%, transparent);
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>