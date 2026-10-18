<template>
  <FilterSidebar
    v-model="isOpen"
    title="Unit cost details"
    width="min(440px, 92vw)"
    storage-key="procurement.warehouse-cost-detail-width"
  >
    <div v-if="stockRow" class="column q-gutter-y-md">
      <div class="detail-card q-pa-md rounded-borders">
        <div class="text-caption text-grey-7 text-weight-medium">Product</div>
        <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ stockRow.item_name }}</div>
        <div v-if="stockRow.product_code" class="text-caption font-mono text-grey-7 q-mt-xs">
          {{ stockRow.product_code }}
        </div>
        <dl class="detail-dl q-mt-sm q-mb-none">
          <dt>Lot qty</dt>
          <dd class="font-mono">{{ stockRow.quantity }}</dd>
          <dt>Unit cost (BDT)</dt>
          <dd class="font-mono text-weight-bold">{{ formatCost(unitCost) }}</dd>
          <dt>Line total (BDT)</dt>
          <dd class="font-mono">{{ formatCost(unitCost * stockRow.quantity) }}</dd>
          <dt>Cost source</dt>
          <dd>{{ costSourceLabel }}</dd>
        </dl>
      </div>

      <div v-if="loading" class="flex flex-center q-py-lg">
        <q-spinner color="primary" size="32px" />
      </div>
      <q-banner v-else-if="loadError" dense rounded class="bg-red-1 text-red-10">
        {{ loadError }}
      </q-banner>

      <template v-else-if="overview">
        <div class="detail-card q-pa-md rounded-borders">
          <div class="text-caption text-grey-7 text-weight-medium">Shipment</div>
          <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ overview.shipment.name }}</div>
          <dl class="detail-dl q-mt-sm q-mb-none">
            <dt>Status</dt>
            <dd>{{ shipmentStatusLabel }}</dd>
            <dt>Type</dt>
            <dd class="text-capitalize">{{ overview.shipment.type }}</dd>
            <dt>Received weight</dt>
            <dd class="font-mono">
              {{ formatWeight(overview.shipment.received_weight ?? overview.shipment.total_weight_kg) }}
            </dd>
            <dt>Costs locked</dt>
            <dd>{{ overview.shipment.costs_locked ? 'Yes' : 'No' }}</dd>
            <dt>Stock posted</dt>
            <dd>{{ overview.shipment.stock_ready ? 'Yes' : 'No' }}</dd>
          </dl>
          <q-btn
            v-if="shipmentRoute"
            flat
            dense
            no-caps
            color="primary"
            class="q-mt-sm"
            icon="ph ph-arrow-square-out"
            label="Open shipment"
            :to="shipmentRoute"
            @click="isOpen = false"
          />
        </div>

        <div class="detail-card q-pa-md rounded-borders">
          <div class="text-caption text-grey-7 text-weight-medium">FX &amp; rates (shipment)</div>
          <dl v-if="costingShipment" class="detail-dl q-mt-sm q-mb-none">
            <dt>Material FX</dt>
            <dd class="font-mono">
              {{ formatRate(costingShipment.product_conversion_rate) }}
            </dd>
            <dt>Freight FX</dt>
            <dd class="font-mono">
              {{ formatRate(costingShipment.cargo_conversion_rate) }}
            </dd>
            <dt>Payment blend</dt>
            <dd class="font-mono">
              {{ formatRate(costingShipment.transaction_rate) }}
            </dd>
            <dt>Cargo (foreign / kg)</dt>
            <dd class="font-mono">{{ formatRate(costingShipment.cargo_rate) }}</dd>
          </dl>
          <div v-else class="text-caption text-grey-7 q-mt-sm">No international FX on this shipment.</div>
        </div>

        <div class="detail-card q-pa-md rounded-borders">
          <div class="text-caption text-grey-7 text-weight-medium">Line inputs</div>
          <dl class="detail-dl q-mt-sm q-mb-none">
            <dt>Purchase price / unit</dt>
            <dd class="font-mono">{{ purchaseSym }}{{ formatCost(lineItem?.purchase_price ?? stockRow.purchase_price) }}</dd>
            <dt>Ordered qty (line)</dt>
            <dd class="font-mono">{{ lineItem?.ordered_quantity ?? stockRow.ordered_quantity }}</dd>
            <dt>Product weight</dt>
            <dd class="font-mono">{{ formatWeight(stockRow.product_weight) }} g</dd>
            <dt>Package weight</dt>
            <dd class="font-mono">{{ formatWeight(stockRow.package_weight) }} g</dd>
            <dt v-if="lineStamp != null">Stamped landed / unit</dt>
            <dd v-if="lineStamp != null" class="font-mono">৳{{ formatCost(lineStamp) }}</dd>
          </dl>
        </div>

        <div v-if="breakdownText" class="detail-card q-pa-md rounded-borders">
          <div class="text-caption text-grey-7 text-weight-medium">Calculation</div>
          <pre class="detail-breakdown q-mt-sm q-mb-none">{{ breakdownText }}</pre>
        </div>
      </template>
    </div>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  calculateLineLandedCostBreakdown,
  costingShipmentFromEntries,
} from 'src/shared/shipment-engine';
import { formatLineLandedCostTooltip } from '../utils/lineLandedCostTooltip';
import { formatGlobalShipmentStatus } from '../constants/shipmentStatus';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';
import type { GlobalStock } from '../repositories/globalStockRepository';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';
import { isGlobalStockCostingInput } from 'src/modules/global/utils/resolveGlobalStockUnitCost';
import type { ShipmentCostingCacheItem } from 'src/modules/global/composables/useShipmentItemsCostingCache';

const props = defineProps<{
  modelValue: boolean;
  stockRow: GlobalStock | null;
  unitCost: number;
  getShipmentItemsSync: (shipmentId: number) => ShipmentCostingCacheItem[];
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const route = useRoute();
const authStore = useAuthStore();

const isOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});

const loading = ref(false);
const loadError = ref<string | null>(null);
const overview = ref<Awaited<ReturnType<typeof globalShipmentRepository.getShipmentOverviewDetails>> | null>(
  null,
);

const formatCost = (val: number | null | undefined) =>
  Number(val ?? 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatRate = (val: number | null | undefined) => {
  const n = Number(val);
  if (!Number.isFinite(n)) return '—';
  return n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });
};

const formatWeight = (val: number | null | undefined) => {
  const n = Number(val);
  if (!Number.isFinite(n)) return '—';
  return n.toLocaleString(undefined, { maximumFractionDigits: 2 });
};

const shipmentStatusLabel = computed(() =>
  overview.value ? formatGlobalShipmentStatus(overview.value.shipment.status) : '—',
);

const lineItem = computed((): GlobalShipmentItem | null => {
  if (!overview.value || !props.stockRow) return null;
  return (
    overview.value.items.find((it) => it.id === props.stockRow!.shipment_item_id) ?? null
  );
});

const lineStamp = computed(() => {
  const stamped = lineItem.value?.landed_cost_bdt ?? props.stockRow?.landed_cost_bdt;
  if (stamped == null || !Number.isFinite(Number(stamped))) return null;
  return Number(stamped);
});

const costSourceLabel = computed(() => {
  if (lineStamp.value != null) return 'Stamped on shipment line (authoritative)';
  return 'Live estimate from shipment costs & weights';
});

const purchaseSym = computed(() => {
  const t = overview.value?.shipment.type;
  return t === 'local' ? '৳' : '£';
});

const costingShipment = computed(() => {
  if (!overview.value) return null;
  return costingShipmentFromEntries(
    overview.value.shipment,
    overview.value.cost_entries as never,
    overview.value.items,
  );
});

const breakdownText = computed(() => {
  if (!props.stockRow || !isGlobalStockCostingInput(props.stockRow) || !costingShipment.value) {
    return '';
  }
  const items = props.getShipmentItemsSync(props.stockRow.shipment_id);
  const allItems =
    overview.value?.items?.length
      ? overview.value.items
      : items.length
        ? items
        : [
            {
              purchase_price: props.stockRow.purchase_price,
              product_weight: props.stockRow.product_weight,
              package_weight: props.stockRow.package_weight,
              ordered_quantity: props.stockRow.ordered_quantity,
            },
          ];
  const breakdown = calculateLineLandedCostBreakdown(
    {
      purchase_price: props.stockRow.purchase_price,
      product_weight: props.stockRow.product_weight,
      package_weight: props.stockRow.package_weight,
      ordered_quantity: props.stockRow.ordered_quantity,
    },
    costingShipment.value,
    allItems,
  );
  return formatLineLandedCostTooltip(breakdown, purchaseSym.value, '৳');
});

const shipmentRoute = computed(() => {
  const id = props.stockRow?.shipment_id;
  if (!id) return null;
  const slug = authStore.selectedTenant?.slug ?? route.params.tenantSlug;
  if (!slug) return null;
  return `/${slug}/app/procurement/shipment/${id}`;
});

const loadOverview = async (shipmentId: number) => {
  loading.value = true;
  loadError.value = null;
  overview.value = null;
  try {
    overview.value = await globalShipmentRepository.getShipmentOverviewDetails(shipmentId);
  } catch (e) {
    loadError.value = e instanceof Error ? e.message : 'Could not load shipment details';
  } finally {
    loading.value = false;
  }
};

watch(
  () => [props.modelValue, props.stockRow?.shipment_id] as const,
  ([open, shipmentId]) => {
    if (open && shipmentId) {
      void loadOverview(shipmentId);
    }
    if (!open) {
      overview.value = null;
      loadError.value = null;
    }
  },
);
</script>

<style scoped lang="scss">
.detail-card {
  background: var(--tf-neutral-surface, #fff);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
}

.detail-dl {
  display: grid;
  grid-template-columns: minmax(0, 42%) 1fr;
  gap: 0.35rem 0.75rem;
  font-size: 12px;

  dt {
    color: var(--tf-neutral-muted, #736a61);
    margin: 0;
  }

  dd {
    margin: 0;
    text-align: right;
    color: var(--tf-neutral-ink, #171412);
  }
}

.detail-breakdown {
  font-family: var(--tf-font-mono, monospace);
  font-size: 11px;
  line-height: 1.45;
  white-space: pre-wrap;
  color: var(--tf-neutral-ink, #171412);
}
</style>
