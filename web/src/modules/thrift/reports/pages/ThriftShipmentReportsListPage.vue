<template>
  <q-page class="bw-page thrift-shipment-reports-list-page">
    <div class="bw-page__stack">
      <header class="page-nav">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="primary"
          aria-label="Back to Reports"
          :to="reportsListPath"
        />
        <div>
          <div class="text-overline text-primary">Thrift / Reports</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Was this purchase worth it?</h1>
          <p class="page-nav__sub q-mb-none">Pick a shipment to see if it made money.</p>
        </div>
      </header>

      <q-input
        v-model="search"
        dense
        outlined
        clearable
        debounce="200"
        placeholder="Search shipments…"
        class="search-input"
      >
        <template #prepend>
          <q-icon name="ph ph-magnifying-glass" />
        </template>
      </q-input>

      <div v-if="isLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="!filteredRows.length" class="empty-state">
        <q-icon name="ph ph-package" size="44px" class="q-mb-sm" />
        <div class="text-subtitle1 text-weight-medium">No shipments yet</div>
        <div class="text-body2">Create a thrift shipment first, then check profit here.</div>
      </div>

      <div v-else class="shipment-list">
        <button
          v-for="row in filteredRows"
          :key="row.id"
          type="button"
          class="shipment-row"
          @click="goDetail(row.id)"
        >
          <span class="shipment-row__icon" aria-hidden="true">
            <q-icon name="ph ph-package" size="22px" />
          </span>
          <span class="shipment-row__body">
            <span class="shipment-row__name">{{ row.name }}</span>
            <span class="shipment-row__meta">{{ formatDate(row.created_at) }}</span>
            <span class="shipment-row__teaser">{{ profitTeaserFor(row.id) }}</span>
          </span>
          <q-icon name="ph ph-caret-right" class="shipment-row__chevron" size="20px" />
        </button>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQueries } from '@tanstack/vue-query';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import { useThriftReportShipmentsQuery } from '../composables/useThriftReportsQuery';
import { thriftReportsRepository } from '../repositories/thriftReportsRepository';

const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const search = ref('');

const { data: shipments, isLoading } = useThriftReportShipmentsQuery(tenantId);

const reportsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports`,
);

const filteredRows = computed(() => {
  const q = search.value.trim().toLowerCase();
  const rows = shipments.value || [];
  if (!q) return rows;
  return rows.filter((row) => row.name?.toLowerCase().includes(q) || String(row.id).includes(q));
});

const teaserQueries = useQueries({
  queries: computed(() => {
    const tid = Number(tenantId.value) || 0;
    return filteredRows.value.map((row) => ({
      queryKey: thriftQueryKeys.reportDetail({ tenantId: tid, shipmentId: row.id }),
      queryFn: () => thriftReportsRepository.getShipmentSalesReport(tid, row.id),
      enabled: !!tenantId.value && !!row.id,
      staleTime: 30 * 1000,
    }));
  }),
});

const teaserByShipmentId = computed(() => {
  const map = new Map<number, { isLoading: boolean; isError: boolean; text: string }>();
  const rows = filteredRows.value;
  const results = teaserQueries.value;
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    const q = results[i];
    if (!q || q.isLoading || q.isPending) {
      map.set(row.id, { isLoading: true, isError: false, text: '…' });
      continue;
    }
    if (q.isError) {
      map.set(row.id, { isLoading: false, isError: true, text: 'Profit unavailable' });
      continue;
    }
    const summary = q.data?.summary;
    if (!summary) {
      map.set(row.id, { isLoading: false, isError: true, text: 'Profit unavailable' });
      continue;
    }
    const finished = summary.unitsSold + summary.unitsRto + summary.unitsReturned;
    if (finished === 0) {
      map.set(row.id, { isLoading: false, isError: false, text: 'No finished sales yet' });
      continue;
    }
    map.set(row.id, {
      isLoading: false,
      isError: false,
      text: `Profit ${formatThriftAmount(summary.netProfit)} · ${summary.unitsSold} delivered`,
    });
  }
  return map;
});

function profitTeaserFor(id: number) {
  return teaserByShipmentId.value.get(id)?.text ?? '…';
}

function goDetail(id: number) {
  void router.push(`/${tenantSlug.value || 'tenant'}/app/thrift/reports/${id}`);
}

function formatDate(value: string) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return value;
  }
}
</script>

<style scoped>
.page-nav {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
}

.page-nav__sub {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--bw-theme-muted, #6b7280);
}

.search-input :deep(.q-field__control) {
  border-radius: 12px;
}

.shipment-list {
  display: grid;
  gap: 0.65rem;
}

.shipment-row {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  width: 100%;
  min-height: 76px;
  padding: 0.9rem 1rem;
  text-align: left;
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
  color: inherit;
  cursor: pointer;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;
}

.shipment-row:hover {
  border-color: var(--bw-theme-primary, var(--q-primary));
  box-shadow: var(--bw-theme-shadow, 0 8px 24px rgb(0 0 0 / 0.06));
}

.shipment-row__icon {
  width: 42px;
  height: 42px;
  border-radius: 11px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: rgba(55, 65, 81, 0.1);
  color: #374151;
  flex: 0 0 auto;
}

.shipment-row__body {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.shipment-row__name {
  font-weight: 700;
  font-size: 1rem;
  color: var(--bw-theme-ink, inherit);
}

.shipment-row__meta {
  font-size: 0.8rem;
  color: var(--bw-theme-muted, #6b7280);
}

.shipment-row__teaser {
  font-size: 0.8rem;
  color: var(--bw-theme-ink, inherit);
  opacity: 0.85;
}

.shipment-row__chevron {
  color: var(--bw-theme-muted, #9ca3af);
  flex: 0 0 auto;
}

.empty-state {
  border: 1px dashed var(--bw-theme-border, rgba(0, 0, 0, 0.15));
  border-radius: 14px;
  padding: 2.5rem 1.25rem;
  text-align: center;
  color: var(--bw-theme-muted, #6b7280);
}
</style>
