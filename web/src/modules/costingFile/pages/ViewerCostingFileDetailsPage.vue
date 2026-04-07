<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack viewer-page">
      <section class="viewer-page__header">
        <div>
          <div class="text-overline">Viewer Access</div>
          <h1 class="text-h5 q-my-none">Costing file details</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ selectedFile ? `${selectedFile.name} | ${selectedFile.market || 'Not set'}` : 'Loading details...' }}
          </p>
        </div>
        <q-chip
          v-if="selectedFile"
          dense
          square
          :color="statusChipColor(selectedFile.status)"
          text-color="white"
        >
          {{ formatStatusLabel(selectedFile.status) }}
        </q-chip>
      </section>

      <q-card v-if="!selectedFile" flat bordered>
        <q-card-section class="text-grey-7">Loading costing file details...</q-card-section>
      </q-card>

      <q-banner v-if="selectedFile && selectedFile.status !== 'completed'" rounded class="bg-blue-1 text-blue-10">
        Item details become visible after the costing file is completed.
      </q-banner>

      <section v-else-if="selectedFile" class="viewer-page__table-section">
        <q-card flat bordered class="viewer-page__pricing-card">
          <q-table
            flat
            bordered
            row-key="id"
            :rows="viewerReviewRows"
            :columns="viewerReviewColumns"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="viewer-page__table"
          >
            <template #body-cell-sl="props">
              <q-td :props="props" class="viewer-page__sl-cell">
                {{ props.row.sl }}
              </q-td>
            </template>

            <template #body-cell-image="props">
              <q-td :props="props">
                <div class="viewer-page__image-cell">
                  <q-img
                    v-if="props.row.imageUrl"
                    :src="props.row.imageUrl"
                    fit="cover"
                    class="viewer-page__image"
                  />
                  <div v-else class="viewer-page__image viewer-page__image--placeholder">
                    No image
                  </div>
                </div>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td :props="props" class="viewer-page__link-cell viewer-page__tone-indigo">
                <a
                  :href="props.row.websiteUrl"
                  :title="props.row.websiteUrl"
                  class="viewer-page__link"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="viewer-page__name-cell">
                <span class="viewer-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

          </q-table>
        </q-card>
      </section>

      <q-card v-else flat bordered>
        <q-card-section class="text-grey-7">No items available for this file.</q-card-section>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute, useRouter } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { buildAdminReviewRows } from 'src/modules/costingFile/composables/useCostingFileDetailRows'

const route = useRoute()
const router = useRouter()
const costingFileStore = useCostingFileStore()
const { selectedItem: selectedFile, costingFileItems } = storeToRefs(costingFileStore)

const formatStatusLabel = (status: string) =>
  status
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())

const statusChipColor = (status: string) => {
  if (status === 'draft') return 'grey-7'
  if (status === 'customer_submitted') return 'indigo'
  if (status === 'in_review') return 'amber-8'
  if (status === 'offered') return 'positive'
  if (status === 'completed') return 'primary'
  return 'secondary'
}

const viewerReviewRows = computed(() =>
  buildAdminReviewRows(costingFileItems.value, {
    cargoRate1Kg: selectedFile.value?.cargo_rate_1kg ?? null,
    cargoRate2Kg: selectedFile.value?.cargo_rate_2kg ?? null,
    conversionRate: selectedFile.value?.conversion_rate ?? null,
    adminProfitRate: selectedFile.value?.admin_profit_rate ?? null,
  }),
)

const viewerReviewColumns = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'left' as const,
    style: 'width: 48px; min-width: 48px;',
    headerStyle: 'width: 48px; min-width: 48px;',
    classes: 'viewer-page__sticky-col viewer-page__sticky-col--sl',
    headerClasses: 'viewer-page__sticky-col viewer-page__sticky-col--sl',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'imageUrl',
    align: 'left' as const,
    style: 'width: 108px; min-width: 108px;',
    headerStyle: 'width: 108px; min-width: 108px;',
    classes: 'viewer-page__sticky-col viewer-page__sticky-col--image',
    headerClasses: 'viewer-page__sticky-col viewer-page__sticky-col--image',
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left' as const,
    style: 'width: 280px; min-width: 280px; max-width: 280px;',
    headerStyle: 'width: 280px; min-width: 280px; max-width: 280px;',
    classes: 'viewer-page__sticky-col viewer-page__sticky-col--name',
    headerClasses: 'viewer-page__sticky-col viewer-page__sticky-col--name',
  },
  { name: 'itemType', label: 'Type', field: 'itemType', align: 'left' as const, style: 'width: 110px; min-width: 110px;', headerStyle: 'width: 110px; min-width: 110px;' },
  { name: 'size', label: 'Size', field: 'size', align: 'left' as const, style: 'width: 96px; min-width: 96px;', headerStyle: 'width: 96px; min-width: 96px;' },
  { name: 'color', label: 'Color', field: 'color', align: 'left' as const, style: 'width: 96px; min-width: 96px;', headerStyle: 'width: 96px; min-width: 96px;' },
  { name: 'extraInformation1', label: 'Extra info 1', field: 'extraInformation1', align: 'left' as const, style: 'width: 180px; min-width: 180px;', headerStyle: 'width: 180px; min-width: 180px;' },
  { name: 'extraInformation2', label: 'Extra info 2', field: 'extraInformation2', align: 'left' as const, style: 'width: 180px; min-width: 180px;', headerStyle: 'width: 180px; min-width: 180px;' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const, style: 'width: 56px; min-width: 56px;', headerStyle: 'width: 56px; min-width: 56px;' },
  {
    name: 'websiteUrl',
    label: 'Web URL',
    field: 'websiteUrl',
    align: 'left' as const,
    style: 'width: 144px; min-width: 144px; max-width: 144px;',
    headerStyle: 'width: 144px; min-width: 144px; max-width: 144px;',
  },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const, style: 'width: 60px; min-width: 60px;', headerStyle: 'width: 60px; min-width: 60px; white-space: normal; line-height: 1.15;' },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const, style: 'width: 60px; min-width: 60px;', headerStyle: 'width: 60px; min-width: 60px; white-space: normal; line-height: 1.15;' },
  { name: 'totalWeight', label: 'Total wt', field: 'totalWeight', align: 'left' as const, style: 'width: 60px; min-width: 60px;', headerStyle: 'width: 60px; min-width: 60px; white-space: normal; line-height: 1.15;' },
  {
    name: 'priceInWebGbp',
    label: 'Web price (GBP)',
    field: 'priceInWebGbp',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'viewer-page__tone-indigo',
    headerClasses: 'viewer-page__tone-indigo',
  },
  {
    name: 'deliveryPriceGbp',
    label: 'Delivery price (GBP)',
    field: 'deliveryPriceGbp',
    align: 'left' as const,
    style: 'width: 92px; min-width: 92px;',
    headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;',
    classes: 'viewer-page__tone-amber',
    headerClasses: 'viewer-page__tone-amber',
  },
  {
    name: 'purchasePriceGbp',
    label: 'Purchase price (GBP)',
    field: 'purchasePriceGbp',
    align: 'left' as const,
    style: 'width: 92px; min-width: 92px;',
    headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;',
    classes: 'viewer-page__tone-indigo',
    headerClasses: 'viewer-page__tone-indigo',
  },
  {
    name: 'cargoRateGbp',
    label: 'Cargo per KG (GBP)',
    field: 'cargoRateGbp',
    align: 'left' as const,
    style: 'width: 92px; min-width: 92px;',
    headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;',
    classes: 'viewer-page__tone-emerald',
    headerClasses: 'viewer-page__tone-emerald',
  },
  {
    name: 'costingPriceGbp',
    label: 'Cost (GBP) per unit',
    field: 'costingPriceGbp',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'viewer-page__tone-indigo',
    headerClasses: 'viewer-page__tone-indigo',
  },
  {
    name: 'auxiliaryPriceGbp',
    label: 'Aux price (GBP)',
    field: 'auxiliaryPriceGbp',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'viewer-page__tone-amber',
    headerClasses: 'viewer-page__tone-amber',
  },
]

const loadFile = async () => {
  const fileId = Number(route.params.id)

  if (!Number.isFinite(fileId) || fileId <= 0) {
    await router.replace({ name: 'viewer-costing-file-page' })
    return
  }

  const result = await costingFileStore.fetchCostingFileById(fileId)

  if (!result.success || !result.data) {
    await router.replace({ name: 'viewer-costing-file-page' })
    return
  }

  if (result.data.status === 'completed') {
    await costingFileStore.fetchCostingFileItems(fileId)
  } else {
    costingFileStore.costingFileItems = []
  }
}

onMounted(async () => {
  await loadFile()
})
</script>

<style scoped>
.viewer-page {
  display: grid;
  gap: 1rem;
}

.viewer-page__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.viewer-page__table-section {
  display: grid;
  gap: 0.75rem;
}

.viewer-page__pricing-card {
  overflow: hidden;
}

.viewer-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

.viewer-page__table :deep(.q-table th),
.viewer-page__table :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.viewer-page__table :deep(.viewer-page__sticky-col) {
  position: sticky;
  background: var(--bw-theme-surface, #fff);
}

.viewer-page__table :deep(td.viewer-page__sticky-col) {
  z-index: 2;
}

.viewer-page__table :deep(th.viewer-page__sticky-col) {
  z-index: 3;
}

.viewer-page__table :deep(.viewer-page__sticky-col--sl) {
  left: 0;
}

.viewer-page__table :deep(.viewer-page__sticky-col--image) {
  left: 48px;
}

.viewer-page__table :deep(.viewer-page__sticky-col--name) {
  left: 156px;
}

.viewer-page :deep(.viewer-page__tone-indigo) {
  background: #eceffd;
  color: #34408f;
}

.viewer-page :deep(.viewer-page__tone-amber) {
  background: #fbefc4;
  color: #7a5313;
}

.viewer-page :deep(.viewer-page__tone-emerald) {
  background: #ddf4e7;
  color: #1f6a43;
}

.viewer-page :deep(th.viewer-page__tone-indigo),
.viewer-page :deep(th.viewer-page__tone-amber),
.viewer-page :deep(th.viewer-page__tone-emerald) {
  font-weight: 700;
}

.viewer-page__image-cell {
  display: flex;
  justify-content: center;
}

.viewer-page__image {
  height: 72px;
  width: 72px;
  border-radius: 12px;
}

.viewer-page__image--placeholder {
  display: grid;
  place-items: center;
  background: rgba(0, 0, 0, 0.04);
  color: var(--bw-theme-muted);
  font-size: 0.75rem;
}

.viewer-page__link {
  color: var(--bw-theme-primary);
  text-decoration: underline;
  overflow-wrap: anywhere;
  word-break: break-word;
  white-space: normal;
  display: inline-block;
}

.viewer-page__name-text {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
