<template>
  <q-page class="tf-page theme-shop customer-orders-page">
    <div class="customer-orders-page__inner">
      <q-card flat class="shop-home-card customer-orders-panel q-pa-md">
        <div class="customer-orders-toolbar row items-center q-col-gutter-sm">
          <div class="col-grow">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              clearable
              hide-bottom-space
              class="customer-orders-toolbar__field"
              :placeholder="$t('shop_admin.orders_search_placeholder')"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-auto customer-orders-toolbar__filter">
            <q-select
              :model-value="selectedBucket"
              dense
              outlined
              emit-value
              map-options
              hide-bottom-space
              class="customer-orders-toolbar__field"
              :options="bucketOptions"
              :label="$t('shop_admin.bucket_filter')"
              data-test="orders-bucket-filter"
              @update:model-value="setBucket"
            />
          </div>
        </div>

        <div class="customer-orders-panel__divider" aria-hidden="true" />

        <CustomerOrdersList
          v-if="isLoading"
          layout="page"
          :orders="[]"
          loading
          :show-pricing-badge="true"
          pricing-badge-variant="text"
          :show-copy-button="false"
        />

        <div
          v-else-if="isError"
          class="column items-center justify-center customer-orders-empty q-pa-xl text-center"
        >
          <q-icon name="ph ph-warning-circle" size="60px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-negative">{{ $t('shop_admin.load_orders_failed') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm q-mb-none">
            {{ error?.message || $t('shop_admin.load_orders_failed_hint') }}
          </p>
        </div>

        <div
          v-else-if="filteredOrders.length === 0"
          class="column items-center justify-center customer-orders-empty q-pa-xl text-center"
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
          layout="page"
          :orders="listRows"
          :show-pricing-badge="true"
          pricing-badge-variant="text"
          :show-copy-button="false"
          @select="goToOrderDetails"
        />
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import {
  parseOrderGlanceBucket,
  type OrderGlanceBucket,
} from 'src/modules/dashboard/utils/customerDashboardStatus';
import { useCustomerOrdersQuery } from '../composables/useCustomerOrdersQuery';
import { shopCatalogEntryPath } from '../utils/catalogShop';
import type { CustomerOrderListItem } from '../types';
import type { CustomerOrderListRow } from '../components/CustomerOrdersList.vue';
import CustomerOrdersList from '../components/CustomerOrdersList.vue';

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

const listRows = computed(() =>
  filteredOrders.value.map((order) => ({
    id: order.id,
    order_no: order.order_no,
    shop_name: order.shop_name,
    shop_id: order.shop_id,
    shop_slug: order.shop_slug,
    status: order.status,
    created_at: order.created_at,
    shop_type_snapshot: order.shop_type_snapshot,
    is_negotiable_snapshot: order.is_negotiable_snapshot,
  })),
);

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
  const tenantSlugParam = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null;
  void router.push(shopCatalogEntryPath(tenantSlugParam));
};

const goToOrderDetails = (order: CustomerOrderListItem | CustomerOrderListRow) => {
  const row = order as CustomerOrderListItem;
  const slug = typeof route.params.tenantSlug === 'string' ? `/${route.params.tenantSlug}` : '';
  void router.push({
    path: `${slug}/shop/orders/${row.id}`,
    state: { shopTypeSnapshot: row.shop_type_snapshot },
  });
};

</script>

<script lang="ts">
export default {
  name: 'CustomerOrdersPage',
};
</script>

<style scoped>
.customer-orders-page__inner {
  width: 100%;
  max-width: 1200px;
  margin-inline: auto;
}

.customer-orders-toolbar__filter {
  min-width: 11rem;
}

.customer-orders-toolbar__field :deep(.q-field__control) {
  min-height: 40px;
  border-radius: 8px;
}

.customer-orders-panel__divider {
  margin: 0.75rem 0 0.65rem;
  border-top: 1px solid #e5e7eb;
}

.customer-orders-empty {
  min-height: 280px;
}
</style>
