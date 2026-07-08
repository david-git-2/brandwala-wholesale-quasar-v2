<template>
  <q-page class="q-pa-md preview-canvas">
    <section class="preview-page__shell a4-sheet">
      <div class="preview-page__actions q-mb-md no-print">
        <q-btn
          size="sm"
          color="primary"
          icon="print"
          label="Print"
          class="preview-page__action-btn preview-page__print-btn"
          @click="printPage"
        />
      </div>

      <q-card flat bordered class="preview-page__meta-card q-mb-md">
        <q-card-section class="preview-page__meta-section">
          <div class="preview-page__meta-line">
            <div class="preview-page__meta-value">{{ fileLabel }}</div>
            <div class="preview-page__meta-value preview-page__meta-value--compact">
              {{ fileName }}
            </div>
          </div>
        </q-card-section>
      </q-card>

      <q-card flat bordered class="preview-page__table-card">
        <q-table
          flat
          bordered
          :rows="tableRows"
          :columns="columns"
          row-key="id"
          :loading="loading"
          hide-pagination
          :pagination="{ rowsPerPage: 0 }"
          class="preview-page__table"
        >
          <template #header="props">
            <q-tr :props="props" class="preview-page__header-row">
              <q-th
                key="sl"
                :props="props"
                class="text-center preview-page__header-cell preview-page__sl-cell"
                >SL</q-th
              >
              <q-th
                key="image"
                :props="props"
                class="text-center preview-page__header-cell preview-page__header-cell--image"
                >Image</q-th
              >
              <q-th key="name" :props="props" class="preview-page__header-cell">Name</q-th>
              <q-th key="quantity" :props="props" class="text-center preview-page__header-cell"
                >Quantity</q-th
              >
              <q-th
                key="unitOfferPrice"
                :props="props"
                class="text-center preview-page__header-cell"
                >Unit Offer Price</q-th
              >
              <q-th
                key="totalOfferPrice"
                :props="props"
                class="text-center preview-page__header-cell"
                >Total Offer Price</q-th
              >
            </q-tr>
          </template>

          <template #body="slotProps">
            <q-tr :props="slotProps">
              <q-td key="sl" :props="slotProps" class="text-center preview-page__sl-cell">{{
                slotProps.row.sl
              }}</q-td>
              <q-td key="image" :props="slotProps" class="text-center">
                <SmartImage
                  :src="slotProps.row.imageUrl"
                  :alt="slotProps.row.name || 'Product image'"
                  img-class="preview-page__image"
                  fallback-class="preview-page__image preview-page__image--placeholder"
                  object-fit="contain"
                />
              </q-td>
              <q-td key="name" :props="slotProps" class="preview-page__name-cell">
                <div class="preview-page__name-text">{{ slotProps.row.name }}</div>
              </q-td>
              <q-td key="quantity" :props="slotProps" class="text-center">{{
                slotProps.row.quantity
              }}</q-td>
              <q-td
                key="unitOfferPrice"
                :props="slotProps"
                class="text-center preview-page__unit-offer-cell"
              >
                {{ formatMoney(slotProps.row.unitOfferPrice) }}
              </q-td>
              <q-td key="totalOfferPrice" :props="slotProps" class="text-center">{{
                formatMoney(slotProps.row.totalOfferPrice)
              }}</q-td>
            </q-tr>
          </template>
        </q-table>
      </q-card>

      <div class="invoice-total-wrap q-mt-md">
        <div class="invoice-total-label">Grand Total</div>
        <div class="invoice-total-value">{{ formatMoney(grandTotal) }}</div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import type { QTableColumn } from 'quasar';
import { useRoute } from 'vue-router';

import SmartImage from 'src/components/SmartImage.vue';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import type { ProductBasedCostingItem } from '../types';
import { toNumberSafe } from '../utils/pricing';

type PdfRow = {
  id: number;
  sl: number;
  imageUrl: string | null;
  name: string;
  quantity: number;
  unitOfferPrice: number;
  totalOfferPrice: number;
  raw: ProductBasedCostingItem;
};

const route = useRoute();
const store = useProductBasedCostingStore();
const loading = ref(false);

const fileId = computed(() => {
  const parsed = Number(route.params.id);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

const fileLabel = computed(() => `#${store.item?.id ?? fileId.value ?? '-'}`);
const fileName = computed(() => store.item?.name?.trim() || 'Items');

const tableRows = computed<PdfRow[]>(() =>
  (store.costingItems ?? []).map((item, index) => {
    const quantity = toNumberSafe(item.quantity);
    const unitOfferPrice = toNumberSafe(item.offer_price);
    return {
      id: item.id,
      sl: index + 1,
      imageUrl: item.image_url,
      name: item.name ?? '-',
      quantity,
      unitOfferPrice,
      totalOfferPrice: quantity * unitOfferPrice,
      raw: item,
    };
  }),
);

const columns = computed<QTableColumn<PdfRow>[]>(() => [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'center' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'center' },
  { name: 'unitOfferPrice', label: 'Unit Offer Price', field: 'unitOfferPrice', align: 'center' },
  {
    name: 'totalOfferPrice',
    label: 'Total Offer Price',
    field: 'totalOfferPrice',
    align: 'center',
  },
]);

const grandTotal = computed(() =>
  tableRows.value.reduce((sum, row) => sum + row.totalOfferPrice, 0),
);

const formatMoney = (value: number) =>
  value.toLocaleString('en-BD', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const printPage = () => window.print();

onMounted(async () => {
  if (!fileId.value) {
    return;
  }
  loading.value = true;
  await Promise.all([
    store.fetchProductBasedCostingFileById(fileId.value),
    store.fetchProductBasedCostingItems(fileId.value),
  ]);
  loading.value = false;
});
</script>

<style scoped>
.preview-page__shell {
  max-width: 210mm;
  margin: 0 auto;
}

.preview-canvas {
  background: #eef1f6;
}

.a4-sheet {
  width: 210mm;
  min-height: 297mm;
  background: #fff;
  padding: 12mm;
  box-shadow: 0 8px 24px rgba(17, 24, 39, 0.12);
  border: 1px solid #d9dce3;
}

.preview-page__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.preview-page__print-btn {
  padding: 10px 18px;
}

.preview-page__meta-card,
.preview-page__table-card {
  border-radius: 12px;
}

.preview-page__meta-section {
  padding: 16px;
}

.preview-page__meta-line {
  display: flex;
  gap: 12px;
  align-items: baseline;
  flex-wrap: wrap;
}

.preview-page__meta-value {
  font-weight: 700;
}

.preview-page__meta-value--compact {
  font-weight: 500;
}

.preview-page__header-row {
  background: #f5f7fb;
}

.preview-page__header-cell {
  font-weight: 700;
}

.preview-page__header-cell--image {
  min-width: 84px;
}

.preview-page__sl-cell {
  width: 52px;
}

.preview-page__name-cell {
  width: 220px;
  max-width: 220px;
  min-width: 220px;
}

.preview-page__name-text {
  white-space: normal;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.25;
}

.preview-page__image {
  width: 1in;
  height: 1in;
  object-fit: contain;
  border-radius: 6px;
  background: #ffffff;
}

.preview-page__image--placeholder {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #6b7280;
  font-size: 12px;
}

.preview-page__unit-offer-cell {
  background: #efe7ff;
  color: #4b2a7a;
  font-weight: 600;
}

.invoice-total-wrap {
  margin-left: auto;
  width: 280px;
  border: 1px solid #d8caef;
  border-radius: 10px;
  overflow: hidden;
}

.invoice-total-label {
  background: #f3ecff;
  color: #4b2a7a;
  font-weight: 700;
  padding: 10px 12px;
}

.invoice-total-value {
  background: #ffffff;
  color: #1f2937;
  font-weight: 700;
  font-size: 18px;
  padding: 12px;
  text-align: right;
}

.preview-page__table :deep(.q-table) {
  table-layout: fixed;
  width: 100%;
}

.preview-page__table :deep(th),
.preview-page__table :deep(td) {
  white-space: normal;
  word-break: break-word;
  overflow-wrap: anywhere;
}

@media print {
  @page {
    size: A4;
    margin: 10mm;
  }

  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  .no-print {
    display: none !important;
  }

  .preview-canvas {
    background: transparent !important;
  }

  .preview-page__shell,
  .preview-page__meta-card,
  .preview-page__table-card {
    box-shadow: none !important;
    border-color: #d9dce3 !important;
  }

  .a4-sheet {
    width: auto !important;
    min-height: auto !important;
    padding: 0 !important;
    border: none !important;
  }
}
</style>
