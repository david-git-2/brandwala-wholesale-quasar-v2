<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 520px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold row items-center q-gutter-x-xs">
          <q-icon name="ph ph-sliders-horizontal" size="24px" class="q-mr-xs" />
          Select Order Columns
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <div class="text-caption text-grey-7 q-mb-md">
          Toggle visible columns for the order table grid.
        </div>

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
          <div class="row q-col-gutter-xs">
            <div
              v-for="col in columnSelectorOptions"
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

const alwaysVisibleColumns = ['item', 'quantity'];

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
];

const selectableColumnValues = columnSelectorOptions.map((opt) => opt.value);

const selectedColumns = ref<string[]>([...props.visibleColumns]);

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
