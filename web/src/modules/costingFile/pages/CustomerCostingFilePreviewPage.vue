<template>
  <q-page class="preview-page">
    <section class="preview-page__card">
      <div class="preview-page__header">
        <div class="text-subtitle1">Offer Preview</div>
        <div class="preview-page__header-actions">
          <q-btn
            flat
            dense
            color="primary"
            :loading="exporting"
            :disable="!rows.length || exporting"
            :label="exporting ? 'Preparing ZIP...' : 'Download ZIP'"
            class="preview-page__print-btn"
            @click="downloadZip"
          />
          <q-btn
            flat
            dense
            color="primary"
            label="Print"
            class="preview-page__print-btn"
            @click="printPage"
          />
        </div>
      </div>

      <div ref="captureRef" class="preview-page__capture">
        <q-table
          v-if="rows.length"
          flat
          bordered
          row-key="id"
          :rows="rows"
          :columns="columns"
          :pagination="{ rowsPerPage: 0 }"
          hide-bottom
          class="preview-page__table"
        >
          <template #body-cell-sl="props">
            <q-td :props="props" class="preview-page__sl-cell">
              {{ props.row.sl }}
            </q-td>
          </template>

          <template #body-cell-image="props">
            <q-td :props="props" class="preview-page__image-cell">
              <q-img
                v-if="props.row.imageUrl"
                :src="props.row.imageUrl"
                fit="contain"
                class="preview-page__image"
              />
              <div v-else class="preview-page__image preview-page__image--placeholder">
                No image
              </div>
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props" class="preview-page__name-cell">
              <span class="preview-page__name-text" :title="props.row.name">
                {{ props.row.name }}
              </span>
            </q-td>
          </template>

          <template #body-cell-buyerSellingPriceBdt="props">
            <q-td :props="props" class="preview-page__price-cell">
              {{ props.row.buyerSellingPriceBdt }}
            </q-td>
          </template>
        </q-table>

        <div v-else class="text-body2 text-grey-7">No items to preview.</div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { toBlob } from 'html-to-image'
import JSZip from 'jszip'
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute, useRouter } from 'vue-router'

import { buildCustomerProductRows } from 'src/modules/costingFile/composables/useCostingFileDetailRows'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'

const route = useRoute()
const router = useRouter()
const costingFileStore = useCostingFileStore()
const { costingFileItems, selectedItem } = storeToRefs(costingFileStore)
const captureRef = ref<HTMLElement | null>(null)
const exporting = ref(false)

const columns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const, style: 'width: 40px; min-width: 40px;', headerStyle: 'width: 40px; min-width: 40px;' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const, style: 'width: 64px; min-width: 64px;', headerStyle: 'width: 64px; min-width: 64px;' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  {
    name: 'buyerSellingPriceBdt',
    label: 'Buyer selling',
    field: 'buyerSellingPriceBdt',
    align: 'right' as const,
    style: 'width: 92px; min-width: 92px;',
    headerStyle: 'width: 92px; min-width: 92px;',
    classes: 'preview-page__tone-orange',
    headerClasses: 'preview-page__tone-orange',
  },
]

const rows = computed(() => buildCustomerProductRows(costingFileItems.value, null))

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!Number.isFinite(fileId) || fileId <= 0) {
    await router.replace({ name: 'customer-costing-file-page' })
    return
  }

  const result = await costingFileStore.fetchCostingFileWithItemsForCustomer(fileId)
  if (!result.success || !result.data || result.data.status !== 'offered') {
    await router.replace({ name: 'customer-costing-file-details-page', params: { id: String(fileId) } })
  }
}

const printPage = () => {
  window.print()
}

const fileSafe = (value: string) =>
  String(value || 'costing')
    .trim()
    .replace(/[^a-z0-9_-]+/gi, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .toLowerCase() || 'costing'

const buildZipBaseName = () => {
  const fileId = selectedItem.value?.id ? String(selectedItem.value.id) : 'file'
  const name = selectedItem.value?.name ?? 'costing'
  return `${fileSafe(name)}-${fileSafe(fileId)}`
}

const downloadBlob = (blob: Blob, filename: string) => {
  const link = document.createElement('a')
  const url = URL.createObjectURL(blob)
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

const downloadZip = async () => {
  if (!rows.value.length || !captureRef.value || exporting.value) {
    return
  }

  exporting.value = true

  try {
    const blob = await toBlob(captureRef.value, {
      cacheBust: true,
      pixelRatio: 2,
      backgroundColor: '#ffffff',
    })

    if (!blob) {
      throw new Error('capture-failed')
    }

    const zip = new JSZip()
    const base = buildZipBaseName()
    zip.file(`${base}-01.png`, blob)
    const zipBlob = await zip.generateAsync({
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 },
    })
    downloadBlob(zipBlob, `${base}.zip`)
  } catch {
    window.alert('Could not export preview image ZIP. Try again.')
  } finally {
    exporting.value = false
  }
}

onMounted(async () => {
  await loadFile()
})
</script>

<style scoped>
.preview-page {
  display: block;
  padding: 1rem 0.5rem;
  background: #fff;
}

.preview-page__card {
  width: min(400px, calc(100vw - 1rem));
  margin: 0 auto;
  display: grid;
  gap: 0.75rem;
}

.preview-page__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.preview-page__header-actions {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.preview-page__table :deep(.q-table th),
.preview-page__table :deep(.q-table td) {
  vertical-align: top;
}

.preview-page__table :deep(.q-table tr) {
  break-inside: avoid;
}

.preview-page__sl-cell {
  white-space: nowrap;
}

.preview-page__image {
  width: 1in;
  height: 1in;
  border-radius: 6px;
  overflow: hidden;
  background: var(--bw-theme-surface);
}

.preview-page__image :deep(img) {
  object-fit: contain !important;
  object-position: center;
}

.preview-page__image--placeholder {
  display: flex;
  align-items: flex-start;
  justify-content: center;
  border: 1px dashed var(--bw-theme-border);
  color: var(--bw-theme-muted);
  font-size: 0.65rem;
  text-align: center;
  padding-top: 0.35rem;
}

.preview-page__name-cell {
  min-width: 0;
}

.preview-page__name-text {
  display: inline-block;
  max-width: 100%;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.25;
}

.preview-page__price-cell {
  white-space: nowrap;
  font-weight: 700;
  background: #fdeccd;
}

.preview-page__table :deep(.preview-page__tone-orange) {
  background: #fdeccd;
  color: #7a5313;
}

.preview-page__table :deep(th.preview-page__tone-orange) {
  font-weight: 700;
}

@media print {
  .preview-page,
  .preview-page * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  .preview-page {
    display: block;
    padding: 0;
    margin: 0;
    background: #fff;
  }

  .preview-page__card {
    width: 400px;
    max-width: 400px;
    margin: 0 auto;
    gap: 0.4rem;
  }

  .preview-page__print-btn {
    display: none !important;
  }

  .preview-page__table :deep(.q-table th),
  .preview-page__table :deep(.q-table td) {
    padding: 4px 6px;
    font-size: 11px;
    line-height: 1.2;
  }

  .preview-page__image {
    width: 1in;
    height: 1in;
  }
}
</style>
