<template>
  <q-card v-if="loading && !isTableLayout" flat bordered class="order-table-card">
    <q-list separator>
      <q-item v-for="n in skeletonCount" :key="n" class="q-py-md">
        <q-item-section>
          <div class="row items-center justify-between no-wrap q-col-gutter-sm">
            <div class="column">
              <q-skeleton type="text" width="110px" height="18px" class="q-mb-xs" />
              <q-skeleton type="text" width="80px" height="14px" />
            </div>
            <q-skeleton type="QBadge" width="90px" height="22px" />
          </div>
        </q-item-section>
      </q-item>
    </q-list>
  </q-card>

  <div
    v-else-if="loading && isTableLayout"
    class="order-table-dashboard"
    :class="tableLayoutClass"
  >
    <div v-for="n in skeletonCount" :key="n" class="order-table-dashboard__row order-table-dashboard__row--body">
      <q-skeleton type="text" width="80%" height="16px" />
      <q-skeleton type="text" width="70%" height="16px" />
      <q-skeleton v-if="hasDetailColumns" type="text" width="52px" height="16px" />
      <q-skeleton v-if="hasDetailColumns" type="text" width="72px" height="16px" class="justify-self-end" />
      <q-skeleton type="text" width="60%" height="16px" />
      <q-skeleton type="text" width="72px" height="22px" class="justify-self-end" />
    </div>
  </div>

  <div
    v-else-if="orders.length === 0 && emptyLabel"
    :class="isTableLayout ? 'order-table-dashboard order-table-dashboard--empty' : 'order-table-card order-table-card--empty text-body2 text-grey-6 text-center q-pa-md'"
  >
    {{ emptyLabel }}
  </div>

  <div v-else-if="isTableLayout" class="order-table-dashboard" :class="tableLayoutClass">
    <div class="order-table-dashboard__row order-table-dashboard__row--head" aria-hidden="true">
      <span>{{ $t('customer_dashboard.orders_col_id') }}</span>
      <span>{{ $t('customer_dashboard.orders_col_shop') }}</span>
      <span v-if="hasDetailColumns">{{ $t('customer_dashboard.orders_col_items') }}</span>
      <span v-if="hasDetailColumns" class="order-table-dashboard__head-total">{{ $t('customer_dashboard.orders_col_total') }}</span>
      <span>{{ $t('customer_dashboard.orders_col_date') }}</span>
      <span class="order-table-dashboard__head-status">{{ $t('customer_dashboard.orders_col_status') }}</span>
    </div>

    <div
      v-for="order in orders"
      :key="order.id"
      class="order-table-dashboard__row order-table-dashboard__row--body cursor-pointer"
      :class="{ 'order-table-dashboard__row--waiting': layout === 'page' && isWaitingStatus(order.status) }"
      role="button"
      tabindex="0"
      :data-test="`customer-order-row-${order.id}`"
      @click="emit('select', order)"
      @keydown.enter.prevent="emit('select', order)"
      @keydown.space.prevent="emit('select', order)"
    >
      <div class="order-table-dashboard__id-cell">
        <div class="order-table-dashboard__id-row">
          <span class="order-table-dashboard__id tf-num">
            {{ order.order_no }}
          </span>
          <q-btn
            v-if="showCopyButton"
            flat
            dense
            size="xs"
            icon="ph ph-copy"
            :ripple="false"
            class="order-table-dashboard__copy-btn"
            :aria-label="$t('shop_admin.copy_order_no')"
            @click.stop="copyOrderNo(order.order_no)"
          />
          <OrderPricingModeBadge
            v-if="shouldShowPricingBadge(order)"
            :variant="pricingBadgeVariant"
            :subtle-fixed="pricingBadgeSubtleFixed"
            :is-negotiable="!!order.is_negotiable_snapshot"
            :shop-type="order.shop_type_snapshot"
          />
        </div>
      </div>
      <div class="order-table-dashboard__shop-cell column min-width-0">
        <span class="order-table-dashboard__shop ellipsis">
          {{ order.shop_name }}
        </span>
        <span v-if="placementCaption(order)" class="text-caption tf-text-muted ellipsis">
          {{ placementCaption(order) }}
        </span>
      </div>
      <span v-if="hasDetailColumns" class="order-table-dashboard__items tf-num">
        {{ formatItemsCount(order.item_count) }}
      </span>
      <span v-if="hasDetailColumns" class="order-table-dashboard__total tf-num">
        {{ formatOrderTotal(order) }}
      </span>
      <span class="order-table-dashboard__date tf-num" :title="formatFullDate(order.created_at)">
        {{ layout === 'page' ? formatRelativeOrShortDate(order.created_at) : formatDate(order.created_at) }}
      </span>
      <div class="order-table-dashboard__status">
        <span class="order-status-pill" :class="statusPillClass(order.status)">
          {{ statusLabel(order.status) }}
        </span>
        <q-icon
          v-if="layout === 'page'"
          name="ph ph-caret-right"
          size="14px"
          class="order-table-dashboard__chevron"
          aria-hidden="true"
        />
      </div>
    </div>
  </div>

  <q-card v-else-if="orders.length > 0" flat bordered class="order-table-card">
    <q-list separator>
      <q-item
        v-for="order in orders"
        :key="order.id"
        clickable
        v-ripple
        class="q-py-md order-item"
        :class="{ 'order-waiting': isWaitingStatus(order.status) }"
        :data-test="`customer-order-row-${order.id}`"
        @click="emit('select', order)"
      >
        <q-item-section>
          <div class="row items-center justify-between no-wrap q-col-gutter-sm">
            <div class="column overflow-hidden">
              <div class="row items-center no-wrap q-gutter-x-xs">
                <span class="text-weight-bold ellipsis">{{ order.order_no }}</span>
                <OrderPricingModeBadge
                  v-if="showPricingBadge"
                  :is-negotiable="!!order.is_negotiable_snapshot"
                  :shop-type="order.shop_type_snapshot"
                />
                <q-btn
                  v-if="showCopyButton"
                  flat
                  dense
                  round
                  size="sm"
                  icon="ph ph-copy"
                  color="grey-6"
                  :aria-label="$t('shop_admin.copy_order_no')"
                  @click.stop="copyOrderNo(order.order_no)"
                />
              </div>
              <span class="text-caption text-grey-6 ellipsis">{{ order.shop_name }}</span>
              <span v-if="placementCaption(order)" class="text-caption text-grey-7 ellipsis">
                {{ placementCaption(order) }}
              </span>
            </div>
            <div class="column text-right">
              <span class="text-caption text-grey-6">{{ formatDate(order.created_at) }}</span>
            </div>
            <q-badge
              :color="getStatusColor(order.status)"
              :outline="!isWaitingStatus(order.status)"
              class="status-badge text-weight-medium q-py-xs q-px-sm"
            >
              {{ statusLabel(order.status) }}
            </q-badge>
          </div>
        </q-item-section>
      </q-item>
    </q-list>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { copyToClipboard, date } from 'quasar';
import { showSuccessNotification } from 'src/utils/appFeedback';
import {
  isWaitingStatus,
  waitingActionI18nKey,
} from 'src/modules/workspace/submodules/dashboard/utils/customerDashboardStatus';
import type { ShopOrderStatus, ShopType } from '../types';
import OrderPricingModeBadge from './OrderPricingModeBadge.vue';
import { orderPlacementCaption } from '../utils/orderPlacementCaption';

export type CustomerOrderListRow = {
  id: number;
  order_no: string;
  shop_name: string;
  shop_id?: number;
  shop_slug?: string;
  status: ShopOrderStatus | (string & {});
  created_at: string;
  item_count?: number | null;
  total_amount?: number | null;
  currency_symbol?: string | null;
  can_see_sell_price?: boolean;
  shop_type_snapshot?: ShopType | (string & {}) | null;
  is_negotiable_snapshot?: boolean;
  placement_scope?: 'shop' | 'app';
  created_by_email?: string;
};

const props = withDefaults(
  defineProps<{
    orders: CustomerOrderListRow[];
    loading?: boolean;
    emptyLabel?: string;
    skeletonCount?: number;
    showCopyButton?: boolean;
    showPricingBadge?: boolean;
    pricingBadgeVariant?: 'badge' | 'text';
    /** Softer fixed-pricing chip in table layout (shop orders page). */
    pricingBadgeSubtleFixed?: boolean;
    showOrderDetailsColumns?: boolean;
    layout?: 'default' | 'dashboard' | 'page';
  }>(),
  {
    loading: false,
    skeletonCount: 5,
    showCopyButton: true,
    showPricingBadge: true,
    pricingBadgeVariant: 'badge',
    pricingBadgeSubtleFixed: false,
    showOrderDetailsColumns: false,
    layout: 'default',
  },
);

const emit = defineEmits<{
  select: [order: CustomerOrderListRow];
}>();

const isTableLayout = computed(
  () => props.layout === 'dashboard' || props.layout === 'page',
);
const hasDetailColumns = computed(
  () => props.layout === 'page' && props.showOrderDetailsColumns,
);
const tableLayoutClass = computed(() => ({
  'order-table-dashboard--page': props.layout === 'page',
  'order-table-dashboard--with-details': hasDetailColumns.value,
}));

const i18n = useI18n();
const { t } = i18n;

const formatDate = (dateStr: string) => date.formatDate(dateStr, 'D MMM YYYY');
const formatFullDate = (dateStr: string) => date.formatDate(dateStr, 'D MMM YYYY, HH:mm');

const formatRelativeOrShortDate = (dateStr: string) => {
  const parsed = new Date(dateStr);
  if (Number.isNaN(parsed.getTime())) return formatDate(dateStr);
  const diffDays = date.getDateDiff(new Date(), parsed, 'days');
  if (diffDays === 0) return date.formatDate(parsed, 'HH:mm');
  if (diffDays === 1) return '1d ago';
  if (diffDays > 1 && diffDays < 7) return `${diffDays}d ago`;
  return formatDate(dateStr);
};

const formatItemsCount = (count: number | null | undefined) => {
  if (count == null || !Number.isFinite(count)) return '—';
  return t('shop_admin.items_count_value', { count });
};

const formatOrderTotal = (order: CustomerOrderListRow) => {
  if (order.can_see_sell_price === false || order.total_amount == null) return '—';
  const amount = Number(order.total_amount);
  if (!Number.isFinite(amount)) return '—';
  const symbol = order.currency_symbol?.trim() || '৳';
  return `${symbol} ${amount.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
};

const shouldShowPricingBadge = (order: CustomerOrderListRow) => {
  if (!props.showPricingBadge) return false;
  if (props.layout === 'page' && props.pricingBadgeSubtleFixed) {
    return Boolean(order.is_negotiable_snapshot);
  }
  return true;
};

const placementCaption = (order: CustomerOrderListRow) =>
  orderPlacementCaption(t, order.placement_scope, order.created_by_email);

const copyOrderNo = (orderNo: string) => {
  void copyToClipboard(orderNo).then(() => {
    showSuccessNotification(t('shop_admin.order_no_copied'));
  });
};

const statusLabel = (status: string) => {
  const actionKey = waitingActionI18nKey(status);
  if (actionKey) return t(actionKey);
  const key = `shop_admin.status_${status}`;
  return i18n.te(key) ? t(key) : status.replaceAll('_', ' ');
};

const getStatusColor = (status: string) => {
  if (isWaitingStatus(status)) return 'amber-9';
  if (status === 'cancelled' || status === 'returned') return 'negative';
  if (status === 'confirmed' || status === 'delivered' || status === 'payment_received') {
    return 'positive';
  }
  return 'primary';
};

const statusPillClass = (status: string) => {
  if (status === 'confirmed' || status === 'delivered' || status === 'payment_received') {
    return 'order-status-pill--confirmed';
  }
  if (status === 'submitted') return 'order-status-pill--submitted';
  if (isWaitingStatus(status)) return 'order-status-pill--attention';
  if (status === 'cancelled' || status === 'returned') return 'order-status-pill--bad';
  if (status === 'shipped') return 'order-status-pill--shipped';
  if (status === 'packed' || status === 'processing' || status === 'procuring' || status === 'placed') {
    return 'order-status-pill--progress';
  }
  return 'order-status-pill--neutral';
};
</script>

<style scoped>
.order-table-card {
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-theme-surface);
  border: 1px solid var(--tf-neutral-border);
  box-shadow: none;
}

.order-table-card--empty {
  border: 1px solid var(--tf-theme-border, rgb(0 0 0 / 0.12));
}

.order-item {
  transition: background-color 0.15s ease;
}

.order-item:hover {
  background-color: var(--tf-theme-primary-soft);
}

.order-waiting {
  box-shadow: inset 3px 0 0 var(--q-warning, #f2c037);
}

.status-badge {
  border-radius: 6px;
  letter-spacing: 0.3px;
  font-size: 11px;
}

.order-table-dashboard {
  min-width: 0;
}

.order-table-dashboard--empty {
  padding: 1rem 0;
  text-align: center;
  font-size: 0.875rem;
  color: var(--shop-home-date, #666);
}

.order-table-dashboard__row {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(0, 0.9fr) minmax(5.5rem, auto) minmax(5.25rem, auto);
  gap: 0.65rem;
  align-items: center;
  width: 100%;
  text-align: left;
}

.order-table-dashboard--page .order-table-dashboard__row {
  grid-template-columns:
    minmax(0, 25%)
    minmax(0, 1fr)
    7.5rem
    minmax(6.5rem, auto);
}

.order-table-dashboard--with-details .order-table-dashboard__row {
  grid-template-columns:
    minmax(0, 1.35fr)
    minmax(0, 1fr)
    5.5rem
    7.5rem
    6rem
    minmax(8.5rem, auto);
}

.order-table-dashboard__row--head {
  padding: 0 0 0.5rem;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text);
  border-bottom: 1px solid var(--tf-neutral-border);
}

.order-table-dashboard--page .order-table-dashboard__row--head {
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  color: var(--tf-neutral-chrome-text);
  border-bottom-color: var(--tf-neutral-border);
}

.order-table-dashboard__head-total {
  text-align: right;
}

.order-table-dashboard__row--head span:last-child,
.order-table-dashboard__head-status {
  text-align: right;
}

.order-table-dashboard__row--body {
  padding: 0.5rem 0;
  align-items: center;
  border-bottom: 1px solid var(--tf-neutral-border);
  cursor: pointer;
  transition: background-color var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.order-table-dashboard--page .order-table-dashboard__row--body {
  padding: 0.65rem 0.5rem;
  margin: 0 -0.5rem;
  border-radius: var(--tf-radius-sm);
  border-bottom-color: var(--tf-neutral-border);
  transition:
    background-color 0.16s ease,
    color 0.16s ease;
}

.order-table-dashboard--page .order-table-dashboard__row--waiting {
  background: var(--tf-warning-soft);
}

.order-table-dashboard__row--body:focus-visible {
  outline: 2px solid var(--q-primary);
  outline-offset: -2px;
}

.order-table-dashboard--page .order-table-dashboard__row--body:hover {
  background: var(--tf-theme-primary-soft);
}

.order-table-dashboard--page .order-table-dashboard__row--waiting:hover {
  background: var(--tf-warning-soft);
}

.order-table-dashboard__copy-btn {
  opacity: 0;
  color: var(--tf-neutral-muted);
  transition: opacity var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.order-table-dashboard__row--body:hover .order-table-dashboard__copy-btn,
.order-table-dashboard__row--body:focus-within .order-table-dashboard__copy-btn {
  opacity: 1;
}

.order-table-dashboard__items {
  font-size: 0.8125rem;
  color: var(--tf-neutral-muted);
  white-space: nowrap;
}

.order-table-dashboard__total {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--tf-neutral-ink);
  text-align: right;
  white-space: nowrap;
}

.order-table-dashboard__chevron {
  color: var(--tf-neutral-muted);
  opacity: 0.55;
  transition:
    transform var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    opacity var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.order-table-dashboard__row--body:hover .order-table-dashboard__chevron {
  opacity: 1;
  transform: translateX(2px);
}

.order-table-dashboard__link {
  border: 0;
  padding: 0;
  background: transparent;
  font: inherit;
  text-align: inherit;
  color: inherit;
  cursor: pointer;
}

.order-table-dashboard__row--body .order-table-dashboard__id,
.order-table-dashboard__row--body .order-table-dashboard__shop,
.order-table-dashboard__row--body .order-table-dashboard__date {
  cursor: pointer;
}

.order-table-dashboard__row--body:last-child {
  border-bottom: 0;
}

.order-table-dashboard__id-cell {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  min-width: 0;
}

.order-table-dashboard__id-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
  min-width: 0;
  max-width: 100%;
}

.order-table-dashboard__id {
  font-weight: 500;
  color: var(--tf-neutral-ink);
}

.order-table-dashboard--page .order-table-dashboard__id {
  font-weight: 600;
  color: var(--tf-neutral-ink);
  transition: color var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.order-table-dashboard--page .order-table-dashboard__row--body:hover .order-table-dashboard__id {
  color: var(--tf-theme-primary);
}

.order-table-dashboard__shop {
  font-size: 0.875rem;
  color: var(--tf-neutral-ink);
}

.order-table-dashboard--page .order-table-dashboard__shop {
  color: var(--tf-neutral-muted);
}

.order-table-dashboard__date {
  font-size: 0.8125rem;
  white-space: nowrap;
  color: var(--tf-neutral-muted);
}

.order-table-dashboard--page .order-table-dashboard__date {
  color: var(--tf-neutral-muted);
  font-variant-numeric: tabular-nums;
}

.order-table-dashboard__status {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.45rem;
}

@media (max-width: 639px) {
  .order-table-dashboard--with-details .order-table-dashboard__row--head {
    display: none;
  }

  .order-table-dashboard--with-details .order-table-dashboard__row--body {
    grid-template-columns: minmax(0, 1fr) auto;
    grid-template-areas:
      'id status'
      'shop total'
      'items date';
    gap: 0.25rem 0.75rem;
    padding: 0.75rem 0.5rem;
  }

  .order-table-dashboard--with-details .order-table-dashboard__id-cell {
    grid-area: id;
  }

  .order-table-dashboard--with-details .order-table-dashboard__status {
    grid-area: status;
  }

  .order-table-dashboard--with-details .order-table-dashboard__shop-cell {
    grid-area: shop;
  }

  .order-table-dashboard--with-details .order-table-dashboard__total {
    grid-area: total;
  }

  .order-table-dashboard--with-details .order-table-dashboard__items {
    grid-area: items;
  }

  .order-table-dashboard--with-details .order-table-dashboard__date {
    grid-area: date;
    text-align: right;
  }

  .order-table-dashboard__copy-btn {
    opacity: 1;
  }
}

.order-status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 2px 10px;
  border-radius: var(--tf-radius-sm, 8px);
  font-size: 0.75rem;
  font-weight: 500;
  line-height: 1.25;
  white-space: nowrap;
  border: 1px solid transparent;
}

.order-table-dashboard--page .order-status-pill {
  padding: 2px 10px;
  font-size: 0.75rem;
  font-weight: 500;
}

.order-status-pill--confirmed {
  color: #047857;
  background: #ecfdf5;
  border-color: rgb(167 243 208 / 0.6);
}

.order-status-pill--submitted {
  color: #0369a1;
  background: #f0f9ff;
  border-color: rgb(186 230 253 / 0.6);
}

.order-status-pill--attention {
  color: #b45309;
  background: #fffbeb;
  border-color: rgb(253 230 138 / 0.6);
}

.order-status-pill--shipped {
  color: #334155;
  background: #f1f5f9;
  border-color: #e2e8f0;
}

.order-status-pill--bad {
  color: #b91c1c;
  background: #fef2f2;
  border-color: rgb(252 165 165 / 0.55);
}

.order-status-pill--progress {
  color: #4338ca;
  background: #eef2ff;
  border-color: rgb(199 210 254 / 0.65);
}

.order-status-pill--neutral {
  color: #475569;
  background: #f8fafc;
  border-color: #e2e8f0;
}

body.body--dark .order-status-pill--confirmed {
  color: #86efac;
  background: rgba(34, 197, 94, 0.14);
  border-color: rgba(34, 197, 94, 0.35);
}

body.body--dark .order-status-pill--submitted {
  color: #7dd3fc;
  background: rgba(14, 165, 233, 0.14);
  border-color: rgba(14, 165, 233, 0.35);
}

body.body--dark .order-status-pill--attention {
  color: #fcd34d;
  background: rgba(245, 158, 11, 0.14);
  border-color: rgba(245, 158, 11, 0.35);
}

body.body--dark .order-status-pill--shipped {
  color: #cbd5e1;
  background: rgba(148, 163, 184, 0.12);
  border-color: rgba(148, 163, 184, 0.28);
}

body.body--dark .order-status-pill--bad {
  color: #fca5a5;
  background: rgba(239, 68, 68, 0.14);
  border-color: rgba(239, 68, 68, 0.35);
}

body.body--dark .order-status-pill--progress {
  color: #a5b4fc;
  background: rgba(99, 102, 241, 0.14);
  border-color: rgba(99, 102, 241, 0.35);
}

body.body--dark .order-status-pill--neutral {
  color: #94a3b8;
  background: rgba(148, 163, 184, 0.1);
  border-color: rgba(148, 163, 184, 0.25);
}
</style>
