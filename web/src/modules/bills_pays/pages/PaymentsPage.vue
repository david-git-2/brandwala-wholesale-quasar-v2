<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden invoice-list-stack">
      <TfDrawerSectionTabs
        v-model="deskTab"
        :tabs="deskTabs"
        aria-label="Payments desk view"
        class="shrink-0"
      />

      <PaymentsRecentList v-if="deskTab === 'recent'" />

      <template v-else>
        <ProcurementOpsListToolbar
          :search="searchText"
          search-placeholder="Search profile…"
          :show-filters="false"
          search-on-enter
          @update:search="onSearchApply"
        >
          <template #pills>
            <TfDrawerSectionTabs
              v-model="entityTab"
              :tabs="typeSectionTabs"
              aria-label="Payment profile type"
            />
          </template>
        </ProcurementOpsListToolbar>

        <div v-if="listError" class="tf-status-banner bg-negative text-white q-pa-sm rounded-borders">
          {{ listError }}
        </div>

        <div v-if="isPending && !rows.length" class="invoice-list-card col">
          <div class="invoice-list-scroll">
            <div v-for="n in 6" :key="n" class="invoice-list-item invoice-list-item--skeleton">
              <q-skeleton type="text" width="60%" />
            </div>
          </div>
        </div>

        <div
          v-else-if="!rows.length"
          class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
        >
          <q-icon name="ph ph-users" size="48px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle1 text-weight-bold text-slate-800">No profiles</div>
        </div>

        <div v-else class="invoice-list-card payments-list-card">
          <div class="invoice-list-scroll">
            <div
              v-for="row in rows"
              :key="`${row.entity_type}-${row.entity_id}`"
              class="profile-row-wrap"
            >
              <CashbookEntityRow :row="row" @open="selectProfile" />
            </div>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import CashbookEntityRow from '../components/CashbookEntityRow.vue';
import PaymentsRecentList from '../components/PaymentsRecentList.vue';
import {
  prefetchCashbookProfileLists,
  useCashbookEntitiesQuery,
} from '../composables/useCashbookEntitiesQuery';
import type { CashbookEntityRow as EntityRow } from '../repositories/cashbookRepository';
import {
  parsePaymentsDeskView,
  parsePaymentsProfileTab,
  type PaymentsDeskView,
  type PaymentsProfileTab,
} from '../utils/paymentsNavigation';

const PROFILE_LIST_LIMIT = 200;

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();

type DeskTab = PaymentsDeskView;
type EntityTab = PaymentsProfileTab;

const deskTab = ref<DeskTab>(parsePaymentsDeskView(route.query.view));
const deskTabs = [
  { name: 'profiles' as const, label: 'Profiles' },
  { name: 'recent' as const, label: 'Recent pays' },
];

const searchText = ref('');
const entityTab = ref<EntityTab>(parsePaymentsProfileTab(route.query.profile));

const typeTabs: { label: string; value: EntityTab }[] = [
  { label: 'Tenant', value: 'tenant' },
  { label: 'Customer', value: 'customer' },
  { label: 'Courier', value: 'courier' },
  { label: 'Vendor', value: 'vendor' },
];

const typeSectionTabs = typeTabs.map((tab) => ({ name: tab.value, label: tab.label }));

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const queryParams = computed(() => ({
  tenantId: operatingTenantId.value,
  booksTenantId: booksTenantId.value,
  entityType: entityTab.value,
  search: searchText.value || undefined,
  limit: PROFILE_LIST_LIMIT,
}));

const { tenantCashQuery, entitiesQuery } = useCashbookEntitiesQuery(queryParams);

const isPending = computed(() =>
  entityTab.value === 'tenant' ? tenantCashQuery.isPending.value : entitiesQuery.isPending.value,
);

const listError = computed(() => {
  const err =
    entityTab.value === 'tenant' ? tenantCashQuery.error.value : entitiesQuery.error.value;
  return err instanceof Error ? err.message : err ? 'Could not load profiles.' : null;
});

const rows = computed<EntityRow[]>(() => {
  if (entityTab.value === 'tenant') {
    const row = tenantCashQuery.data.value;
    return row ? [row] : [];
  }
  return entitiesQuery.data.value ?? [];
});

const warmProfileListCache = () => {
  if (!operatingTenantId.value || deskTab.value !== 'profiles') return;
  prefetchCashbookProfileLists(queryClient, operatingTenantId.value, booksTenantId.value, {
    search: searchText.value || undefined,
    limit: PROFILE_LIST_LIMIT,
  });
};

watch([operatingTenantId, deskTab, searchText], warmProfileListCache, { immediate: true });

let syncingTabsFromRoute = false;

watch(
  () => [route.query.view, route.query.profile] as const,
  ([view, profile]) => {
    syncingTabsFromRoute = true;
    deskTab.value = parsePaymentsDeskView(view);
    entityTab.value = parsePaymentsProfileTab(profile);
    syncingTabsFromRoute = false;
  },
);

watch([deskTab, entityTab], ([view, profile]) => {
  if (syncingTabsFromRoute) return;
  const nextView = view === 'recent' ? 'recent' : 'profiles';
  if (route.query.view === nextView && route.query.profile === profile) return;
  void router.replace({
    name: 'app-payments-page',
    params: route.params,
    query: {
      ...route.query,
      view: nextView,
      profile,
    },
  });
}, { immediate: true });

const onSearchApply = (value: string | null | undefined) => {
  searchText.value = (value ?? '').trim();
};

const selectProfile = (row: EntityRow) => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-payment-profile-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      entityType: row.entity_type,
      entityId: String(row.entity_id),
    },
  });
};
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.payments-list-card {
  flex: 0 1 auto;
  align-self: stretch;
  max-height: 100%;
  min-height: 0;
}
.payments-list-card .invoice-list-scroll {
  flex: 0 1 auto;
  max-height: calc(100vh - 11rem);
  overflow-y: auto;
}
</style>
