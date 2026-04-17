<template>
  <div class="product-based-costing-table">
    <q-table
      flat
      bordered
      :rows="tableRows"
      :columns="columns"
      row-key="id"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      :table-style="{ maxHeight: '72vh' }"
      class="costing-q-table"
    >
      <template #body="slotProps">
        <q-tr :props="slotProps">
          <q-td key="sl" :props="slotProps" class="col-sl text-center">
            {{ slotProps.row.sl }}
          </q-td>

          <q-td key="image" :props="slotProps" class="col-image text-center">
            <SmartImage
              :src="slotProps.row.imageUrl"
              :alt="slotProps.row.name || 'Product image'"
              img-class="table-image"
              fallback-class="table-image-placeholder"
            />
          </q-td>

          <q-td key="name" :props="slotProps" class="col-name">
            {{ slotProps.row.name }}
          </q-td>

          <q-td key="note" :props="slotProps" class="col-note">
            <div
              v-if="slotProps.row.noteHtml"
              class="item-note-html"
              v-html="slotProps.row.noteHtml"
            />
            <span v-else>-</span>
          </q-td>

          <q-td key="qty" :props="slotProps" class="col-qty text-center editable-cell">
            <div class="editable-value">
              {{ slotProps.row.qty }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.qty"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.qty = toNumber(value);
                  onQtySave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="barcodeText" :props="slotProps" class="col-barcode">
            {{ slotProps.row.barcodeText }}
          </q-td>

          <q-td key="website" :props="slotProps" class="col-website">
            <a
              v-if="slotProps.row.website"
              :href="slotProps.row.website"
              target="_blank"
              rel="noopener noreferrer"
            >
              Open
            </a>
            <span v-else>-</span>
          </q-td>

          <q-td key="priceGbp" :props="slotProps" class="col-price-gbp text-right">
            {{ formatNumber(slotProps.row.priceGbp) }}
          </q-td>

          <q-td
            key="productWeight"
            :props="slotProps"
            class="col-product-weight text-right editable-cell"
          >
            <div class="editable-value">
              {{ formatNumber(slotProps.row.productWeight) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.productWeight"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.productWeight = toNumber(value);
                  onProductWeightSave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td
            key="packageWeight"
            :props="slotProps"
            class="col-package-weight text-right editable-cell"
          >
            <div class="editable-value">
              {{ formatNumber(slotProps.row.packageWeight) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.packageWeight"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.packageWeight = toNumber(value);
                  onPackageWeightSave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="totalWeight" :props="slotProps" class="col-total-weight text-right">
            {{ formatNumber(getTotalWeight(slotProps.row)) }}
          </q-td>

          <q-td key="cargoRate" :props="slotProps" class="col-cargo-rate text-right">
            {{ formatNumber(slotProps.row.cargoRate) }}
          </q-td>

          <q-td key="cargoCostGbp" :props="slotProps" class="col-cargo-cost-gbp text-right">
            {{ formatNumber(getCargoCostGbp(slotProps.row)) }}
          </q-td>

          <q-td key="totalCostGbp" :props="slotProps" class="col-total-cost-gbp text-right">
            {{ formatNumber(getTotalCostGbp(slotProps.row)) }}
          </q-td>

          <q-td key="rowTotalCostGbp" :props="slotProps" class="col-row-total-cost-gbp text-right">
            {{ formatNumber(getRowTotalCostGbp(slotProps.row)) }}
          </q-td>

          <q-td key="costBdt" :props="slotProps" class="col-cost-bdt text-right">
            {{ formatNumber(getCostBdt(slotProps.row)) }}
          </q-td>

          <q-td key="totalCostBdt" :props="slotProps" class="col-total-cost-bdt text-right">
            {{ formatNumber(getTotalCostBdt(slotProps.row)) }}
          </q-td>

          <q-td
            key="offerPriceBdt"
            :props="slotProps"
            class="col-offer-price-bdt text-right editable-cell"
          >
            <div class="editable-value">
              {{ formatNumber(slotProps.row.offerPriceBdt) }}
            </div>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.offerPriceBdt"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.offerPriceBdt = toNumber(value);
                  onOfferPriceBdtSave(slotProps.row);
                }
              "
            >
              <q-input
                v-model.number="scope.value"
                type="number"
                dense
                outlined
                autofocus
                min="0"
              />
            </q-popup-edit>
          </q-td>

          <q-td key="totalBdt" :props="slotProps" class="col-total-bdt text-right">
            {{ formatNumber(getTotalBdt(slotProps.row)) }}
          </q-td>

          <q-td key="profitPerUnitBdt" :props="slotProps" class="col-profit-per-unit-bdt text-right">
            {{ formatNumber(getProfitPerUnit(slotProps.row)) }}
          </q-td>

          <q-td key="profitBdt" :props="slotProps" class="col-profit-bdt text-right">
            {{ formatNumber(getProfitBdt(slotProps.row)) }}
          </q-td>

          <q-td key="profitRate" :props="slotProps" class="col-profit-rate text-right">
            {{ formatNumber(getProfitRate(slotProps.row)) }}
          </q-td>

          <q-td key="status" :props="slotProps" class="col-status text-center editable-cell">
            <q-badge :color="getStatusColor(slotProps.row.status)" outline>
              {{ slotProps.row.status }}
            </q-badge>

            <q-popup-edit
              v-slot="scope"
              :model-value="slotProps.row.status"
              buttons
              persistent
              label-set="Save"
              label-cancel="Cancel"
              @save="
                (value) => {
                  slotProps.row.status = toText(value, 'pending').toLowerCase();
                  onStatusSave(slotProps.row);
                }
              "
            >
              <q-select
                v-model="scope.value"
                :options="statusOptions"
                dense
                outlined
                emit-value
                map-options
                autofocus
              />
            </q-popup-edit>
          </q-td>

          <q-td key="action" :props="slotProps" class="col-action">
            <div class="row items-center justify-center q-gutter-xs">
              <q-btn
                icon="edit"
                flat
                round
                dense
                :disable="props.status !== 'pending'"
                :color="props.status == 'pending' ? 'blue-10' : 'grey'"
                @click="onEdit(slotProps.row)"
                class="col"
              />
              <q-btn
                icon="delete"
                flat
                round
                dense
                :color="props.status == 'pending' ? 'negative' : 'grey'"
                :disable="props.status !== 'pending'"
                @click="onDelete(slotProps.row)"
                class="col"
              />
            </div>
          </q-td>
        </q-tr>
      </template>

      <template #bottom-row>
        <q-tr class="totals-row">
          <q-td class="totals-row__cell col-sl text-center">
            Total
          </q-td>
          <q-td class="totals-row__cell col-image" />
          <q-td class="totals-row__cell col-name">
            {{ tableRows.length }} Items
          </q-td>
          <q-td class="totals-row__cell col-note" />
          <q-td class="totals-row__cell col-qty text-center">
            {{ formatNumber(totals.qty) }}
          </q-td>
          <q-td class="totals-row__cell col-barcode" />
          <q-td class="totals-row__cell col-website" />
          <q-td class="totals-row__cell col-price-gbp text-right">
            <div class="totals-row__value bg-gbp">
            {{ formatNumber(totals.priceGbp) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-product-weight text-right">
            {{ formatNumber(totals.productWeight) }}
          </q-td>
          <q-td class="totals-row__cell col-package-weight text-right">
            {{ formatNumber(totals.packageWeight) }}
          </q-td>
          <q-td class="totals-row__cell col-total-weight text-right">
            {{ formatNumber(totals.totalWeight) }}
          </q-td>
          <q-td class="totals-row__cell col-cargo-rate text-right">
            {{ formatNumber(totals.cargoRate) }}
          </q-td>
          <q-td class="totals-row__cell col-cargo-cost-gbp text-right">
            <div class="totals-row__value bg-gbp">
            {{ formatNumber(totals.cargoCostGbp) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-total-cost-gbp text-right">
            <div class="totals-row__value bg-gbp">
            {{ formatNumber(totals.totalCostGbp) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-row-total-cost-gbp text-right">
            <div class="totals-row__value bg-gbp">
            {{ formatNumber(totals.rowTotalCostGbp) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-cost-bdt text-right">
            <div class="totals-row__value bg-bdt">
            {{ formatNumber(totals.costBdt) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-total-cost-bdt text-right">
            <div class="totals-row__value bg-bdt">
            {{ formatNumber(totals.totalCostBdt) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-offer-price-bdt text-right">
            <div class="totals-row__value bg-offer">
            {{ formatNumber(totals.offerPriceBdt) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-total-bdt text-right">
            <div class="totals-row__value bg-offer">
            {{ formatNumber(totals.totalBdt) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-profit-per-unit-bdt text-right">
            <div class="totals-row__value bg-bdt">
            {{ formatNumber(totals.profitPerUnitBdt) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-profit-bdt text-right">
            <div class="totals-row__value bg-bdt">
            {{ formatNumber(totals.profitBdt) }}
            </div>
          </q-td>
          <q-td class="totals-row__cell col-profit-rate text-right">
            {{ formatNumber(totals.averageProfitRate) }}
          </q-td>
          <q-td class="totals-row__cell col-status" />
          <q-td class="totals-row__cell col-action" />
        </q-tr>
      </template>

      <template #no-data>
        <div class="full-width row flex-center q-pa-md text-grey-7">No items found</div>
      </template>
    </q-table>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { roundBdtUpToZeroOrFive } from 'src/modules/costingFile/utils/costingCalculations';

interface ProductBasedCostingItem {
  id: number;
  product_based_costing_file_id: number | null;
  product_id?: number | null;
  name: string | null;
  image_url: string | null;
  note: string | null;
  quantity: number | null;
  barcode: string | null;
  product_code: string | null;
  web_link: string | null;
  price_gbp: number | null;
  product_weight: number | null;
  package_weight: number | null;
  offer_price: number | null;
  status: string | null;
  created_at: string;
  updated_at: string;
}

interface ProductBasedCostingTableRow {
  id: number;
  sl: number;
  name: string;
  noteHtml: string;
  imageUrl: string | null;
  qty: number;
  barcodeText: string;
  website: string | null;
  priceGbp: number;
  productWeight: number;
  packageWeight: number;
  cargoRate: number;
  conversionRate: number;
  profitRate: number;
  offerPriceBdt: number;
  status: string;
  raw: ProductBasedCostingItem;
}

const props = withDefaults(
  defineProps<{
    items: ProductBasedCostingItem[];
    cargoRate?: number;
    conversionRate?: number;
    profitRate?: number;
    status?: string | undefined;
  }>(),
  {
    cargoRate: 0,
    conversionRate: 0,
    profitRate: 0,
    status: 'pending',
  },
);

const emit = defineEmits<{
  (e: 'edit', item: ProductBasedCostingItem): void;
  (e: 'delete', item: ProductBasedCostingItem): void;
  (
    e: 'row-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field: 'quantity' | 'offer_price' | 'status';
    },
  ): void;
  (
    e: 'product-weight-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field: 'product_weight';
    },
  ): void;
  (
    e: 'package-weight-change',
    payload: {
      item: ProductBasedCostingItem;
      row: ProductBasedCostingTableRow;
      field: 'package_weight';
    },
  ): void;
}>();

const $q = useQuasar();

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Accepted', value: 'accepted' },
  { label: 'Rejected', value: 'rejected' },
];

const toNumber = (value: unknown) => {
  const num = Number(value ?? 0);
  return Number.isNaN(num) ? 0 : num;
};

const toText = (value: unknown, fallback = '-') => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
};

const formatNumber = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '-';
  }

  return Number(value).toFixed(2);
};

const getUnitWeight = (productWeight: number, packageWeight: number) =>
  productWeight + packageWeight;

const getUnitCargoCostGbp = (
  productWeight: number,
  packageWeight: number,
  cargoRate: number,
) => (getUnitWeight(productWeight, packageWeight) / 1000) * cargoRate;

const getUnitTotalCostGbp = (
  priceGbp: number,
  productWeight: number,
  packageWeight: number,
  cargoRate: number,
) => priceGbp + getUnitCargoCostGbp(productWeight, packageWeight, cargoRate);

const getUnitCostBdt = (
  priceGbp: number,
  productWeight: number,
  packageWeight: number,
  cargoRate: number,
  conversionRate: number,
) => Math.ceil(
  getUnitTotalCostGbp(priceGbp, productWeight, packageWeight, cargoRate) * conversionRate,
);

const buildRows = (): ProductBasedCostingTableRow[] => {
  return (props.items ?? []).map((item, index) => {
    const barcode = toText(item.barcode, '');
    const productCode = toText(item.product_code, '');
    const barcodeParts = [barcode, productCode, String(item.id)].filter(Boolean);
    const qty = toNumber(item.quantity);
    const priceGbp = toNumber(item.price_gbp);
    const productWeight = toNumber(item.product_weight);
    const packageWeight = toNumber(item.package_weight);
    const cargoRate = toNumber(props.cargoRate);
    const conversionRate = toNumber(props.conversionRate);
    const profitRate = toNumber(props.profitRate);
    const costBdt = getUnitCostBdt(
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
    );
    const calculatedOfferPriceBdt = roundBdtUpToZeroOrFive(costBdt + (costBdt * profitRate) / 100);

    return {
      id: item.id,
      sl: index + 1,
      name: toText(item.name),
      noteHtml: item.note ?? '',
      imageUrl: item.image_url ?? null,
      qty,
      barcodeText: barcodeParts.length ? barcodeParts.join(' / ') : '-',
      website: item.web_link ?? null,
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate,
      conversionRate,
      profitRate,
      offerPriceBdt:
        item.offer_price == null ? calculatedOfferPriceBdt : toNumber(item.offer_price),
      status: toText(item.status, 'pending').toLowerCase(),
      raw: { ...item },
    };
  });
};

const tableRows = ref<ProductBasedCostingTableRow[]>([]);

watch(
  () => [props.items, props.cargoRate, props.conversionRate, props.profitRate],
  () => {
    tableRows.value = buildRows();
  },
  { immediate: true, deep: true },
);

const columns = computed<QTableColumn[]>(() => [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'imageUrl',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    classes: 'col-name-wrap',
    headerClasses: 'col-name-wrap',
    style: 'text-align: center;',
  },
  {
    name: 'note',
    label: 'Note',
    field: 'noteHtml',
    align: 'left',
    style: 'text-align: left;',
  },
  { name: 'qty', label: 'Qty', field: 'qty', align: 'center', style: 'text-align: center;' },
  {
    name: 'barcodeText',
    label: 'Barcode / Code / Product ID',
    field: 'barcodeText',
    align: 'left',
    style: 'text-align: center;',
  },
  {
    name: 'website',
    label: 'Website',
    field: 'website',
    align: 'left',
    style: 'text-align: center;',
  },

  {
    name: 'priceGbp',
    label: 'Price (GBP)/Unit',
    field: 'priceGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'productWeight',
    label: 'Product Wt (g/Unit)',
    field: 'productWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'packageWeight',
    label: 'Package Wt (g/Unit)',
    field: 'packageWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'totalWeight',
    label: 'Total Wt (g/Unit)',
    field: 'totalWeight',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'cargoRate',
    label: 'Cargo Rate',
    field: 'cargoRate',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'cargoCostGbp',
    label: 'Cargo Cost (GBP/Unit)',
    field: 'cargoCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'totalCostGbp',
    label: 'Total Cost (GBP/Unit)',
    field: 'totalCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },
  {
    name: 'rowTotalCostGbp',
    label: 'Row Total Cost (GBP)',
    field: 'rowTotalCostGbp',
    align: 'center',
    classes: 'bg-gbp',
    headerClasses: 'bg-gbp',
    style: 'text-align: center;',
  },

  {
    name: 'costBdt',
    label: 'Cost (BDT/Unit)',
    field: 'costBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'totalCostBdt',
    label: 'Row Total Cost (BDT)',
    field: 'totalCostBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'offerPriceBdt',
    label: 'Offer Price (BDT/Unit)',
    field: 'offerPriceBdt',
    align: 'center',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: center;',
  },
  {
    name: 'totalBdt',
    label: 'Row Offer Total (BDT)',
    field: 'totalBdt',
    align: 'center',
    classes: 'bg-offer',
    headerClasses: 'bg-offer',
    style: 'text-align: center;',
  },
  {
    name: 'profitPerUnitBdt',
    label: 'Profit (BDT/Unit)',
    field: 'profitPerUnitBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },
  {
    name: 'profitBdt',
    label: 'Row Total Profit (BDT)',
    field: 'profitBdt',
    align: 'center',
    classes: 'bg-bdt',
    headerClasses: 'bg-bdt',
    style: 'text-align: center;',
  },

  {
    name: 'profitRate',
    label: 'Profit Rate (%)',
    field: 'profitRate',
    align: 'center',
    style: 'text-align: center;',
  },
  {
    name: 'status',
    label: 'Status',
    field: 'status',
    align: 'center',
    style: 'text-align： center;',
  },
  {
    name: 'action',
    label: 'Action',
    field: 'action',
    align: 'center',
    style: 'text-align： center;',
  },
]);

const getTotalWeight = (row: ProductBasedCostingTableRow) => {
  return getUnitWeight(row.productWeight, row.packageWeight);
};

const getCargoCostGbp = (row: ProductBasedCostingTableRow) => {
  return getUnitCargoCostGbp(row.productWeight, row.packageWeight, row.cargoRate);
};

const getTotalCostGbp = (row: ProductBasedCostingTableRow) => {
  return getUnitTotalCostGbp(
    row.priceGbp,
    row.productWeight,
    row.packageWeight,
    row.cargoRate,
  );
};

const getRowTotalCostGbp = (row: ProductBasedCostingTableRow) => {
  return getTotalCostGbp(row) * row.qty;
};

const getCostBdt = (row: ProductBasedCostingTableRow) => {
  return getUnitCostBdt(
    row.priceGbp,
    row.productWeight,
    row.packageWeight,
    row.cargoRate,
    row.conversionRate,
  );
};

const getTotalCostBdt = (row: ProductBasedCostingTableRow) => {
  return getCostBdt(row) * row.qty;
};

const getTotalBdt = (row: ProductBasedCostingTableRow) => {
  return row.offerPriceBdt * row.qty;
};

const getProfitPerUnit = (row: ProductBasedCostingTableRow) => {
  return row.offerPriceBdt - getCostBdt(row);
};

const getProfitBdt = (row: ProductBasedCostingTableRow) => {
  return getProfitPerUnit(row) * row.qty;
};

const getProfitRate = (row: ProductBasedCostingTableRow) => {
  const costBdt = getCostBdt(row);

  if (costBdt <= 0) return 0;

  return (getProfitPerUnit(row) / costBdt) * 100;
};

const emitRowChange = (
  row: ProductBasedCostingTableRow,
  field: 'quantity' | 'offer_price' | 'status',
) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    offer_price: row.offerPriceBdt,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  };

  row.raw = updatedItem;

  emit('row-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field,
  });
};

const emitProductWeightChange = (row: ProductBasedCostingTableRow) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    offer_price: row.offerPriceBdt,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  };

  row.raw = updatedItem;

  emit('product-weight-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field: 'product_weight',
  });
};

const emitPackageWeightChange = (row: ProductBasedCostingTableRow) => {
  const updatedItem: ProductBasedCostingItem = {
    ...row.raw,
    quantity: row.qty,
    offer_price: row.offerPriceBdt,
    status: row.status,
    product_weight: row.productWeight,
    package_weight: row.packageWeight,
  };

  row.raw = updatedItem;

  emit('package-weight-change', {
    item: updatedItem,
    row: { ...row, raw: updatedItem },
    field: 'package_weight',
  });
};

const onQtySave = (row: ProductBasedCostingTableRow) => {
  row.qty = toNumber(row.qty);
  emitRowChange(row, 'quantity');
};

const onOfferPriceBdtSave = (row: ProductBasedCostingTableRow) => {
  row.offerPriceBdt = toNumber(row.offerPriceBdt);
  emitRowChange(row, 'offer_price');
};

const onStatusSave = (row: ProductBasedCostingTableRow) => {
  row.status = toText(row.status, 'pending').toLowerCase();
  emitRowChange(row, 'status');
};

const onProductWeightSave = (row: ProductBasedCostingTableRow) => {
  row.productWeight = toNumber(row.productWeight);
  emitProductWeightChange(row);
};

const onPackageWeightSave = (row: ProductBasedCostingTableRow) => {
  row.packageWeight = toNumber(row.packageWeight);
  emitPackageWeightChange(row);
};

const onEdit = (row: ProductBasedCostingTableRow) => {
  emit('edit', row.raw);
};

const onDelete = (row: ProductBasedCostingTableRow) => {
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete #${row.id} ${row.name || ''}?`,
    cancel: true,
    persistent: true,
  }).onOk(() => {
    emit('delete', row.raw);
  });
};

const getStatusColor = (status: string | null) => {
  switch ((status || '').toLowerCase()) {
    case 'pending':
      return 'warning';
    case 'accepted':
      return 'positive';
    case 'rejected':
      return 'negative';
    default:
      return 'grey';
  }
};

const totals = computed(() => {
  const initial = {
    qty: 0,
    priceGbp: 0,
    productWeight: 0,
    packageWeight: 0,
    totalWeight: 0,
    cargoRate: 0,
    cargoCostGbp: 0,
    totalCostGbp: 0,
    rowTotalCostGbp: 0,
    costBdt: 0,
    totalCostBdt: 0,
    offerPriceBdt: 0,
    totalBdt: 0,
    profitPerUnitBdt: 0,
    profitBdt: 0,
    averageProfitRate: 0,
  };

  const sum = tableRows.value.reduce((acc, row) => {
    acc.qty += row.qty;
    acc.priceGbp += row.priceGbp;
    acc.productWeight += row.productWeight;
    acc.packageWeight += row.packageWeight;
    acc.totalWeight += getTotalWeight(row);
    acc.cargoRate += row.cargoRate;
    acc.cargoCostGbp += getCargoCostGbp(row);
    acc.totalCostGbp += getTotalCostGbp(row);
    acc.rowTotalCostGbp += getRowTotalCostGbp(row);
    acc.costBdt += getCostBdt(row);
    acc.totalCostBdt += getTotalCostBdt(row);
    acc.offerPriceBdt += row.offerPriceBdt;
    acc.totalBdt += getTotalBdt(row);
    acc.profitPerUnitBdt += getProfitPerUnit(row);
    acc.profitBdt += getProfitBdt(row);

    return acc;
  }, initial);

  sum.averageProfitRate =
    sum.totalCostBdt > 0 ? (sum.profitBdt / sum.totalCostBdt) * 100 : 0;

  return sum;
});
</script>

<style scoped>
.product-based-costing-table {
  width: 100%;
}

.costing-q-table {
  max-width: 100%;
  height: 72vh;
}

:deep(.q-table) {
  min-width: 2200px;
}

.product-based-costing-table :deep(.costing-q-table thead tr th) {
  position: sticky;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
}

.product-based-costing-table :deep(.costing-q-table thead tr:first-child th) {
  top: 0;
  z-index: 1;
}

.product-based-costing-table :deep(.costing-q-table thead tr + tr th) {
  top: 48px;
  z-index: 3;
}

.product-based-costing-table :deep(.costing-q-table td:first-child),
.product-based-costing-table :deep(.costing-q-table th:first-child) {
  position: sticky;
  left: 0;
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(2)),
.product-based-costing-table :deep(.costing-q-table th:nth-child(2)) {
  position: sticky;
  left: 60px;
}

.product-based-costing-table :deep(.costing-q-table td:first-child) {
  z-index: 1;
  background: #f8f9fa;
}

.product-based-costing-table :deep(.costing-q-table td:nth-child(2)) {
  z-index: 1;
  background: #fcfcfc;
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:first-child) {
  z-index: 4;
  background: #f8f9fa;
}

.product-based-costing-table :deep(.costing-q-table tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: #fcfcfc;
}

.product-based-costing-table :deep(.costing-q-table tbody) {
  scroll-margin-top: 48px;
}

.table-image {
  width: 96px;
  height: 96px;
  display: block;
  margin: 0 auto;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
  object-fit: contain;
  object-position: center;
}

.table-image-placeholder {
  width: 96px;
  height: 96px;
  margin: 0 auto;
  border: 1px dashed #bbb;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  color: #777;
  background: #fafafa;
}

.editable-cell {
  cursor: pointer;
}

.editable-value {
  min-height: 24px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.col-sl {
  min-width: 60px;
  width: 60px;
  background: #f8f9fa;
}

.col-image {
  min-width: 130px;
  width: 130px;
  background: #fcfcfc;
}

.col-name {
  min-width: 200px;
  background: #ffffff;
}

.col-note {
  min-width: 260px;
  background: #fcfcfc;
}

.col-qty {
  min-width: 100px;
  width: 100px;
  background: #f8f9fa;
}

.col-barcode {
  min-width: 180px;
  background: #ffffff;
}

.col-website {
  min-width: 120px;
  background: #f8f9fa;
}

.col-price-gbp {
  min-width: 110px;
  background: #ffffff;
}

.col-product-weight {
  min-width: 120px;
  background: #f8f9fa;
}

.col-package-weight {
  min-width: 130px;
  background: #ffffff;
}

.col-total-weight {
  min-width: 120px;
  background: #f8f9fa;
}

.col-cargo-rate {
  min-width: 100px;
  background: #ffffff;
}

.col-cargo-cost-gbp {
  min-width: 130px;
  background: #f8f9fa;
}

.col-total-cost-gbp {
  min-width: 130px;
  background: #ffffff;
}

.col-row-total-cost-gbp {
  min-width: 150px;
  background: #f8f9fa;
}

.col-cost-bdt {
  min-width: 110px;
  background: #f8f9fa;
}

.col-total-cost-bdt {
  min-width: 130px;
  background: #ffffff;
}

.col-offer-price-bdt {
  min-width: 150px;
  background: #f8f9fa;
}

.col-total-bdt {
  min-width: 110px;
  background: #ffffff;
}

.col-profit-per-unit-bdt {
  min-width: 130px;
  background: #f8f9fa;
}

.col-profit-bdt {
  min-width: 110px;
  background: #f8f9fa;
}

.col-profit-rate {
  min-width: 110px;
  background: #ffffff;
}

.col-status {
  min-width: 150px;
  background: #f8f9fa;
}

.col-action {
  min-width: 100px;
  background: #ffffff;
}

.totals-row {
  background: inherit;
}

.totals-row__cell {
  font-weight: 700;
  color: inherit;
  white-space: normal;
  word-break: break-word;
  padding: 0;
  text-align: center;
}

.totals-row__value {
  display: block;
  width: 100%;
  min-height: 100%;
  padding: 8px 16px;
  text-align: center;
}

:deep(.bg-gbp) {
  background-color: #e6f4ea !important;
}

:deep(.bg-bdt) {
  background-color: #fff8e1 !important;
}

:deep(.bg-offer) {
  background-color: #f3e5f5 !important;
}
.col-name-wrap {
  min-width: 150px;
  max-width: 200px;
  white-space: normal; /* allow wrapping */
  word-break: break-word; /* break long words */
  line-height: 1.3;
}

.item-note-html {
  white-space: normal;
  word-break: break-word;
  line-height: 1.35;
}
</style>
