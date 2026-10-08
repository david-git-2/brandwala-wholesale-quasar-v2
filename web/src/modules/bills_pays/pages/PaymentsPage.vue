<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden invoice-list-stack">
      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search pay ID, reference, note…"
        :filter-count="0"
        @update:search="onSearchTextUpdate"
      >
        <template #pills>
          <div class="row items-center q-gutter-x-xs quick-filter-toggle">
            <button
              v-for="tab in sideTabs"
              :key="tab.value"
              type="button"
              class="quick-filter-pill"
              :class="{ 'quick-filter-pill--active': side === tab.value }"
              @click="setSide(tab.value)"
            >
              {{ tab.label }}
            </button>
          </div>
        </template>
        <template #trailing>
          <q-btn
            outline
            dense
            no-caps
            color="grey-8"
            class="rounded-sq-btn q-px-sm"
            label="Pay out"
            icon="ph ph-arrow-up-right"
            @click="goPayout"
          />
          <q-btn
            unelevated
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            label="Pay in"
            icon="ph ph-plus"
            @click="goCollect"
          />
        </template>
      </ProcurementOpsListToolbar>

      <template v-if="side === 'out' || side === 'in'">
        <div v-if="listQuery.isError.value" class="bw-status-banner bg-negative text-white q-pa-sm rounded-borders">
          {{ listErrorMessage }}
        </div>

        <div
          v-if="listQuery.isPending.value && !listQuery.data.value?.data.length"
          class="invoice-list-card col"
        >
          <div class="invoice-list-scroll">
            <div v-for="n in 6" :key="n" class="invoice-list-item invoice-list-item--skeleton">
              <q-skeleton type="text" width="60%" />
            </div>
          </div>
        </div>

        <div
          v-else-if="!rows.length && !debouncedSearch"
          class="column items-center justify-center q-pa-xl text-grey-6 col invoice-list-card"
        >
          <q-icon name="ph ph-credit-card" size="48px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle1 text-weight-bold text-slate-800">No payments yet</div>
          <q-btn
            v-if="side === 'in'"
            class="q-mt-md"
            unelevated
            no-caps
            color="primary"
            label="Record pay in"
            @click="goCollect"
          />
          <q-btn
            v-else
            class="q-mt-md"
            unelevated
            no-caps
            color="primary"
            label="Record pay out"
            @click="goPayout"
          />
        </div>

        <div v-else-if="!rows.length" class="column items-center justify-center text-grey-7 q-py-xl col invoice-list-card">
          <div class="text-subtitle2">No payments match</div>
        </div>

        <div v-else class="invoice-list-card payments-list-card">
          <div class="invoice-list-scroll">
            <PayListRow v-for="row in rows" :key="row.id" :row="row" @open="openPay" />
            <div v-if="hasMore" class="row justify-center q-py-sm">
              <q-btn
                flat
                dense
                no-caps
                :loading="listQuery.isFetching.value"
                class="load-more-btn q-px-md"
                label="Load more"
                icon="ph ph-arrow-down"
                @click="page += 1"
              />
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
import PayListRow from '../components/PayListRow.vue';
import { usePaysListQuery } from '../composables/usePaysListQuery';
import type { PayListRow as PayRow } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';
import { parsePaymentsListSide } from '../utils/paymentsNavigation';

const PAGE_SIZE = 25;
const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const queryClient = useQueryClient();

const searchText = ref('');
const debouncedSearch = ref('');
const side = ref<'in' | 'out'>(parsePaymentsListSide(route.query.side));
const page = ref(1);
const accumulatedRows = ref<PayRow[]>([]);

const sideTabs = [
  { label: 'Pay in', value: 'in' as const },
  { label: 'Pay out', value: 'out' as const },
];

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? null);

const listParams = computed(() => ({
  tenantId: operatingTenantId.value ?? 0,
  page: page.value,
  pageSize: PAGE_SIZE,
  search: debouncedSearch.value || undefined,
  side: side.value,
}));

const listQuery = usePaysListQuery(listParams);

const rows = computed(() => accumulatedRows.value);
const total = computed(() => listQuery.data.value?.total ?? 0);
const hasMore = computed(() => accumulatedRows.value.length < total.value);

const listErrorMessage = computed(() => {
  const err = listQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load payments.';
});

let searchTimer: ReturnType<typeof setTimeout> | null = null;

const syncRowsFromQuery = (payload: { data: PayRow[]; total: number } | undefined) => {
  if (!payload) return;
  if (page.value === 1) accumulatedRows.value = payload.data;
  else {
    const ids = new Set(accumulatedRows.value.map((r) => r.id));
    accumulatedRows.value = [...accumulatedRows.value, ...payload.data.filter((r) => !ids.has(r.id))];
  }
};

watch(() => listQuery.data.value, syncRowsFromQuery, { immediate: true });

watch([side, debouncedSearch], () => {
  page.value = 1;
  accumulatedRows.value = [];
});

watch(
  () => route.query.side,
  (value) => {
    side.value = parsePaymentsListSide(value);
  },
);

watch(
  () => route.name,
  (name) => {
    if (name !== 'app-payments-page') return;
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root });
  },
);

const setSide = (value: 'in' | 'out') => {
  if (side.value === value) return;
  side.value = value;
  void router.replace({ query: { ...route.query, side: value } });
};

const routeParams = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  return tenantSlug ? { tenantSlug } : {};
};

const onSearchTextUpdate = (value: string) => {
  searchText.value = value;
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = value.trim();
  }, 300);
};

const openPay = (row: PayRow) => {
  router.push({ name: 'app-pay-detail-page', params: { ...routeParams(), payId: String(row.id) } });
};
const goCollect = () => router.push({ name: 'app-collect-pay-page', params: routeParams() });
const goPayout = () => router.push({ name: 'app-payout-pay-page', params: routeParams() });
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.quick-filter-pill {
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  background: var(--bw-neutral-surface, #fff);
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 500;
  color: #64748b;
  cursor: pointer;
}
.quick-filter-pill--active {
  background: #0d6b5c;
  border-color: #0d6b5c;
  color: #fff;
}
.rounded-sq-btn {
  border-radius: 8px;
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
