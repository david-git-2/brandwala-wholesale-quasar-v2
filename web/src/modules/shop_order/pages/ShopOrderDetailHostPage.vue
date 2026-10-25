<script setup lang="ts">
import { computed, defineAsyncComponent } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopOrderDetailQuery } from '../composables/useShopOrderDetailQuery';
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { resolveDropshipOrderDetailView } from '../composables/useDropshipOrderStatusRedirect';
import StaffOrderDetailSkeleton from '../components/StaffOrderDetailSkeleton.vue';

const StaffOrderDetailPage = defineAsyncComponent(
  () => import('./StaffOrderDetailPage.vue'),
);
const DropshipOrderDetailV2Page = defineAsyncComponent(
  () => import('./DropshipOrderDetailV2Page.vue'),
);
const DropshipOrderDetailV2ProcessingPage = defineAsyncComponent(
  () => import('./DropshipOrderDetailV2ProcessingPage.vue'),
);
const DropshipOrderDetailV2ReadyForPickupPage = defineAsyncComponent(
  () => import('./DropshipOrderDetailV2ReadyForPickupPage.vue'),
);

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const orderId = computed(() => Number(route.params.id || 0));
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);

const shopTypeHint = computed(() => {
  const state = history.state as { shopTypeSnapshot?: string } | null;
  return state?.shopTypeSnapshot ?? null;
});
const isDropshipHint = computed(() => shopTypeHint.value === 'dropship');
const isCatalogHint = computed(() => shopTypeHint.value === 'vendor_catalog');

const staffQuery = useShopOrderDetailQuery(orderId, {
  enabled: computed(() => !isDropshipHint.value),
});
const staffShopType = computed(
  () => staffQuery.data.value?.order?.shop_type_snapshot ?? null,
);
const isDropshipFromStaff = computed(() => staffShopType.value === 'dropship');

const dropshipQuery = useDropshipOrderDetailV2Query({
  tenantSlug,
  orderId,
  enabled: computed(() => isDropshipHint.value || isDropshipFromStaff.value),
});

const isDropship = computed(
  () => isDropshipHint.value || isDropshipFromStaff.value,
);

const status = computed(
  () =>
    dropshipQuery.data.value?.order?.status ??
    staffQuery.data.value?.order?.status ??
    null,
);

const isLoading = computed(() => {
  if (isDropshipHint.value) {
    return dropshipQuery.isLoading.value && !dropshipQuery.data.value;
  }
  if (isCatalogHint.value) {
    return staffQuery.isLoading.value && !staffQuery.data.value;
  }
  if (staffQuery.isLoading.value && !staffQuery.data.value) return true;
  if (isDropshipFromStaff.value && dropshipQuery.isLoading.value && !dropshipQuery.data.value) {
    return true;
  }
  return false;
});
const isError = computed(() => {
  if (isDropshipHint.value) return dropshipQuery.isError.value;
  if (isCatalogHint.value) return staffQuery.isError.value;
  if (staffQuery.isError.value) return true;
  return isDropshipFromStaff.value && dropshipQuery.isError.value;
});
const loadError = computed(() => {
  const err = isDropshipHint.value || isDropshipFromStaff.value
    ? dropshipQuery.error.value
    : staffQuery.error.value;
  return (err instanceof Error ? err.message : null) || 'Failed to load order details.';
});

const skeletonVariant = computed<'catalog' | 'dropship'>(() => {
  const state = history.state as { shopTypeSnapshot?: string } | null;
  if (state?.shopTypeSnapshot === 'vendor_catalog') return 'catalog';
  if (isDropship.value) return 'dropship';
  return staffShopType.value === 'vendor_catalog' ? 'catalog' : 'dropship';
});

const activePage = computed(() => {
  if (!isDropship.value) return StaffOrderDetailPage;
  const view = resolveDropshipOrderDetailView(status.value);
  if (view === 'processing') return DropshipOrderDetailV2ProcessingPage;
  if (view === 'ready') return DropshipOrderDetailV2ReadyForPickupPage;
  return DropshipOrderDetailV2Page;
});

const orderNo = computed(
  () =>
    dropshipQuery.data.value?.order?.order_no ??
    staffQuery.data.value?.order?.order_no ??
    null,
);

usePageBreadcrumbs(() => {
  const slug =
    tenantSlug.value ??
    authStore.tenantSlug ??
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null);
  const shopHubPath = slug ? `/${slug}/app/shop` : '/app/shop';
  const ordersPath = slug ? `/${slug}/app/shop/orders` : '/app/shop/orders';
  const rawNo = orderNo.value?.trim();
  const lastLabel = rawNo
    ? rawNo.startsWith('#')
      ? rawNo
      : `#${rawNo}`
    : orderId.value > 0
      ? `#${orderId.value}`
      : 'Order';

  return [
    {
      label: authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'Shop & Order', to: shopHubPath },
    { label: 'Orders', to: ordersPath },
    { label: lastLabel },
  ];
});

const goBack = () => {
  void router.push({
    name: 'app-shop-orders-page',
    params: { tenantSlug: tenantSlug.value ?? undefined },
  });
};
</script>

<template>
  <q-page v-if="isLoading" class="q-pa-md">
    <StaffOrderDetailSkeleton :variant="skeletonVariant" />
  </q-page>

  <q-page
    v-else-if="isError"
    class="column items-center justify-center q-pa-xl text-center"
  >
    <q-icon name="ph ph-warning-circle" size="48px" color="negative" class="q-mb-sm" />
    <div class="text-h6 text-grey-8">{{ loadError }}</div>
    <q-btn flat color="primary" label="Go Back to Orders" class="q-mt-md" @click="goBack" />
  </q-page>

  <component :is="activePage" v-else />
</template>
