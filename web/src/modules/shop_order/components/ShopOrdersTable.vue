<template>
  <div v-if="isLoadingOrders" class="column items-center justify-center q-pa-xl floating-surface full-height">
    <q-spinner color="primary" size="40px" />
    <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_orders', 'Loading orders...') }}</div>
  </div>

  <div
    v-else-if="orders.length === 0"
    class="column items-center justify-center empty-state q-pa-xl text-center floating-surface full-height"
  >
    <q-icon name="ph ph-receipt" size="80px" color="grey-4" class="q-mb-md" />
    <div class="text-h6 text-grey-7">{{ $t('shop_admin.no_orders_found', 'No orders found') }}</div>
    <p class="text-body2 text-grey-5 q-mt-sm">
      {{ $t('shop_admin.no_orders_match', 'No orders match your active filter criteria.') }}
    </p>
  </div>

  <div v-else class="treasury-table-wrap full-height">
    <q-card flat class="q-pa-none full-height column no-wrap">
      <q-table
        :rows="orders"
        :columns="columns"
        row-key="id"
        flat
        class="orders-table cursor-pointer col"
        :pagination="{ rowsPerPage: 20 }"
        hide-pagination
      >
        <template #body="props">
          <q-tr
            :props="props"
            class="orders-table__row cursor-pointer"
            :style="getOrderRowStyle(props.row.status)"
            @click="emit('row-click', props.row.id)"
          >
            <q-td key="order_no" :props="props">
              <div class="row items-center no-wrap q-gutter-xs">
                <span class="text-weight-bold text-primary font-mono">{{ props.row.order_no }}</span>
              </div>
              <div v-if="props.row.name" class="text-caption text-grey-6 ellipsis" style="max-width: 180px">
                {{ props.row.name }}
              </div>
            </q-td>

            <q-td key="date" :props="props">
              <span class="text-grey-8">{{ formatDate(props.row.created_at) }}</span>
            </q-td>

            <q-td key="shop" :props="props">
              <div class="row items-center no-wrap q-gutter-xs">
                <span class="text-weight-medium text-grey-9">{{ props.row.shop_name }}</span>
                <span
                  v-if="isParentTenant && props.row.tenant_name"
                  class="tenant-badge"
                >
                  <q-icon name="ph ph-buildings" size="11px" class="q-mr-xs text-grey-6" />
                  {{ props.row.tenant_name }}
                </span>
              </div>
            </q-td>

            <q-td v-if="isParentTenant" key="tenant" :props="props">
              <div class="row items-center no-wrap q-gutter-xs">
                <q-icon name="ph ph-buildings" size="14px" class="text-grey-6" />
                <span class="text-weight-medium text-grey-9">{{ props.row.tenant_name || '—' }}</span>
              </div>
            </q-td>

            <q-td key="group" :props="props">
              <span class="text-grey-8">{{ props.row.customer_group_name || '—' }}</span>
            </q-td>

            <q-td key="items" :props="props" class="text-right">
              <span class="items-count-badge">
                <q-icon name="ph ph-package" size="12px" class="q-mr-xs text-grey-6" />
                {{ props.row.item_count ?? 0 }}
              </span>
            </q-td>

            <q-td key="pricing_mode" :props="props" class="text-center">
              <OrderPricingModeBadge
                :is-negotiable="!!props.row.is_negotiable_snapshot"
                :shop-type="props.row.shop_type_snapshot"
              />
            </q-td>

            <q-td key="status" :props="props" class="text-center">
              <span
                class="order-status-badge"
                :class="getStatusBadgeInfo(props.row.status).className"
              >
                <q-icon :name="getStatusBadgeInfo(props.row.status).icon" size="12px" class="q-mr-xs" />
                <span>{{ getStatusBadgeInfo(props.row.status).label }}</span>
              </span>
            </q-td>

            <q-td key="actions" :props="props" class="text-right">
              <div class="row items-center justify-end q-gutter-xs no-wrap">
                <q-btn
                  v-if="isDropshipShop?.(props.row.shop_id) && props.row.status === 'confirmed'"
                  flat
                  round
                  dense
                  icon="ph ph-truck"
                  color="primary"
                  :loading="isProcessingDropship"
                  @click.stop="emit('add-to-dropship', props.row.id)"
                >
                  <q-tooltip>{{ $t('shop_admin.add_to_dropship_desk', 'Add to Dropship Desk') }}</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  dense
                  round
                  size="sm"
                  color="grey-7"
                  icon="ph ph-caret-right"
                  @click.stop="emit('row-click', props.row.id)"
                />
              </div>
            </q-td>
          </q-tr>
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
import OrderPricingModeBadge from './OrderPricingModeBadge.vue';
import { normalizeCatalogOrderStatus } from '../utils/catalogOrderStatus';

const { isDropshipShop, isLoadingOrders, isProcessingDropship, isParentTenant } = defineProps<{
  orders: ShopOrder[];
  isLoadingOrders: boolean;
  isProcessingDropship: boolean;
  isDropshipShop?: (shopId: number) => boolean;
  isParentTenant?: boolean;
}>();

const emit = defineEmits<{
  (e: 'row-click', orderId: number): void;
  (e: 'add-to-dropship', orderId: number): void;
}>();

const { t } = useI18n();

const columns = computed(() => {
  const cols = [
    { name: 'order_no', label: t('shop_admin.order_no', 'Order No'), field: 'order_no', align: 'left', sortable: true },
    { name: 'date', label: t('shop_admin.date', 'Date'), field: 'created_at', align: 'left', sortable: true },
    { name: 'shop', label: t('shop_admin.shop_label', 'Shop'), field: 'shop_name', align: 'left', sortable: true },
  ];

  if (isParentTenant) {
    cols.push({
      name: 'tenant',
      label: 'Tenant',
      field: 'tenant_name',
      align: 'left',
      sortable: true,
    });
  }

  cols.push(
    { name: 'group', label: t('shop_admin.group_label', 'Customer Group'), field: 'customer_group_name', align: 'left', sortable: true },
    { name: 'items', label: t('shop_admin.items_label', 'Items'), field: 'item_count', align: 'right', sortable: true },
    { name: 'pricing_mode', label: t('shop_admin.col_pricing_mode', 'Mode'), field: 'is_negotiable_snapshot', align: 'center', sortable: true },
    { name: 'status', label: t('shop_admin.status', 'Status'), field: 'status', align: 'center', sortable: true },
    { name: 'actions', label: '', field: 'actions', align: 'right' },
  );

  return cols as any[];
});

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const getOrderRowStyle = (status: string) => {
  const norm = normalizeCatalogOrderStatus(status);
  switch (norm) {
    case 'confirmed':
    case 'delivered':
    case 'payment_received':
    case 'fulfilled':
      return {
        backgroundColor: 'var(--row-bg-received, #f6fcf8)',
        boxShadow: 'inset 3px 0 0 #22c55e',
      };
    case 'submitted':
    case 'procuring':
      return {
        backgroundColor: 'var(--row-bg-transit, #f0f7ff)',
        boxShadow: 'inset 3px 0 0 #3b82f6',
      };
    case 'placed':
    case 'ready_for_shipment':
    case 'shipped':
    case 'processing':
      return {
        backgroundColor: 'var(--row-bg-processing, #fbf7ff)',
        boxShadow: 'inset 3px 0 0 #7c3aed',
      };
    case 'costing_pending':
    case 'negotiating':
    case 'countered':
    case 'priced':
    case 'final_offered':
      return {
        backgroundColor: 'var(--row-bg-draft, #fffdf5)',
        boxShadow: 'inset 3px 0 0 #f59e0b',
      };
    case 'cancelled':
    case 'returned':
      return {
        backgroundColor: 'var(--row-bg-cancelled, #fef7f7)',
        boxShadow: 'inset 3px 0 0 #ef4444',
      };
    case 'draft':
    default:
      return {
        backgroundColor: 'var(--row-bg-draft, #fafaf9)',
        boxShadow: 'inset 3px 0 0 #94a3b8',
      };
  }
};

const getStatusBadgeInfo = (status: string) => {
  const norm = normalizeCatalogOrderStatus(status);
  switch (norm) {
    case 'draft':
      return {
        label: t('shop_admin.status_draft', 'Draft'),
        icon: 'ph ph-pencil-simple',
        className: 'status-draft',
      };
    case 'submitted':
      return {
        label: t('shop_admin.status_submitted', 'Submitted'),
        icon: 'ph ph-paper-plane-tilt',
        className: 'status-submitted',
      };
    case 'costing_pending':
      return {
        label: t('shop_admin.status_costing_pending', 'Costing Pending'),
        icon: 'ph ph-clock',
        className: 'status-costing-pending',
      };
    case 'negotiating':
      return {
        label: t('shop_admin.status_negotiating', 'Negotiating'),
        icon: 'ph ph-arrows-left-right',
        className: 'status-negotiating',
      };
    case 'countered':
      return {
        label: t('shop_admin.status_countered', 'Countered'),
        icon: 'ph ph-arrow-counter-clockwise',
        className: 'status-negotiating',
      };
    case 'priced':
      return {
        label: t('shop_admin.status_priced', 'Priced'),
        icon: 'ph ph-tag',
        className: 'status-priced',
      };
    case 'final_offered':
      return {
        label: t('shop_admin.status_final_offered', 'Final Offered'),
        icon: 'ph ph-handshake',
        className: 'status-final-offered',
      };
    case 'confirmed':
      return {
        label: t('shop_admin.status_confirmed', 'Confirmed'),
        icon: 'ph ph-check-circle',
        className: 'status-confirmed',
      };
    case 'procuring':
      return {
        label: t('shop_admin.status_procuring', 'Procuring'),
        icon: 'ph ph-package',
        className: 'status-procuring',
      };
    case 'ready_for_shipment':
      return {
        label: t('shop_admin.status_ready_for_shipment', 'Ready for Shipment'),
        icon: 'ph ph-box-arrow-up',
        className: 'status-ready',
      };
    case 'placed':
      return {
        label: t('shop_admin.status_placed', 'Placed'),
        icon: 'ph ph-tray',
        className: 'status-placed',
      };
    case 'fulfilled':
      return {
        label: t('shop_admin.status_fulfilled', 'Fulfilled'),
        icon: 'ph ph-check-square-offset',
        className: 'status-fulfilled',
      };
    case 'processing':
      return {
        label: t('shop_admin.status_processing', 'Processing'),
        icon: 'ph ph-arrows-clockwise',
        className: 'status-processing',
      };
    case 'shipped':
      return {
        label: t('shop_admin.status_shipped', 'Shipped'),
        icon: 'ph ph-truck',
        className: 'status-shipped',
      };
    case 'delivered':
      return {
        label: t('shop_admin.status_delivered', 'Delivered'),
        icon: 'ph ph-house-line',
        className: 'status-delivered',
      };
    case 'payment_received':
      return {
        label: t('shop_admin.status_payment_received', 'Payment Received'),
        icon: 'ph ph-currency-dollar',
        className: 'status-payment',
      };
    case 'cancelled':
      return {
        label: t('shop_admin.status_cancelled', 'Cancelled'),
        icon: 'ph ph-x-circle',
        className: 'status-cancelled',
      };
    case 'returned':
      return {
        label: t('shop_admin.status_returned', 'Returned'),
        icon: 'ph ph-arrow-u-up-left',
        className: 'status-returned',
      };
    default:
      return {
        label: (status || 'Unknown').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()),
        icon: 'ph ph-circle',
        className: 'status-draft',
      };
  }
};
</script>

<style scoped>
.treasury-table-wrap {
  min-height: 0;
  overflow: hidden;
}

.orders-table {
  --row-bg-received: #f6fcf8;
  --row-bg-transit: #f0f7ff;
  --row-bg-processing: #fbf7ff;
  --row-bg-draft: #fffdf5;
  --row-bg-cancelled: #fef7f7;
}

body.body--dark .orders-table {
  --row-bg-received: rgba(34, 197, 94, 0.08);
  --row-bg-transit: rgba(59, 130, 246, 0.08);
  --row-bg-processing: rgba(124, 58, 237, 0.08);
  --row-bg-draft: rgba(245, 158, 11, 0.08);
  --row-bg-cancelled: rgba(239, 68, 68, 0.08);
}

.orders-table :deep(.q-table__middle) {
  overflow-y: auto;
}

.orders-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  color: var(--bw-neutral-chrome, #0f172a);
  font-weight: 700;
  background: var(--bw-neutral-surface, #f8fafc);
}

body.body--dark .orders-table :deep(thead tr th) {
  color: #a1a1aa;
  background: #1c1c1c;
}

.orders-table__row {
  transition: background-color 0.15s ease;
}

.orders-table__row:hover {
  filter: brightness(0.97);
}

body.body--dark .orders-table__row:hover {
  filter: brightness(1.15);
}

.order-status-badge {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  padding: 3px 8px;
  border-radius: 6px;
  line-height: 1.2;
  white-space: nowrap;
}

.items-count-badge {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 6px;
  background: #f1f5f9;
  color: #334155;
  border: 1px solid #e2e8f0;
}

.tenant-badge {
  display: inline-flex;
  align-items: center;
  font-size: 10px;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 4px;
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
  line-height: 1.2;
}

/* Status Soft Tint Themes */
.status-draft {
  background: #f8fafc;
  color: #475569;
  border: 1px solid #cbd5e1;
}

.status-submitted {
  background: #eff6ff;
  color: #1d4ed8;
  border: 1px solid #bfdbfe;
}

.status-costing-pending {
  background: #fff7ed;
  color: #c2410c;
  border: 1px solid #fed7aa;
}

.status-negotiating {
  background: #fffbeb;
  color: #b45309;
  border: 1px solid #fde68a;
}

.status-priced {
  background: #ecfeff;
  color: #0e7490;
  border: 1px solid #a5f3fc;
}

.status-final-offered {
  background: #faf5ff;
  color: #7e22ce;
  border: 1px solid #e9d5ff;
}

.status-confirmed,
.status-placed {
  background: #f0fdf4;
  color: #15803d;
  border: 1px solid #bbf7d0;
}

.status-procuring {
  background: #eef2ff;
  color: #3730a3;
  border: 1px solid #c7d2fe;
}

.status-ready {
  background: #f5f3ff;
  color: #5b21b6;
  border: 1px solid #ddd6fe;
}

.status-fulfilled {
  background: #f0fdfa;
  color: #0f766e;
  border: 1px solid #99f6e4;
}

.status-processing {
  background: #fbf7ff;
  color: #6b21a8;
  border: 1px solid #e9d5ff;
}

.status-shipped {
  background: #f0f9ff;
  color: #0369a1;
  border: 1px solid #bae6fd;
}

.status-delivered,
.status-payment {
  background: #ecfdf5;
  color: #047857;
  border: 1px solid #a7f3d0;
}

.status-cancelled,
.status-returned {
  background: #fef2f2;
  color: #b91c1c;
  border: 1px solid #fecaca;
}

/* Dark mode overrides */
body.body--dark .items-count-badge,
body.body--dark .tenant-badge {
  background: rgba(255, 255, 255, 0.08);
  color: #cbd5e1;
  border-color: rgba(255, 255, 255, 0.12);
}

body.body--dark .status-draft {
  background: rgba(148, 163, 184, 0.12);
  color: #cbd5e1;
  border-color: rgba(148, 163, 184, 0.25);
}

body.body--dark .status-submitted {
  background: rgba(59, 130, 246, 0.14);
  color: #93c5fd;
  border-color: rgba(59, 130, 246, 0.3);
}

body.body--dark .status-costing-pending {
  background: rgba(249, 115, 22, 0.14);
  color: #fdba74;
  border-color: rgba(249, 115, 22, 0.3);
}

body.body--dark .status-negotiating {
  background: rgba(245, 158, 11, 0.14);
  color: #fcd34d;
  border-color: rgba(245, 158, 11, 0.3);
}

body.body--dark .status-priced {
  background: rgba(6, 182, 212, 0.14);
  color: #67e8f9;
  border-color: rgba(6, 182, 212, 0.3);
}

body.body--dark .status-final-offered {
  background: rgba(168, 85, 247, 0.14);
  color: #d8b4fe;
  border-color: rgba(168, 85, 247, 0.3);
}

body.body--dark .status-confirmed,
body.body--dark .status-placed {
  background: rgba(34, 197, 94, 0.14);
  color: #86efac;
  border-color: rgba(34, 197, 94, 0.3);
}

body.body--dark .status-procuring {
  background: rgba(99, 102, 241, 0.14);
  color: #a5b4fc;
  border-color: rgba(99, 102, 241, 0.3);
}

body.body--dark .status-ready {
  background: rgba(139, 92, 246, 0.14);
  color: #c4b5fd;
  border-color: rgba(139, 92, 246, 0.3);
}

body.body--dark .status-fulfilled {
  background: rgba(20, 184, 166, 0.14);
  color: #5eead4;
  border-color: rgba(20, 184, 166, 0.3);
}

body.body--dark .status-processing {
  background: rgba(147, 51, 234, 0.14);
  color: #d8b4fe;
  border-color: rgba(147, 51, 234, 0.3);
}

body.body--dark .status-shipped {
  background: rgba(14, 165, 233, 0.14);
  color: #7dd3fc;
  border-color: rgba(14, 165, 233, 0.3);
}

body.body--dark .status-delivered,
body.body--dark .status-payment {
  background: rgba(16, 185, 129, 0.14);
  color: #6ee7b7;
  border-color: rgba(16, 185, 129, 0.3);
}

body.body--dark .status-cancelled,
body.body--dark .status-returned {
  background: rgba(239, 68, 68, 0.14);
  color: #fca5a5;
  border-color: rgba(239, 68, 68, 0.3);
}

.font-mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

.empty-state {
  min-height: 280px;
}
</style>
