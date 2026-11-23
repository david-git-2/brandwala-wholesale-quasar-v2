<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner v-if="error" class="tf-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ (error as Error).message }}
      </q-banner>

      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search customer name, phone, or email..."
        :filter-count="0"
        :show-filters="false"
        icon-search
        @update:search="onSearchTextUpdate"
      >
        <template #trailing>
          <q-btn
            flat
            round
            dense
            color="grey-8"
            icon="ph ph-arrows-clockwise"
            class="flex-shrink-0"
            aria-label="Refresh"
            :loading="isFetching"
            @click="() => refetch()"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </template>
      </ProcurementOpsListToolbar>

      <div v-if="isLoading && !customers.length" class="customer-list-card col">
        <div class="customer-list-scroll">
          <div v-for="n in 8" :key="n" class="customer-list-item customer-list-item--skeleton">
            <q-skeleton type="text" width="220px" class="q-mb-xs" />
            <q-skeleton type="text" width="320px" />
          </div>
        </div>
      </div>

      <div
        v-else-if="!customers.length"
        class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block col customer-list-card"
      >
        <q-icon name="ph ph-users-three" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-2xs">No customers found</div>
      </div>

      <div v-else class="customer-list-card col column no-wrap">
        <div class="customer-list-scroll col">
          <div
            v-for="row in customers"
            :key="row.customer_group_id"
            class="customer-list-item"
            @click="openCustomer(row.customer_group_id)"
          >
            <div class="customer-info">
              <div class="customer-title-line">
                <span class="customer-name">{{ row.name }}</span>
                <TfStatusBadge v-if="!row.is_active" status="inactive" label="Inactive" />
              </div>
              <div class="customer-meta-line text-caption text-grey-7">
                <span v-if="row.phone">{{ row.phone }}</span>
                <span v-if="row.phone" class="meta-dot">·</span>
                <span>{{ row.member_count }} member{{ row.member_count === 1 ? '' : 's' }}</span>
              </div>
            </div>
            <div class="customer-aside column items-end">
              <span class="text-caption tf-tabular" :class="row.still_due > 0 ? 'text-negative' : ''">
                Due {{ formatAmountBdt(row.still_due) }}
              </span>
              <span class="text-caption tf-tabular text-grey-7">
                Credit {{ formatAmountBdt(row.store_credit_balance) }}
              </span>
              <q-icon name="ph ph-caret-right" size="15px" class="customer-chevron" />
            </div>
          </div>
        </div>
        <div v-if="hasMore" class="q-pa-sm row justify-center border-top">
          <TfBtn flat dense no-caps label="Load more" :loading="isLoadingMore" @click="() => fetchNextPage()" />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { useCustomersReportList } from '../composables/useCustomersReportList';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const {
  customers,
  isLoading,
  isFetching,
  error,
  searchText,
  hasMore,
  isLoadingMore,
  fetchNextPage,
  refetch,
} = useCustomersReportList();

function onSearchTextUpdate(val: string | null | undefined) {
  searchText.value = val ?? '';
}

function openCustomer(customerGroupId: number) {
  void router.push({
    name: 'app-finance-customers-report-detail-page',
    params: {
      tenantSlug: tenantSlug.value || undefined,
      customerGroupId: String(customerGroupId),
    },
  });
}
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  max-height: calc(100vh - 55px);
  overflow: hidden;
  background: var(--tf-neutral-canvas, #f8fafc);
}

.customer-list-card {
  flex: 1 1 0%;
  min-height: 0;
  background: var(--tf-neutral-surface, #ffffff);
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
}

.customer-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.customer-list-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--tf-neutral-border, #f1f5f9);
  cursor: pointer;
  min-height: 50px;
}

.customer-list-item:hover {
  background: var(--tf-hover-bg);
}

.customer-title-line {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.customer-name {
  font-weight: 600;
}

.customer-meta-line .meta-dot {
  margin: 0 0.35rem;
}
</style>