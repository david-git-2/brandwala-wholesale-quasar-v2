<script setup lang="ts">
import { computed, defineAsyncComponent } from 'vue';
import { useRoute, useRouter } from 'vue-router';
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

const orderId = computed(() => Number(route.params.id || 0));
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);

const staffQuery = useShopOrderDetailQuery(orderId);
const shopType = computed(
  () => staffQuery.data.value?.order?.shop_type_snapshot ?? null,
);
const isDropship = computed(() => shopType.value === 'dropship');

const dropshipQuery = useDropshipOrderDetailV2Query({
  tenantSlug,
  orderId,
  enabled: isDropship,
});

const status = computed(
  () =>
    dropshipQuery.data.value?.order?.status ??
    staffQuery.data.value?.order?.status ??
    null,
);

const isLoading = computed(
  () => staffQuery.isLoading.value && !staffQuery.data.value,
);
const isError = computed(() => staffQuery.isError.value);
const loadError = computed(
  () =>
    (staffQuery.error.value instanceof Error
      ? staffQuery.error.value.message
      : null) || 'Failed to load order details.',
);

const skeletonVariant = computed<'catalog' | 'dropship'>(() => {
  const state = history.state as { shopTypeSnapshot?: string } | null;
  if (state?.shopTypeSnapshot === 'vendor_catalog') return 'catalog';
  if (isDropship.value) return 'dropship';
  return shopType.value === 'vendor_catalog' ? 'catalog' : 'dropship';
});

const activePage = computed(() => {
  if (!isDropship.value) return StaffOrderDetailPage;
  const view = resolveDropshipOrderDetailView(status.value);
  if (view === 'processing') return DropshipOrderDetailV2ProcessingPage;
  if (view === 'ready') return DropshipOrderDetailV2ReadyForPickupPage;
  return DropshipOrderDetailV2Page;
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
