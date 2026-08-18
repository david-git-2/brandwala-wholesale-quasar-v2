<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin" style="width: 520px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold row items-center q-gutter-x-xs">
          <q-icon name="ph ph-eye" size="24px" class="q-mr-xs" />
          {{ $t('product_based_costing.preview_select_columns') }}
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <div class="text-caption text-grey-7 q-mb-md">
          {{ $t('product_based_costing.preview_select_columns_hint') }}
        </div>

        <div class="row items-center justify-between q-mb-sm bg-grey-2 q-pa-sm rounded-borders">
          <q-checkbox
            v-model="allColumnsSelected"
            :label="$t('product_based_costing.preview_select_all_optional')"
            dense
            class="text-weight-bold text-caption"
          />
          <q-badge :color="selectedCount > 7 ? 'warning' : 'primary'" outline class="text-caption">
            {{ $t('product_based_costing.selected_count', { count: selectedCount }) }}
          </q-badge>
        </div>

        <q-banner
          v-if="selectedCount > 7"
          dense
          class="bg-amber-1 text-amber-10 rounded-borders q-mb-sm"
        >
          <template #avatar>
            <q-icon name="ph ph-warning" color="warning" size="18px" />
          </template>
          <div class="text-caption">
            <strong>{{ $t('product_based_costing.preview_a4_warning_title') }}</strong>
            {{ $t('product_based_costing.preview_a4_warning_body', { count: selectedCount }) }}
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
        <q-btn flat :label="$t('product_based_costing.cancel')" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          icon="ph ph-arrow-up-right"
          :label="$t('product_based_costing.preview_open_print')"
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
import { useI18n } from 'vue-i18n';

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const { t } = useI18n();

const alwaysVisibleColumns = ['sl', 'image', 'name'];

const columnSelectorOptions = [
  { label: t('product_based_costing.table_col_brand'), value: 'brand' },
  { label: t('product_based_costing.note'), value: 'note' },
  { label: t('product_based_costing.table_col_qty'), value: 'qty' },
  { label: t('product_based_costing.table_col_deliveredQty'), value: 'deliveredQty' },
  { label: t('product_based_costing.preview_barcode_code'), value: 'barcodeText' },
  { label: t('product_based_costing.preview_website_link'), value: 'website' },
  { label: t('product_based_costing.preview_price_gbp'), value: 'priceGbp' },
  { label: t('product_based_costing.preview_total_purchase_gbp'), value: 'totalPurchasePriceGbp' },
  { label: t('product_based_costing.preview_product_wt_kg'), value: 'productWeight' },
  { label: t('product_based_costing.preview_package_wt_kg'), value: 'packageWeight' },
  { label: t('product_based_costing.preview_total_wt_kg'), value: 'totalWeight' },
  { label: t('product_based_costing.table_col_cargoRate'), value: 'cargoRate' },
  { label: t('product_based_costing.preview_cargo_cost_gbp'), value: 'cargoCostGbp' },
  { label: t('product_based_costing.preview_total_cost_gbp'), value: 'totalCostGbp' },
  { label: t('product_based_costing.preview_cost_bdt'), value: 'costBdt' },
  { label: t('product_based_costing.preview_offer_price_bdt'), value: 'offerPriceBdt' },
  { label: t('product_based_costing.preview_total_offer_bdt'), value: 'totalBdt' },
  { label: t('product_based_costing.preview_profit_bdt'), value: 'profitPerUnitBdt' },
  { label: t('product_based_costing.table_col_profitRate'), value: 'profitRate' },
  { label: t('product_based_costing.col_status'), value: 'status' },
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
