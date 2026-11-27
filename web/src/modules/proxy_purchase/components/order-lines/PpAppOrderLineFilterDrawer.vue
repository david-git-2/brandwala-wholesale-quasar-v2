<template>
  <FilterSidebar v-model="isOpen" title="Filters">
    <div class="column q-gutter-y-md">
      <q-select
        :model-value="draftGroupBy"
        :options="groupByOptions"
        outlined
        dense
        label="Group by"
        emit-value
        map-options
        @update:model-value="emit('update:draftGroupBy', $event)"
      />

      <div>
        <div class="text-caption text-grey-7 q-mb-xs">Fulfillment</div>
        <div class="row q-gutter-xs pp-app-line-filter-drawer__chip-row">
          <q-chip
            v-for="opt in fulfillmentChipOptions"
            :key="opt.value"
            clickable
            dense
            :color="isPlacementSelected(opt.value) ? 'primary' : undefined"
            :text-color="isPlacementSelected(opt.value) ? 'white' : undefined"
            :outline="!isPlacementSelected(opt.value)"
            @click="togglePlacement(opt.value)"
          >
            {{ opt.label }}
          </q-chip>
        </div>
      </div>

      <q-select
        :model-value="draft.pp_customer_group_id"
        @update:model-value="patchDraft({ pp_customer_group_id: $event })"
        :options="customerGroupOptions"
        outlined
        dense
        label="Customer group"
        emit-value
        map-options
        clearable
        :loading="loading"
      />
      <q-select
        :model-value="draft.pp_supplier_group_id"
        @update:model-value="patchDraft({ pp_supplier_group_id: $event })"
        :options="supplierGroupOptions"
        outlined
        dense
        label="Supplier"
        emit-value
        map-options
        clearable
        :loading="loading"
      />
      <q-select
        :model-value="draft.shipment_id"
        @update:model-value="patchDraft({ shipment_id: $event })"
        :options="shipmentOptions"
        outlined
        dense
        label="Shipment"
        emit-value
        map-options
        clearable
        :loading="loading"
      />

      <q-expansion-item
        dense
        switch-toggle-side
        expand-separator
        class="pp-app-line-filter-drawer__store-hosts"
        :label="storeUrlExpansionLabel"
        header-class="q-px-none"
        :default-opened="draft.url_hosts.length > 0"
      >
        <q-linear-progress v-if="loading" indeterminate color="primary" class="q-mb-sm" />
        <div
          v-else-if="!urlHostList.length"
          class="text-caption text-grey-6 q-py-sm"
        >
          No store URLs on order lines yet.
        </div>
        <q-list v-else dense class="pp-app-line-filter-drawer__host-list">
          <q-item
            v-for="host in urlHostList"
            :key="host"
            tag="label"
            dense
            class="q-px-none"
            clickable
          >
            <q-item-section side class="q-pr-sm">
              <q-checkbox
                dense
                :model-value="isUrlHostSelected(host)"
                @update:model-value="setUrlHostSelected(host, $event)"
              />
            </q-item-section>
            <q-item-section class="pp-app-line-filter-drawer__host-label">
              {{ host }}
            </q-item-section>
          </q-item>
        </q-list>
      </q-expansion-item>
    </div>

    <template #footer>
      <div class="row justify-end q-gutter-x-sm">
        <q-btn flat no-caps label="Reset" color="grey-7" @click="onReset" />
        <q-btn unelevated no-caps label="Apply filters" color="primary" @click="onApply" />
      </div>
    </template>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import {
  PP_ORDER_LINE_PLACEMENT_LABELS,
  PP_ORDER_LINE_STAFF_PLACEMENT_STATUSES,
} from '../../utils/ppOrderLinePlacement';
import type { PpOrderLinePlacementStatus } from '../../types/ppPurchaseRequest';
import {
  normalizePpAppOrderLineUrlHosts,
  type PpAppOrderLineGroupBy,
  type PpAppOrderLineListFilters,
  type PpAppOrderLineStaffFilterOptions,
} from '../../types/ppAppOrderLineFilters';

const props = defineProps<{
  modelValue: boolean;
  draft: PpAppOrderLineListFilters;
  draftGroupBy: PpAppOrderLineGroupBy;
  filterOptions: PpAppOrderLineStaffFilterOptions | undefined;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'update:draft': [value: PpAppOrderLineListFilters];
  'update:draftGroupBy': [value: PpAppOrderLineGroupBy];
  apply: [];
  reset: [];
}>();

const groupByOptions = [
  { label: 'None', value: 'none' as const },
  { label: 'Store URL', value: 'store_url' as const },
];

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const draft = computed(() => props.draft);

const patchDraft = (patch: Partial<PpAppOrderLineListFilters>) => {
  emit('update:draft', { ...props.draft, ...patch });
};

const fulfillmentChipOptions = computed(() =>
  PP_ORDER_LINE_STAFF_PLACEMENT_STATUSES.map((value) => ({
    label: PP_ORDER_LINE_PLACEMENT_LABELS[value as PpOrderLinePlacementStatus],
    value,
  })),
);

const selectedPlacements = computed(() => new Set(props.draft.placement_statuses));

const isPlacementSelected = (status: PpOrderLinePlacementStatus) =>
  selectedPlacements.value.has(status);

const togglePlacement = (status: PpOrderLinePlacementStatus) => {
  const next = new Set(props.draft.placement_statuses);
  if (next.has(status)) {
    next.delete(status);
  } else {
    next.add(status);
  }
  patchDraft({ placement_statuses: [...next] });
};

const customerGroupOptions = computed(() =>
  (props.filterOptions?.customer_groups ?? []).map((g) => ({
    label: g.name,
    value: g.id,
  })),
);

const supplierGroupOptions = computed(() =>
  (props.filterOptions?.supplier_groups ?? []).map((g) => ({
    label: g.name,
    value: g.id,
  })),
);

const shipmentOptions = computed(() =>
  (props.filterOptions?.shipments ?? []).map((s) => ({
    label: s.name?.trim() || s.shipment_code?.trim() || `#${s.id}`,
    value: s.id,
  })),
);

const urlHostList = computed(() => {
  const hosts = [...(props.filterOptions?.url_hosts ?? [])];
  hosts.sort((a, b) => a.localeCompare(b));
  return hosts;
});

const selectedUrlHosts = computed(() => new Set(normalizePpAppOrderLineUrlHosts(props.draft.url_hosts)));

const isUrlHostSelected = (host: string) => selectedUrlHosts.value.has(host.trim().toLowerCase());

const setUrlHostSelected = (host: string, selected: boolean) => {
  const key = host.trim().toLowerCase();
  const next = new Set(selectedUrlHosts.value);
  if (selected) {
    next.add(key);
  } else {
    next.delete(key);
  }
  patchDraft({ url_hosts: [...next] });
};

const storeUrlExpansionLabel = computed(() => {
  const total = urlHostList.value.length;
  const selected = props.draft.url_hosts.length;
  if (total === 0) return 'Store URL';
  if (selected === 0) return `Store URL (${total})`;
  return `Store URL (${selected} selected)`;
});

const onApply = () => {
  emit('apply');
  isOpen.value = false;
};

const onReset = () => {
  emit('reset');
};
</script>

<style scoped>
.pp-app-line-filter-drawer__chip-row {
  flex-wrap: wrap;
}

.pp-app-line-filter-drawer__store-hosts {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
}

.pp-app-line-filter-drawer__store-hosts :deep(.q-item) {
  min-height: 36px;
}

.pp-app-line-filter-drawer__host-list {
  max-height: 220px;
  overflow-y: auto;
}

.pp-app-line-filter-drawer__host-label {
  word-break: break-all;
  font-size: 12px;
}
</style>