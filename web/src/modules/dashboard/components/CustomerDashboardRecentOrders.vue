<template>
  <div>
    <h3 class="shop-home-section__subtitle q-my-none q-mb-sm">
      {{ $t('customer_dashboard.recent_orders_title') }}
    </h3>

    <q-card flat class="recent-orders-card">
      <q-list separator>
        <q-item
          v-for="order in displayOrders"
          :key="order.id"
          class="q-py-md recent-order-row"
          :class="{ 'order-waiting': isWaiting(order.status) }"
        >
          <q-item-section>
            <div class="row items-center justify-between no-wrap q-col-gutter-sm">
              <div class="column">
                <span class="text-weight-bold">{{ order.order_no }}</span>
                <span class="text-caption text-grey-6">{{ order.shop_name }}</span>
              </div>
              <div class="column text-right">
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

    <div class="row justify-center q-mt-sm">
      <q-btn
        unelevated
        no-caps
        dense
        class="shop-ds-cta"
        :label="$t('customer_dashboard.view_all_orders')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { date } from 'quasar';
import { useI18n } from 'vue-i18n';
import type { CustomerDashboardRecentOrder } from '../types/customerDashboard';
import { isWaitingStatus, waitingActionI18nKey } from '../utils/customerDashboardStatus';

const props = defineProps<{
  recentOrders: CustomerDashboardRecentOrder[];
}>();

const { t, te } = useI18n();

const displayOrders = computed(() => props.recentOrders.slice(0, 5));

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
.shop-home-section__subtitle {
  text-align: center;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--bw-shop-plum);
}

.recent-orders-card {
  border-radius: var(--bw-shop-radius-card, 20px);
  background: var(--bw-theme-surface);
  overflow: hidden;
  box-shadow: var(--bw-theme-shadow);
}

.recent-order-row {
  cursor: default;
}

.order-waiting {
  box-shadow: inset 3px 0 0 var(--q-warning, #f2c037);
}
</style>
