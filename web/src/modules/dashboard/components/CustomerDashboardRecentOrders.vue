<template>
  <div>
    <div class="row items-center justify-between q-mb-sm q-mb-md-md">
      <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('customer_dashboard.recent_activity') }}</span>
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

    <div v-if="recentOrders.length === 0" class="empty-orders-block q-pa-lg q-pa-sm-xl text-center border-dashed-1">
      <q-icon name="ph ph-shopping-cart" size="48px" color="grey-3" class="q-mb-sm" />
      <div class="text-subtitle2 text-grey-6">{{ $t('customer_dashboard.no_recent_orders') }}</div>
      <q-btn
        unelevated
        color="primary"
        :label="$t('customer_dashboard.browse_catalog')"
        no-caps
        class="q-mt-md"
        @click="$emit('go-browse')"
      />
    </div>

    <q-card v-else flat bordered class="recent-orders-card">
      <q-list separator>
        <q-item
          v-for="order in recentOrders"
          :key="order.id"
          clickable
          class="q-py-md card-hover"
          @click="$emit('view-order-detail', order.id)"
        >
          <q-item-section>
            <div class="row items-center justify-between no-wrap q-col-gutter-sm">
              <div class="column">
                <span class="text-weight-bold text-grey-9">{{ order.order_no }}</span>
                <span class="text-caption text-grey-6">{{ order.shop_name }}</span>
              </div>
              <div class="column text-right">
                <span class="text-subtitle2 text-weight-bold text-primary">
                  {{ getCurrencySymbol(order) }}{{ Number(order.total_amount || 0).toFixed(2) }}
                </span>
                <span class="text-caption text-grey-6">{{ formatDate(order.created_at) }}</span>
              </div>
              <div class="q-pl-xs q-pl-sm-sm">
                <q-badge
                  :color="getStatusColor(order.status)"
                  text-color="white"
                  class="q-py-xs q-px-sm text-weight-bold"
                  style="border-radius: 6px;"
                >
                  {{ order.status.toUpperCase() }}
                </q-badge>
              </div>
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { date } from 'quasar';

defineProps<{
  recentOrders: any[];
  getCurrencySymbol: (order?: { shop_id?: number }) => string;
}>();

defineEmits<{
  (e: 'go-orders'): void;
  (e: 'go-browse'): void;
  (e: 'view-order-detail', orderId: number): void;
}>();

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY');
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<style scoped>
.recent-orders-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
  overflow: hidden;
}

.empty-orders-block {
  border: 2px dashed var(--bw-theme-border, #e0e0e0);
  border-radius: 12px;
  background: var(--bw-theme-surface, rgba(0, 0, 0, 0.01));
}

.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease, border-color 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow, 0 4px 12px rgba(0, 0, 0, 0.05));
  border-color: var(--q-primary);
}

.border-dashed-1 {
  border-style: dashed !important;
}
</style>
