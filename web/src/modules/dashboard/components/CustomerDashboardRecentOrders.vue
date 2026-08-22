<template>
  <div>
    <div class="row items-center justify-between q-mb-sm">
      <span class="text-subtitle1 text-weight-bold">{{ $t('customer_dashboard.recent_orders_title') }}</span>
      <q-btn
        v-if="recentOrders.length > 0"
        flat
        no-caps
        dense
        color="primary"
        :label="$t('customer_dashboard.view_all_orders')"
        icon-right="chevron_right"
        @click="$emit('go-orders')"
      />
    </div>

    <div v-if="loading" class="q-gutter-y-sm">
      <q-card v-for="n in 5" :key="n" flat bordered class="q-pa-md">
        <div class="row items-center justify-between">
          <div>
            <q-skeleton type="text" width="110px" height="18px" class="q-mb-xs" />
            <q-skeleton type="text" width="80px" height="14px" />
          </div>
          <q-skeleton type="QBadge" width="90px" height="22px" />
        </div>
      </q-card>
    </div>

    <q-banner v-else-if="error" class="bw-status-banner bg-negative text-white" rounded>
      {{ error }}
    </q-banner>

    <q-card v-else-if="recentOrders.length === 0" flat bordered class="recent-orders-card q-pa-lg text-center">
      <div class="text-body2 text-grey-6">{{ $t('customer_dashboard.no_recent_orders') }}</div>
    </q-card>

    <q-card v-else flat bordered class="recent-orders-card">
      <q-list separator>
        <q-item
          v-for="order in recentOrders"
          :key="order.id"
          clickable
          class="q-py-md card-hover"
          :class="{ 'order-waiting': isWaiting(order.status) }"
          @click="$emit('view-order-detail', order.id)"
        >
          <q-item-section>
            <div class="row items-center justify-between no-wrap q-col-gutter-sm">
              <div class="column">
                <span class="text-weight-bold">{{ order.order_no }}</span>
                <span class="text-caption text-grey-6">{{ order.shop_name }}</span>
              </div>
              <div class="column text-right">
                <span class="text-subtitle2 text-weight-bold text-primary">
                  {{ order.currency_symbol || '৳' }}{{ Number(order.total_amount || 0).toFixed(2) }}
                </span>
                <span class="text-caption text-grey-6">{{ formatDate(order.created_at) }}</span>
              </div>
              <q-badge
                :color="statusColor(order.status)"
                :outline="!isWaiting(order.status)"
                class="q-py-xs q-px-sm text-weight-medium"
              >
                {{ statusLabel(order.status) }}
              </q-badge>
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { date } from 'quasar';
import { useI18n } from 'vue-i18n';
import { isWaitingStatus, waitingActionI18nKey } from '../utils/customerDashboardStatus';

defineProps<{
  recentOrders: Array<{
    id: number;
    order_no?: string;
    shop_name?: string;
    shop_id?: number;
    status: string;
    total_amount?: number;
    currency_symbol?: string | null;
    created_at?: string;
  }>;
  loading: boolean;
  error: string | null;
}>();

defineEmits<{
  (e: 'go-orders'): void;
  (e: 'view-order-detail', orderId: number): void;
}>();

const { t, te } = useI18n();

const isWaiting = isWaitingStatus;

const formatDate = (dateStr?: string) => {
  if (!dateStr) return '';
  return date.formatDate(dateStr, 'D MMM YYYY');
};

const statusLabel = (status: string) => {
  const actionKey = waitingActionI18nKey(status);
  if (actionKey) return t(actionKey);
  const key = `shop_admin.status_${status}`;
  return te(key) ? t(key) : status.replaceAll('_', ' ');
};

const statusColor = (status: string) => {
  if (isWaitingStatus(status)) return 'amber-9';
  if (status === 'cancelled' || status === 'returned') return 'negative';
  if (status === 'confirmed' || status === 'delivered' || status === 'payment_received') {
    return 'positive';
  }
  return 'primary';
};
</script>

<style scoped>
.recent-orders-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  overflow: hidden;
}

.order-waiting {
  box-shadow: inset 3px 0 0 var(--q-warning, #f2c037);
}
</style>
