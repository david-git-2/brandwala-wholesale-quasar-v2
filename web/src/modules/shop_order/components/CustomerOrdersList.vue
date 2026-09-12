<template>
  <q-card v-if="loading" flat bordered class="order-table-card">
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
    v-else-if="orders.length === 0 && emptyLabel"
    class="order-table-card order-table-card--empty text-body2 text-grey-6 text-center q-pa-md"
  >
    {{ emptyLabel }}
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
  status: ShopOrderStatus | string;
  created_at: string;
  shop_type_snapshot?: ShopType | string | null;
  is_negotiable_snapshot?: boolean;
};

withDefaults(
  defineProps<{
    orders: CustomerOrderListRow[];
    loading?: boolean;
    emptyLabel?: string;
    skeletonCount?: number;
    showCopyButton?: boolean;
    showPricingBadge?: boolean;
  }>(),
  {
    loading: false,
    skeletonCount: 5,
    showCopyButton: true,
    showPricingBadge: true,
  },
);

const emit = defineEmits<{
  select: [order: CustomerOrderListRow];
}>();

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
</script>

<style scoped>
.order-table-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  box-shadow: var(--bw-theme-shadow, 0 2px 8px rgba(0, 0, 0, 0.04));
}

.order-table-card--empty {
  border: 1px solid var(--bw-theme-border, rgb(0 0 0 / 0.12));
}

.order-item {
  transition: background-color 0.15s ease;
}

.order-item:hover {
  background-color: var(--bw-theme-primary-soft);
}

.order-waiting {
  box-shadow: inset 3px 0 0 var(--q-warning, #f2c037);
}

.status-badge {
  border-radius: 6px;
  letter-spacing: 0.3px;
  font-size: 11px;
}
</style>
