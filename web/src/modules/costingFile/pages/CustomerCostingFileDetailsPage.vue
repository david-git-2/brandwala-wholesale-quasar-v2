<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section>
        <h1 class="text-h5 q-my-none">Costing file details</h1>
      </section>

      <div v-if="selectedFile">
        <div class="costing-page__summary">
          <p class="costing-page__summary-text q-my-none text-body2 text-grey-7">
            {{ selectedFile.name }} | {{ selectedFile.market || 'Not set' }}
          </p>
          <q-chip
            dense
            square
            color="primary"
            text-color="white"
            class="costing-page__status-chip"
          >
            {{ selectedFile.status }}
          </q-chip>
        </div>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__input-section">


          <div class="costing-page__sticky-form">
            <div class="costing-page__request-grid">
              <q-input v-model="requestForm.websiteUrl" label="Web link" outlined dense color="primary" />
              <q-input v-model.number="requestForm.quantity" label="Qty" type="number" outlined dense color="primary" />
              <q-btn
                color="primary"
                unelevated
                :label="editingItemId ? 'Update' : 'Save'"
                :loading="submittingRequest"
                :disable="!canCreateRequest"
                @click="handleSubmitRequest"
              />
              <q-btn
                v-if="editingItemId"
                flat
                color="grey-7"
                label="Cancel"
                @click="resetRequestForm"
              />
            </div>
          </div>
        </div>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__table-section">
          <q-table
            v-if="productRows.length"
            flat
            bordered
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="costing-page__table"
          >
            <template #body-cell-sl="props">
              <q-td :props="props" class="costing-page__sl-cell">
                {{ props.row.sl }}
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="costing-page__name-cell">
                <span class="costing-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td :props="props" class="costing-page__url-cell">
                <a
                  class="costing-page__url-text"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" class="costing-page__actions-cell">
                <q-btn flat dense color="primary" icon="edit" class="costing-page__icon-btn" @click="handleEdit(props.row.id)" />
                <q-btn
                  flat
                  dense
                  color="negative"
                  icon="delete"
                  class="costing-page__icon-btn"
                  :loading="deletingItemId === props.row.id"
                  @click="handleDelete(props.row.id)"
                />
              </q-td>
            </template>
          </q-table>
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
        </div>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__submit-actions">
          <q-btn
            v-if="productRows.length"
            color="primary"
            unelevated
            label="Submit order"
            class="q-mt-md"
            :loading="submittingOrder"
            @click="submitDialog = true"
          />
        </div>

        <div
          v-else-if="selectedFile.status === 'customer_submitted' || selectedFile.status === 'in_review'"
          class="costing-page__customer-submitted-section"
        >
          <div class="costing-page__table-section">
            <q-table
              v-if="productRows.length"
              flat
              bordered
              dense
              row-key="id"
              :rows="productRows"
              :columns="visibleColumns"
              :pagination="{ rowsPerPage: 0 }"
              hide-bottom
              class="costing-page__table"
            >
              <template #body-cell-sl="props">
                <q-td :props="props" class="costing-page__sl-cell">
                  {{ props.row.sl }}
                </q-td>
              </template>

              <template #body-cell-name="props">
                <q-td :props="props" class="costing-page__name-cell">
                  <span class="costing-page__name-text" :title="props.row.name">
                    {{ props.row.name }}
                  </span>
                </q-td>
              </template>

              <template #body-cell-websiteUrl="props">
                <q-td :props="props" class="costing-page__url-cell">
                  <a
                    class="costing-page__url-text"
                    :href="toExternalUrl(props.row.websiteUrl)"
                    :title="props.row.websiteUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {{ props.row.websiteUrl }}
                  </a>
                </q-td>
              </template>
            </q-table>
            <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
          </div>
        </div>

        <div v-else-if="selectedFile.status === 'offered'" class="costing-page__table-section">
          <div class="costing-page__offered-controls">
            <q-input
              v-model.number="sharedProfitRate"
              type="number"
              dense
              outlined
              min="0"
              step="0.01"
              label="Buyer profit %"
              class="costing-page__shared-profit-input"
            />
            <q-btn
              unelevated
              color="primary"
              label="Save buyer profit"
              :loading="savingProfitAll"
              :disable="savingProfitAll"
              @click="handleSaveSharedProfitRate"
            />
            <q-btn
              outline
              color="primary"
              label="Preview"
              @click="openPreview"
            />
          </div>

          <q-table
            v-if="productRows.length"
            flat
            bordered
            dense
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="costing-page__table costing-page__table--offered"
          >
            <template #body-cell-sl="props">
              <q-td :props="props" class="costing-page__sl-cell">
                {{ props.row.sl }}
              </q-td>
            </template>

            <template #body-cell-image="props">
              <q-td :props="props" class="costing-page__image-table-cell">
                <q-img
                  v-if="props.row.imageUrl"
                  :src="props.row.imageUrl"
                  fit="cover"
                  class="costing-page__image"
                />
                <div v-else class="costing-page__image costing-page__image--placeholder">
                  No image
                </div>
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="costing-page__name-cell">
                <span class="costing-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td :props="props" class="costing-page__url-cell">
                <a
                  class="costing-page__url-text"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
              </q-td>
            </template>

            <template #body-cell-quantity="props">
              <q-td :props="props" class="costing-page__numeric-cell">
                {{ props.row.quantity }}
              </q-td>
            </template>

            <template #body-cell-offerPriceBdt="props">
              <q-td :props="props" class="costing-page__numeric-cell">
                {{ props.row.offerPriceBdt }}
              </q-td>
            </template>

            <template #body-cell-buyerSellingPriceBdt="props">
              <q-td :props="props" class="costing-page__numeric-cell costing-page__tone-indigo">
                {{ props.row.buyerSellingPriceBdt }}
              </q-td>
            </template>

            <template #body-cell-customerProfitAmountBdt="props">
              <q-td :props="props" class="costing-page__numeric-cell costing-page__tone-amber">
                {{ props.row.customerProfitAmountBdt }}
              </q-td>
            </template>

            <template #body-cell-customerProfitRateDisplay="props">
              <q-td :props="props" class="costing-page__numeric-cell">
                {{ props.row.customerProfitRateDisplay }}
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" class="costing-page__actions-cell">
                <q-btn
                  unelevated
                  size="sm"
                  dense
                  color="positive"
                  label="Accept"
                  class="costing-page__decision-btn costing-page__decision-btn--accept"
                  :loading="savingDecisionItemId === props.row.id && savingDecisionStatus === 'accepted'"
                  :disable="props.row.status === 'accepted' || savingDecisionItemId === props.row.id"
                  @click="handleDecision(props.row.id, 'accepted')"
                />
                <q-btn
                  unelevated
                  size="sm"
                  dense
                  color="negative"
                  label="Reject"
                  class="costing-page__decision-btn costing-page__decision-btn--reject"
                  :loading="savingDecisionItemId === props.row.id && savingDecisionStatus === 'rejected'"
                  :disable="props.row.status === 'rejected' || savingDecisionItemId === props.row.id"
                  @click="handleDecision(props.row.id, 'rejected')"
                />
              </q-td>
            </template>
          </q-table>
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
        </div>

        <div v-else class="costing-page__table-section">
          <q-table
            v-if="productRows.length"
            flat
            bordered
            dense
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="costing-page__table"
          >
            <template #body-cell-sl="props">
              <q-td :props="props" class="costing-page__sl-cell">
                {{ props.row.sl }}
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="costing-page__name-cell">
                <span class="costing-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td :props="props" class="costing-page__url-cell">
                <a
                  class="costing-page__url-text"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
              </q-td>
            </template>
          </q-table>
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
        </div>
      </div>

      <q-dialog v-model="submitDialog" persistent>
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Submit order</div>
          </q-card-section>

          <q-card-section>
            <div class="text-body2">
              Submit this costing file for review?
            </div>
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="submitDialog = false" />
            <q-btn
              color="primary"
              unelevated
              label="Confirm"
              :loading="submittingOrder"
              @click="handleSubmitOrder"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute, useRouter } from 'vue-router'

import { buildCustomerProductRows } from 'src/modules/costingFile/composables/useCostingFileDetailRows'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItemStatus } from 'src/modules/costingFile/types'
import { showSuccessNotification } from 'src/utils/appFeedback'

const route = useRoute()
const router = useRouter()
const costingFileStore = useCostingFileStore()
const {
  selectedItem: selectedFile,
  costingFileItems: itemForms,
} = storeToRefs(costingFileStore)

const submittingRequest = ref(false)
const deletingItemId = ref<number | null>(null)
const editingItemId = ref<number | null>(null)
const submitDialog = ref(false)
const submittingOrder = ref(false)
const savingDecisionItemId = ref<number | null>(null)
const savingDecisionStatus = ref<CostingFileItemStatus | null>(null)
const savingProfitAll = ref(false)
const sharedProfitRate = ref<number | null>(null)

const requestForm = reactive({
  websiteUrl: '',
  quantity: 1,
})

const fileForm = reactive({
  name: '',
  market: '',
})

const canCreateRequest = computed(
  () => requestForm.websiteUrl.trim().length > 0 && Number(requestForm.quantity) > 0,
)


const productRows = computed(() =>
  buildCustomerProductRows(itemForms.value, sharedProfitRate.value),
)

const allColumns = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center' as const,
    style: 'width: 48px; min-width: 48px;',
    headerStyle: 'width: 48px; min-width: 48px;',
  },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'center' as const },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'center' as const,
    style: 'width: 320px; min-width: 320px;',
    headerStyle: 'width: 320px; min-width: 320px; white-space: normal; line-height: 1.15;',
  },
  {
    name: 'websiteUrl',
    label: 'Web link',
    field: 'websiteUrl',
    align: 'center' as const,
    style: 'width: 144px; min-width: 144px; max-width: 144px;',
    headerStyle: 'width: 144px; min-width: 144px; max-width: 144px;',
  },
  {
    name: 'quantity',
    label: 'Qty',
    field: 'quantity',
    align: 'center' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px; white-space: normal; line-height: 1.15;',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' as const },
  {
    name: 'offerPriceBdt',
    label: 'Offer price (BDT)',
    field: 'offerPriceBdt',
    align: 'center' as const,
    style: 'width: 98px; min-width: 98px;',
    headerStyle: 'width: 98px; min-width: 98px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-emerald',
    headerClasses: 'costing-page__tone-emerald',
  },
  {
    name: 'buyerSellingPriceBdt',
    label: 'Buyer selling (BDT)',
    field: 'buyerSellingPriceBdt',
    align: 'center' as const,
    style: 'width: 104px; min-width: 104px;',
    headerStyle: 'width: 104px; min-width: 104px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-orange',
    headerClasses: 'costing-page__tone-orange',
  },
  {
    name: 'customerProfitAmountBdt',
    label: 'Profit per item (BDT)',
    field: 'customerProfitAmountBdt',
    align: 'center' as const,
    style: 'width: 104px; min-width: 104px;',
    headerStyle: 'width: 104px; min-width: 104px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-amber',
    headerClasses: 'costing-page__tone-amber',
  },
  {
    name: 'customerProfitRateDisplay',
    label: 'Profit rate',
    field: 'customerProfitRateDisplay',
    align: 'center' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
  },
  { name: 'actions', label: '', field: 'actions', align: 'center' as const },
]

const visibleColumns = computed(() => {
  if (!selectedFile.value) {
    return []
  }

  if (selectedFile.value.status === 'draft') {
    return allColumns.filter((column) => ['sl', 'websiteUrl', 'quantity', 'actions'].includes(column.name))
  }

  if (
    selectedFile.value.status === 'customer_submitted' ||
    selectedFile.value.status === 'in_review'
  ) {
    return allColumns.filter((column) => ['sl', 'websiteUrl', 'quantity'].includes(column.name))
  }

  if (selectedFile.value.status === 'offered') {
    return allColumns.filter((column) =>
      [
        'sl',
        'image',
        'name',
        'websiteUrl',
        'quantity',
        'offerPriceBdt',
        'buyerSellingPriceBdt',
        'customerProfitAmountBdt',
        'customerProfitRateDisplay',
        'status',
        'actions',
      ].includes(column.name),
    )
  }

  return allColumns.filter((column) => ['sl', 'websiteUrl', 'quantity', 'name', 'status', 'offerPriceBdt'].includes(column.name))
})

const toExternalUrl = (value: string) => (/^https?:\/\//i.test(value) ? value : `https://${value}`)

const resetRequestForm = () => {
  requestForm.websiteUrl = ''
  requestForm.quantity = 1
  editingItemId.value = null
}

const syncFileForm = () => {
  fileForm.name = selectedFile.value?.name ?? ''
  fileForm.market = selectedFile.value?.market ?? ''
}

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!fileId) return
  await costingFileStore.fetchCostingFileWithItemsForCustomer(fileId)
}

const handleSubmitRequest = async () => {
  if (!selectedFile.value || !canCreateRequest.value) return

  submittingRequest.value = true
  try {
    const result = editingItemId.value
      ? await costingFileStore.updateCostingFileItem({
          id: editingItemId.value,
          websiteUrl: requestForm.websiteUrl.trim(),
          quantity: Math.max(1, Number(requestForm.quantity || 1)),
        })
      : await costingFileStore.createCostingFileItemRequest({
          costingFileId: selectedFile.value.id,
          websiteUrl: requestForm.websiteUrl.trim(),
          quantity: Math.max(1, Number(requestForm.quantity || 1)),
        })

    if (!result.success) {
      return
    }

    showSuccessNotification(editingItemId.value ? 'Item updated.' : 'Item saved.')
    resetRequestForm()
  } finally {
    submittingRequest.value = false
  }
}

const handleEdit = (id: number) => {
  const item = itemForms.value.find((entry) => entry.id === id)

  if (!item) {
    return
  }

  editingItemId.value = id
  requestForm.websiteUrl = item.website_url
  requestForm.quantity = item.quantity
}

const handleDelete = async (id: number) => {
  deletingItemId.value = id
  try {
    const result = await costingFileStore.deleteCostingFileItem({ id })

    if (!result.success) {
      return
    }

    if (editingItemId.value === id) {
      resetRequestForm()
    }
  } finally {
    deletingItemId.value = null
  }
}


const handleDecision = async (id: number, status: CostingFileItemStatus) => {
  savingDecisionItemId.value = id
  savingDecisionStatus.value = status
  try {
    const result = await costingFileStore.updateCostingFileItemStatus({ id, status })

    if (!result.success) {
      return
    }

    showSuccessNotification(`Item ${status}.`)
  } finally {
    savingDecisionItemId.value = null
    savingDecisionStatus.value = null
  }
}

const handleSaveSharedProfitRate = async () => {
  if (!itemForms.value.length || !selectedFile.value) return

  savingProfitAll.value = true
  try {
    const normalized =
      sharedProfitRate.value == null || Number.isNaN(Number(sharedProfitRate.value))
        ? null
        : Number(sharedProfitRate.value)

    const result = await costingFileStore.updateCostingFileItemsCustomerProfit({
      costingFileId: selectedFile.value.id,
      customerProfitRate: normalized,
    })

    if (!result.success) {
      return
    }
  } finally {
    savingProfitAll.value = false
  }
}

const handleSubmitOrder = async () => {
  if (!selectedFile.value) {
    return
  }

  submittingOrder.value = true
  try {
    const result = await costingFileStore.updateCostingFileStatus({
      id: selectedFile.value.id,
      status: 'customer_submitted',
    })

    if (!result.success) {
      return
    }

    submitDialog.value = false
    showSuccessNotification('Order submitted.')
  } finally {
    submittingOrder.value = false
  }
}

const openPreview = () => {
  if (!selectedFile.value || selectedFile.value.status !== 'offered') {
    return
  }

  const targetRoute = router.resolve({
    name: 'customer-costing-file-preview-page',
    params: { id: String(selectedFile.value.id) },
  })

  window.open(targetRoute.href, '_blank', 'noopener,noreferrer')
}

onMounted(async () => {
  await loadFile()
})

watch(selectedFile, () => {
  syncFileForm()
}, { immediate: true })

watch(
  itemForms,
  (items) => {
    sharedProfitRate.value = items[0]?.customer_profit_rate ?? null
  },
  { immediate: true, deep: true },
)
</script>

<style scoped>
.costing-page {
  min-width: 0;
}

.costing-page > * {
  min-width: 0;
}

.costing-page__input-section,
.costing-page__table-section {
  display: block;
  min-width: 0;
}

.costing-page__summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.costing-page__summary-text {
  min-width: 0;
  flex: 1 1 auto;
}

.costing-page__status-chip {
  flex: 0 0 auto;
  text-transform: capitalize;
}

.costing-page__sticky-form {
  position: sticky;
  top: 0;
  z-index: 10;
  padding: 0.75rem 0;
}

.costing-page__file-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto;
  gap: 1rem;
  align-items: start;
  margin-bottom: 0.75rem;
}

.costing-page__request-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
  align-items: start;
}

.costing-page :deep(.q-btn) {
  border-radius: 8px;
}

.costing-page__table :deep(.q-table th),
.costing-page__table :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.costing-page__table :deep(.q-table th) {
  white-space: normal;
  line-height: 1.15;
}

.costing-page__sl-cell {
  width: 3ch;
  max-width: 3ch;
  white-space: nowrap;
}

.costing-page__name-cell {
  width: 320px;
  min-width: 320px;
  max-width: 320px;
}

.costing-page__name-text {
  display: inline-block;
  max-width: 320px;
  overflow: visible;
  text-overflow: clip;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.3;
}

.costing-page__table--offered :deep(.costing-page__tone-emerald) {
  background: #ddf4e7;
  color: #1f6a43;
}

.costing-page__table--offered :deep(.costing-page__tone-orange) {
  background: #fdeccd;
  color: #7a5313;
}

.costing-page__table--offered :deep(th.costing-page__tone-emerald) {
  font-weight: 700;
}

.costing-page__table--offered :deep(th.costing-page__tone-orange) {
  font-weight: 700;
}

.costing-page__actions-cell {
  white-space: nowrap;
}

.costing-page__image-table-cell {
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

.costing-page__numeric-cell {
  font-weight: 700;
  font-size: 0.95rem;
  line-height: 1.35;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.costing-page__url-cell {
  width: 144px;
  max-width: 144px;
}

.costing-page__url-text {
  display: inline-block;
  max-width: 144px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
  color: var(--bw-theme-primary);
  text-decoration: none;
}

.costing-page__icon-btn {
  border-radius: 8px;
}

.costing-page__decision-btn {
  border-radius: 8px;
  min-width: 66px;
}

.costing-page__decision-btn--accept {
  background: #ddf4e7 !important;
  color: #1f6a43 !important;
}

.costing-page__decision-btn--reject {
  background: #fbe3e6 !important;
  color: #a33b49 !important;
}

.costing-page__offered-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  justify-content: flex-end;
  margin-bottom: 0.75rem;
}

.costing-page__shared-profit-input {
  width: 160px;
}

.costing-page__submit-actions {
  display: flex;
  justify-content: flex-end;
}

.costing-page__dialog {
  min-width: min(420px, 92vw);
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

@media (max-width: 900px) {
  .costing-page__file-grid {
    grid-template-columns: 1fr 1fr;
  }

  .costing-page__file-grid > :nth-child(3) {
    grid-column: 1 / -1;
  }

  .costing-page__request-grid {
    grid-template-columns: minmax(0, 1fr) minmax(110px, 140px);
  }

  .costing-page__request-grid > :nth-child(3),
  .costing-page__request-grid > :nth-child(4) {
    grid-column: span 1;
  }
}

@media (max-width: 599px) {
  .costing-page__summary {
    flex-direction: column;
    align-items: flex-start;
  }

  .costing-page__file-grid,
  .costing-page__request-grid {
    grid-template-columns: 1fr;
  }

  .costing-page {
    font-size: 0.92rem;
  }

  .costing-page :deep(.q-field__label),
  .costing-page :deep(.q-field__native),
  .costing-page :deep(.q-btn__content),
  .costing-page :deep(.q-table th),
  .costing-page :deep(.q-table td) {
    font-size: 0.82rem;
  }

  .costing-page :deep(.q-icon) {
    font-size: 1rem;
  }

  .costing-page__image-table-cell {
    width: 72px;
  }

  .costing-page__image {
    width: 72px;
    height: 72px;
  }

  .costing-page__icon-btn {
    min-height: 28px;
    min-width: 28px;
    padding: 0.2rem;
  }
}
</style>
