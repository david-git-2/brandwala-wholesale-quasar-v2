<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack costing-page">
      <section class="costing-page__header">
        <div class="costing-page__heading">
          <div class="text-overline">Costing File</div>
          <h1 class="text-h5 q-my-none">Costing file details</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>

        <div class="costing-page__toolbar">
          <q-chip
            v-if="selectedFile"
            dense
            square
            :color="statusChipColor(selectedFile.status)"
            text-color="white"
          >
            {{ selectedFile.status }}
          </q-chip>
          <q-btn
            outline
            color="primary"
            label="Add item"
            :disable="!canEditFile"
            @click="addItemDialogOpen = true"
          />
          <q-btn
            color="primary"
            unelevated
            label="Send to review"
            :disable="!canSendToReview"
            :loading="savingStatus"
            @click="handleSendToReview"
          />
        </div>
      </section>

      <q-card v-if="loadingPage || !selectedFile" flat bordered>
        <q-card-section class="text-grey-7">
          Loading costing file details...
        </q-card-section>
      </q-card>

      <template v-else>


        <section class="costing-page__body">
          <q-table
            v-if="productRows.length"
            flat
            bordered
            row-key="id"
            :rows="productRows"
            :columns="productColumns"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="costing-page__table"
          >
            <template #body-cell-sl="props">
              <q-td :props="props" class="costing-page__sl-cell">
                {{ props.row.sl }}
              </q-td>
            </template>

            <template #body-cell-image="props">
              <q-td :props="props">
                <div class="costing-page__image-cell">
                  <q-img
                    v-if="props.row.imageUrl"
                    :src="toExternalUrl(props.row.imageUrl)"
                    fit="cover"
                    class="costing-page__image"
                  />
                  <div v-else class="costing-page__image costing-page__image--placeholder">
                    No image
                  </div>
                </div>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td :props="props" class="costing-page__link-cell">
                <a
                  class="costing-page__link"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="costing-page__name-cell">
                <span class="costing-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

            <template #body-cell-priceInWebGbp="props">
              <q-td :props="props" class="costing-page__numeric-cell">
                {{ props.row.priceInWebGbp }}
              </q-td>
            </template>

            <template #body-cell-productWeight="props">
              <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
                {{ props.row.productWeight }}
              </q-td>
            </template>

            <template #body-cell-packageWeight="props">
              <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
                {{ props.row.packageWeight }}
              </q-td>
            </template>

            <template #body-cell-quantity="props">
              <q-td :props="props" class="costing-page__numeric-cell">
                {{ props.row.quantity }}
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" auto-width>
                <q-btn
                  flat
                  dense
                  round
                  color="primary"
                  icon="edit"
                  :disable="!canEditFile"
                  @click="openEditDialog(props.row.id)"
                />
              </q-td>
            </template>
          </q-table>

          <q-card v-else flat bordered>
            <q-card-section class="text-center">
              <div class="text-subtitle1">No items yet</div>
              <div class="text-body2 text-grey-7 q-mt-sm">
                Add the first item for this costing file.
              </div>
            </q-card-section>
          </q-card>
        </section>
      </template>

      <AddCostingFileItemDialog
        v-model="addItemDialogOpen"
        :loading="creatingItem"
        @save="handleCreateItem"
      />

      <StaffCostingFileItemEditDialog
        v-model="editDialogOpen"
        :item="editingItem"
        :loading="savingItemId === editingItem?.id"
        @save="handleSaveItem"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import AddCostingFileItemDialog from 'src/modules/costingFile/components/AddCostingFileItemDialog.vue'
import StaffCostingFileItemEditDialog from 'src/modules/costingFile/components/StaffCostingFileItemEditDialog.vue'
import { buildAdminProductRows } from 'src/modules/costingFile/composables/useCostingFileDetailRows'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileDetails, CostingFileItem, CostingFileStatus } from 'src/modules/costingFile/types'

const route = useRoute()
const router = useRouter()
const costingFileStore = useCostingFileStore()
const selectedFile = computed<CostingFileDetails | null>(() => costingFileStore.selectedItem)
const costingFileItems = computed<CostingFileItem[]>(() => costingFileStore.costingFileItems)
const detailsLoading = computed(() => costingFileStore.detailsLoading)
const itemLoading = computed(() => costingFileStore.itemLoading)

const addItemDialogOpen = ref(false)
const editDialogOpen = ref(false)
const creatingItem = ref(false)
const savingItemId = ref<number | null>(null)
const savingStatus = ref(false)
const editingItemId = ref<number | null>(null)

const editableStatuses: CostingFileStatus[] = ['customer_submitted']

const productRows = computed(() => buildAdminProductRows(costingFileItems.value))
const editingItem = computed<CostingFileItem | null>(
  () => costingFileItems.value.find((item) => item.id === editingItemId.value) ?? null,
)

const productColumns = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'left' as const,
    style: 'width: 48px; min-width: 48px;',
    headerStyle: 'width: 48px; min-width: 48px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--sl',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--sl',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'imageUrl',
    align: 'left' as const,
    style: 'width: 108px; min-width: 108px;',
    headerStyle: 'width: 108px; min-width: 108px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--image',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--image',
  },

  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left' as const,
    style: 'min-width: 280px;',
    headerStyle: 'min-width: 280px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--name',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--name',
  },
  {
    name: 'quantity',
    label: 'Qty',
    field: 'quantity',
    align: 'left' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px;',
  },
  { name: 'websiteUrl', label: 'Web link', field: 'websiteUrl', align: 'left' as const, style: 'width: 220px; min-width: 220px;', headerStyle: 'width: 220px; min-width: 220px;' },
  { name: 'priceInWebGbp', label: 'Web price (GBP)', field: 'priceInWebGbp', align: 'left' as const, style: 'width: 110px; min-width: 110px;', headerStyle: 'width: 110px; min-width: 110px;' },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
]

const subtitle = computed(() =>
  selectedFile.value
    ? `Staff can add items and send this file to review.`
    : 'Loading costing file details.',
)

const loadingPage = computed(() => detailsLoading.value || itemLoading.value)
const canEditFile = computed(() =>
  Boolean(selectedFile.value && editableStatuses.includes(selectedFile.value.status)),
)
const canSendToReview = computed(
  () => Boolean(selectedFile.value && editableStatuses.includes(selectedFile.value.status)),
)

const statusChipColor = (status: CostingFileStatus) => {
  if (status === 'draft') return 'grey-7'
  if (status === 'customer_submitted') return 'indigo'
  if (status === 'in_review') return 'amber-8'
  if (status === 'offered') return 'positive'
  return 'primary'
}

const toExternalUrl = (value: string) =>
  /^https?:\/\//i.test(value) ? value : `https://${value}`

const loadFile = async () => {
  const fileId = Number(route.params.id)

  if (!Number.isFinite(fileId) || fileId <= 0) {
    await router.replace({ name: 'staff-costing-file-page' })
    return
  }

  costingFileStore.clearSelectedItem()

  const result = await costingFileStore.fetchCostingFileWithItems(fileId)

  if (!result.success || !result.data) {
    await router.replace({ name: 'staff-costing-file-page' })
    return
  }

  if (!editableStatuses.includes(result.data.status)) {
    await router.replace({ name: 'staff-costing-file-page' })
  }
}

const openEditDialog = (itemId: number) => {
  editingItemId.value = itemId
  editDialogOpen.value = true
}

const handleCreateItem = async (payload: {
  websiteUrl: string
  quantity: number
  name: string
  imageUrl: string
  productWeight: number
  packageWeight: number
  priceInWebGbp: number
  deliveryPriceGbp: number
}) => {
  if (!selectedFile.value || !canEditFile.value) {
    return
  }

  creatingItem.value = true
  try {
    const result = await costingFileStore.createCostingFileItem({
      costingFileId: selectedFile.value.id,
      websiteUrl: payload.websiteUrl,
      quantity: payload.quantity,
      name: payload.name,
      imageUrl: payload.imageUrl,
      productWeight: payload.productWeight,
      packageWeight: payload.packageWeight,
      priceInWebGbp: payload.priceInWebGbp,
      deliveryPriceGbp: payload.deliveryPriceGbp,
      status: 'pending',
    })

    if (result.success) {
      addItemDialogOpen.value = false
    }
  } finally {
    creatingItem.value = false
  }
}

const handleSaveItem = async (payload: {
  id: number
  name: string
  imageUrl: string
  productWeight: number
  packageWeight: number
  priceInWebGbp: number
  deliveryPriceGbp: number
}) => {
  if (!selectedFile.value || !canEditFile.value) {
    return
  }

  savingItemId.value = payload.id
  try {
    const result = await costingFileStore.updateCostingFileItemEnrichment({
      id: payload.id,
      name: payload.name,
      imageUrl: payload.imageUrl,
      productWeight: payload.productWeight,
      packageWeight: payload.packageWeight,
      priceInWebGbp: payload.priceInWebGbp,
      deliveryPriceGbp: payload.deliveryPriceGbp,
    })

    if (result.success) {
      editDialogOpen.value = false
    }
  } finally {
    savingItemId.value = null
  }
}

const handleSendToReview = async () => {
  if (!selectedFile.value || !canSendToReview.value) {
    return
  }

  savingStatus.value = true
  try {
    const result = await costingFileStore.updateCostingFileStatus({
      id: selectedFile.value.id,
      status: 'in_review',
    })

    if (result.success) {
      await router.replace({ name: 'staff-costing-file-page' })
    }
  } finally {
    savingStatus.value = false
  }
}

watch(
  () => route.params.id,
  async () => {
    addItemDialogOpen.value = false
    editDialogOpen.value = false
    editingItemId.value = null
    await loadFile()
  },
  { immediate: true },
)

watch(editDialogOpen, (isOpen) => {
  if (!isOpen) {
    editingItemId.value = null
  }
})
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
}

.costing-page__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.costing-page__heading {
  min-width: 0;
  flex: 1 1 auto;
}

.costing-page__toolbar {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.75rem;
  align-items: center;
}

.costing-page__summary {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  align-items: center;
  padding: 0.75rem 1rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.72);
}

.costing-page__summary-main {
  min-width: 0;
}

.costing-page__body {
  min-width: 0;
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

.costing-page__table :deep(.q-table th),
.costing-page__table :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.costing-page__table :deep(.q-table th:nth-child(4)),
.costing-page__table :deep(.q-table td:nth-child(4)) {
  text-align: left;
}

.costing-page__table :deep(.q-table th:nth-child(5)),
.costing-page__table :deep(.q-table td:nth-child(5)) {
  text-align: left;
}

.costing-page__table :deep(.q-table th:last-child),
.costing-page__table :deep(.q-table td:last-child) {
  text-align: right;
}

.costing-page__table :deep(.costing-page__sticky-col) {
  position: sticky;
  background: var(--bw-theme-surface, #fff);
}

.costing-page__table :deep(td.costing-page__sticky-col) {
  z-index: 2;
}

.costing-page__table :deep(th.costing-page__sticky-col) {
  z-index: 3;
}

.costing-page__table :deep(.costing-page__sticky-col--sl) {
  left: 0;
}

.costing-page__table :deep(.costing-page__sticky-col--image) {
  left: 48px;
}

.costing-page__table :deep(.costing-page__sticky-col--name) {
  left: 156px;
}

.costing-page__sl-cell {
  width: 3ch;
  max-width: 3ch;
  white-space: nowrap;
}

.costing-page__image-cell {
  width: 96px;
}

.costing-page__image {
  width: 96px;
  height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-theme-surface);
}

.costing-page__image--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px dashed var(--bw-theme-border);
  color: var(--bw-theme-muted);
  font-size: 0.75rem;
  text-align: center;
  padding: 0.5rem;
}

.costing-page__link-cell {
  width: 144px;
  max-width: 144px;
}

.costing-page__link {
  display: inline-block;
  max-width: 144px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--bw-theme-primary);
  text-decoration: none;
}

.costing-page__name-cell {
  width: 280px;
  max-width: 280px;
}

.costing-page__name-text {
  display: inline-block;
  max-width: 280px;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.costing-page__weight-cell {
  width: 72px;
  max-width: 72px;
  white-space: nowrap;
}

.costing-page__numeric-cell {
  font-weight: 700;
  font-size: 0.95rem;
  line-height: 1.35;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

@media (max-width: 900px) {
  .costing-page__header {
    flex-direction: column;
  }

  .costing-page__toolbar {
    justify-content: flex-start;
  }
}

@media (max-width: 599px) {
  .costing-page__image-cell {
    width: 72px;
  }

  .costing-page__image {
    width: 72px;
    height: 72px;
  }
}
</style>
