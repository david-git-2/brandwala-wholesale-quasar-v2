<template>
  <q-btn flat dense icon="ph ph-dots-three-vertical" color="grey-8" aria-label="Actions">
    <q-menu anchor="bottom end" self="top end" class="shadow-4">
      <q-list dense style="min-width: 200px" class="q-py-xs">
        <q-item v-if="showColumnMenu" clickable>
          <q-item-section avatar style="min-width: 28px">
            <q-icon name="ph ph-columns" color="grey-8" size="18px" />
          </q-item-section>
          <q-item-section class="text-weight-medium">Columns</q-item-section>
          <q-item-section side>
            <q-icon name="ph ph-caret-right" size="14px" />
          </q-item-section>

          <q-menu anchor="top end" self="top start" class="shadow-4">
            <q-list style="min-width: 280px; max-height: 420px" class="q-pa-xs">
              <q-item class="q-pb-none">
                <q-item-section>
                  <div class="text-subtitle2 q-mb-xs text-weight-bold text-primary">Show columns</div>
                  <q-input
                    v-model="quickColumnSearch"
                    dense
                    outlined
                    placeholder="Search columns..."
                    clearable
                  >
                    <template #prepend>
                      <q-icon name="ph ph-magnifying-glass" size="16px" />
                    </template>
                  </q-input>
                </q-item-section>
              </q-item>

              <q-item clickable class="q-py-xs">
                <q-item-section>
                  <q-checkbox
                    v-model="allQuickColumnsSelected"
                    label="Select / deselect all"
                    dense
                    class="text-caption text-weight-bold"
                  />
                </q-item-section>
              </q-item>

              <q-separator class="q-my-xs" />

              <q-scroll-area style="height: 240px">
                <div v-if="!filteredQuickColumns.length" class="text-caption text-grey-6 q-pa-sm text-center">
                  No matching columns found
                </div>
                <div v-else class="q-px-sm">
                  <div v-for="col in filteredQuickColumns" :key="col.value" class="q-py-xs">
                    <q-checkbox
                      :model-value="resolvedVisibleColumns.includes(col.value)"
                      :label="col.label"
                      dense
                      class="text-caption"
                      @update:model-value="(val) => toggleColumn(col.value, val)"
                    />
                  </div>
                </div>
              </q-scroll-area>
            </q-list>
          </q-menu>
        </q-item>

        <q-item v-close-popup clickable @click="emit('override-status')">
          <q-item-section avatar style="min-width: 28px">
            <q-icon name="ph ph-arrows-clockwise" color="grey-8" size="18px" />
          </q-item-section>
          <q-item-section class="text-weight-medium">Override status…</q-item-section>
        </q-item>
      </q-list>
    </q-menu>
  </q-btn>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';

const props = defineProps<{
  visibleColumns?: string[];
}>();

const emit = defineEmits<{
  (e: 'update:visible-columns', columns: string[]): void;
  (e: 'override-status'): void;
}>();

const quickColumnSearch = ref('');

const showColumnMenu = computed(() => !!props.visibleColumns?.length);

const allCatalogColumns = [
  { label: 'SL (Serial)', value: 'sl' },
  { label: 'Image', value: 'image' },
  { label: 'Product Name', value: 'name' },
  { label: 'Brand', value: 'brand' },
  { label: 'Note', value: 'note' },
  { label: 'Barcode / Code / ID', value: 'code_barcode_id' },
  { label: 'Qty (Customer)', value: 'qty_customer' },
  { label: 'Ordered Qty', value: 'ordered_qty' },
  { label: 'Delivered Qty', value: 'delivered_qty' },
  { label: 'Price (Purchase) / Unit', value: 'purchase_price_unit' },
  { label: 'Total Purchase Price', value: 'purchase_price_total' },
  { label: 'Product Weight (gm)', value: 'product_weight_gm' },
  { label: 'Package Weight (gm)', value: 'package_weight_gm' },
  { label: 'Total Weight (gm)', value: 'total_weight_gm' },
  { label: 'Cargo Rate', value: 'cargo_rate' },
  { label: 'Cargo Cost / Unit', value: 'cargo_cost_unit_purchase' },
  { label: 'Total Cost (Purchase)', value: 'landed_cost_unit_purchase' },
  { label: 'Row Total Cost (Purchase)', value: 'landed_cost_row_purchase' },
  { label: 'Cost (Selling Currency)', value: 'landed_cost_unit_sell' },
  { label: 'Row Total Cost (Selling)', value: 'landed_cost_row_sell' },
  { label: '1st Offer Unit', value: 'first_offer_unit' },
  { label: '1st Offer Row Total', value: 'first_offer_row' },
  { label: '1st Offer Margin %', value: 'first_offer_margin' },
  { label: 'Counter Offer Unit', value: 'counter_offer_unit' },
  { label: 'Counter Offer Row Total', value: 'counter_offer_row' },
  { label: 'Counter Offer Margin %', value: 'counter_offer_margin' },
  { label: 'Final Offer Unit', value: 'final_offer_unit' },
  { label: 'Final Offer Row Total', value: 'final_offer_row' },
  { label: 'Final Offer Margin %', value: 'final_offer_margin' },
  { label: 'Status', value: 'status' },
  { label: 'Action', value: 'action' },
];

const resolvedVisibleColumns = computed<string[]>(() => {
  return props.visibleColumns?.length ? props.visibleColumns : allCatalogColumns.map((c) => c.value);
});

const filteredQuickColumns = computed(() => {
  const query = quickColumnSearch.value.trim().toLowerCase();
  if (!query) return allCatalogColumns;
  return allCatalogColumns.filter((c) => c.label.toLowerCase().includes(query));
});

const allQuickColumnsSelected = computed({
  get: () => allCatalogColumns.every((col) => resolvedVisibleColumns.value.includes(col.value)),
  set: (val: boolean) => {
    const next = val ? allCatalogColumns.map((c) => c.value) : ['sl', 'image', 'name', 'qty_customer', 'final_offer_unit', 'action'];
    emit('update:visible-columns', next);
  },
});

function toggleColumn(colValue: string, active: boolean) {
  const current = [...resolvedVisibleColumns.value];
  if (active) {
    if (!current.includes(colValue)) current.push(colValue);
  } else {
    const idx = current.indexOf(colValue);
    if (idx !== -1) current.splice(idx, 1);
  }
  emit('update:visible-columns', current);
}
</script>
