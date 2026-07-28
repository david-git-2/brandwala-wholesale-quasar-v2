<template>
  <div v-if="isLoadingOrders" class="column items-center justify-center q-pa-xl">
    <q-spinner color="primary" size="40px" />
    <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_orders') }}</div>
  </div>

  <div
    v-else-if="orders.length === 0"
    class="column items-center justify-center empty-state q-pa-xl text-center"
  >
    <q-icon name="ph ph-receipt" size="80px" color="grey-3" class="q-mb-md" />
    <div class="text-h6 text-grey-6">{{ $t('shop_admin.no_orders_found') }}</div>
    <p class="text-body2 text-grey-5 q-mt-sm">
      {{ $t('shop_admin.no_orders_match') }}
    </p>
  </div>

  <div v-else class="column q-gutter-md">
    <q-card flat bordered class="order-table-card">
      <q-table
        :rows="orders"
        :columns="columns"
        row-key="id"
        flat
        class="full-width cursor-pointer"
        @row-click="(_, row) => emit('row-click', row.id)"
        :pagination="{ rowsPerPage: 20 }"
      >
        <!-- Body slots for custom formatting -->
        <template #body-cell-date="props">
          <q-td :props="props">
            {{ formatDate(props.row.created_at) }}
          </q-td>
        </template>
        
        <template #body-cell-total="props">
          <q-td :props="props" class="text-primary text-weight-bold">
            {{ getCurrencySymbol(props.row) }}{{ Number(props.row.total_amount || 0).toFixed(2) }}
          </q-td>
        </template>
        
        <template #body-cell-status="props">
          <q-td :props="props">
            <q-badge
              :color="getStatusColor(props.row.status)"
              text-color="white"
              class="status-badge text-weight-bold q-py-xs q-px-sm"
            >
              {{ props.row.status.toUpperCase() }}
            </q-badge>
          </q-td>
        </template>
        
        <template #body-cell-actions="props">
          <q-td :props="props">
            <q-btn
              v-if="props.row.shop_type_snapshot === 'dropship' && props.row.status === 'confirmed'"
              unelevated
              color="primary"
              no-caps
              dense
              icon="ph ph-truck"
              :label="$t('shop_admin.add_to_dropship_desk')"
              class="q-px-md pill-btn text-weight-bold"
              :loading="isProcessingDropship"
              @click.stop="emit('add-to-dropship', props.row.id)"
            />
          </q-td>
        </template>
      </q-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { date } from 'quasar';
import type { ShopOrder, Shop } from '../types';

const props = defineProps<{
  orders: ShopOrder[];
  shops: Shop[];
  currencies: any[];
  isLoadingOrders: boolean;
  isProcessingDropship: boolean;
}>();

const emit = defineEmits<{
  (e: 'row-click', orderId: number): void;
  (e: 'add-to-dropship', orderId: number): void;
}>();

const { t } = useI18n();

const columns = computed(() => [
  { name: 'order_no', label: t('shop_admin.order_no', 'Order No'), field: 'order_no', align: 'left', sortable: true },
  { name: 'date', label: t('shop_admin.date', 'Date'), field: 'created_at', align: 'left', sortable: true },
  { name: 'shop', label: t('shop_admin.shop_label'), field: 'shop_name', align: 'left', sortable: true },
  { name: 'group', label: t('shop_admin.group_label'), field: 'customer_group_name', align: 'left', sortable: true },
  { name: 'items', label: t('shop_admin.items_label'), field: 'item_count', align: 'right', sortable: true },
  { name: 'total', label: t('shop_admin.total_value'), field: 'total_amount', align: 'right', sortable: true },
  { name: 'status', label: t('shop_admin.status', 'Status'), field: 'status', align: 'center', sortable: true },
  { name: 'actions', label: '', field: 'actions', align: 'right' },
] as any[]);

const getCurrencySymbol = (order: any) => {
  const shopId = order.shop_id;
  if (shopId) {
    const shop = props.shops.find((s) => s.id === shopId);
    if (shop?.sell_currency_id) {
      const curr = props.currencies.find((c) => c.id === shop.sell_currency_id);
      if (curr?.symbol) return curr.symbol;
    }
  }
  return '৳';
};

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
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
.order-table-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.pill-btn {
  border-radius: 30px;
}

.status-badge {
  border-radius: 8px;
}

.empty-state {
  min-height: 350px;
}
</style>
