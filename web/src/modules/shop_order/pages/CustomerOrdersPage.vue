<template>
  <q-page class="q-pa-md theme-shop">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('shop_admin.my_orders') }}</h1>
        </div>
      </section>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-xs-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              clearable
              :placeholder="$t('shop_admin.orders_search_placeholder')"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-xs-12 col-sm-6 col-md-3">
            <q-select
              :model-value="selectedBucket"
              dense
              outlined
              emit-value
              map-options
              :options="bucketOptions"
              :label="$t('shop_admin.bucket_filter')"
              data-test="orders-bucket-filter"
              @update:model-value="setBucket"
            />
          </div>
        </div>
      </q-card>

      <div v-if="isLoading">
        <q-card flat bordered class="order-table-card">
          <q-list separator>
            <q-item v-for="n in 5" :key="n" class="q-py-md">
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
      </div>

      <div
        v-else-if="isError"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="ph ph-warning-circle" size="60px" color="negative" class="q-mb-md" />
        <div class="text-h6 text-negative">{{ $t('shop_admin.load_orders_failed') }}</div>
        <p class="text-body2 text-grey-6 q-mt-sm q-mb-md">
          {{ error?.message || $t('shop_admin.load_orders_failed_hint') }}
        </p>
      </div>

      <div
        v-else-if="filteredOrders.length === 0"
        class="column items-center justify-center empty-state q-pa-xl text-center"
      >
        <q-icon name="ph ph-receipt" size="80px" color="grey-4" class="q-mb-md" />
        <div class="text-h6 text-grey-6">
          {{ hasListFilter ? $t('shop_admin.no_orders_match') : $t('shop_admin.no_orders_yet') }}
        </div>
        <p v-if="!hasListFilter" class="text-body2 text-grey-5 q-mt-sm q-mb-md">
          {{ $t('shop_admin.no_orders_hint') }}
        </p>
        <q-btn
          color="primary"
          unelevated
          no-caps
          :label="$t('shop_admin.go_browse_catalog')"
          data-test="orders-empty-catalog"
          @click="goCatalog"
        />
      </div>

      <div v-else class="column q-gutter-md">
        <q-card flat bordered class="order-table-card">
          <q-list separator>
            <q-item
              v-for="order in filteredOrders"
              :key="order.id"
              clickable
              v-ripple
              class="q-py-md order-item"
              :class="{ 'order-waiting': isWaitingStatus(order.status) }"
              @click="goToOrderDetails(order.id)"
            >
              <q-item-section>
                <div class="row items-center justify-between no-wrap q-col-gutter-sm">
                  <div class="column overflow-hidden">
                    <span class="text-weight-bold ellipsis">{{ order.order_no }}</span>
                    <span class="text-caption text-grey-6 ellipsis">{{ order.shop_name }}</span>
                  </div>
                  <div class="column text-right">
                    <span class="text-subtitle2 text-weight-bold text-primary">
                      {{ order.currency_symbol || '৳' }}{{ Number(order.total_amount || 0).toFixed(2) }}
                    </span>
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
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { date } from 'quasar';
import { useCustomerOrdersQuery } from '../composables/useCustomerOrdersQuery';
import { shopCatalogEntryPath } from '../utils/catalogShop';
import {
  isWaitingStatus,
  parseOrderGlanceBucket,
  waitingActionI18nKey,
  type OrderGlanceBucket,
} from 'src/modules/dashboard/utils/customerDashboardStatus';

const route = useRoute();
const router = useRouter();
const { t, te } = useI18n();

const statusBucket = computed(() => parseOrderGlanceBucket(route.query.bucket));
const { data: rawOrders, isLoading, isError, error } = useCustomerOrdersQuery(statusBucket);
const orders = computed(() => rawOrders.value ?? []);

const searchQuery = ref('');

const bucketOptions = computed(() => [
  { label: t('shop_admin.bucket_all'), value: 'all' },
  { label: t('customer_dashboard.glance_needs_you'), value: 'needs_you' },
  { label: t('customer_dashboard.glance_in_progress'), value: 'in_progress' },
  { label: t('customer_dashboard.glance_done'), value: 'done' },
]);

const selectedBucket = computed(() => statusBucket.value ?? 'all');

const hasListFilter = computed(
  () => Boolean(statusBucket.value) || Boolean(searchQuery.value.trim()),
);

const filteredOrders = computed(() => {
  const q = searchQuery.value.toLowerCase().trim();
  if (!q) return orders.value;
  return orders.value.filter((o) => o.order_no?.toLowerCase().includes(q));
});

const setBucket = (value: OrderGlanceBucket | 'all' | null) => {
  const nextQuery = { ...route.query };
  const bucket = parseOrderGlanceBucket(value);
  if (bucket) {
    nextQuery.bucket = bucket;
  } else {
    delete nextQuery.bucket;
  }
  void router.replace({ query: nextQuery });
};

const goCatalog = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null;
  void router.push(shopCatalogEntryPath(tenantSlug));
};

const goToOrderDetails = (orderId: number) => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/orders/${orderId}`);
};

const formatDate = (dateStr: string) => date.formatDate(dateStr, 'D MMM YYYY');

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

<script lang="ts">
export default {
  name: 'CustomerOrdersPage',
};
</script>

<style scoped>
.order-table-card {
  border-radius: 12px;
  background: var(--bw-theme-surface);
  box-shadow: var(--bw-theme-shadow, 0 2px 8px rgba(0, 0, 0, 0.04));
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

.empty-state {
  min-height: 400px;
}
</style>
