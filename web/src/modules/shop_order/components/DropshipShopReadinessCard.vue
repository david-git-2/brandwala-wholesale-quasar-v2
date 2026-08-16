<template>
  <q-card flat bordered class="q-pa-md bg-grey-1 rounded-borders">
    <div class="row items-center justify-between q-mb-sm">
      <div class="row items-center q-gutter-x-xs">
        <q-icon name="ph ph-list-checks" color="primary" size="20px" />
        <span class="text-subtitle2 text-weight-bold text-grey-9">
          Dropship Go-Live Readiness
        </span>
      </div>
      <div>
        <q-chip
          dense
          square
          size="sm"
          :color="readiness?.ready ? 'positive' : 'warning'"
          text-color="white"
          class="text-weight-bold q-px-sm"
        >
          <q-icon
            :name="readiness?.ready ? 'ph ph-check-circle' : 'ph ph-warning'"
            size="14px"
            class="q-mr-xs"
          />
          {{ readiness?.ready ? 'Ready for Go-Live' : 'Action Required' }}
        </q-chip>
      </div>
    </div>

    <div v-if="isLoading" class="q-py-sm">
      <q-skeleton type="text" width="60%" class="q-mb-xs" />
      <q-skeleton type="text" width="40%" />
    </div>

    <div v-else-if="readiness" class="q-gutter-y-xs q-mt-xs">
      <div
        v-for="check in checkItems"
        :key="check.id"
        class="row items-center justify-between q-py-xs border-b-grey"
      >
        <div class="row items-center q-gutter-x-xs col">
          <q-icon
            :name="check.passed ? 'ph ph-check-circle' : 'ph ph-x-circle'"
            :color="check.passed ? 'positive' : 'negative'"
            size="18px"
          />
          <span
            class="text-caption"
            :class="check.passed ? 'text-grey-8' : 'text-grey-10 text-weight-medium'"
          >
            {{ check.label }}
          </span>
        </div>
        <div v-if="!check.passed" class="col-auto">
          <q-btn
            flat
            dense
            no-caps
            size="xs"
            color="primary"
            class="text-weight-bold"
            :label="check.actionLabel"
            icon-right="ph ph-arrow-right"
            @click="navigateToRoute(check.routeName, check.routeParams, check.routeQuery)"
          />
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { dropshipShopReadinessRepository } from '../repositories/dropshipShopReadinessRepository';
import { shopOrderQueryKeys } from '../services/shopOrderQueryKeys';

const props = defineProps<{
  shopId: number;
  tenantSlug: string;
}>();

const router = useRouter();

const readinessQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.readiness(props.shopId)),
  enabled: computed(() => props.shopId > 0),
  staleTime: 30_000,
  queryFn: () => dropshipShopReadinessRepository.getDropshipShopReadiness(props.shopId),
});

const readiness = computed(() => readinessQuery.data.value);
const isLoading = computed(() => readinessQuery.isLoading.value);

interface CheckItem {
  id: string;
  label: string;
  passed: boolean;
  actionLabel: string;
  routeName: string;
  routeParams: Record<string, string>;
  routeQuery?: Record<string, string>;
}

const checkItems = computed<CheckItem[]>(() => {
  if (!readiness.value) return [];
  const r = readiness.value;
  return [
    {
      id: 'access_group_with_price',
      label: 'Access group with dropship price permission',
      passed: r.has_access_group_with_price,
      actionLabel: 'Setup Access Matrix',
      routeName: 'app-shop-settings-page',
      routeParams: { tenantSlug: props.tenantSlug, shopId: String(props.shopId) },
      routeQuery: { tab: 'access' },
    },
    {
      id: 'customer_group_with_members',
      label: 'Customer group with active members attached',
      passed: r.has_customer_group_with_members,
      actionLabel: 'Manage Customer Groups',
      routeName: 'app-shop-customer-groups-page',
      routeParams: { tenantSlug: props.tenantSlug },
    },
    {
      id: 'billing_profile_linked',
      label: 'Billing profile linked to customer group',
      passed: r.has_billing_profile_linked,
      actionLabel: 'Link Billing Profile',
      routeName: 'app-global-billing-profiles',
      routeParams: { tenantSlug: props.tenantSlug },
    },
    {
      id: 'listing_with_floor',
      label: 'Active product listing with floor price set',
      passed: r.has_listing_with_floor,
      actionLabel: 'Manage Shop Pricing',
      routeName: 'app-shop-settings-page',
      routeParams: { tenantSlug: props.tenantSlug, shopId: String(props.shopId) },
      routeQuery: { tab: 'listings' },
    },
    {
      id: 'active_courier',
      label: 'Active courier service configured',
      passed: r.has_active_courier,
      actionLabel: 'Configure Couriers',
      routeName: 'app-shop-dropship-couriers-page',
      routeParams: { tenantSlug: props.tenantSlug },
    },
  ];
});

const navigateToRoute = (
  name: string,
  params?: Record<string, string>,
  query?: Record<string, string>,
) => {
  const loc: { name: string; params?: Record<string, string>; query?: Record<string, string> } = { name };
  if (params) loc.params = params;
  if (query) loc.query = query;
  void router.push(loc);
};
</script>

<style scoped>
.border-b-grey {
  border-bottom: 1px dashed #e0e0e0;
}
.border-b-grey:last-child {
  border-bottom: none;
}
</style>
