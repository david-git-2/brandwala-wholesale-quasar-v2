<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack costing-page">
      <section>
        <div class="text-overline">Costing File</div>
        <h1 class="text-h5 q-my-none">Staff costing files</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
      </section>

      <q-table flat bordered row-key="id" :rows="fileRows" :columns="fileColumns" :loading="loadingFiles" hide-bottom>
        <template #body-cell-open="props">
          <q-td :props="props">
            <q-btn flat color="primary" label="Open" :loading="openingFileId === props.row.id" @click="openFile(Number(props.row.id))" />
          </q-td>
        </template>
      </q-table>

      <q-card v-if="selectedFile" flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Costing file details</div>
          <div class="text-body2 text-grey-7">{{ selectedFile.name }} | {{ selectedFile.market }} | {{ customerGroupNameById(selectedFile.customer_group_id) }}</div>
        </q-card-section>

        <q-card-section v-if="selectedFile.status === 'draft'">
          <div class="costing-page__detail-grid">
            <q-input :model-value="selectedFile.name" label="File name" outlined dense readonly />
            <q-input :model-value="selectedFile.market" label="Market" outlined dense readonly />
            <q-input :model-value="customerGroupNameById(selectedFile.customer_group_id)" label="Customer group" outlined dense readonly />
          </div>
        </q-card-section>

        <template v-else>
          <q-card-section v-if="selectedFile.status === 'customer_submitted'">
            <div class="costing-page__detail-grid">
              <q-input :model-value="selectedFile.name" label="File name" outlined dense readonly />
              <q-input :model-value="selectedFile.market" label="Market" outlined dense readonly />
              <q-input :model-value="customerGroupNameById(selectedFile.customer_group_id)" label="Customer group" outlined dense readonly />
            </div>
          </q-card-section>

          <q-card-section>
            <q-table
              flat
              bordered
              row-key="id"
              :rows="productRows"
              :columns="productColumns"
              :loading="loadingItems"
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
                      :src="props.row.imageUrl"
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
                    :href="props.row.websiteUrl"
                    :title="props.row.websiteUrl"
                    class="costing-page__link"
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

              <template #body-cell-productWeight="props">
                <q-td :props="props" class="costing-page__weight-cell">
                  {{ props.row.productWeight }}
                </q-td>
              </template>

              <template #body-cell-packageWeight="props">
                <q-td :props="props" class="costing-page__weight-cell">
                  {{ props.row.packageWeight }}
                </q-td>
              </template>

              <template #body-cell-actions="props">
                <q-td :props="props" auto-width>
                  <q-btn
                    flat
                    dense
                    color="primary"
                    icon="edit"
                    round
                    aria-label="Edit item"
                    :disable="savingItemId === props.row.id"
                    @click="openEditDialog(props.row.id)"
                  />
                </q-td>
              </template>
            </q-table>
          </q-card-section>

          <div v-if="selectedFile.status !== 'customer_submitted'" class="costing-page__editor-list">
            <div v-for="item in itemForms" :key="item.id" class="costing-page__editor">
              <div class="costing-page__editor-title">Item {{ item.id }}</div>

              <div class="costing-page__editor-grid">
                <q-input v-model="item.image_url" label="Image URL" outlined dense />
                <q-input v-model="item.website_url" label="Website URL" outlined dense />
                <q-input v-model.number="item.quantity" label="Quantity" type="number" outlined dense />
                <q-input v-model.number="item.price_in_web_gbp" label="Web price GBP" type="number" outlined dense />
                <q-input v-model.number="item.delivery_price_gbp" label="Delivery price GBP" type="number" outlined dense />
              </div>

              <div class="costing-page__actions">
                <q-btn
                  color="primary"
                  unelevated
                  label="Save item"
                  :loading="savingItemId === item.id"
                  @click="handleSaveItem(item)"
                />
              </div>
            </div>
          </div>
        </template>
      </q-card>

      <AdminCostingFileItemEditDialog
        v-model="editDialogOpen"
        :item="editingItem"
        :loading="savingItemId === editingItem?.id"
        @save="handleSaveEnrichment"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'

import AdminCostingFileItemEditDialog from 'src/modules/costingFile/components/AdminCostingFileItemEditDialog.vue'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItem } from 'src/modules/costingFile/types'
import { customerGroupService } from 'src/modules/tenant/services/customerGroupService'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'

const tenantStore = useTenantStore()
const costingFileStore = useCostingFileStore()
const {
  items: files,
  selectedItem: selectedFile,
  costingFileItems,
  listLoading: loadingFiles,
  itemLoading: loadingItems,
} = storeToRefs(costingFileStore)

const openingFileId = ref<number | null>(null)
const savingItemId = ref<number | null>(null)
const editDialogOpen = ref(false)
const editingItemId = ref<number | null>(null)

const itemForms = ref<CostingFileItem[]>([])
const customerGroupOptions = ref<{ label: string; value: number }[]>([])

const subtitle = computed(() =>
  tenantStore.selectedTenant?.name
    ? `${tenantStore.selectedTenant.name} staff can update item image, URL, quantity, web price, and delivery charge here.`
    : 'Select a tenant to edit costing file items.',
)

const fileRows = computed(() =>
  files.value.map((file) => ({
    id: file.id,
    name: file.name,
    market: file.market,
    status: file.status,
    open: file.id,
  })),
)

const productRows = computed(() =>
  itemForms.value.map((item) => ({
    id: item.id,
    sl: itemForms.value.findIndex((entry) => entry.id === item.id) + 1,
    imageUrl: item.image_url,
    websiteUrl: item.website_url,
    name: item.name ?? '-',
    webPriceGbp: item.price_in_web_gbp == null ? '-' : `GBP ${item.price_in_web_gbp}`,
    productWeight: item.product_weight == null ? '-' : item.product_weight,
    packageWeight: item.package_weight == null ? '-' : item.package_weight,
    quantity: item.quantity ?? '-',
  })),
)

const editingItem = computed<CostingFileItem | null>(
  () => itemForms.value.find((item) => item.id === editingItemId.value) ?? null,
)

const fileColumns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'market', label: 'Market', field: 'market', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  { name: 'open', label: 'Open', field: 'open', align: 'left' as const },
]

const productColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const },
  { name: 'websiteUrl', label: 'Web link', field: 'websiteUrl', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const },
  { name: 'webPriceGbp', label: 'Web Price GBP', field: 'webPriceGbp', align: 'left' as const },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const },
]

const customerGroupNameById = (customerGroupId: number) =>
  customerGroupOptions.value.find((option) => option.value === customerGroupId)?.label ?? `#${customerGroupId}`

const loadFiles = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    costingFileStore.items = []
    return
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId)
}

const loadCustomerGroups = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    customerGroupOptions.value = []
    return
  }

  const result = await customerGroupService.listCustomerGroupsByTenant(tenantId)

  if (!result.success) {
    customerGroupOptions.value = []
    return
  }

  customerGroupOptions.value = (result.data ?? []).map((group) => ({
    label: group.name,
    value: group.id,
  }))
}

const openFile = async (id: number) => {
  openingFileId.value = id

  try {
    await costingFileStore.fetchCostingFileWithItems(id)
  } finally {
    openingFileId.value = null
  }
}

const refreshSelectedFile = async () => {
  if (!selectedFile.value) {
    return
  }

  await openFile(selectedFile.value.id)
  await loadFiles()
}

const openEditDialog = (itemId: number) => {
  editingItemId.value = itemId
  editDialogOpen.value = true
}

const handleSaveEnrichment = async (payload: {
  id: number
  name: string | null
  productWeight: number | null
  packageWeight: number | null
  imageUrl: string | null
  priceInWebGbp: number | null
}) => {
  savingItemId.value = payload.id

  try {
    const result = await costingFileStore.updateCostingFileItemEnrichment({
      id: payload.id,
      name: payload.name,
      productWeight: payload.productWeight,
      packageWeight: payload.packageWeight,
      imageUrl: payload.imageUrl,
      priceInWebGbp: payload.priceInWebGbp,
    })

    if (result.success) {
      editDialogOpen.value = false
    }
  } finally {
    savingItemId.value = null
  }
}

const handleSaveItem = async (item: CostingFileItem) => {
  savingItemId.value = item.id

  try {
    await costingFileStore.updateCostingFileItem({
      id: item.id,
      imageUrl: item.image_url,
      websiteUrl: item.website_url,
      quantity: item.quantity,
      priceInWebGbp: item.price_in_web_gbp,
      deliveryPriceGbp: item.delivery_price_gbp,
    })
    await refreshSelectedFile()
  } finally {
    savingItemId.value = null
  }
}

watch(
  costingFileItems,
  (items) => {
    itemForms.value = (items ?? []).map((item) => ({ ...item }))
  },
  { immediate: true },
)

watch(editDialogOpen, (isOpen) => {
  if (!isOpen) {
    editingItemId.value = null
  }
})

onMounted(async () => {
  await loadCustomerGroups()
  await loadFiles()
})
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

.costing-page__detail-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
}

.costing-page__editor-list {
  display: grid;
  gap: 1rem;
  margin-top: 1rem;
}

.costing-page__editor {
  border: 1px solid var(--bw-theme-border);
  border-radius: 12px;
  padding: 1rem;
}

.costing-page__editor-title {
  margin-bottom: 0.75rem;
  font-weight: 700;
}

.costing-page__editor-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.costing-page__actions {
  display: flex;
  gap: 0.75rem;
  margin-top: 1rem;
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
  width: 144px;
  max-width: 144px;
}

.costing-page__name-text {
  display: inline-block;
  max-width: 144px;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.costing-page__weight-cell {
  width: 72px;
  max-width: 72px;
  white-space: nowrap;
}

@media (max-width: 900px) {
  .costing-page__detail-grid,
  .costing-page__editor-grid {
    grid-template-columns: 1fr;
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
