<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 640px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold row items-center q-gutter-x-xs">
          <q-icon name="ph ph-sliders-horizontal" size="24px" class="q-mr-xs" />
          Customize Catalog Table Columns
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <div class="text-caption text-grey-7 q-mb-sm">
          Select which columns to show or hide in the catalog staff order table grid.
        </div>

        <!-- Search & Preset Quick Bar -->
        <div class="row q-col-gutter-sm items-center q-mb-md">
          <div class="col-12 col-sm-7">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              placeholder="Search column names..."
              clearable
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-5 row justify-end q-gutter-x-xs">
            <q-btn flat dense no-caps label="Select All" color="primary" class="text-caption" @click="selectAll" />
            <q-btn flat dense no-caps label="Default View" color="grey-8" class="text-caption" @click="resetToDefault" />
          </div>
        </div>

        <!-- Column Selection List with Categorized Sections -->
        <q-scroll-area style="height: 380px">
          <div v-for="section in filteredSections" :key="section.title" class="q-mb-md">
            <div class="row items-center justify-between q-pa-xs rounded-borders q-mb-xs" :class="section.bgClass">
              <span class="text-subtitle2 text-weight-bold" :class="section.textClass">
                {{ section.title }}
              </span>
              <q-btn
                flat
                dense
                no-caps
                size="xs"
                :color="section.badgeColor"
                label="Toggle Section"
                @click="toggleSection(section.columns.map(c => c.value))"
              />
            </div>

            <div class="row q-col-gutter-xs q-px-xs">
              <div
                v-for="col in section.columns"
                :key="col.value"
                class="col-12 col-sm-6"
              >
                <q-checkbox
                  v-model="selectedColumns"
                  :val="col.value"
                  :label="col.label"
                  dense
                  class="q-py-xs full-width text-caption"
                />
              </div>
            </div>
          </div>

          <div v-if="!filteredSections.length" class="text-center text-grey-6 q-pa-md">
            No matching columns found
          </div>
        </q-scroll-area>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1 border-top">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          label="Apply Column Settings"
          no-caps
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';

const props = defineProps<{
  visibleColumns: string[];
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const searchQuery = ref('');

interface ColumnOption {
  label: string;
  value: string;
}

interface ColumnSection {
  title: string;
  bgClass: string;
  textClass: string;
  badgeColor: string;
  columns: ColumnOption[];
}

const sections: ColumnSection[] = [
  {
    title: '1. Basic Info',
    bgClass: 'bg-grey-3',
    textClass: 'text-grey-9',
    badgeColor: 'grey-9',
    columns: [
      { label: 'SL (Serial)', value: 'sl' },
      { label: 'Image', value: 'image' },
      { label: 'Product Name', value: 'name' },
      { label: 'Brand', value: 'brand' },
      { label: 'Note', value: 'note' },
      { label: 'Barcode / Code / ID', value: 'code_barcode_id' },
    ],
  },
  {
    title: '2. Quantities',
    bgClass: 'bg-amber-2',
    textClass: 'text-amber-10',
    badgeColor: 'amber-10',
    columns: [
      { label: 'Qty (Customer)', value: 'qty_customer' },
    ],
  },
  {
    title: '3. Purchase & Freight Metrics',
    bgClass: 'bg-blue-2',
    textClass: 'text-blue-10',
    badgeColor: 'blue-10',
    columns: [
      { label: 'Price (Purchase Currency) / Unit', value: 'purchase_price_unit' },
      { label: 'Total Purchase Price', value: 'purchase_price_total' },
      { label: 'Product Weight (gm)', value: 'product_weight_gm' },
      { label: 'Package Weight (gm)', value: 'package_weight_gm' },
      { label: 'Total Weight (gm)', value: 'total_weight_gm' },
      { label: 'Cargo Rate', value: 'cargo_rate' },
      { label: 'Cargo Cost (Purchase Currency) / Unit', value: 'cargo_cost_unit_purchase' },
    ],
  },
  {
    title: '4. Landed Costs',
    bgClass: 'bg-teal-2',
    textClass: 'text-teal-10',
    badgeColor: 'teal-10',
    columns: [
      { label: 'Total Cost (Purchase Cost)', value: 'landed_cost_unit_purchase' },
      { label: 'Row Total Cost (Purchase)', value: 'landed_cost_row_purchase' },
      { label: 'Cost (Selling Currency)', value: 'landed_cost_unit_sell' },
      { label: 'Row Total Cost (Selling)', value: 'landed_cost_row_sell' },
    ],
  },
  {
    title: '5. First Offer (Staff 1st Offer)',
    bgClass: 'bg-deep-purple-2',
    textClass: 'text-deep-purple-10',
    badgeColor: 'deep-purple-10',
    columns: [
      { label: 'First Offer Unit (Selling Currency)', value: 'first_offer_unit' },
      { label: 'Row Total (First Offer)', value: 'first_offer_row' },
      { label: 'Profit Percentage (First Offer)', value: 'first_offer_margin' },
    ],
  },
  {
    title: '6. Counter Offer (Customer Counter)',
    bgClass: 'bg-orange-2',
    textClass: 'text-orange-10',
    badgeColor: 'orange-10',
    columns: [
      { label: 'Counter Offer Per Unit', value: 'counter_offer_unit' },
      { label: 'Row Total (Counter Offer)', value: 'counter_offer_row' },
      { label: 'Profit Percentage (Counter Offer)', value: 'counter_offer_margin' },
    ],
  },
  {
    title: '7. Final Offer',
    bgClass: 'bg-green-2',
    textClass: 'text-green-10',
    badgeColor: 'green-10',
    columns: [
      { label: 'Final Offer Unit', value: 'final_offer_unit' },
      { label: 'Row Total (Final Offer)', value: 'final_offer_row' },
      { label: 'Profit Percentage (Final Offer)', value: 'final_offer_margin' },
    ],
  },
  {
    title: '8. Status',
    bgClass: 'bg-grey-4',
    textClass: 'text-grey-10',
    badgeColor: 'grey-10',
    columns: [
      { label: 'Status', value: 'status' },
    ],
  },
];

const allColumnValues = sections.flatMap((s) => s.columns.map((c) => c.value));
const defaultColumns = [
  'sl',
  'image',
  'name',
  'brand',
  'qty_customer',
  'qty_customer',
  'code_barcode_id',
  'purchase_price_unit',
  'purchase_price_total',
  'total_weight_gm',
  'cargo_cost_unit_purchase',
  'landed_cost_unit_purchase',
  'landed_cost_unit_sell',
  'landed_cost_row_sell',
  'first_offer_unit',
  'first_offer_row',
  'first_offer_margin',
  'counter_offer_unit',
  'counter_offer_row',
  'counter_offer_margin',
  'final_offer_unit',
  'final_offer_row',
  'final_offer_margin',
  'status',
];

const selectedColumns = ref<string[]>([...(props.visibleColumns?.length ? props.visibleColumns : defaultColumns)]);

const filteredSections = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) return sections;

  return sections
    .map((sec) => ({
      ...sec,
      columns: sec.columns.filter((c) => c.label.toLowerCase().includes(query) || c.value.toLowerCase().includes(query)),
    }))
    .filter((sec) => sec.columns.length > 0);
});

function toggleSection(sectionCols: string[]) {
  const allIn = sectionCols.every((c) => selectedColumns.value.includes(c));
  if (allIn) {
    selectedColumns.value = selectedColumns.value.filter((c) => !sectionCols.includes(c));
  } else {
    const set = new Set([...selectedColumns.value, ...sectionCols]);
    selectedColumns.value = Array.from(set);
  }
}

function selectAll() {
  selectedColumns.value = [...allColumnValues];
}

function resetToDefault() {
  selectedColumns.value = [...defaultColumns];
}

const onConfirm = () => {
  onDialogOK({ visibleColumns: [...selectedColumns.value] });
};
</script>
