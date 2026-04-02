<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section>
        <h1 class="text-h5 q-my-none">Costing file details</h1>
      </section>

      <div v-if="selectedFile">
        <div>
          <p class="q-my-none text-body2 text-grey-7">{{ selectedFile.name }} | {{ selectedFile.market }} | {{ selectedFile.status }}</p>
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

        <div v-else-if="selectedFile.status === 'customer_submitted'" class="costing-page__customer-submitted-section">
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
  itemForms.value.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    websiteUrl: item.website_url,
    quantity: item.quantity,
    name: item.name ?? '-',
    offerPriceBdt: formatBdt(item.offer_price_bdt),
    status: item.status,
  })),
)

const allColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const },
  { name: 'websiteUrl', label: 'Web link', field: 'websiteUrl', align: 'left' as const },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const },
  { name: 'actions', label: '', field: 'actions', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  { name: 'offerPriceBdt', label: 'Offer BDT', field: 'offerPriceBdt', align: 'left' as const },
]

const visibleColumns = computed(() => {
  if (!selectedFile.value) {
    return []
  }

  if (selectedFile.value.status === 'draft') {
    return allColumns.filter((column) => ['sl', 'websiteUrl', 'quantity', 'actions'].includes(column.name))
  }

  if (selectedFile.value.status === 'customer_submitted') {
    return allColumns.filter((column) => ['sl', 'websiteUrl', 'quantity'].includes(column.name))
  }

  return allColumns.filter((column) => ['sl', 'websiteUrl', 'quantity', 'name', 'status', 'offerPriceBdt'].includes(column.name))
})

const formatBdt = (value: number | null) => (value == null ? '-' : `BDT ${value}`)
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
</script>

<style scoped>
.costing-page__input-section,
.costing-page__table-section {
  display: block;
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

.costing-page__actions-cell {
  white-space: nowrap;
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

.costing-page__submit-actions {
  display: flex;
  justify-content: flex-end;
}

.costing-page__dialog {
  min-width: min(420px, 92vw);
}

.costing-page__table {
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
