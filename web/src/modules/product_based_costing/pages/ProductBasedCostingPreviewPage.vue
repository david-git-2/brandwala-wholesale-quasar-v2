<template>
  <q-page class="q-pa-md">
    <section class="preview-page__shell">
      <div class="preview-page__actions q-mb-md">
        <q-btn
          size="sm"
          dense
          flat
          color="primary"
          icon="arrow_back"
          label="Back"
          class="preview-page__action-btn"
          @click="goBack"
        />
        <q-btn
          size="sm"
          dense
          color="primary"
          icon="print"
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
                class="text-center preview-page__header-cell preview-page__header-cell--sl preview-page__sl-cell"
              >
                SL
              </q-th>
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
                Offer Price (BDT/Unit)
              </q-th>
            </q-tr>
          </template>

          <template #body="slotProps">
            <q-tr :props="slotProps">
              <q-td key="sl" :props="slotProps" class="text-center preview-page__sl-cell">
                {{ slotProps.row.sl }}
              </q-td>

              <q-td key="image" :props="slotProps" class="text-center">
                <SmartImage
                  :src="resolvePreviewImageUrl(slotProps.row.imageUrl)"
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

      <div class="preview-page__pager q-mt-sm">
        <q-btn
          size="sm"
          dense
          round
          flat
          color="primary"
          icon="chevron_left"
          class="preview-page__pager-nav"
          :disable="currentPage <= 1 || !rows.length"
          @click="goPrevPage"
        />
        <div class="preview-page__pager-center">
          <div class="preview-page__pager-label">Page {{ currentPage }} / {{ totalPages }}</div>
          <div class="preview-page__pager-sub">
            Showing {{ pageStartIndex }}-{{ pageEndIndex }} of {{ rows.length }}
          </div>
        </div>
        <q-btn
          size="sm"
          dense
          round
          flat
          color="primary"
          icon="chevron_right"
          class="preview-page__pager-nav"
          :disable="currentPage >= totalPages || !rows.length"
          @click="goNextPage"
        />
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import type { QTableColumn } from 'quasar'
import { useRoute, useRouter } from 'vue-router'

import SmartImage from 'src/components/SmartImage.vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types'
import { calculateOfferPriceBdt, normalizeOfferPriceBdt, toNumberSafe } from '../utils/pricing'

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
const isPrintMode = ref(false)
const currentPage = ref(1)
const errorMessage = ref('')
const fileInfo = ref<ProductBasedCostingFile | null>(null)
const items = ref<ProductBasedCostingItem[]>([])
const VIEW_ROWS_PER_PAGE = 6

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

const toExternalUrl = (value: string) => (/^https?:\/\//i.test(value) ? value : `https://${value}`)

const getDriveFileId = (url: string) => {
  const byQuery = url.match(/[?&]id=([^&]+)/)
  const byPath = url.match(/\/file\/d\/([^/]+)/)
  return byQuery?.[1] || byPath?.[1] || null
}

const resolvePreviewImageUrl = (value: string | null) => {
  if (!value) {
    return null
  }

  const normalized = toExternalUrl(value)
  const driveId = getDriveFileId(normalized)
  if (driveId) {
    return `https://lh3.googleusercontent.com/d/${driveId}`
  }

  return normalized
}

const formatNumber = (value: number | null | undefined) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return '-'
  }

  return Number(value).toFixed(2)
}

const toNumber = (value: unknown) => {
  return toNumberSafe(value)
}

const getOfferPriceBdt = (item: ProductBasedCostingItem) => {
  // Always prefer saved cell value from offer_price, then round to nearest upper 0/5.
  const rawOffer = toNumber(item.offer_price)
  if (rawOffer > 0) {
    return normalizeOfferPriceBdt(rawOffer)
  }

  return calculateOfferPriceBdt({
    priceGbp: toNumber(item.price_gbp),
    productWeight: toNumber(item.product_weight),
    packageWeight: toNumber(item.package_weight),
    cargoRate: cargoRate.value,
    conversionRate: conversionRate.value,
    profitRate: profitRate.value,
  })
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

const totalPages = computed(() =>
  Math.max(1, Math.ceil(rows.value.length / VIEW_ROWS_PER_PAGE)),
)

const pagedRows = computed<PreviewRow[]>(() => {
  const start = (currentPage.value - 1) * VIEW_ROWS_PER_PAGE
  return rows.value.slice(start, start + VIEW_ROWS_PER_PAGE)
})
const tableRows = computed<PreviewRow[]>(() => (isPrintMode.value ? rows.value : pagedRows.value))
const pageStartIndex = computed(() => (rows.value.length ? (currentPage.value - 1) * VIEW_ROWS_PER_PAGE + 1 : 0))
const pageEndIndex = computed(() =>
  rows.value.length ? Math.min(currentPage.value * VIEW_ROWS_PER_PAGE, rows.value.length) : 0,
)

const columns = computed((): QTableColumn[] => [
  {
    name: 'sl',
    label: '',
    field: 'sl',
    align: 'center',
    style: 'width: 36px; min-width: 36px;',
    headerStyle: 'width: 36px; min-width: 36px;',
  },
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
  isPrintMode.value = true
  void nextTick(async () => {
    // Ensure full list is rendered and visible images are loaded before opening print dialog.
    const root = document.querySelector('.preview-page__table-card') as HTMLElement | null
    if (root) {
      const images = Array.from(root.querySelectorAll('img')) as HTMLImageElement[]
      await Promise.all(
        images.map(
          (img) =>
            new Promise<void>((resolve) => {
              if (img.complete && img.naturalWidth > 0) {
                resolve()
                return
              }

              const done = () => {
                img.removeEventListener('load', done)
                img.removeEventListener('error', done)
                resolve()
              }

              img.addEventListener('load', done, { once: true })
              img.addEventListener('error', done, { once: true })
              setTimeout(done, 7000)
            }),
        ),
      )
    }

    await new Promise((resolve) => setTimeout(resolve, 120))
    window.print()
  })
}

const resetPrintMode = () => {
  isPrintMode.value = false
}

const activatePrintMode = () => {
  isPrintMode.value = true
}

const goPrevPage = () => {
  if (currentPage.value > 1) {
    currentPage.value -= 1
  }
}

const goNextPage = () => {
  if (currentPage.value < totalPages.value) {
    currentPage.value += 1
  }
}

watch(fileId, () => {
  void loadPreviewData()
})

watch(
  () => rows.value.length,
  () => {
    if (currentPage.value > totalPages.value) {
      currentPage.value = totalPages.value
    }
  },
)

onMounted(() => {
  window.addEventListener('beforeprint', activatePrintMode)
  window.addEventListener('afterprint', resetPrintMode)
  void loadPreviewData()
})

onUnmounted(() => {
  window.removeEventListener('beforeprint', activatePrintMode)
  window.removeEventListener('afterprint', resetPrintMode)
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
  gap: 0.35rem;
  justify-content: center;
}

.preview-page__action-btn {
  flex: 0 0 auto;
  min-width: 132px;
  min-height: 28px;
  padding: 0 6px;
}

.preview-page__action-btn :deep(.q-btn__content) {
  gap: 4px;
  font-size: 11px;
}

.preview-page__pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 6px;
  border: 1px solid rgba(148, 163, 184, 0.32);
  border-radius: 12px;
  background: linear-gradient(180deg, rgba(248, 250, 252, 0.95) 0%, rgba(241, 245, 249, 0.95) 100%);
}

.preview-page__pager-nav {
  border: 1px solid rgba(148, 163, 184, 0.35);
  background: #fff;
}

.preview-page__pager-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
  min-width: 150px;
}

.preview-page__pager-label {
  text-align: center;
  font-size: 12px;
  font-weight: 700;
  color: #0f172a;
}

.preview-page__pager-sub {
  text-align: center;
  font-size: 10px;
  font-weight: 600;
  color: #64748b;
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
  background: transparent;
}

.preview-page__header-cell {
  font-size: 11px;
  line-height: 1.1;
  padding: 4px 5px;
  color: #0f172a;
  font-weight: 700;
  text-transform: none;
  white-space: normal;
  word-break: break-word;
}

.preview-page__header-cell--image {
  width: 104px;
  min-width: 104px;
}

.preview-page__sl-cell {
  width: 36px;
  min-width: 36px;
  max-width: 36px;
  padding-left: 2px !important;
  padding-right: 2px !important;
}

.preview-page__header-cell--offer {
  width: 82px;
  min-width: 82px;
  background: #faf5ff;
  color: #4a044e;
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
  :root,
  body,
  .preview-page__shell,
  .preview-page__meta-card,
  .preview-page__table-card,
  .preview-page__header-row,
  .preview-page__header-cell,
  .preview-page__offer-cell,
  .preview-page__offer-value {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  .preview-page {
    background: #fff;
    padding: 0;
  }

  .preview-page__actions,
  .preview-page__pager,
  .q-banner {
    display: none !important;
  }

  .preview-page__meta-card,
  .preview-page__table-card {
    box-shadow: none;
    border-radius: 0;
  }

  .preview-page__header-row {
    background: transparent !important;
  }

  .preview-page__header-cell {
    color: #0f172a !important;
  }

  .preview-page__header-cell--offer {
    background: #faf5ff !important;
    color: #4a044e !important;
  }

  .preview-page__offer-cell {
    background: rgba(126, 34, 206, 0.08) !important;
  }

  .preview-page__offer-value {
    color: #6b21a8 !important;
  }
}
</style>
