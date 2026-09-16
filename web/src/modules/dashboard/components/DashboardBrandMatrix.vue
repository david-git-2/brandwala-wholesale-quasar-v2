<template>
  <div v-if="brands && brands.length > 0" class="brand-matrix-card">
    <div class="brand-matrix-header">
      <div class="row items-center q-gutter-x-xs">
        <span class="brand-matrix-title">Brand Performance & Contribution</span>
      </div>
      <span class="text-caption text-slate-400">Filter workspace by brand</span>
    </div>

    <!-- Table of Brands -->
    <div class="brand-matrix-table-wrap">
      <table class="brand-table">
        <thead>
          <tr>
            <th class="text-left">Brand</th>
            <th class="text-right">Revenue</th>
            <th class="text-center" style="width: 140px">Share</th>
            <th class="text-right">Orders</th>
            <th class="text-right">Gross Margin</th>
            <th class="text-center">Velocity</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="brand in brands"
            :key="brand.id"
            class="brand-row"
            :class="{ 'brand-row--active': activeBrandId === brand.id }"
            @click="$emit('selectBrand', brand.id)"
          >
            <!-- Brand Name -->
            <td class="text-left">
              <div class="row items-center no-wrap">
                <div class="brand-avatar-box q-mr-sm">
                  {{ brand.name.charAt(0) }}
                </div>
                <div class="column">
                  <span class="text-weight-medium text-slate-900 line-height-1">{{ brand.name }}</span>
                  <span class="text-caption text-slate-400">{{ brand.category || 'Wholesale Desk' }}</span>
                </div>
              </div>
            </td>

            <!-- Revenue -->
            <td class="text-right bw-tabular text-weight-semibold text-slate-900">
              {{ formatDashboardMoney(brand.revenue) }}
            </td>

            <!-- Share % (Mini Progress Bar) -->
            <td class="text-center">
              <div class="share-cell">
                <div class="share-bar">
                  <div class="share-bar__fill" :style="{ width: `${brand.sharePct}%` }" />
                </div>
                <span class="share-val bw-tabular text-caption text-slate-500">{{ brand.sharePct }}%</span>
              </div>
            </td>

            <!-- Orders Count -->
            <td class="text-right bw-tabular text-slate-600">
              {{ formatDashboardCount(brand.orderCount) }}
            </td>

            <!-- Gross Margin % -->
            <td class="text-right bw-tabular">
              <span class="text-weight-medium" :class="brand.marginPct >= 28 ? 'text-emerald' : 'text-slate-600'">
                {{ brand.marginPct.toFixed(1) }}%
              </span>
            </td>

            <!-- Velocity Status Chip -->
            <td class="text-center">
              <span class="velocity-pill" :class="`velocity-pill--${brand.velocityKey || 'steady'}`">
                {{ brand.velocityLabel || 'Steady' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDashboardCount, formatDashboardMoney } from '../utils/formatDashboardMetric';

export type BrandMatrixItem = {
  id: number;
  name: string;
  category?: string;
  revenue: number;
  sharePct: number;
  orderCount: number;
  marginPct: number;
  velocityLabel?: string;
  velocityKey?: 'fast' | 'steady' | 'slow';
};

withDefaults(
  defineProps<{
    brands?: BrandMatrixItem[];
    activeBrandId?: number | null;
  }>(),
  {
    brands: () => [],
    activeBrandId: null,
  },
);

defineEmits<{
  (e: 'selectBrand', brandId: number): void;
}>();
</script>

<style scoped>
.brand-matrix-card {
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #F1F5F9);
  border-radius: var(--bw-radius-md, 12px);
  padding: 0.85rem 1rem;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
}

.brand-matrix-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.brand-matrix-title {
  font-size: 13px;
  font-weight: 600;
  color: #0F172A;
}

.brand-matrix-table-wrap {
  overflow-x: auto;
}

.brand-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
}

.brand-table thead tr th {
  padding: 0.4rem 0.65rem;
  font-size: 11px;
  font-weight: 500;
  color: #64748B;
  border-bottom: 1px solid #F1F5F9;
}

.brand-row {
  cursor: pointer;
  transition: all 0.15s ease;
  border-bottom: 1px solid #F8FAFC;
}

.brand-row:hover {
  background: #F8FAFC;
}

.brand-row--active {
  background: #F1F5F9;
}

.brand-row td {
  padding: 0.6rem 0.65rem;
}

.brand-avatar-box {
  width: 22px;
  height: 22px;
  border-radius: 4px;
  background: #F1F5F9;
  color: #475569;
  font-size: 11px;
  font-weight: 700;
  display: grid;
  place-content: center;
}

.share-cell {
  display: flex;
  align-items: center;
  gap: 6px;
  justify-content: center;
}

.share-bar {
  flex: 1;
  height: 4px;
  border-radius: 2px;
  background: #E2E8F0;
  overflow: hidden;
  max-width: 65px;
}

.share-bar__fill {
  height: 100%;
  background: #0F172A;
  border-radius: 2px;
}

.velocity-pill {
  font-size: 10.5px;
  font-weight: 500;
  padding: 1px 7px;
  border-radius: 4px;
}

.velocity-pill--fast {
  background: #DCFCE7;
  color: #166534;
}

.velocity-pill--steady {
  background: #E0F2FE;
  color: #075985;
}

.velocity-pill--slow {
  background: #FEF3C7;
  color: #92400E;
}

.line-height-1 {
  line-height: 1.2;
}

.text-emerald {
  color: #10B981;
}
.text-slate-400 { color: #94A3B8; }
.text-slate-500 { color: #64748B; }
.text-slate-600 { color: #475569; }
.text-slate-900 { color: #0F172A; }
</style>
