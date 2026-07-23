<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 520px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold row items-center q-gutter-x-xs">
          <q-icon name="preview" size="24px" class="q-mr-xs" />
          Select Preview Columns
        </div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <div class="text-caption text-grey-7 q-mb-md">
          Choose which columns to display when exporting or previewing this costing file.
          Your selections will be saved for future previews.
        </div>

        <div class="row items-center justify-between q-mb-sm bg-grey-2 q-pa-sm rounded-borders">
          <q-checkbox
            v-model="allColumnsSelected"
            label="Select / Deselect All Optional Columns"
            dense
            class="text-weight-bold text-caption"
          />
          <q-badge :color="selectedCount > 7 ? 'warning' : 'primary'" outline class="text-caption">
            {{ selectedCount }} selected
          </q-badge>
        </div>

        <q-banner
          v-if="selectedCount > 7"
          dense
          class="bg-amber-1 text-amber-10 rounded-borders q-mb-sm"
        >
          <template #avatar>
            <q-icon name="warning" color="warning" size="18px" />
          </template>
          <div class="text-caption">
            <strong>A4 Layout Warning:</strong> {{ selectedCount }} columns selected. Printing on standard A4 paper works best with 7 or fewer columns to prevent table overflow.
          </div>
        </q-banner>

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
          icon="open_in_new"
          label="Open Preview & Print"
          no-caps
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const alwaysVisibleColumns = ['sl', 'image', 'name'];

const columnSelectorOptions = [
  { label: 'Brand', value: 'brand' },
  { label: 'Note / Description', value: 'note' },
  { label: 'Quantity', value: 'qty' },
  { label: 'Delivered Qty', value: 'deliveredQty' },
  { label: 'Barcode / Code', value: 'barcodeText' },
  { label: 'Website Link', value: 'website' },
  { label: 'Price (GBP)', value: 'priceGbp' },
  { label: 'Total Purchase (GBP)', value: 'totalPurchasePriceGbp' },
  { label: 'Product Wt (kg)', value: 'productWeight' },
  { label: 'Package Wt (kg)', value: 'packageWeight' },
  { label: 'Total Wt (kg)', value: 'totalWeight' },
  { label: 'Cargo Rate', value: 'cargoRate' },
  { label: 'Cargo Cost (GBP)', value: 'cargoCostGbp' },
  { label: 'Total Cost (GBP)', value: 'totalCostGbp' },
  { label: 'Cost (BDT)', value: 'costBdt' },
  { label: 'Offer Price (BDT)', value: 'offerPriceBdt' },
  { label: 'Total Offer (BDT)', value: 'totalBdt' },
  { label: 'Profit (BDT)', value: 'profitPerUnitBdt' },
  { label: 'Profit Rate (%)', value: 'profitRate' },
  { label: 'Status', value: 'status' },
];

const selectableColumnValues = columnSelectorOptions.map((opt) => opt.value);
const allColumnNames = [...alwaysVisibleColumns, ...selectableColumnValues];

const { visibleColumns: selectedColumns } = useMembershipColumnPreference({
  preferencePath: 'productBasedCostingPreviewPrintColumns',
  allColumnNames,
  alwaysVisibleColumns,
  defaultVisibleColumns: [
    'sl',
    'image',
    'name',
    'brand',
    'qty',
    'barcodeText',
    'priceGbp',
    'productWeight',
    'offerPriceBdt',
    'totalBdt',
  ],
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
