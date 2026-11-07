<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <q-card flat bordered class="q-pa-sm flex-shrink-0 q-mb-xs">
      <div class="row items-center no-wrap q-gutter-sm">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="grey-8"
          :aria-label="$t('shop_admin.back_to_orders', 'Back to orders')"
          data-test="cancelled-orders-back"
          @click="goBackToOrders"
        />
        <div class="column">
          <span class="text-subtitle1 text-weight-bold text-grey-9">
            {{ $t('shop_admin.cancelled_orders_delete_title', 'Delete cancelled orders') }}
          </span>
          <span class="text-caption text-grey-7">
            {{ $t('shop_admin.cancelled_orders_delete_desc', 'Select orders to remove permanently.') }}
          </span>
        </div>
      </div>
    </q-card>

    <ShopOrdersSkeleton v-if="isLoadingOrders && !orders.length" />

    <div v-else class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <ShopOrdersFilters
        v-model:selected-shop-id="selectedShopId"
        v-model:selected-profile-id="selectedProfileId"
        v-model:search="searchInput"
        v-model:status-filter="statusFilterStub"
        :shops="shops"
        :profiles="customerProfiles"
        :shops-loading="isLoadingShops"
        :profiles-loading="isLoadingProfiles"
        :refreshing="isRefreshing"
        :show-status-filter="false"
        :show-create-actions="false"
        :show-cancelled-delete-entry="false"
        @apply-search="applySearch"
        @refresh="refresh()"
      />

      <div
        v-if="selectedOrderIds.length > 0"
        class="row items-center q-gutter-sm q-px-xs flex-shrink-0"
      >
        <q-btn
          outline
          color="negative"
          no-caps
          icon="ph ph-trash"
          :label="$t('shop_admin.bulk_delete_cancelled_orders', { count: selectedOrderIds.length })"
          :loading="isBulkDeletingOrders"
          data-test="cancelled-orders-bulk-delete"
          @click="confirmBulkDeleteCancelled"
        />
        <q-btn
          flat
          no-caps
          color="grey-7"
          :label="$t('shop_admin.clear_selection', 'Clear selection')"
          @click="selectedOrderIds = []"
        />
      </div>

      <div class="col" style="min-height: 0">
        <ShopOrdersList
          v-model:selected-order-ids="selectedOrderIds"
          bulk-delete-selection
          :orders="orders"
          :is-loading-orders="isLoadingOrders"
          :is-processing-dropship="false"
          :is-parent-tenant="isParentTenant"
          :is-filtered="isFiltered"
          :has-next-page="hasNextPage"
          :is-fetching-next-page="isFetchingNextPage"
          @row-click="goToOrderDetails"
          @clear-filters="clearAllFilters"
          @load-more="onLoadMoreOrders"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerProfiles } from 'src/modules/sales_invoice/composables/useCustomerProfiles';
import { useShopOrdersStaffPageQuery } from '../composables/useShopOrdersStaffPageQuery';
import { useDeleteShopOrdersForStaffMutation } from '../composables/useShopOrderMutations';
import { requestConfirmation } from 'src/utils/appFeedback';
import ShopOrdersFilters from '../components/ShopOrdersFilters.vue';
import ShopOrdersList from '../components/ShopOrdersList.vue';
import ShopOrdersSkeleton from '../components/ShopOrdersSkeleton.vue';
import type { ShopType } from '../types';

const router = useRouter();
const authStore = useAuthStore();
const { t } = useI18n();

const selectedOrderIds = ref<number[]>([]);
const statusFilterStub = ref<string | null>('cancelled');

const tenantId = computed(() => authStore.tenantId as number);
const parentTenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.tenantId);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const isParentTenant = computed(() => {
  if (!tenantId.value) return false;
  const pId = authStore.selectedTenant?.parent_id ?? tenantId.value;
  return Number(pId) === Number(tenantId.value);
});

const selectedShopId = ref<number | null>(null);
const selectedProfileId = ref<number | null>(null);

const { profiles: customerProfiles, isLoading: isLoadingProfiles } = useCustomerProfiles(parentTenantId);

const searchInput = ref('');
const appliedSearch = ref('');

const applySearch = () => {
  appliedSearch.value = searchInput.value.trim();
};

const isFiltered = computed(() => {
  return Boolean(
    appliedSearch.value || selectedShopId.value !== null || selectedProfileId.value !== null,
  );
});

const clearAllFilters = () => {
  searchInput.value = '';
  appliedSearch.value = '';
  selectedShopId.value = null;
  selectedProfileId.value = null;
};

const pageParams = computed(() => ({
  tenantId: tenantId.value,
  parentTenantId: parentTenantId.value,
  search: appliedSearch.value || null,
  status: 'cancelled' as const,
  shopId: selectedShopId.value || null,
  profileId: selectedProfileId.value || null,
}));

const {
  shops,
  orders,
  isLoadingOrders,
  isLoadingShops,
  hasNextPage,
  isFetchingNextPage,
  fetchNextPage,
  isRefreshing,
  refresh,
} = useShopOrdersStaffPageQuery(pageParams);

const onLoadMoreOrders = async (done: (stop?: boolean) => void) => {
  if (!hasNextPage.value) {
    done(true);
    return;
  }
  await fetchNextPage();
  done(!hasNextPage.value);
};

const { mutateAsync: deleteOrdersForStaff, isPending: isBulkDeletingOrders } =
  useDeleteShopOrdersForStaffMutation();

const confirmBulkDeleteCancelled = async () => {
  if (!selectedOrderIds.value.length || !tenantId.value) return;

  const count = selectedOrderIds.value.length;
  const confirmed = await requestConfirmation(
    t('shop_admin.bulk_delete_cancelled_orders_confirm', { count }),
    t('shop_admin.bulk_delete_cancelled_orders_title'),
    t('shop_admin.delete'),
  );
  if (!confirmed) return;

  try {
    await deleteOrdersForStaff({ tenantId: tenantId.value, orderIds: selectedOrderIds.value });
    selectedOrderIds.value = [];
    await refresh();
  } catch {
    // notification from mutation onError
  }
};

const goToOrderDetails = (orderId: number) => {
  const order = orders.value.find((o) => o.id === orderId);
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  const shopType: ShopType | null | undefined = order?.shop_type_snapshot ?? undefined;
  void router.push({
    path: `${slug}/app/shop/orders/${orderId}`,
    state: { shopTypeSnapshot: shopType ?? undefined },
  });
};

const goBackToOrders = () => {
  const slug = tenantSlug.value ? `/${tenantSlug.value}` : '';
  void router.push(`${slug}/app/shop/orders`);
};
</script>

<script lang="ts">
export default {
  name: 'CancelledShopOrdersPage',
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
</style>
