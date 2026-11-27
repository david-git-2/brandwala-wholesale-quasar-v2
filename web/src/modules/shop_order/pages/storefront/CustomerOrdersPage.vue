<template>
  <q-page class="tf-page theme-shop customer-orders-page">
    <div class="customer-orders-page__inner">
      <header class="customer-orders-header row items-center justify-between q-gutter-sm q-mb-md">
        <div class="row items-center q-gutter-x-sm">
          <h1 class="customer-orders-header__title q-my-none">
            {{ $t('shop_admin.my_orders') }}
          </h1>
          <span
            v-if="!isLoading && !isError && orders.length > 0"
            class="customer-orders-header__count tf-num"
          >
            {{ orders.length }}
          </span>
        </div>
        <q-chip
          v-if="shopIdFilter"
          removable
          color="primary"
          text-color="white"
          icon="ph ph-storefront"
          class="customer-orders-shop-chip"
          data-test="orders-shop-filter-chip"
          @remove="clearShopFilter"
        >
          {{ shopFilterLabel }}
        </q-chip>
      </header>

      <div class="customer-orders-toolbar row items-center justify-between q-gutter-sm q-mb-md">
        <div
          class="customer-orders-buckets"
          role="tablist"
          :aria-label="$t('shop_admin.bucket_filter')"
          data-test="orders-bucket-filter"
        >
          <button
            v-for="opt in bucketOptions"
            :key="opt.value"
            type="button"
            role="tab"
            :aria-selected="selectedBucket === opt.value"
            class="customer-orders-bucket-pill"
            :class="{
              'customer-orders-bucket-pill--active': selectedBucket === opt.value,
              'customer-orders-bucket-pill--attention': opt.value === 'needs_you' && (opt.count ?? 0) > 0,
            }"
            :data-test="`orders-bucket-${opt.value}`"
            @click="setBucket(opt.value)"
          >
            <span>{{ opt.label }}</span>
            <span
              v-if="opt.count != null && opt.count > 0"
              class="customer-orders-bucket-pill__count tf-num"
            >
              {{ opt.count }}
            </span>
          </button>
        </div>

        <div class="customer-orders-toolbar__controls row items-center q-gutter-sm">
          <q-input
            v-model="searchQuery"
            dense
            outlined
            clearable
            hide-bottom-space
            :placeholder="$t('shop_admin.orders_search_placeholder')"
            class="customer-orders-toolbar__search"
            data-test="orders-search-input"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="16px" />
            </template>
          </q-input>

          <q-select
            v-if="availableShops.length > 1 || shopIdFilter"
            :model-value="shopIdFilter ?? 0"
            dense
            outlined
            emit-value
            map-options
            hide-bottom-space
            class="customer-orders-toolbar__shop-select"
            :options="shopFilterOptions"
            data-test="orders-shop-select"
            @update:model-value="setShopFilter"
          />
        </div>
      </div>

      <div class="customer-orders-table-card">
        <CustomerOrdersList
          v-if="isLoading"
          layout="page"
          :orders="[]"
          loading
          show-order-details-columns
          :show-pricing-badge="true"
          pricing-badge-variant="badge"
          pricing-badge-subtle-fixed
          :show-copy-button="true"
        />

        <div
          v-else-if="isError"
          class="column items-center justify-center customer-orders-empty q-pa-lg text-center"
        >
          <q-icon name="ph ph-warning-circle" size="60px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-negative">{{ $t('shop_admin.load_orders_failed') }}</div>
          <p class="text-body2 tf-text-muted q-mt-sm q-mb-none">
            {{ error?.message || $t('shop_admin.load_orders_failed_hint') }}
          </p>
        </div>

        <div
          v-else-if="orders.length === 0"
          class="column items-center justify-center customer-orders-empty q-pa-lg text-center"
        >
          <q-icon name="ph ph-receipt" size="72px" class="customer-orders-empty__icon q-mb-md" />
          <div class="text-h6 tf-text-muted">
            {{ hasListFilter ? $t('shop_admin.no_orders_match') : $t('shop_admin.no_orders_yet') }}
          </div>
          <p v-if="!hasListFilter" class="text-body2 tf-text-muted q-mt-sm q-mb-md">
            {{ $t('shop_admin.no_orders_hint') }}
          </p>
          <q-btn
            v-if="!hasListFilter"
            color="primary"
            unelevated
            no-caps
            :ripple="false"
            :label="$t('shop_admin.go_browse_catalog')"
            data-test="orders-empty-catalog"
            @click="goCatalog"
          />
        </div>

        <CustomerOrdersList
          v-else
          layout="page"
          :orders="listRows"
          show-order-details-columns
          :show-pricing-badge="true"
          pricing-badge-variant="badge"
          pricing-badge-subtle-fixed
          :show-copy-button="true"
          @select="goToOrderDetails"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import {
  countOrderGlance,
  parseOrderGlanceBucket,
  type OrderGlanceBucket,
} from 'src/modules/workspace/submodules/dashboard/utils/customerDashboardStatus';
import { useCustomerOrdersQuery } from '../../composables/useCustomerOrdersQuery';
import { resolveCustomerShopTypePath, shopCatalogEntryPath } from '../../utils/catalogShop';
import { shopTypeToPathSegment } from '../../utils/shopRouteTypes';
import type { CustomerOrderListItem } from '../../types';
import type { CustomerOrderListRow } from '../../components/CustomerOrdersList.vue';
import CustomerOrdersList from '../../components/CustomerOrdersList.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const searchQuery = ref('');
const statusBucket = computed(() => parseOrderGlanceBucket(route.query.bucket));
const shopIdFilter = computed(() => {
  const parsed = Number(route.query.shopId);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
});
const { data: rawOrders, isLoading, isError, error } = useCustomerOrdersQuery(statusBucket);

const availableShops = computed(() => {
  const map = new Map<number, string>();
  (rawOrders.value ?? []).forEach((order) => {
    if (order.shop_id && order.shop_name && !map.has(order.shop_id)) {
      map.set(order.shop_id, order.shop_name);
    }
  });
  return Array.from(map.entries()).map(([id, name]) => ({ id, name }));
});

const shopFilterOptions = computed(() => [
  { label: t('shop_admin.all_shops'), value: 0 },
  ...availableShops.value.map((s) => ({ label: s.name, value: s.id })),
]);

const orders = computed(() => {
  let list = rawOrders.value ?? [];
  if (shopIdFilter.value) {
    list = list.filter((order) => order.shop_id === shopIdFilter.value);
  }
  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    list = list.filter(
      (order) =>
        order.order_no.toLowerCase().includes(q) ||
        order.shop_name.toLowerCase().includes(q),
    );
  }
  return list;
});

const shopFilterLabel = computed(() => {
  const matched = (rawOrders.value ?? []).find((o) => o.shop_id === shopIdFilter.value);
  return matched?.shop_name ?? `Shop #${shopIdFilter.value}`;
});

const selectedBucket = computed(() => statusBucket.value ?? 'all');

const glanceCounts = computed(() => {
  if (selectedBucket.value !== 'all') return null;
  const scoped = shopIdFilter.value
    ? (rawOrders.value ?? []).filter((o) => o.shop_id === shopIdFilter.value)
    : (rawOrders.value ?? []);
  return countOrderGlance(scoped);
});

const bucketOptions = computed<
  Array<{ label: string; value: OrderGlanceBucket | 'all'; count: number | null }>
>(() => [
  {
    label: t('shop_admin.bucket_all'),
    value: 'all',
    count: glanceCounts.value ? glanceCounts.value.total : null,
  },
  {
    label: t('customer_dashboard.glance_needs_you'),
    value: 'needs_you',
    count: glanceCounts.value ? glanceCounts.value.needs_you : null,
  },
  {
    label: t('customer_dashboard.glance_in_progress'),
    value: 'in_progress',
    count: glanceCounts.value ? glanceCounts.value.in_progress : null,
  },
  {
    label: t('customer_dashboard.glance_done'),
    value: 'done',
    count: glanceCounts.value ? glanceCounts.value.done : null,
  },
]);

const hasListFilter = computed(() =>
  Boolean(statusBucket.value || shopIdFilter.value || searchQuery.value.trim()),
);

const listRows = computed(() =>
  orders.value.map((order) => ({
    id: order.id,
    order_no: order.order_no,
    shop_name: order.shop_name,
    shop_id: order.shop_id,
    shop_slug: order.shop_slug,
    status: order.status,
    created_at: order.created_at,
    item_count: order.item_count,
    total_amount: order.total_amount,
    currency_symbol: order.currency_symbol,
    can_see_sell_price: order.can_see_sell_price,
    shop_type_snapshot: order.shop_type_snapshot,
    is_negotiable_snapshot: order.is_negotiable_snapshot,
    placement_scope: order.placement_scope,
    created_by_email: order.created_by_email,
  })),
);

const clearShopFilter = () => {
  const nextQuery = { ...route.query };
  delete nextQuery.shopId;
  void router.replace({ query: nextQuery });
};

const setShopFilter = (shopId: number | null) => {
  const nextQuery = { ...route.query };
  if (shopId && shopId > 0) {
    nextQuery.shopId = String(shopId);
  } else {
    delete nextQuery.shopId;
  }
  void router.replace({ query: nextQuery });
};

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
  void router.push(
    shopCatalogEntryPath(tenantSlugParam, resolveCustomerShopTypePath(route, null)),
  );
};

const goToOrderDetails = (order: CustomerOrderListRow) => {
  const row = order as unknown as CustomerOrderListItem;
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '';
  const shopType =
    shopTypeToPathSegment(row.shop_type_snapshot) ?? resolveCustomerShopTypePath(route, null);
  void router.push({
    name: 'shop-order-detail-page',
    params: { tenantSlug, shopType, id: String(row.id) },
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
  background: var(--tf-neutral-canvas);
}

.customer-orders-page__inner {
  width: 100%;
  max-width: 1200px;
  margin-inline: auto;
  padding: 1rem 0.75rem 1.5rem;
}

.customer-orders-header__title {
  font-size: 1.25rem;
  font-weight: 700;
  letter-spacing: -0.015em;
  color: var(--tf-neutral-ink);
  line-height: 1.3;
}

.customer-orders-shop-chip {
  border-radius: var(--tf-radius-sm, 8px);
}

.customer-orders-header__count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.15rem 0.55rem;
  border-radius: var(--tf-radius-sm, 8px);
  font-size: 0.75rem;
  font-weight: 600;
  background: var(--tf-theme-primary-soft);
  color: var(--tf-theme-primary);
}

.customer-orders-buckets {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
}

.customer-orders-bucket-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.35rem 0.8rem;
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-surface);
  color: var(--tf-neutral-muted);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    border-color var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    background-color var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    color var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.customer-orders-bucket-pill:hover {
  border-color: var(--tf-theme-primary);
  color: var(--tf-neutral-ink);
}

.customer-orders-bucket-pill--active {
  background: var(--tf-theme-primary);
  border-color: var(--tf-theme-primary);
  color: #ffffff;
}

.customer-orders-bucket-pill--active:hover {
  color: #ffffff;
}

.customer-orders-bucket-pill__count {
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.05rem 0.4rem;
  border-radius: var(--tf-radius-sm, 8px);
  background: rgba(15, 23, 42, 0.07);
  color: inherit;
}

.customer-orders-bucket-pill--active .customer-orders-bucket-pill__count {
  background: rgba(255, 255, 255, 0.22);
}

.customer-orders-bucket-pill--attention:not(.customer-orders-bucket-pill--active) {
  border-color: var(--tf-warning);
  color: var(--tf-warning);
}

.customer-orders-toolbar__controls {
  flex: 1 1 auto;
  justify-content: flex-end;
}

.customer-orders-toolbar__search {
  min-width: 13rem;
  max-width: 18rem;
  flex: 1 1 13rem;
}

.customer-orders-toolbar__shop-select {
  min-width: 9.5rem;
}

.customer-orders-table-card {
  background: var(--tf-neutral-surface);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
  padding: 0.85rem 1.1rem 1rem;
  min-height: 0;
}

.customer-orders-empty {
  min-height: 280px;
}

.customer-orders-empty__icon {
  color: var(--tf-neutral-muted);
  opacity: 0.45;
}
</style>
