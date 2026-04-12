<template>
  <q-page class="q-pa-md">
    <section class="preview-page__shell">
      <div class="preview-page__actions q-mb-md">
        <q-btn
          dense
          flat
          color="primary"
          icon="arrow_back"
          label="Back"
          class="preview-page__action-btn"
          @click="goBack"
        />
        <q-btn
          dense
          color="primary"
          icon="print"
          label="Print"
          class="preview-page__action-btn"
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

          <div class="preview-page__meta-label q-mt-sm">Created For</div>
          <div class="preview-page__meta-value preview-page__meta-value--compact">
            {{ createdFor }}
          </div>
        </q-card-section>
      </q-card>

      <q-card flat bordered class="preview-page__table-card">
        <q-table
          flat
          bordered
          :rows="rows"
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
                key="image"
                :props="props"
                class="text-center preview-page__header-cell preview-page__header-cell--image"
              >
                Image
              </q-th>
              <q-th key="name" :props="props" class="preview-page__header-cell">
                Name
              </q-th>
              <q-th
                key="offerPriceBdt"
                :props="props"
                class="text-center preview-page__header-cell preview-page__header-cell--offer"
              >
                Offer Price
              </q-th>
            </q-tr>
          </template>

          <template #body="slotProps">
            <q-tr :props="slotProps">
              <q-td key="image" :props="slotProps" class="text-center" >
                <SmartImage
                  :src="slotProps.row.imageUrl"
                  :alt="slotProps.row.name || 'Product image'"
                  img-class="preview-page__image"
                  fallback-class="preview-page__image preview-page__image--placeholder"
                />
              </q-td>

              <q-td key="name" :props="slotProps" class="preview-page__name-cell">
                <div class="preview-page__name-text">
                  {{ slotProps.row.name }}
                </div>
              </q-td>

              <q-td
                key="offerPriceBdt"
                :props="slotProps"
                class="text-center preview-page__offer-cell"
              >
                <span class="preview-page__offer-value">
                  {{ formatNumber(slotProps.row.offerPriceBdt) }}
                </span>
              </q-td>
            </q-tr>
          </template>

          <template #loading>
            <q-inner-loading showing color="primary" />
          </template>

          <template #no-data>
            <div class="full-width row flex-center q-pa-lg text-grey-7">
              No preview items found
            </div>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import type { QTableColumn } from 'quasar'
import { useRoute, useRouter } from 'vue-router'

import SmartImage from 'src/components/SmartImage.vue'
import { roundBdtUpToZeroOrFive } from 'src/modules/costingFile/utils/costingCalculations'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types'

type PreviewRow = {
  id: number
  sl: number
  name: string
  imageUrl: string | null
  offerPriceBdt: number
  raw: ProductBasedCostingItem
}

const route = useRoute()
const router = useRouter()
const store = useProductBasedCostingStore()

const loading = ref(false)
const errorMessage = ref('')
const fileInfo = ref<ProductBasedCostingFile | null>(null)
const items = ref<ProductBasedCostingItem[]>([])

const fileId = computed(() => {
  const parsed = Number(route.params.id)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})

const cargoRate = computed(() => Number(fileInfo.value?.cargo_rate_kg_gbp ?? 0))
const conversionRate = computed(() => Number(fileInfo.value?.conversion_rate ?? 140))
const profitRate = computed(() => Number(fileInfo.value?.profit_rate ?? 25))

const fileLabel = computed(() => `#${fileInfo.value?.id ?? fileId.value ?? '-'}`)

const fileName = computed(() => fileInfo.value?.name?.trim() || '-')

const createdFor = computed(() => fileInfo.value?.order_for?.trim() || '-')

const formatNumber = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '-'
  }

  return Number(value).toFixed(2)
}

const toNumber = (value: unknown) => {
  const num = Number(value ?? 0)
  return Number.isNaN(num) ? 0 : num
}

const getOfferPriceBdt = (item: ProductBasedCostingItem) => {
  if (item.offer_price != null) {
    return toNumber(item.offer_price)
  }

  const qty = toNumber(item.quantity)
  const priceGbp = toNumber(item.price_gbp)
  const productWeight = toNumber(item.product_weight)
  const packageWeight = toNumber(item.package_weight)

  const cargoCostGbp = (((productWeight + packageWeight) * qty) / 1000) * cargoRate.value
  const totalCostGbp = priceGbp + cargoCostGbp
  const costBdt = roundBdtUpToZeroOrFive(totalCostGbp * conversionRate.value)

  return roundBdtUpToZeroOrFive(costBdt + (costBdt * profitRate.value) / 100)
}

const rows = computed<PreviewRow[]>(() =>
  items.value.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    name: item.name?.trim() || '-',
    imageUrl: item.image_url ?? null,
    offerPriceBdt: getOfferPriceBdt(item),
    raw: item,
  })),
)

const columns = computed((): QTableColumn[] => [
  {
    name: 'image',
    label: '',
    field: 'imageUrl',
    align: 'center',
    style: 'width: 104px; min-width: 104px;',
    headerStyle: 'width: 104px; min-width: 104px;',
  },
  {
    name: 'name',
    label: '',
    field: 'name',
    align: 'left',
    classes: 'preview-page__name-column',
    headerClasses: 'preview-page__name-column',
  },
  {
    name: 'offerPriceBdt',
    label: '',
    field: 'offerPriceBdt',
    align: 'center',
    style: 'width: 82px; min-width: 82px;',
    headerStyle: 'width: 82px; min-width: 82px;',
  },
])

const loadPreviewData = async () => {
  if (!fileId.value) {
    errorMessage.value = 'Invalid file id.'
    fileInfo.value = null
    items.value = []
    return
  }

  loading.value = true
  errorMessage.value = ''
  fileInfo.value = null
  items.value = []

  try {
    const [fileResult, itemsResult] = await Promise.all([
      store.fetchProductBasedCostingFileById(fileId.value),
      store.fetchProductBasedCostingItems(fileId.value),
    ])

    if (!fileResult.success) {
      errorMessage.value = fileResult.error ?? 'Failed to load preview data.'
      return
    }

    fileInfo.value = fileResult.data ?? null

    if (!itemsResult.success) {
      errorMessage.value = itemsResult.error ?? 'Failed to load preview items.'
      return
    }

    items.value = itemsResult.data ?? []
  } finally {
    loading.value = false
  }
}

const goBack = () => {
  if (fileId.value) {
    void router.push({
      name: 'product-based-costing-file-details-page',
      params: { id: fileId.value },
    })
    return
  }

  router.back()
}

const printPage = () => {
  window.print()
}

watch(fileId, () => {
  void loadPreviewData()
})

onMounted(() => {
  void loadPreviewData()
})
</script>

<style scoped>


.preview-page__shell {
  width: 320px;
  max-width: calc(100vw - 1rem);
  margin: 0 auto;
}

.preview-page__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.7rem;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.08);
  color: #1d4ed8;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.preview-page__actions {
  display: flex;
  flex-direction: row;
  gap: 0.5rem;
}

.preview-page__action-btn {
  flex: 1 1 0;
  min-width: 0;
}

.preview-page__meta-card,
.preview-page__table-card {
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06);
}

.preview-page__meta-section {
  padding: 12px;
}

.preview-page__meta-line {
  display: flex;
  align-items: baseline;
  gap: 0.45rem;
  flex-wrap: wrap;
}

.preview-page__meta-label {
  font-size: 11px;
  color: #64748b;
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.preview-page__meta-value {
  font-size: 16px;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.25;
  word-break: break-word;
}

.preview-page__meta-value--compact {
  font-size: 14px;
  font-weight: 600;
  min-width: 0;
  overflow-wrap: anywhere;
}

.preview-page__header-row {
  background: #faf5ff;
}

.preview-page__header-cell {
  font-size: 11px;
  line-height: 1.1;
  padding: 4px 5px;
  color: #4a044e;
  font-weight: 700;
  text-transform: none;
  white-space: normal;
  word-break: break-word;
}

.preview-page__header-cell--image {
  width: 104px;
  min-width: 104px;
}

.preview-page__header-cell--offer {
  width: 82px;
  min-width: 82px;
}

.preview-page__table :deep(.q-table) {
  width: 100%;
  min-width: 0;
  table-layout: fixed;
  font-size: 12px;
}

.preview-page__table :deep(.q-table th),
.preview-page__table :deep(.q-table td) {
  border-color: rgba(148, 163, 184, 0.24);
  padding: 4px 5px;
}

.preview-page__table :deep(.q-table tr) {
  transition: background-color 0.18s ease;
}

.preview-page__table :deep(.q-table tbody tr:hover) {
  background: rgba(59, 130, 246, 0.04);
}

.preview-page__image {
  width: 96px;
  height: 96px;
  object-fit: contain;
  margin: 0 auto;
  border: 1px solid #dbe3ef;
  border-radius: 8px;
  background: #fff;
}

.preview-page__image--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  color: #64748b;
  background: #f8fafc;
}

.preview-page__name-cell {
  min-width: 0;
  max-width: 100%;
  white-space: normal;
  word-break: break-word;
  overflow-wrap: anywhere;
}

.preview-page__name-text {
  white-space: normal;
  word-break: break-word;
  overflow-wrap: anywhere;
  hyphens: auto;
  line-height: 1.2;
  font-size: 11px;
  max-width: 100%;
}

:deep(.preview-page__name-column) {
  min-width: 0;
  width: auto;
}

.preview-page__offer-cell {
  background: rgba(126, 34, 206, 0.08);
}

.preview-page__offer-value {
  display: inline-block;
  white-space: normal;
  word-break: break-word;
  font-size: 11px;
  font-weight: 700;
  color: #6b21a8;
  line-height: 1.15;
}

@media print {
  .preview-page {
    background: #fff;
    padding: 0;
  }

  .preview-page__actions,
  .q-banner {
    display: none !important;
  }

  .preview-page__meta-card,
  .preview-page__table-card {
    box-shadow: none;
    border-radius: 0;
  }
}
</style>
