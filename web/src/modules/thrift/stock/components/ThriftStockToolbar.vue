<script setup lang="ts">
import { computed } from 'vue';

export type ThriftStockViewMode = 'table' | 'compact';

const props = defineProps<{
  search: string;
  activeFilterCount: number;
  columnSelectorOptions: Array<{ label: string; value: string }>;
  selectedColumnNames: string[];
  allSelectableColumnsSelected: boolean;
  csvExportLoading: boolean;
  viewMode: ThriftStockViewMode;
}>();

const emit = defineEmits<{
  (e: 'update:search', val: string): void;
  (e: 'update:selectedColumnNames', val: string[]): void;
  (e: 'update:allSelectableColumnsSelected', val: boolean): void;
  (e: 'update:viewMode', val: ThriftStockViewMode): void;
  (e: 'open-filters'): void;
  (e: 'download-csv'): void;
}>();

const searchText = computed({
  get: () => props.search,
  set: (val: string) => emit('update:search', val),
});

const selectedCols = computed({
  get: () => props.selectedColumnNames,
  set: (val: string[]) => emit('update:selectedColumnNames', val),
});

const selectAllCols = computed({
  get: () => props.allSelectableColumnsSelected,
  set: (val: boolean) => emit('update:allSelectableColumnsSelected', val),
});

const viewModeModel = computed({
  get: () => props.viewMode,
  set: (val: ThriftStockViewMode) => emit('update:viewMode', val),
});
</script>

<template>
  <q-card flat bordered class="q-pa-sm">
    <div class="row items-center justify-between q-col-gutter-sm">
      <div class="col-12 col-sm-6 col-md-4 row items-center q-gutter-sm">
        <q-input
          v-model="searchText"
          outlined
          dense
          clearable
          placeholder="Search..."
          debounce="400"
          class="soft-input col-grow"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="18px" />
          </template>
        </q-input>

        <!-- Filter drawer open button -->
        <q-btn
          flat
          round
          dense
          icon="ph ph-funnel"
          aria-label="Open filters"
          @click="$emit('open-filters')"
        >
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>

      <div class="col-auto row items-center q-gutter-sm">
        <q-btn-toggle
          v-model="viewModeModel"
          dense
          unelevated
          no-caps
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="[
            { icon: 'ph ph-rows', value: 'table', attrs: { 'aria-label': 'Table view' } },
            { icon: 'ph ph-list', value: 'compact', attrs: { 'aria-label': 'Compact view' } },
          ]"
        />

        <!-- Column Selector (table view only) -->
        <q-btn
          v-if="viewMode === 'table'"
          color="primary"
          outline
          no-caps
          dense
          class="q-px-sm"
          icon="ph ph-columns"
          label="Columns"
          aria-label="Select columns"
        >
          <q-menu>
            <q-list style="min-width: 240px">
              <q-item>
                <q-item-section>
                  <div class="text-subtitle2">Show Columns</div>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-checkbox
                    v-model="selectAllCols"
                    label="Select / Deselect All"
                  />
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-option-group
                    v-model="selectedCols"
                    type="checkbox"
                    :options="columnSelectorOptions"
                  />
                </q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>

        <!-- Download CSV -->
        <q-btn
          outline
          color="primary"
          no-caps
          dense
          class="q-px-sm"
          icon="ph ph-download-simple"
          label="CSV"
          :loading="csvExportLoading"
          @click="$emit('download-csv')"
        >
          <q-tooltip>Download CSV</q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>
</template>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
