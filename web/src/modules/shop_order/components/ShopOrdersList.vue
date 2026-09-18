<template>
  <div v-if="isLoadingOrders" class="column items-center justify-center q-pa-xl clean-list-loading full-height">
    <q-spinner color="primary" size="36px" />
    <div class="text-grey-6 text-caption q-mt-sm">{{ $t('shop_admin.loading_orders', 'Loading orders...') }}</div>
  </div>

  <div
    v-else-if="orders.length === 0"
    class="column items-center justify-center empty-orders-state q-pa-xl text-center full-height"
  >
    <div class="empty-icon-wrap q-mb-md">
      <q-icon name="ph ph-receipt" size="44px" color="grey-5" />
    </div>
    <div class="text-subtitle1 text-weight-bold text-grey-9">
      {{ isFiltered ? $t('shop_admin.no_matching_orders', 'No matching orders found') : $t('shop_admin.no_orders_found', 'No orders yet') }}
    </div>
    <p class="text-caption text-grey-6 q-mt-xs q-mb-md" style="max-width: 360px">
      {{
        isFiltered
          ? $t('shop_admin.no_orders_match_desc', 'Try adjusting your search query, shop selector, or status filters.')
          : $t('shop_admin.orders_empty_desc', 'When customers place orders from your storefronts, they will appear here.')
      }}
    </p>
    <q-btn
      v-if="isFiltered"
      flat
      no-caps
      color="primary"
      icon="ph ph-arrow-counter-clockwise"
      :label="$t('shop_admin.clear_all_filters', 'Clear filters')"
      class="clear-filters-btn"
      @click="emit('clear-filters')"
    />
  </div>

  <div v-else class="orders-list-wrapper column no-wrap full-height">
    <!-- List Summary Bar -->
    <div class="orders-list-meta-bar row items-center justify-between q-px-md q-py-xs flex-shrink-0">
      <div class="row items-center q-gutter-x-sm">
        <span class="text-caption text-weight-bold text-grey-8 font-mono">
          {{ orders.length }} {{ orders.length === 1 ? $t('shop_admin.order_singular', 'order') : $t('shop_admin.orders_plural', 'orders') }}
        </span>
        <span v-if="confirmedCount > 0" class="meta-count-chip meta-count-chip--confirmed">
          <q-icon name="ph ph-check-circle" size="12px" class="q-mr-xs" />
          {{ confirmedCount }} {{ $t('shop_admin.status_confirmed', 'Confirmed') }}
        </span>
        <span v-if="inProgressCount > 0" class="meta-count-chip meta-count-chip--progress">
          <q-icon name="ph ph-arrows-clockwise" size="12px" class="q-mr-xs" />
          {{ inProgressCount }} {{ $t('shop_admin.in_progress', 'In Progress') }}
        </span>
        <span v-if="draftCount > 0" class="meta-count-chip meta-count-chip--draft">
          <q-icon name="ph ph-pencil-simple" size="12px" class="q-mr-xs" />
          {{ draftCount }} {{ $t('shop_admin.status_draft', 'Draft') }}
        </span>
      </div>
      <div class="text-caption text-grey-5 text-xxs">
        {{ $t('shop_admin.click_order_to_open', 'Click any order to view details') }}
      </div>
    </div>

    <!-- Scrollable Linear List -->
    <div class="orders-list-scroll col">
      <div class="orders-list-container">
        <div
          v-for="order in orders"
          :key="order.id"
          class="order-list-row row items-center justify-between no-wrap cursor-pointer"
          :class="getOrderRowClass(order.status)"
          :data-test="`shop-order-item-${order.id}`"
          tabindex="0"
          role="button"
          @click="emit('row-click', order.id)"
          @keydown.enter="emit('row-click', order.id)"
          @keydown.space.prevent="emit('row-click', order.id)"
        >
          <!-- Left Section: Status indicator, Order No, Name & Inline Metadata -->
          <div class="order-main-info col min-width-0 row items-center no-wrap">
            <div class="order-id-block column flex-shrink-0 q-mr-md">
              <div class="row items-center no-wrap q-gutter-x-xs">
                <span class="order-no font-mono text-weight-bolder text-primary">
                  {{ order.order_no }}
                </span>
                <q-btn
                  flat
                  dense
                  round
                  size="xs"
                  color="grey-6"
                  icon="ph ph-copy"
                  class="order-copy-btn"
                  :aria-label="$t('shop_admin.copy_order_no', 'Copy Order No')"
                  @click.stop="copyOrderNo(order.order_no)"
                >
                  <q-tooltip anchor="top middle" self="bottom middle" :offset="[0, 4]">
                    {{ $t('shop_admin.copy_order_no', 'Copy Order No') }}
                  </q-tooltip>
                </q-btn>
              </div>

              <span class="order-date text-caption text-grey-6">
                {{ formatDate(order.created_at) }}
              </span>
            </div>

            <!-- Details / Meta Tags Strip -->
            <div class="order-details-block column col min-width-0 justify-center">
              <div class="row items-center no-wrap q-gutter-x-xs ellipsis q-mb-xs">
                <span v-if="order.name" class="order-name text-weight-bold text-grey-9 ellipsis">
                  {{ order.name }}
                </span>
                <span v-else-if="order.recipient_name" class="order-name text-weight-bold text-grey-9 ellipsis">
                  {{ order.recipient_name }}
                </span>
                <span v-else class="order-name text-weight-medium text-grey-8 ellipsis">
                  {{ order.shop_name || $t('shop_admin.untitled_order', 'Order') }}
                </span>
              </div>

              <div class="order-meta-line row items-center wrap q-gutter-xs text-caption">
                <!-- Shop Name Pill -->
                <span class="meta-pill meta-pill--shop">
                  <q-icon name="ph ph-storefront" size="12px" class="q-mr-xs text-grey-6" />
                  <span class="ellipsis" style="max-width: 140px">{{ order.shop_name }}</span>
                </span>

                <!-- Tenant Badge if Parent Tenant -->
                <span v-if="isParentTenant && order.tenant_name" class="meta-pill meta-pill--tenant">
                  <q-icon name="ph ph-buildings" size="12px" class="q-mr-xs text-grey-6" />
                  <span class="ellipsis" style="max-width: 120px">{{ order.tenant_name }}</span>
                </span>

                <!-- Customer Group Pill -->
                <span v-if="order.customer_group_name" class="meta-pill meta-pill--group">
                  <q-icon name="ph ph-users" size="12px" class="q-mr-xs text-grey-6" />
                  <span class="ellipsis" style="max-width: 130px">{{ order.customer_group_name }}</span>
                </span>

                <!-- Items Count Badge -->
                <span class="meta-pill meta-pill--items">
                  <q-icon name="ph ph-package" size="12px" class="q-mr-xs text-grey-6" />
                  {{ order.item_count ?? 0 }} {{ order.item_count === 1 ? 'item' : 'items' }}
                </span>

                <!-- Pricing Mode Badge (Fixed / Negotiable) -->
                <OrderPricingModeBadge
                  v-if="order.shop_type_snapshot"
                  :is-negotiable="!!order.is_negotiable_snapshot"
                  :shop-type="order.shop_type_snapshot"
                />
              </div>
            </div>
          </div>

          <!-- Right Section: Status Pill + Dropship Desk Action + Navigation Chevron -->
          <div class="order-aside-actions row items-center no-wrap flex-shrink-0 q-gutter-x-sm">
            <!-- Order Status Badge -->
            <span
              class="order-status-badge"
              :class="getStatusBadgeInfo(order.status).className"
            >
              <q-icon :name="getStatusBadgeInfo(order.status).icon" size="13px" class="q-mr-xs" />
              <span>{{ getStatusBadgeInfo(order.status).label }}</span>
            </span>

            <!-- Quick Dropship Desk Processing Action -->
            <q-btn
              v-if="isDropshipShop?.(order.shop_id) && order.status === 'confirmed'"
              flat
              dense
              no-caps
              color="primary"
              class="dropship-desk-btn"
              :loading="isProcessingDropship"
              @click.stop="emit('add-to-dropship', order.id)"
            >
              <q-icon name="ph ph-truck" size="14px" class="q-mr-xs" />
              <span>{{ $t('shop_admin.dropship_desk_btn', 'Desk') }}</span>
              <q-tooltip>{{ $t('shop_admin.add_to_dropship_desk', 'Add to Dropship Desk') }}</q-tooltip>
            </q-btn>

            <!-- Navigation Chevron -->
            <q-btn
              flat
              round
              dense
              size="sm"
              color="grey-6"
              icon="ph ph-caret-right"
              class="order-chevron-btn"
              @click.stop="emit('row-click', order.id)"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { date, copyToClipboard } from 'quasar';
import { showSuccessNotification } from 'src/utils/appFeedback';
import type { ShopOrder } from '../types';
import OrderPricingModeBadge from './OrderPricingModeBadge.vue';
import { normalizeCatalogOrderStatus } from '../utils/catalogOrderStatus';

const props = defineProps<{
  orders: ShopOrder[];
  isLoadingOrders: boolean;
  isProcessingDropship: boolean;
  isDropshipShop?: (shopId: number) => boolean;
  isParentTenant?: boolean;
  isFiltered?: boolean;
}>();

const emit = defineEmits<{
  (e: 'row-click', orderId: number): void;
  (e: 'add-to-dropship', orderId: number): void;
  (e: 'clear-filters'): void;
}>();

const { t } = useI18n();

const confirmedCount = computed(() => {
  return props.orders.filter((o) => {
    const norm = normalizeCatalogOrderStatus(o.status);
    return norm === 'confirmed' || norm === 'placed' || norm === 'fulfilled' || norm === 'delivered' || norm === 'payment_received';
  }).length;
});

const inProgressCount = computed(() => {
  return props.orders.filter((o) => {
    const norm = normalizeCatalogOrderStatus(o.status);
    return (
      norm === 'submitted' ||
      norm === 'procuring' ||
      norm === 'ready_for_shipment' ||
      norm === 'processing' ||
      norm === 'shipped' ||
      norm === 'negotiating' ||
      norm === 'priced' ||
      norm === 'countered' ||
      norm === 'costing_pending' ||
      norm === 'final_offered'
    );
  }).length;
});

const draftCount = computed(() => {
  return props.orders.filter((o) => normalizeCatalogOrderStatus(o.status) === 'draft').length;
});

const formatDate = (dateStr: string) => {
  if (!dateStr) return '—';
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const copyOrderNo = (orderNo: string) => {
  void copyToClipboard(orderNo).then(() => {
    showSuccessNotification(t('shop_admin.order_no_copied', 'Order number copied'));
  });
};

const getOrderRowClass = (status: string) => {
  const norm = normalizeCatalogOrderStatus(status);
  switch (norm) {
    case 'confirmed':
    case 'delivered':
    case 'payment_received':
    case 'fulfilled':
      return 'order-row--success';
    case 'submitted':
    case 'procuring':
      return 'order-row--info';
    case 'placed':
    case 'ready_for_shipment':
    case 'shipped':
    case 'processing':
      return 'order-row--purple';
    case 'costing_pending':
    case 'negotiating':
    case 'countered':
    case 'priced':
    case 'final_offered':
      return 'order-row--warning';
    case 'cancelled':
    case 'returned':
      return 'order-row--danger';
    case 'draft':
    default:
      return 'order-row--neutral';
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
.orders-list-wrapper {
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  border-radius: 10px;
  overflow: hidden;
}

.orders-list-meta-bar {
  background: var(--bw-neutral-surface, #f8fafc);
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
  min-height: 34px;
}

.orders-list-scroll {
  overflow-y: auto;
  min-height: 0;
}

.orders-list-container {
  display: flex;
  flex-direction: column;
}

.order-list-row {
  padding: 10px 14px;
  border-bottom: 1px solid var(--bw-theme-border, #f1f5f9);
  transition: all 0.15s ease-in-out;
  position: relative;
}

.order-list-row:last-child {
  border-bottom: none;
}

.order-list-row:hover {
  background-color: var(--bw-theme-primary-soft, #f8fafc);
}

.order-list-row:focus-visible {
  outline: 2px solid var(--q-primary);
  outline-offset: -2px;
}

/* Status Accents (left inset bar) */
.order-row--success {
  box-shadow: inset 3px 0 0 #22c55e;
}

.order-row--info {
  box-shadow: inset 3px 0 0 #3b82f6;
}

.order-row--purple {
  box-shadow: inset 3px 0 0 #7c3aed;
}

.order-row--warning {
  box-shadow: inset 3px 0 0 #f59e0b;
}

.order-row--danger {
  box-shadow: inset 3px 0 0 #ef4444;
}

.order-row--neutral {
  box-shadow: inset 3px 0 0 #94a3b8;
}

/* Typography & ID block */
.order-id-block {
  min-width: 140px;
}

.order-no {
  font-size: 13px;
  letter-spacing: 0.02em;
}

.order-copy-btn {
  opacity: 0.6;
  transition: opacity 0.15s ease;
}

.order-list-row:hover .order-copy-btn {
  opacity: 1;
}

.order-date {
  font-size: 11px;
}

.order-name {
  font-size: 13.5px;
  color: var(--bw-neutral-chrome, #0f172a);
}

/* Meta Pills */
.meta-pill {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  font-weight: 500;
  padding: 2px 7px;
  border-radius: 5px;
  background: #f1f5f9;
  color: #334155;
  border: 1px solid #e2e8f0;
  line-height: 1.2;
}

.meta-count-chip {
  display: inline-flex;
  align-items: center;
  font-size: 10.5px;
  font-weight: 600;
  padding: 1.5px 6px;
  border-radius: 4px;
}

.meta-count-chip--confirmed {
  background: #dcfce7;
  color: #166534;
}

.meta-count-chip--progress {
  background: #ede9fe;
  color: #6b21a8;
}

.meta-count-chip--draft {
  background: #f1f5f9;
  color: #475569;
}

.dropship-desk-btn {
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  padding: 2px 8px;
}

.dropship-desk-btn:hover {
  background: #dbeafe;
}

.order-chevron-btn {
  transition: transform 0.15s ease;
}

.order-list-row:hover .order-chevron-btn {
  transform: translateX(2px);
  color: var(--q-primary);
}

/* Status Badges */
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

/* Empty State */
.empty-orders-state {
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  border-radius: 10px;
}

.empty-icon-wrap {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: #f1f5f9;
  display: flex;
  align-items: center;
  justify-content: center;
}

.clear-filters-btn {
  border-radius: 8px;
  font-weight: 600;
  font-size: 12px;
  border: 1px solid var(--bw-theme-border, #cbd5e1);
}

.font-mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}

.text-xxs {
  font-size: 11px;
}

.min-width-0 {
  min-width: 0;
}

/* Dark Mode Overrides */
body.body--dark .orders-list-wrapper,
body.body--dark .empty-orders-state {
  background: #1c1917;
  border-color: #2a2622;
}

body.body--dark .orders-list-meta-bar {
  background: #24201d;
  border-color: #2a2622;
}

body.body--dark .order-list-row {
  border-color: #2a2622;
}

body.body--dark .order-list-row:hover {
  background-color: rgba(255, 255, 255, 0.04);
}

body.body--dark .empty-icon-wrap {
  background: #262626;
}

body.body--dark .meta-pill {
  background: rgba(255, 255, 255, 0.06);
  color: #cbd5e1;
  border-color: rgba(255, 255, 255, 0.1);
}

body.body--dark .dropship-desk-btn {
  background: rgba(59, 130, 246, 0.15);
  color: #93c5fd;
  border-color: rgba(59, 130, 246, 0.3);
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

@media (max-width: 600px) {
  .order-list-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }
  .order-aside-actions {
    width: 100%;
    justify-content: space-between;
  }
  .order-id-block {
    min-width: 100%;
    margin-right: 0;
    margin-bottom: 4px;
  }
}
</style>
