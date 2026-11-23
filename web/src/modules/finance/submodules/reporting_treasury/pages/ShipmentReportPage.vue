<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-banner v-if="error" class="tf-status-banner bg-negative text-white flex-shrink-0" dense rounded>
        {{ (error as Error).message }}
      </q-banner>

      <ProcurementOpsListToolbar
        :search="searchText"
        search-placeholder="Search by shipment name, number, or vendor..."
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

      <div v-if="isLoading && !shipments.length" class="shipment-list-card col">
        <div class="shipment-list-scroll">
          <div v-for="n in 8" :key="n" class="shipment-list-item shipment-list-item--skeleton">
            <div class="shipment-info">
              <q-skeleton type="text" width="220px" height="18px" class="q-mb-xs" />
              <q-skeleton type="text" width="320px" height="13px" />
            </div>
            <div class="shipment-aside">
              <q-skeleton type="QBadge" width="75px" height="22px" class="rounded-borders" />
              <q-skeleton type="QBtn" size="xs" width="16px" height="16px" />
            </div>
          </div>
        </div>
      </div>

      <div
        v-else-if="!shipments.length"
        class="column items-center justify-center q-pa-xl text-grey-6 empty-state-block col shipment-list-card"
      >
        <q-icon name="ph ph-package" size="48px" class="q-mb-sm text-grey-4" />
        <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-2xs">No shipments found</div>
        <div class="text-caption text-grey-6">Try a different search or refresh the list.</div>
      </div>

      <div v-else class="shipment-list-card col">
        <div class="shipment-list-scroll">
          <div
            v-for="row in shipments"
            :key="row.id"
            class="shipment-list-item"
            @click="openShipmentDetail(row.id)"
          >
            <div class="shipment-info">
              <div class="shipment-title-line">
                <span class="shipment-name">{{ row.name || `Shipment #${row.id}` }}</span>
              </div>
              <div class="shipment-meta-line">
                <span class="meta-item meta-vendor font-mono">{{ formatShipmentDisplayNo(row) }}</span>
                <span v-if="row.vendor_name" class="meta-dot">·</span>
                <span v-if="row.vendor_name" class="meta-item meta-vendor">{{ row.vendor_name }}</span>
                <span class="meta-dot">·</span>
                <span class="meta-item meta-type">{{ formatTypeLabel(row.type) }}</span>
                <span class="meta-dot">·</span>
                <span class="meta-item meta-date">{{ formatDate(row.created_at) }}</span>
              </div>
            </div>

            <div class="shipment-aside">
              <span class="status-pill" :class="`status-pill--${getStatusSlug(row.status)}`">
                <q-icon :name="getStatusIcon(row.status)" size="12px" class="status-icon" />
                {{ formatShipmentStatusLabel(row.status) }}
              </span>
              <q-icon name="ph ph-caret-right" size="15px" class="shipment-chevron" />
            </div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import ProcurementOpsListToolbar from 'src/modules/procurement_stock/components/ProcurementOpsListToolbar.vue';
import { formatGlobalShipmentStatus } from 'src/modules/procurement_stock/constants/shipmentStatus';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  formatShipmentDisplayNo,
  useShipmentReportList,
} from '../composables/useShipmentReportList';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const { shipments, isLoading, isFetching, error, searchText, refetch } = useShipmentReportList();

const formatShipmentStatusLabel = formatGlobalShipmentStatus;

const formatDate = (dateStr: string | null | undefined): string => {
  if (!dateStr) return '—';
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch {
    return dateStr.split('T')[0] ?? '—';
  }
};

const formatTypeLabel = (type: string | null | undefined): string => {
  if (!type) return 'Standard';
  return type.charAt(0).toUpperCase() + type.slice(1);
};

const getStatusSlug = (status: string | null | undefined): string => {
  const s = (status ?? '').toLowerCase().trim();
  if (s === 'received') return 'received';
  if (s === 'in_transit') return 'transit';
  if (s === 'draft') return 'draft';
  if (s === 'cancelled') return 'cancelled';
  return 'default';
};

const getStatusIcon = (status: string | null | undefined): string => {
  const s = (status ?? '').toLowerCase().trim();
  if (s === 'received') return 'ph ph-check-circle';
  if (s === 'in_transit') return 'ph ph-truck';
  if (s === 'draft') return 'ph ph-file-dashed';
  if (s === 'cancelled') return 'ph ph-x-circle';
  return 'ph ph-circle';
};

function onSearchTextUpdate(val: string | null | undefined) {
  searchText.value = val ?? '';
}

function openShipmentDetail(shipmentId: number) {
  void router.push({
    name: 'app-finance-shipment-report-detail-page',
    params: {
      tenantSlug: tenantSlug.value || undefined,
      shipmentId: String(shipmentId),
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

.shipment-list-card {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--tf-neutral-surface, #ffffff);
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

.shipment-list-scroll {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.shipment-list-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--tf-neutral-border, #f1f5f9);
  cursor: pointer;
  transition: all 0.15s ease;
  min-height: 50px;
}

.shipment-list-item:hover {
  background: var(--tf-hover-bg);
}

.shipment-list-item:hover .shipment-name {
  color: var(--tf-neutral-ink);
}

.shipment-list-item:hover .shipment-chevron {
  color: var(--tf-neutral-ink);
  transform: translateX(2px);
}

.shipment-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.shipment-title-line {
  display: flex;
  align-items: center;
  gap: 6px;
}

.shipment-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  letter-spacing: -0.01em;
}

.shipment-meta-line {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  color: var(--tf-neutral-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.meta-item {
  font-weight: 400;
}

.meta-vendor {
  color: var(--tf-neutral-muted);
  font-weight: 500;
}

.meta-dot {
  color: var(--tf-neutral-chrome-text);
  font-weight: 700;
}

.shipment-aside {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-shrink: 0;
  margin-left: 1rem;
}

.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11.5px;
  font-weight: 500;
  padding: 2.5px 8px;
  border-radius: 999px;
  white-space: nowrap;
}

.status-icon {
  flex-shrink: 0;
}

.status-pill--received {
  background: var(--tf-success-soft);
  color: var(--tf-success);
}

.status-pill--transit {
  background: var(--tf-info-soft);
  color: var(--tf-info);
}

.status-pill--draft {
  background: var(--tf-warning-soft);
  color: var(--tf-warning);
}

.status-pill--cancelled {
  background: var(--tf-error-soft);
  color: var(--tf-error);
}

.status-pill--default {
  background: var(--tf-disabled-bg);
  color: var(--tf-neutral-muted);
}

.shipment-chevron {
  color: var(--tf-neutral-chrome-text);
  transition: all 0.15s ease;
}

.shipment-list-item--skeleton {
  cursor: default;
}

.shipment-list-item--skeleton:hover {
  background: transparent;
}

.text-slate-800 {
  color: var(--tf-neutral-ink);
}
</style>
