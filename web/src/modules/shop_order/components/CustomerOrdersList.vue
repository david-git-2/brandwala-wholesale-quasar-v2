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

  <div v-else-if="loading && isTableLayout" class="order-table-dashboard" :class="tableLayoutClass">
    <div v-for="n in skeletonCount" :key="n" class="order-table-dashboard__row order-table-dashboard__row--body">
      <q-skeleton type="text" width="80%" height="16px" />
      <q-skeleton type="text" width="70%" height="16px" />
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
      <span>{{ $t('customer_dashboard.orders_col_date') }}</span>
      <span class="order-table-dashboard__head-status">{{ $t('customer_dashboard.orders_col_status') }}</span>
    </div>

    <div
      v-for="order in orders"
      :key="order.id"
      class="order-table-dashboard__row order-table-dashboard__row--body cursor-pointer"
      role="button"
      tabindex="0"
      :data-test="`customer-order-row-${order.id}`"
      @click="emit('select', order)"
      @keydown.enter.prevent="emit('select', order)"
      @keydown.space.prevent="emit('select', order)"
    >
      <div class="order-table-dashboard__id-cell">
        <div class="order-table-dashboard__id-row">
          <span class="order-table-dashboard__id">
            {{ order.order_no }}
          </span>
          <OrderPricingModeBadge
            v-if="showPricingBadge"
            :variant="pricingBadgeVariant"
            :subtle-fixed="pricingBadgeSubtleFixed"
            :is-negotiable="!!order.is_negotiable_snapshot"
            :shop-type="order.shop_type_snapshot"
          />
        </div>
      </div>
      <span class="order-table-dashboard__shop ellipsis">
        {{ order.shop_name }}
      </span>
      <span class="order-table-dashboard__date tf-num">
        {{ formatDate(order.created_at) }}
      </span>
      <div class="order-table-dashboard__status">
        <span class="order-status-pill" :class="statusPillClass(order.status)">
          {{ statusLabel(order.status) }}
        </span>
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
} from 'src/modules/dashboard/utils/customerDashboardStatus';
import type { ShopOrderStatus, ShopType } from '../types';
import OrderPricingModeBadge from './OrderPricingModeBadge.vue';

export type CustomerOrderListRow = {
  id: number;
  order_no: string;
  shop_name: string;
  shop_id?: number;
  shop_slug?: string;
  status: ShopOrderStatus | string;
  created_at: string;
  shop_type_snapshot?: ShopType | string | null;
  is_negotiable_snapshot?: boolean;
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
    layout?: 'default' | 'dashboard' | 'page';
  }>(),
  {
    loading: false,
    skeletonCount: 5,
    showCopyButton: true,
    showPricingBadge: true,
    pricingBadgeVariant: 'badge',
    pricingBadgeSubtleFixed: false,
    layout: 'default',
  },
);

const emit = defineEmits<{
  select: [order: CustomerOrderListRow];
}>();

const isTableLayout = computed(
  () => props.layout === 'dashboard' || props.layout === 'page',
);
const tableLayoutClass = computed(() => ({
  'order-table-dashboard--page': props.layout === 'page',
}));

const { t, te } = useI18n();

const formatDate = (dateStr: string) => date.formatDate(dateStr, 'D MMM YYYY');

const copyOrderNo = (orderNo: string) => {
  void copyToClipboard(orderNo).then(() => {
    showSuccessNotification(t('shop_admin.order_no_copied'));
  });
};

const statusLabel = (status: string) => {
  const actionKey = waitingActionI18nKey(status);
  if (actionKey) return t(actionKey);
  const key = `shop_admin.status_${status}`;
  return te(key) ? t(key) : status.replaceAll('_', ' ');
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
  border-radius: 12px;
  background: var(--tf-theme-surface);
  border: 1px solid #e2e8f0;
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
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr) minmax(0, 0.85fr) minmax(5.5rem, auto);
  gap: 0.75rem;
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
  color: #64748b;
  border-bottom-color: #e2e8f0;
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

.order-table-dashboard--page .order-table-dashboard__row--head {
  border-bottom-color: var(--tf-neutral-border);
}

.order-table-dashboard--page .order-table-dashboard__row--body {
  padding: 0.55rem 0.35rem;
  margin: 0 -0.35rem;
  border-radius: var(--tf-radius-sm);
  border-bottom-color: #e2e8f0;
  transition:
    background-color 0.18s ease,
    color 0.18s ease;
}

.order-table-dashboard__row--body:focus-visible {
  outline: 2px solid var(--q-primary);
  outline-offset: -2px;
}

.order-table-dashboard--page .order-table-dashboard__row--body:hover {
  background: rgb(248 250 252 / 0.7);
}

body.body--dark .order-table-dashboard--page .order-table-dashboard__row--body:hover {
  background: rgba(255, 255, 255, 0.05);
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
  color: #0f172a;
  transition: color var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.order-table-dashboard--page .order-table-dashboard__row--body:hover .order-table-dashboard__id {
  color: var(--tf-theme-primary);
}

body.body--dark .order-table-dashboard--page .order-table-dashboard__id {
  color: var(--tf-neutral-ink);
}

.order-table-dashboard__shop {
  font-size: 0.875rem;
  color: var(--tf-neutral-ink);
}

.order-table-dashboard--page .order-table-dashboard__shop {
  color: #475569;
}

body.body--dark .order-table-dashboard--page .order-table-dashboard__shop {
  color: var(--tf-neutral-muted);
}

.order-table-dashboard__date {
  font-size: 0.875rem;
  color: var(--tf-neutral-muted);
}

.order-table-dashboard--page .order-table-dashboard__date {
  color: #475569;
  font-variant-numeric: tabular-nums;
}

body.body--dark .order-table-dashboard--page .order-table-dashboard__date {
  color: var(--tf-neutral-muted);
}

.order-table-dashboard__status {
  display: flex;
  justify-content: flex-end;
}

.order-status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 2px 10px;
  border-radius: 9999px;
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
