<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <q-skeleton type="rect" height="40px" />
    </q-card>

    <div v-else-if="order" class="column q-gutter-y-xs">
      <div class="catalog-workflow-header-grid">
        <div class="row items-center q-gutter-x-xs no-wrap ellipsis min-width-0 catalog-workflow-header-grid__identity">
          <span
            class="text-subtitle2 text-weight-bolder text-grey-8 font-mono bg-grey-2 q-px-xs rounded-borders"
            style="font-size: 12px"
          >
            {{ order.order_no }}
          </span>
          <OrderPricingModeBadge
            :is-negotiable="!!order.is_negotiable_snapshot"
            :shop-type="order.shop_type_snapshot"
          />
        </div>

        <CatalogOrderRatesBar
          variant="compact"
          compact-layout="header"
          :order="order"
          :saving="savingRates"
          @save-rates="emit('save-rates', $event)"
          @change-rates="emit('change-rates', $event)"
        />

        <div class="row items-center justify-end q-gutter-x-xs no-wrap workflow-trailing catalog-workflow-header-grid__actions">
        <q-btn
          flat
          round
          dense
          color="grey-8"
          icon="ph ph-arrows-clockwise"
          size="sm"
          aria-label="Reload order"
          :loading="isRefreshing"
          @click="emit('refresh')"
        >
          <q-tooltip>Reload order</q-tooltip>
        </q-btn>
        <q-btn
          outline
          dense
          no-caps
          color="primary"
          class="text-weight-bold q-px-sm"
          icon="ph ph-clipboard-text"
          label="Bulk Paste"
          size="sm"
          :disable="!canBulkPaste"
          @click="emit('open-bulk-paste')"
        >
          <q-tooltip>Paste barcode, product code, and values from Excel</q-tooltip>
        </q-btn>
        <CatalogOrderColumnSelectorButton
          :visible-columns="visibleColumns"
          @update:visible-columns="emit('update:visible-columns', $event)"
        />
        <q-btn-dropdown
          flat
          round
          dense
          color="grey-8"
          icon="ph ph-file-xls"
          size="sm"
          auto-close
          :disable="!canDownloadExcel"
        >
          <q-tooltip>Download Excel</q-tooltip>
          <q-list dense class="q-py-xs" style="min-width: 200px">
            <q-item clickable v-ripple @click="emit('download-excel', { includeImages: true })">
              <q-item-section avatar style="min-width: 28px">
                <q-icon name="ph ph-image" size="16px" color="positive" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-caption text-weight-medium">With images</q-item-label>
                <q-item-label caption>Product pictures in column B</q-item-label>
              </q-item-section>
            </q-item>
            <q-item clickable v-ripple @click="emit('download-excel', { includeImages: false })">
              <q-item-section avatar style="min-width: 28px">
                <q-icon name="ph ph-table" size="16px" color="grey-8" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-caption text-weight-medium">Without images</q-item-label>
                <q-item-label caption>Faster export, compact rows</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
        <q-btn
          flat
          round
          dense
          color="grey-8"
          icon="ph ph-gear"
          size="sm"
          @click="emit('open-settings')"
        >
          <q-tooltip>Order settings and totals</q-tooltip>
        </q-btn>
        </div>
      </div>

      <CatalogOrderStatusWorkflowBar
        :status="order.status"
        :is-negotiable="!!order.is_negotiable_snapshot"
        :updating="updating"
        :target-status="targetStatus"
        @update-status="emit('update-status', $event)"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder } from '../types';
import CatalogOrderColumnSelectorButton from './CatalogOrderColumnSelectorButton.vue';
import CatalogOrderRatesBar from './CatalogOrderRatesBar.vue';
import CatalogOrderStatusWorkflowBar from './CatalogOrderStatusWorkflowBar.vue';
import OrderPricingModeBadge from './OrderPricingModeBadge.vue';
import { isCatalogStaffReadOnly } from '../utils/catalogOrderStatus';

const props = defineProps<{
  order: ShopOrder | null;
  isLoading?: boolean;
  visibleColumns?: string[];
  canDownloadExcel?: boolean;
  isRefreshing?: boolean;
  updating?: boolean;
  targetStatus?: string | null;
  savingRates?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:visible-columns', columns: string[]): void;
  (e: 'download-excel', payload: { includeImages: boolean }): void;
  (e: 'refresh'): void;
  (e: 'open-settings'): void;
  (e: 'open-bulk-paste'): void;
  (e: 'update-status', status: string): void;
  (
    e: 'save-rates',
    payload: {
      conversion_rate: number | null;
      cargo_rate: number | null;
      profit_rate: number | null;
      first_offer_rate: number | null;
      final_offer_rate: number | null;
      profit_basis: 'purchase' | 'total_cost';
    },
  ): void;
  (
    e: 'change-rates',
    payload: {
      conversion_rate: number | null;
      cargo_rate: number | null;
      profit_rate: number | null;
      first_offer_rate: number | null;
      final_offer_rate: number | null;
      profit_basis: 'purchase' | 'total_cost';
    },
  ): void;
}>();

const canBulkPaste = computed(() => !isCatalogStaffReadOnly(props.order?.status));
</script>

<style scoped>
.catalog-workflow-header-grid {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  grid-template-rows: auto auto;
  align-items: center;
  column-gap: 8px;
  row-gap: 4px;
}

.catalog-workflow-header-grid__identity {
  grid-column: 1;
  grid-row: 1;
}

.catalog-workflow-header-grid__actions {
  grid-column: 3;
  grid-row: 1;
}

.workflow-trailing {
  flex-shrink: 0;
}

@media (max-width: 599px) {
  .workflow-trailing {
    flex-wrap: wrap;
    row-gap: 4px;
  }
}
</style>
