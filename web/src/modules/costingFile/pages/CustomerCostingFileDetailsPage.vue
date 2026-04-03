<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section>
        <h1 class="text-h5 q-my-none">Costing file details</h1>
      </section>

      <div v-if="selectedFile">
        <div class="costing-page__summary">
          <p class="costing-page__summary-text q-my-none text-body2 text-grey-7">
            {{ selectedFile.name }} | {{ selectedFile.market }}
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
          <div class="costing-page__file-grid">
            <q-input v-model="fileForm.name" label="File name" outlined dense color="primary" />
            <q-input v-model="fileForm.market" label="Market" outlined dense color="primary" />
            <q-btn
              color="primary"
              unelevated
              label="Update file"
              :loading="savingFileDetails"
              :disable="!canSaveFileDetails"
              @click="handleSaveFileDetails"
            />
          </div>

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
            hide-bottom
            class="costing-page__table"
          >
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
              row-key="id"
              :rows="productRows"
              :columns="visibleColumns"
              hide-bottom
              class="costing-page__table"
            >
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
          </div>

          <q-table
            v-if="productRows.length"
            flat
            bordered
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            hide-bottom
            class="costing-page__table costing-page__table--offered"
          >
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
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            hide-bottom
            class="costing-page__table"
          >
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
import { useRoute } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItemStatus } from 'src/modules/costingFile/types'
import { calculateBuyerSellPrice } from 'src/modules/costingFile/utils/costingCalculations'
import { showSuccessNotification } from 'src/utils/appFeedback'

const route = useRoute()
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
const savingFileDetails = ref(false)
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

const canSaveFileDetails = computed(
  () =>
    Boolean(selectedFile.value) &&
    fileForm.name.trim().length > 0 &&
    fileForm.market.trim().length > 0 &&
    (
      fileForm.name.trim() !== (selectedFile.value?.name ?? '') ||
      fileForm.market.trim() !== (selectedFile.value?.market ?? '')
    ),
)

const productRows = computed(() =>
  itemForms.value.map((item, index) => {
    const offerPriceBdt = Number(item.offer_price_bdt ?? 0)
    const effectiveProfitRate = sharedProfitRate.value ?? item.customer_profit_rate
    const buyerSellingPriceBdt = calculateBuyerSellPrice(item.offer_price_bdt, effectiveProfitRate)
    const customerProfitAmountBdt = buyerSellingPriceBdt - offerPriceBdt
    const customerProfitRateDisplay =
      offerPriceBdt > 0 ? `${((customerProfitAmountBdt / offerPriceBdt) * 100).toFixed(2)}%` : '-'

    return {
      id: item.id,
      sl: index + 1,
      imageUrl: item.image_url,
      websiteUrl: item.website_url,
      quantity: item.quantity,
      name: item.name ?? '-',
      offerPriceBdt: formatBdt(item.offer_price_bdt),
      buyerSellingPriceBdt: formatBdt(buyerSellingPriceBdt),
      customerProfitAmountBdt: formatBdt(customerProfitAmountBdt),
      customerProfitRateDisplay,
      status: item.status,
    }
  }),
)

const allColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'websiteUrl', label: 'Web link', field: 'websiteUrl', align: 'left' as const },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  {
    name: 'offerPriceBdt',
    label: 'Offer price (BDT)',
    field: 'offerPriceBdt',
    align: 'left' as const,
    classes: 'costing-page__tone-emerald',
    headerClasses: 'costing-page__tone-emerald',
  },
  {
    name: 'buyerSellingPriceBdt',
    label: 'Buyer selling (BDT)',
    field: 'buyerSellingPriceBdt',
    align: 'left' as const,
    classes: 'costing-page__tone-indigo',
    headerClasses: 'costing-page__tone-indigo',
  },
  {
    name: 'customerProfitAmountBdt',
    label: 'Profit per item (BDT)',
    field: 'customerProfitAmountBdt',
    align: 'left' as const,
    classes: 'costing-page__tone-amber',
    headerClasses: 'costing-page__tone-amber',
  },
  { name: 'customerProfitRateDisplay', label: 'Profit rate', field: 'customerProfitRateDisplay', align: 'left' as const },
  { name: 'actions', label: '', field: 'actions', align: 'left' as const },
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

const formatBdt = (value: number | null) => (value == null ? '-' : String(value))
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
  await costingFileStore.fetchCostingFileWithItems(fileId)
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

const handleSaveFileDetails = async () => {
  if (!selectedFile.value || !canSaveFileDetails.value) {
    return
  }

  savingFileDetails.value = true
  try {
    const result = await costingFileStore.updateCostingFile({
      id: selectedFile.value.id,
      name: fileForm.name.trim(),
      market: fileForm.market.trim(),
    })

    if (!result.success) {
      return
    }

    showSuccessNotification('Costing file updated.')
    syncFileForm()
  } finally {
    savingFileDetails.value = false
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
  if (!itemForms.value.length) return

  savingProfitAll.value = true
  try {
    const normalized =
      sharedProfitRate.value == null || Number.isNaN(Number(sharedProfitRate.value))
        ? null
        : Number(sharedProfitRate.value)

    for (const item of itemForms.value) {
      const result = await costingFileStore.updateCostingFileItemCustomerProfit({
        id: item.id,
        customerProfitRate: normalized,
      })

      if (!result.success) {
        return
      }
    }

    showSuccessNotification('Buyer profit rate updated.')
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

.costing-page :deep(th) {
  text-align: left;
}

.costing-page :deep(.q-btn) {
  border-radius: 8px;
}

.costing-page__table--offered :deep(.q-table th),
.costing-page__table--offered :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.costing-page__table--offered :deep(.costing-page__tone-emerald) {
  background: #ddf4e7;
  color: #1f6a43;
}

.costing-page__table--offered :deep(th.costing-page__tone-emerald) {
  font-weight: 700;
}

.costing-page__actions-cell {
  white-space: nowrap;
}

.costing-page__image-table-cell {
  width: 92px;
}

.costing-page__image {
  width: 72px;
  height: 72px;
  border-radius: 8px;
  overflow: hidden;
}

.costing-page__image--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bw-theme-surface, #f3f4f6);
  color: var(--bw-theme-muted, #6b7280);
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
  width: 280px;
  max-width: 280px;
}

.costing-page__url-text {
  display: inline-block;
  width: 100%;
  max-width: 280px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
}

.costing-page__icon-btn {
  border-radius: 8px;
}

.costing-page__decision-btn {
  border-radius: 8px;
  min-width: 78px;
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

  .costing-page__url-cell {
    width: 160px;
    max-width: 160px;
  }

  .costing-page__url-text {
    max-width: 160px;
  }

  .costing-page__icon-btn {
    min-height: 28px;
    min-width: 28px;
    padding: 0.2rem;
  }
}
</style>
