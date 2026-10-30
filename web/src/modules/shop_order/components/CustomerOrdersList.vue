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
      class="order-table-dashboard__row order-table-dashboard__row--body"
      :data-test="`customer-order-row-${order.id}`"
    >
      <div class="order-table-dashboard__id-cell">
        <button
          type="button"
          class="order-table-dashboard__link order-table-dashboard__id"
          @click="emit('select', order)"
        >
          {{ order.order_no }}
        </button>
        <OrderPricingModeBadge
          v-if="showPricingBadge"
          :variant="pricingBadgeVariant"
          :is-negotiable="!!order.is_negotiable_snapshot"
          :shop-type="order.shop_type_snapshot"
        />
      </div>
      <button
        type="button"
        class="order-table-dashboard__link order-table-dashboard__shop ellipsis"
        @click="emit('select', order)"
      >
        {{ order.shop_name }}
      </button>
      <button
        type="button"
        class="order-table-dashboard__link order-table-dashboard__date"
        @click="emit('select', order)"
      >
        {{ formatDate(order.created_at) }}
      </button>
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
    layout?: 'default' | 'dashboard' | 'page';
  }>(),
  {
    loading: false,
    skeletonCount: 5,
    showCopyButton: true,
    showPricingBadge: true,
    pricingBadgeVariant: 'badge',
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
  return 'order-status-pill--progress';
};
</script>

<style scoped>
.order-table-card {
  border-radius: 12px;
  background: var(--tf-theme-surface);
  box-shadow: var(--tf-theme-shadow, 0 2px 8px rgba(0, 0, 0, 0.04));
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

.order-table-dashboard__row--head {
  padding: 0 0 0.5rem;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--shop-home-date, #666);
  border-bottom: 1px solid rgb(0 0 0 / 0.06);
}

.order-table-dashboard__row--head span:last-child,
.order-table-dashboard__head-status {
  text-align: right;
}

.order-table-dashboard__row--body {
  padding: 0.5rem 0;
  align-items: center;
  border-bottom: 1px solid rgb(0 0 0 / 0.05);
}

.order-table-dashboard--page .order-table-dashboard__row--head {
  border-bottom-color: #e5e7eb;
}

.order-table-dashboard--page .order-table-dashboard__row--body {
  padding: 0.55rem 0.2rem;
  margin: 0 -0.2rem;
  border-radius: 6px;
  border-bottom-color: #e5e7eb;
  transition: background-color 0.15s ease;
}

.order-table-dashboard--page .order-table-dashboard__row--body:hover {
  background: #f9fafb;
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

.order-table-dashboard__id {
  font-weight: 500;
  color: var(--shop-home-ink-strong, #111);
}

.order-table-dashboard__shop {
  color: var(--shop-home-ink, #1a1a1a);
}

.order-table-dashboard__date {
  font-weight: 500;
  color: #4b5563;
  font-size: 0.875rem;
}

.order-table-dashboard__status {
  display: flex;
  justify-content: flex-end;
}

.order-status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 4.75rem;
  padding: 0.2rem 0.55rem;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  line-height: 1.2;
  color: #fff;
  white-space: nowrap;
}

.order-status-pill--confirmed {
  background: #1a7f4b;
}

.order-status-pill--submitted {
  background: #2b5fa8;
}

.order-status-pill--attention {
  background: #b45309;
}

.order-status-pill--bad {
  background: #b83a3a;
}

.order-status-pill--progress {
  background: #4b5563;
}
</style>
