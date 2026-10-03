<template>
  <div class="column q-gutter-y-sm">
    <q-select
      v-model="siteRootId"
      :options="siteOptions"
      :label="siteLabel"
      dense
      outlined
      emit-value
      map-options
      class="soft-input"
      :rules="[(v) => v != null || 'Pick a warehouse or returns area']"
    />

    <q-select
      v-for="step in chainSteps"
      :key="step.kind"
      :model-value="selectedIds[step.kind] ?? null"
      :options="step.options"
      :label="step.label"
      dense
      outlined
      emit-value
      map-options
      class="soft-input"
      :disable="!step.parentId"
      :rules="step.kind === 'bin' ? [(v) => v != null || 'Pick a bin'] : []"
      @update:model-value="(id: number | null) => onPick(step.kind, id)"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, watch, withDefaults } from 'vue';
import {
  STOCK_LOCATION_KIND_LABELS,
  STOCK_LOCATION_PICK_CHAIN,
} from '../constants/stockLocationHierarchy';
import type { StockLocation, StockLocationKind } from '../types/stockLocation';
import {
  activeChildrenOfKind,
  activeRootSites,
  formatLocationOption,
  getStockLocationChain,
} from '../utils/stockLocationOptions';

const props = withDefaults(
  defineProps<{
    locations: StockLocation[];
    modelValue: number | null;
    excludeIds?: number[];
    /** When true, emit the deepest selected node (warehouse/zone/…/bin), not only bin. */
    pickAnyNode?: boolean;
  }>(),
  { pickAnyNode: false },
);

const emit = defineEmits<{
  'update:modelValue': [value: number | null];
}>();

const siteLabel = `${STOCK_LOCATION_KIND_LABELS.warehouse} / ${STOCK_LOCATION_KIND_LABELS.returns}`;

const siteRootId = computed({
  get: () => selectedIds.warehouse ?? selectedIds.returns ?? null,
  set: (id: number | null) => {
    clearFromKind('zone');
    if (id == null) {
      selectedIds.warehouse = null;
      selectedIds.returns = null;
      emitBin();
      return;
    }
    const loc = props.locations.find((l) => l.id === id);
    selectedIds.warehouse = loc?.kind === 'warehouse' ? id : null;
    selectedIds.returns = loc?.kind === 'returns' ? id : null;
    emitBin();
  },
});

const selectedIds = reactive<Partial<Record<StockLocationKind, number | null>>>({
  warehouse: null,
  returns: null,
  zone: null,
  shelf: null,
  level: null,
  bin: null,
});

const excluded = computed(() => new Set(props.excludeIds ?? []));

const siteOptions = computed(() =>
  activeRootSites(props.locations)
    .filter((loc) => !excluded.value.has(loc.id))
    .map((loc) => ({
      label: `${STOCK_LOCATION_KIND_LABELS[loc.kind]}: ${formatLocationOption(loc)}`,
      value: loc.id,
    })),
);

const chainSteps = computed(() => {
  const rootId = siteRootId.value;
  const steps: Array<{
    kind: StockLocationKind;
    label: string;
    parentId: number | null;
    options: { label: string; value: number }[];
  }> = [];

  let parentId: number | null = rootId;
  for (const kind of STOCK_LOCATION_PICK_CHAIN) {
    const options = parentId == null
      ? []
      : activeChildrenOfKind(props.locations, parentId, kind)
          .filter((loc) => !excluded.value.has(loc.id))
          .map((loc) => ({
            label: formatLocationOption(loc),
            value: loc.id,
          }));

    steps.push({
      kind,
      label: STOCK_LOCATION_KIND_LABELS[kind],
      parentId,
      options,
    });

    const picked = selectedIds[kind] ?? null;
    parentId = picked;
  }

  return steps;
});

function clearFromKind(kind: StockLocationKind) {
  const start = STOCK_LOCATION_PICK_CHAIN.indexOf(kind);
  if (start < 0) return;
  for (const k of STOCK_LOCATION_PICK_CHAIN.slice(start)) {
    selectedIds[k] = null;
  }
}

function onPick(kind: StockLocationKind, id: number | null) {
  selectedIds[kind] = id;
  const idx = STOCK_LOCATION_PICK_CHAIN.indexOf(kind);
  if (idx >= 0) {
    for (const k of STOCK_LOCATION_PICK_CHAIN.slice(idx + 1)) selectedIds[k] = null;
  }
  emitBin();
}

function resolvedPickId(): number | null {
  if (props.pickAnyNode) {
    return (
      selectedIds.bin ??
      selectedIds.level ??
      selectedIds.shelf ??
      selectedIds.zone ??
      siteRootId.value ??
      null
    );
  }
  return selectedIds.bin ?? null;
}

function emitBin() {
  emit('update:modelValue', resolvedPickId());
}

function hydrateFromLocationId(locationId: number | null) {
  selectedIds.warehouse = null;
  selectedIds.returns = null;
  selectedIds.zone = null;
  selectedIds.shelf = null;
  selectedIds.level = null;
  selectedIds.bin = null;

  if (locationId == null) return;

  const chain = getStockLocationChain(props.locations, locationId);
  if (chain.warehouse) selectedIds.warehouse = chain.warehouse.id;
  if (chain.returns) selectedIds.returns = chain.returns.id;
  if (chain.zone) selectedIds.zone = chain.zone.id;
  if (chain.shelf) selectedIds.shelf = chain.shelf.id;
  if (chain.level) selectedIds.level = chain.level.id;
  if (chain.bin) selectedIds.bin = chain.bin.id;
}

watch(
  () => [props.modelValue, props.locations] as const,
  ([id]) => {
    if (id == null) {
      hydrateFromLocationId(null);
      return;
    }
    if (resolvedPickId() === id) return;
    hydrateFromLocationId(id);
  },
  { immediate: true },
);
</script>
