<template>
  <div v-if="isLoadingOrders" class="column items-center justify-center q-pa-xl floating-surface full-height">
    <q-spinner color="primary" size="40px" />
    <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_orders') }}</div>
  </div>

  <div
    v-else-if="orders.length === 0"
    class="column items-center justify-center empty-state q-pa-xl text-center floating-surface full-height"
  >
    <q-icon name="ph ph-receipt" size="80px" color="grey-3" class="q-mb-md" />
    <div class="text-h6 text-grey-6">{{ $t('shop_admin.no_orders_found') }}</div>
    <p class="text-body2 text-grey-5 q-mt-sm">
      {{ $t('shop_admin.no_orders_match') }}
    </p>
  </div>

  <div v-else class="treasury-table-wrap full-height">
    <q-card flat class="floating-surface q-pa-none full-height column no-wrap">
      <q-table
        :rows="orders"
        :columns="columns"
        row-key="id"
        flat
        class="orders-table cursor-pointer col"
        :pagination="{ rowsPerPage: 20 }"
        @row-click="(_, row) => emit('row-click', row.id)"
      >
        <template #body-cell-date="props">
          <q-td :props="props">
            {{ formatDate(props.row.created_at) }}
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

        <template #body-cell-actions="cellProps">
          <q-td :props="cellProps">
            <q-btn
              v-if="isDropshipShop?.(cellProps.row.shop_id) && cellProps.row.status === 'confirmed'"
              flat
              round
              dense
              icon="ph ph-truck"
              color="primary"
              :loading="isProcessingDropship"
              @click.stop="emit('add-to-dropship', cellProps.row.id)"
            >
              <q-tooltip>{{ $t('shop_admin.add_to_dropship_desk') }}</q-tooltip>
            </q-btn>
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
import type { ShopOrder } from '../types';

const { isDropshipShop, isLoadingOrders, isProcessingDropship } = defineProps<{
  orders: ShopOrder[];
  isLoadingOrders: boolean;
  isProcessingDropship: boolean;
  isDropshipShop?: (shopId: number) => boolean;
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
  { name: 'status', label: t('shop_admin.status', 'Status'), field: 'status', align: 'center', sortable: true },
  { name: 'actions', label: '', field: 'actions', align: 'right' },
] as any[]);

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'costing_pending':
      return 'deep-orange-7';
    case 'negotiating':
    case 'countered':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'final_offered':
      return 'purple-7';
    case 'confirmed':
      return 'green-7';
    case 'procuring':
      return 'blue-9';
    case 'ordered':
      return 'indigo-7';
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
.treasury-table-wrap {
  min-height: 0;
  overflow: hidden;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: none;
  box-shadow: none;
}

body.body--dark .floating-surface {
  background: #1c1c1c;
}

.orders-table :deep(.q-table__middle) {
  overflow-y: auto;
}

.orders-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  color: #0f172a;
  font-weight: 700;
  background: #f8fafc;
}

body.body--dark .orders-table :deep(thead tr th) {
  color: #a1a1aa;
  background: #1c1c1c;
}

.status-badge {
  border-radius: 6px;
}

.empty-state {
  min-height: 280px;
}
</style>
