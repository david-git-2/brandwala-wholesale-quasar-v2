<template>
  <div class="pp-app-order-line-table column no-wrap col min-h-0">
    <div
      v-if="selectedIds.length > 0"
      class="pp-app-order-line-table__bulk row items-center justify-between q-mb-sm shrink-0"
    >
      <span class="text-body2">{{ selectedIds.length }} selected</span>
      <TfBtn
        variant="danger"
        size="md"
        icon="ph ph-trash"
        label="Delete selected"
        @click="emit('delete-selected', selectedIds.slice())"
      />
    </div>

    <div class="pp-app-order-line-table__card column col min-h-0 no-wrap overflow-hidden">
      <div
        ref="tableScrollRef"
        class="pp-app-order-line-table__scroll col min-h-0 hide-native-scrollbar"
      >
        <div class="pp-app-order-line-table__sheet">
          <div class="pp-app-order-line-table__head pp-app-order-line-table__grid" aria-hidden="true">
            <span class="text-center">
              <q-checkbox
                dense
                :model-value="allSelected"
                :indeterminate="someSelected && !allSelected"
                aria-label="Select all lines"
                @update:model-value="toggleAll"
              />
            </span>
            <span class="pp-app-order-line-table__head-product">Product</span>
            <span class="pp-app-order-line-table__head-text">Description</span>
            <span class="text-center">Customer quantity</span>
            <span class="text-center">Placed quantity</span>
            <span class="text-center">Price</span>
            <span class="text-center">Customer</span>
            <span class="text-center">Fulfillment</span>
            <span class="text-center">Supplier</span>
            <span class="text-center">Shipment</span>
            <span class="text-center">Status</span>
            <span class="text-center">Edit</span>
          </div>
          <div
            v-for="line in lines"
            :key="line.id"
            class="pp-app-order-line-table__body-row"
            :class="{ 'pp-app-order-line-table__body-row--selected': selectedSet.has(line.id) }"
          >
            <PpAppOrderLineRow
              :line="line"
              :selected="selectedSet.has(line.id)"
              :updating="updatingLineId === line.id"
              :supplier-options="supplierOptions"
              :shipment-options="shipmentOptions"
              :supplier-loading="supplierGroupsQuery.isPending.value"
              :shipment-loading="shipmentsQuery.isPending.value"
              @edit="emit('edit', $event)"
              @patch="emit('patch', $event)"
              @toggle-select="onToggleSelect"
            />
          </div>
        </div>
      </div>
      <ExcelTableScrollFooter
        ref="scrollFooterRef"
        class="pp-app-order-line-table__scroll-footer shrink-0"
        :get-scroll-container="getTableScrollContainer"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import ExcelTableScrollFooter from 'src/components/ui/ExcelTableScrollFooter.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { usePpPeopleGroupsQuery } from '../../composables/usePpPeopleGroupsQuery';
import { usePpShipmentsQuery } from '../../composables/usePpShipmentsQuery';
import { buildPpShipmentSelectOptions } from '../../types/ppShipment';
import type { PpOrderLine, PpStaffOrderLineUpdatePayload } from '../../types/ppPurchaseRequest';
import PpAppOrderLineRow from './PpAppOrderLineRow.vue';

const props = withDefaults(
  defineProps<{
    lines: PpOrderLine[];
    updatingLineId?: number | null;
  }>(),
  {
    updatingLineId: null,
  },
);

const emit = defineEmits<{
  edit: [line: PpOrderLine];
  patch: [payload: PpStaffOrderLineUpdatePayload];
  'delete-selected': [lineIds: number[]];
}>();

const selectedIds = ref<number[]>([]);
const selectedSet = computed(() => new Set(selectedIds.value));
const tableScrollRef = ref<HTMLElement | null>(null);
const scrollFooterRef = ref<InstanceType<typeof ExcelTableScrollFooter> | null>(null);

const getTableScrollContainer = () => tableScrollRef.value;

const supplierType = ref<'supplier'>('supplier');
const supplierGroupsQuery = usePpPeopleGroupsQuery(supplierType);
const shipmentsQuery = usePpShipmentsQuery();

const supplierOptions = computed(() => [
  { label: 'None', value: null as number | null },
  ...(supplierGroupsQuery.data.value ?? []).map((g) => ({
    label: g.name,
    value: g.id as number | null,
  })),
]);

const shipmentOptions = computed(() =>
  buildPpShipmentSelectOptions(shipmentsQuery.data.value ?? []),
);

const allSelected = computed(
  () => props.lines.length > 0 && props.lines.every((line) => selectedSet.value.has(line.id)),
);

const someSelected = computed(() =>
  props.lines.some((line) => selectedSet.value.has(line.id)),
);

watch(
  () => props.lines.map((line) => line.id).join(','),
  () => {
    const valid = new Set(props.lines.map((line) => line.id));
    selectedIds.value = selectedIds.value.filter((id) => valid.has(id));
    requestAnimationFrame(() => scrollFooterRef.value?.updateThumb?.());
  },
);

const onToggleSelect = (lineId: number, selected: boolean) => {
  if (selected) {
    if (!selectedIds.value.includes(lineId)) selectedIds.value = [...selectedIds.value, lineId];
    return;
  }
  selectedIds.value = selectedIds.value.filter((id) => id !== lineId);
};

const toggleAll = (value: boolean | null) => {
  if (value) {
    selectedIds.value = props.lines.map((line) => line.id);
    return;
  }
  selectedIds.value = [];
};

defineExpose({ clearSelection: () => { selectedIds.value = []; } });
</script>

<style scoped>
.pp-app-order-line-table {
  min-width: 0;
}

.pp-app-order-line-table__scroll {
  width: 100%;
  max-width: 100%;
  overflow-x: auto;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
}

.pp-app-order-line-table__bulk {
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
  background: var(--tf-neutral-surface);
}

.pp-app-order-line-table__card {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 10px;
  background: var(--tf-neutral-surface);
}

.pp-app-order-line-table__sheet {
  min-width: 1440px;
}

.pp-app-order-line-table__scroll-footer {
  border-top: 1px solid var(--tf-neutral-border);
  border-radius: 0 0 10px 10px;
}

.pp-app-order-line-table__grid {
  display: grid;
  grid-template-columns:
    2.5rem
    minmax(15rem, 2.4fr)
    minmax(11rem, 1.2fr)
    minmax(6.75rem, 0.65fr)
    minmax(5.75rem, 0.55fr)
    4.25rem
    minmax(5.5rem, 0.6fr)
    minmax(6.75rem, 0.75fr)
    minmax(6.5rem, 0.72fr)
    minmax(11rem, 1.15fr)
    minmax(6.5rem, 0.72fr)
    2.75rem;
  align-items: stretch;
}

.pp-app-order-line-table__head {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--tf-disabled-bg);
  border-bottom: 1px solid var(--tf-neutral-border);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted);
}

.pp-app-order-line-table__head > span {
  padding: 0.5rem;
  border-right: 1px solid var(--tf-neutral-border);
  text-align: center;
}

.pp-app-order-line-table__head-product,
.pp-app-order-line-table__head-text {
  text-align: left;
}

.pp-app-order-line-table__head > span:last-child {
  border-right: none;
}

.pp-app-order-line-table__body-row {
  border-bottom: 1px solid var(--tf-neutral-border);
  background: transparent;
}

.pp-app-order-line-table__body-row:last-child {
  border-bottom: none;
}

.pp-app-order-line-table__body-row:hover :deep(.pp-app-order-line-row),
.pp-app-order-line-table__body-row--selected :deep(.pp-app-order-line-row) {
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--tf-neutral-ink) 18%, transparent);
}

.pp-app-order-line-table__body-row--selected :deep(.pp-app-order-line-row) {
  box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--q-primary) 45%, transparent);
}
</style>