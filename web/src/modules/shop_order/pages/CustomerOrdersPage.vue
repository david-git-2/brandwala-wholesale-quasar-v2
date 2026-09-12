<template>
  <q-page class="theme-shop">
    <div class="q-gutter-y-md">
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

      <CustomerOrdersList v-if="isLoading" :orders="[]" loading />

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

      <CustomerOrdersList
        v-else
        :orders="filteredOrders"
        @select="goToOrderDetails"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useCustomerOrdersQuery } from '../composables/useCustomerOrdersQuery';
import { shopCatalogEntryPath } from '../utils/catalogShop';
import type { CustomerOrderListItem } from '../types';
import CustomerOrdersList from '../components/CustomerOrdersList.vue';
import {
  parseOrderGlanceBucket,
  type OrderGlanceBucket,
} from 'src/modules/dashboard/utils/customerDashboardStatus';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

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

const goToOrderDetails = (order: CustomerOrderListItem) => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push({
    path: `${tenantSlug}/shop/orders/${order.id}`,
    state: { shopTypeSnapshot: order.shop_type_snapshot },
  });
};

</script>

<script lang="ts">
export default {
  name: 'CustomerOrdersPage',
};
</script>

<style scoped>
.empty-state {
  min-height: 400px;
}
</style>
