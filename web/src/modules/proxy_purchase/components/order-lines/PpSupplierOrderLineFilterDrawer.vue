<template>
  <FilterSidebar v-model="isOpen" title="Filters">
    <div>
      <div class="text-caption text-grey-7 q-mb-xs">Fulfillment</div>
      <div class="row q-gutter-xs pp-supplier-line-filter-drawer__chip-row">
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
import type { PpOrderLinePlacementStatus } from '../../types/ppPurchaseRequest';
import type { PpSupplierOrderLineListFilters } from '../../types/ppSupplierOrderLineFilters';
import {
  PP_ORDER_LINE_PLACEMENT_LABELS,
  PP_SUPPLIER_FILTER_PLACEMENT_STATUSES,
} from '../../utils/ppOrderLinePlacement';

const props = defineProps<{
  modelValue: boolean;
  draft: PpSupplierOrderLineListFilters;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'update:draft': [value: PpSupplierOrderLineListFilters];
  apply: [];
  reset: [];
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const patchDraft = (patch: Partial<PpSupplierOrderLineListFilters>) => {
  emit('update:draft', { ...props.draft, ...patch });
};

const fulfillmentChipOptions = computed(() =>
  PP_SUPPLIER_FILTER_PLACEMENT_STATUSES.map((value) => ({
    label: PP_ORDER_LINE_PLACEMENT_LABELS[value],
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

const onApply = () => {
  emit('apply');
  isOpen.value = false;
};

const onReset = () => {
  emit('reset');
  isOpen.value = false;
};
</script>

<style scoped>
.pp-supplier-line-filter-drawer__chip-row {
  flex-wrap: wrap;
}
</style>