<template>
  <q-page class="tf-page theme-shop customer-orders-page">
    <div class="customer-orders-page__inner">
      <div class="customer-orders-toolbar row items-end justify-end q-mb-md">
        <div class="col-12 col-sm-auto customer-orders-toolbar__filter">
          <q-select
            :model-value="selectedBucket"
            dense
            outlined
            emit-value
            map-options
            hide-bottom-space
            class="customer-orders-toolbar__field customer-orders-toolbar__select"
            :options="bucketOptions"
            data-test="orders-bucket-filter"
            @update:model-value="setBucket"
          >
            <template #selected>
              <span class="customer-orders-toolbar__select-value ellipsis">
                {{ bucketSelectedLabel }}
              </span>
            </template>
          </q-select>
        </div>
      </div>

      <div class="customer-orders-table-card">
        <CustomerOrdersList
          v-if="isLoading"
          layout="page"
          :orders="[]"
          loading
          :show-pricing-badge="true"
          pricing-badge-variant="badge"
          pricing-badge-subtle-fixed
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
          v-else-if="orders.length === 0"
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
          pricing-badge-variant="badge"
          pricing-badge-subtle-fixed
          :show-copy-button="false"
          @select="goToOrderDetails"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
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

const bucketOptions = computed(() => [
  { label: t('shop_admin.bucket_all'), value: 'all' },
  { label: t('customer_dashboard.glance_needs_you'), value: 'needs_you' },
  { label: t('customer_dashboard.glance_in_progress'), value: 'in_progress' },
  { label: t('customer_dashboard.glance_done'), value: 'done' },
]);

const selectedBucket = computed(() => statusBucket.value ?? 'all');

const bucketSelectedLabel = computed(() => {
  const match = bucketOptions.value.find((opt) => opt.value === selectedBucket.value);
  return match?.label ?? t('shop_admin.bucket_all');
});

const hasListFilter = computed(() => Boolean(statusBucket.value));

const listRows = computed(() =>
  orders.value.map((order) => ({
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
.customer-orders-page {
  background: #f8fafc;
}

body.body--dark .customer-orders-page {
  background: var(--tf-neutral-canvas);
}

.customer-orders-page__inner {
  width: 100%;
  max-width: 1200px;
  margin-inline: auto;
  padding: 0.75rem 0.75rem 1.25rem;
}

.customer-orders-toolbar__filter {
  min-width: 11rem;
}

.customer-orders-toolbar__field :deep(.q-field__control) {
  min-height: 40px;
  height: 40px;
  border-radius: 12px;
}

.customer-orders-toolbar__select :deep(.q-field__native) {
  min-height: 40px;
}

.customer-orders-toolbar__select-value {
  display: block;
  width: 100%;
  font-size: 0.875rem;
  color: var(--tf-neutral-ink);
}

.customer-orders-table-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 0.75rem 1rem 1rem;
  min-height: 0;
}

body.body--dark .customer-orders-table-card {
  background: var(--tf-neutral-surface);
  border-color: var(--tf-neutral-border);
}

.customer-orders-empty {
  min-height: 280px;
}
</style>
