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
          ? $t('shop_admin.no_orders_match_desc', 'Try adjusting your search, shop, profile, or status filters.')
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

  <div v-else class="orders-list-wrapper column no-wrap">
    <div class="orders-list-scroll col">
      <q-infinite-scroll :offset="250" @load="onInfiniteLoad">
        <div class="orders-list-container">
          <div
            v-if="bulkDeleteSelection && hasSelectableOnPage"
            class="order-bulk-select-bar row items-center no-wrap q-px-sm q-py-xs q-gutter-x-sm"
          >
            <q-checkbox
              dense
              :model-value="allCancelledSelected"
              :indeterminate="someCancelledSelected && !allCancelledSelected"
              :aria-label="$t('shop_admin.bulk_delete_select_all_cancelled', 'Select all cancelled on this page')"
              @update:model-value="toggleSelectAllCancelled"
            />
            <span class="text-caption text-grey-7">
              {{ $t('shop_admin.bulk_delete_select_hint', 'Select cancelled orders to delete permanently') }}
            </span>
          </div>
          <div
            v-for="order in orders"
            :key="order.id"
            class="order-list-row cursor-pointer"
            :class="{ 'order-list-row--with-check': isOrderSelectable(order) }"
            :data-test="`shop-order-item-${order.id}`"
            tabindex="0"
            role="button"
            @click="emit('row-click', order.id)"
            @keydown.enter="emit('row-click', order.id)"
            @keydown.space.prevent="emit('row-click', order.id)"
          >
            <div v-if="isOrderSelectable(order)" class="order-list-row__check">
              <q-checkbox
                dense
                :model-value="selectedIdSet.has(order.id)"
                :aria-label="$t('shop_admin.bulk_delete_select_order', 'Select order for deletion')"
                @update:model-value="(on) => toggleOrderSelection(order.id, on)"
                @click.stop
              />
            </div>

            <div class="order-list-row__col order-list-row__col--identity min-width-0">
              <div class="order-card__title ellipsis">
                {{ orderListPrimaryLabel(order) }}
              </div>
              <div class="order-card__reference row items-center no-wrap min-width-0">
                <span class="order-card__order-no font-mono ellipsis">{{ order.order_no }}</span>
                <q-btn
                  flat
                  dense
                  round
                  size="xs"
                  color="grey-6"
                  icon="ph ph-copy"
                  class="order-copy-btn flex-shrink-0"
                  :aria-label="$t('shop_admin.copy_order_no', 'Copy Order No')"
                  @click.stop="copyOrderNo(order.order_no)"
                >
                  <q-tooltip anchor="top middle" self="bottom middle" :offset="[0, 4]">
                    {{ $t('shop_admin.copy_order_no', 'Copy Order No') }}
                  </q-tooltip>
                </q-btn>
                <span class="order-card__dot" aria-hidden="true">·</span>
                <span class="order-card__timestamp flex-shrink-0">{{ formatListTimestamp(order.created_at) }}</span>
              </div>
            </div>

            <div class="order-list-row__col order-list-row__col--ops min-width-0">
              <div class="order-card__ops-line ellipsis">
                <span>{{ order.shop_name || '—' }}</span>
                <template v-if="placementChannelLabel(order)">
                  <span class="order-card__dot" aria-hidden="true">·</span>
                  <span>{{ placementChannelLabel(order) }}</span>
                </template>
                <template v-if="isParentTenant && order.tenant_name">
                  <span class="order-card__dot" aria-hidden="true">·</span>
                  <span class="order-card__tenant-hint">{{ order.tenant_name }}</span>
                </template>
              </div>
              <div class="order-card__ops-line ellipsis">
                <span>
                  {{ order.item_count ?? 0 }}
                  {{ order.item_count === 1 ? $t('shop_admin.item_singular', 'item') : $t('shop_admin.items_plural', 'items') }}
                </span>
                <template v-if="orderActorDisplay(order)">
                  <span class="order-card__dot" aria-hidden="true">·</span>
                  <span class="order-card__actor">
                    {{ orderActorDisplay(order) }}
                    <q-tooltip v-if="order.created_by_email" anchor="top middle" self="bottom middle">
                      {{ order.created_by_email }}
                    </q-tooltip>
                  </span>
                </template>
              </div>
            </div>

            <div class="order-list-row__col order-list-row__col--status">
              <TfStatusBadge
                :status="order.status"
                :label="statusLabel(order.status)"
              />
              <div
                v-if="hasSecondaryFlags(order)"
                class="order-card__flags column items-end q-gutter-y-xs"
              >
                <TfStatusBadge
                  v-if="showNegotiableFlag(order)"
                  status="negotiating"
                  :label="$t('shop_admin.order_pricing_negotiable', 'Negotiable')"
                />
                <TfStatusBadge
                  v-if="order.hidden_from_customer"
                  status="on_hold"
                  :label="$t('shop_admin.order_hidden_from_customer', 'Staff only')"
                />
                <TfStatusBadge
                  v-if="order.catalog_manual_price_entry"
                  status="costing_pending"
                  :label="$t('shop_admin.catalog_manual_price_entry', 'Manual prices')"
                />
              </div>
            </div>
          </div>
        </div>

        <template v-if="hasNextPage" #loading>
          <div class="row justify-center q-py-sm">
            <q-spinner color="primary" size="24px" />
          </div>
        </template>
      </q-infinite-scroll>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { date, copyToClipboard } from 'quasar';
import { showSuccessNotification } from 'src/utils/appFeedback';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import type { ShopOrder } from '../types';
import { normalizeCatalogOrderStatus } from '../utils/catalogOrderStatus';

const props = withDefaults(
  defineProps<{
    orders: ShopOrder[];
    isLoadingOrders: boolean;
    isProcessingDropship: boolean;
    isDropshipShop?: (shopId: number) => boolean;
    isParentTenant?: boolean;
    isFiltered?: boolean;
    hasNextPage?: boolean;
    isFetchingNextPage?: boolean;
    selectedOrderIds?: number[];
    bulkDeleteSelection?: boolean;
  }>(),
  {
    selectedOrderIds: () => [],
    bulkDeleteSelection: false,
  },
);

const emit = defineEmits<{
  (e: 'row-click', orderId: number): void;
  (e: 'add-to-dropship', orderId: number): void;
  (e: 'load-more', done: (stop?: boolean) => void): void;
  (e: 'clear-filters'): void;
  (e: 'update:selectedOrderIds', ids: number[]): void;
}>();

const selectedIdSet = computed(() => new Set(props.selectedOrderIds ?? []));

function isOrderSelectable(order: ShopOrder): boolean {
  if (props.bulkDeleteSelection) return true;
  return order.status === 'cancelled';
}

const selectableOrdersOnPage = computed(() => props.orders.filter((o) => isOrderSelectable(o)));

const hasSelectableOnPage = computed(() => selectableOrdersOnPage.value.length > 0);

const allCancelledSelected = computed(() => {
  const selectable = selectableOrdersOnPage.value;
  if (!selectable.length) return false;
  return selectable.every((o) => selectedIdSet.value.has(o.id));
});

const someCancelledSelected = computed(() =>
  selectableOrdersOnPage.value.some((o) => selectedIdSet.value.has(o.id)),
);

function toggleOrderSelection(orderId: number, selected: boolean) {
  const next = new Set(props.selectedOrderIds ?? []);
  if (selected) next.add(orderId);
  else next.delete(orderId);
  emit('update:selectedOrderIds', Array.from(next));
}

function toggleSelectAllCancelled(selectAll: boolean) {
  const selectableIds = selectableOrdersOnPage.value.map((o) => o.id);
  if (!selectAll) {
    const next = (props.selectedOrderIds ?? []).filter((id) => !selectableIds.includes(id));
    emit('update:selectedOrderIds', next);
    return;
  }
  const next = new Set(props.selectedOrderIds ?? []);
  for (const id of selectableIds) next.add(id);
  emit('update:selectedOrderIds', Array.from(next));
}

const onInfiniteLoad = (_index: number, done: (stop?: boolean) => void) => {
  if (props.isFetchingNextPage) {
    done();
    return;
  }
  if (!props.hasNextPage) {
    done(true);
    return;
  }
  emit('load-more', done);
};

const { t } = useI18n();

const formatListTimestamp = (dateStr: string) => {
  if (!dateStr) return '—';
  return date.formatDate(dateStr, 'D MMM, HH:mm');
};

const placementChannelLabel = (order: ShopOrder): string | null => {
  if (order.placement_scope === 'app') {
    return t('shop_admin.placement_channel_mobile_app', 'Mobile App');
  }
  if (order.placement_scope === 'shop') {
    return t('shop_admin.placement_channel_shopfront', 'Shopfront');
  }
  return null;
};

const orderActorDisplay = (order: ShopOrder): string | null => {
  const email = (order.created_by_email || '').trim();
  if (!email) return null;
  const at = email.indexOf('@');
  if (at > 0) return email.slice(0, at);
  return email;
};

const showNegotiableFlag = (order: ShopOrder): boolean => {
  if (!order.is_negotiable_snapshot) return false;
  const shopType = order.shop_type_snapshot;
  return shopType === 'vendor_catalog' || shopType === 'fixed_price';
};

const hasSecondaryFlags = (order: ShopOrder): boolean =>
  showNegotiableFlag(order) || Boolean(order.hidden_from_customer) || Boolean(order.catalog_manual_price_entry);

/** Staff list title: company (customer group), not `Order for {recipient}`. */
const orderListPrimaryLabel = (order: ShopOrder): string => {
  const groupName = order.customer_group_name?.trim();
  if (groupName) return groupName;

  if (order.recipient_name?.trim()) return order.recipient_name.trim();
  if (order.name?.trim()) return order.name.trim();
  return order.shop_name || t('shop_admin.untitled_order', 'Order');
};

const copyOrderNo = (orderNo: string) => {
  void copyToClipboard(orderNo).then(() => {
    showSuccessNotification(t('shop_admin.order_no_copied', 'Order number copied'));
  });
};

const statusLabel = (status: string) => {
  const norm = normalizeCatalogOrderStatus(status);
  switch (norm) {
    case 'draft':
      return t('shop_admin.status_draft', 'Draft');
    case 'submitted':
      return t('shop_admin.status_submitted', 'Submitted');
    case 'costing_pending':
      return t('shop_admin.status_costing_pending', 'Costing Pending');
    case 'negotiating':
      return t('shop_admin.status_negotiating', 'Negotiating');
    case 'countered':
      return t('shop_admin.status_countered', 'Countered');
    case 'priced':
      return t('shop_admin.status_priced', 'Priced');
    case 'final_offered':
      return t('shop_admin.status_final_offered', 'Final Offered');
    case 'confirmed':
      return t('shop_admin.status_confirmed', 'Confirmed');
    case 'procuring':
      return t('shop_admin.status_procuring', 'Procuring');
    case 'packed':
      return t('shop_admin.status_packed', 'Packed');
    case 'placed':
      return t('shop_admin.status_placed', 'Placed');
    case 'fulfilled':
      return t('shop_admin.status_fulfilled', 'Fulfilled');
    case 'processing':
      return t('shop_admin.status_processing', 'Processing');
    case 'shipped':
      return t('shop_admin.status_shipped', 'Shipped');
    case 'delivered':
      return t('shop_admin.status_delivered', 'Delivered');
    case 'payment_received':
      return t('shop_admin.status_payment_received', 'Payment Received');
    case 'cancelled':
      return t('shop_admin.status_cancelled', 'Cancelled');
    case 'returned':
      return t('shop_admin.status_returned', 'Returned');
    default:
      return (status || 'Unknown').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
};
</script>

<style scoped>
.orders-list-wrapper {
  background: var(--tf-neutral-surface);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
  max-height: 100%;
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
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, 1.2fr) auto;
  column-gap: 20px;
  row-gap: 4px;
  align-items: center;
  padding: 14px 16px;
  border-bottom: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-surface);
  transition:
    background-color var(--tf-dur-fast, 0.15s) ease,
    border-color var(--tf-dur-fast, 0.15s) ease;
}

.order-list-row--with-check {
  grid-template-columns: auto minmax(0, 1.05fr) minmax(0, 1.2fr) auto;
}

.order-list-row:last-child {
  border-bottom: none;
}

.order-list-row:hover,
.order-list-row:focus-within {
  background: var(--tf-hover-bg);
}

.order-list-row:focus-visible {
  outline: 2px solid var(--tf-theme-primary, var(--q-primary));
  outline-offset: -2px;
}

.order-list-row__check {
  display: flex;
  align-items: center;
}

.order-list-row__col--identity {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.order-list-row__col--ops {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.order-list-row__col--status {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 6px;
  min-width: 108px;
}

.order-card__title {
  font-size: 15px;
  font-weight: 600;
  line-height: 1.25;
  color: var(--tf-neutral-ink, #0f172a);
}

.order-card__reference {
  gap: 4px;
  font-size: 13px;
  line-height: 1.25;
}

.order-card__order-no {
  font-size: 13px;
  letter-spacing: 0.02em;
  color: var(--tf-neutral-ink, #334155);
}

.order-card__timestamp {
  color: var(--tf-neutral-muted, #64748b);
}

.order-card__dot {
  color: var(--tf-neutral-border-strong, #cbd5e1);
  margin: 0 2px;
}

.order-card__ops-line {
  font-size: 13px;
  line-height: 1.35;
  color: var(--tf-neutral-muted, #64748b);
}

.order-card__tenant-hint {
  font-size: 12px;
  color: var(--tf-neutral-chrome-text, #94a3b8);
}

.order-card__actor {
  color: var(--tf-neutral-ink, #475569);
}

.order-copy-btn {
  opacity: 0.55;
  transition: opacity var(--tf-dur-fast, 0.15s) ease;
}

.order-list-row:hover .order-copy-btn,
.order-list-row:focus-within .order-copy-btn {
  opacity: 1;
}

.order-card__flags {
  max-width: 220px;
}

/* Empty State */
.empty-orders-state {
  background: var(--tf-neutral-surface);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
}

.empty-icon-wrap {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: var(--tf-status-wait-soft);
  display: flex;
  align-items: center;
  justify-content: center;
}

.clear-filters-btn {
  border-radius: 8px;
  font-weight: 600;
  font-size: 12px;
  border: 1px solid var(--tf-neutral-border-strong);
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
  background: var(--tf-neutral-surface);
  border-color: var(--tf-neutral-border);
}

body.body--dark .order-list-row {
  border-color: var(--tf-neutral-border);
}

body.body--dark .order-card__title {
  color: var(--tf-neutral-ink);
}

body.body--dark .order-card__ops-line,
body.body--dark .order-card__timestamp {
  color: var(--tf-neutral-muted);
}

@media (max-width: 768px) {
  .order-list-row,
  .order-list-row--with-check {
    grid-template-columns: minmax(0, 1fr);
    row-gap: 10px;
  }

  .order-list-row__col--status {
    align-items: flex-start;
    flex-direction: row;
    flex-wrap: wrap;
    gap: 8px;
  }

  .order-card__flags {
    justify-content: flex-start;
    max-width: none;
  }
}
</style>
