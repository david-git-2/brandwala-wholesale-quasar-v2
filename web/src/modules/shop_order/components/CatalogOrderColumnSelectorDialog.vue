<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 540px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold row items-center q-gutter-x-xs">
          <q-icon name="ph ph-sliders-horizontal" size="24px" class="q-mr-xs" />
          Select Order Columns
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <div class="text-caption text-grey-7 q-mb-sm">
          Toggle visible columns for the order table grid.
        </div>

        <!-- Search Bar -->
        <q-input
          v-model="searchQuery"
          dense
          outlined
          placeholder="Search columns..."
          clearable
          class="q-mb-md"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="18px" />
          </template>
        </q-input>

        <!-- Select All Bar -->
        <div class="row items-center justify-between q-mb-sm bg-grey-2 q-pa-sm rounded-borders">
          <q-checkbox
            v-model="allColumnsSelected"
            label="Select / Deselect All Optional Columns"
            dense
            class="text-weight-bold text-caption"
          />
          <q-badge color="primary" outline class="text-caption">
            {{ selectedCount }} selected
          </q-badge>
        </div>

        <q-scroll-area style="height: 280px">
          <div v-if="!filteredOptions.length" class="text-center text-grey-6 q-pa-md">
            No matching columns found
          </div>
          <div v-else class="row q-col-gutter-xs">
            <div
              v-for="col in filteredOptions"
              :key="col.value"
              class="col-12 col-sm-6"
            >
              <q-checkbox
                v-model="selectedColumns"
                :val="col.value"
                :label="col.label"
                dense
                class="q-py-xs full-width"
              />
            </div>
          </div>
        </q-scroll-area>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          label="Apply Columns"
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

const alwaysVisibleColumns = ['sl', 'image', 'name', 'quantity', 'total_amount'];
const searchQuery = ref('');

const columnSelectorOptions = [
  { label: 'SKU / Code', value: 'sku' },
  { label: 'List Price', value: 'list_price' },
  { label: 'Weight (kg)', value: 'weight_kg' },
  { label: 'Cost Price', value: 'cost_price' },
  { label: 'Profit Base', value: 'profit_base' },
  { label: 'Staff Offer', value: 'staff_offer' },
  { label: 'Customer Counter', value: 'customer_offer' },
  { label: 'Final Offer Price', value: 'final_price' },
  { label: 'Confirmed Qty', value: 'confirmed_quantity' },
  { label: 'Ordered Qty', value: 'ordered_quantity' },
  { label: 'Delivered Qty', value: 'delivered_quantity' },
];

const selectableColumnValues = columnSelectorOptions.map((opt) => opt.value);

const selectedColumns = ref<string[]>([...props.visibleColumns]);

const filteredOptions = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) return columnSelectorOptions;
  return columnSelectorOptions.filter((opt) => opt.label.toLowerCase().includes(query));
});

const selectedCount = computed(() => selectedColumns.value.length);

const allColumnsSelected = computed({
  get: () => selectableColumnValues.every((val) => selectedColumns.value.includes(val)),
  set: (checked: boolean) => {
    selectedColumns.value = checked
      ? [...alwaysVisibleColumns, ...selectableColumnValues]
      : [...alwaysVisibleColumns];
  },
});

const onConfirm = () => {
  onDialogOK({ visibleColumns: [...selectedColumns.value] });
};
</script>
