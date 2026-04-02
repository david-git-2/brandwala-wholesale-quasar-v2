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
          <div class="text-body2 text-grey-7">{{ selectedFile.name }} | {{ selectedFile.market }} | {{ selectedFile.status }}</div>
        </q-card-section>

        <q-card-section>
          <q-table flat bordered row-key="id" :rows="productRows" :columns="productColumns" :loading="loadingItems" hide-bottom />
        </q-card-section>

        <div class="costing-page__editor-list">
          <div v-for="item in itemForms" :key="item.id" class="costing-page__editor">
            <div class="costing-page__editor-title">Item {{ item.id }}</div>

            <div class="costing-page__editor-grid">
              <q-input :model-value="item.website_url" label="Website URL" outlined dense readonly />
              <q-input :model-value="item.quantity" label="Quantity" type="number" outlined dense readonly />
              <q-input :model-value="item.status" label="Item status" outlined dense readonly />
              <q-input v-model="item.name" label="Name" outlined dense />
              <q-input v-model="item.image_url" label="Image URL" outlined dense />
              <q-input v-model.number="item.product_weight" label="Product weight" type="number" outlined dense />
              <q-input v-model.number="item.package_weight" label="Package weight" type="number" outlined dense />
              <q-input v-model.number="item.price_in_web_gbp" label="Web price GBP" type="number" outlined dense />
              <q-input v-model.number="item.delivery_price_gbp" label="Delivery price GBP" type="number" outlined dense />
              <q-input :model-value="formatBdt(item.offer_price_bdt)" label="Offer BDT" outlined dense readonly />
            </div>

            <div class="costing-page__actions">
              <q-btn
                color="primary"
                unelevated
                label="Save enrichment"
                :loading="savingItemId === item.id"
                @click="handleSaveEnrichment(item)"
              />
            </div>
          </div>
        </div>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItem } from 'src/modules/costingFile/types'
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

const itemForms = ref<CostingFileItem[]>([])

const subtitle = computed(() =>
  tenantStore.selectedTenant?.name
    ? `${tenantStore.selectedTenant.name} staff can enrich products here.`
    : 'Select a tenant to enrich costing files.',
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
    websiteUrl: item.website_url,
    quantity: item.quantity,
    status: item.status,
    name: item.name ?? '-',
    productWeight: item.product_weight ?? '-',
    packageWeight: item.package_weight ?? '-',
    offerPriceBdt: formatBdt(item.offer_price_bdt),
  })),
)

const fileColumns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'market', label: 'Market', field: 'market', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  { name: 'open', label: 'Open', field: 'open', align: 'left' as const },
]

const productColumns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' as const },
  { name: 'websiteUrl', label: 'Website URL', field: 'websiteUrl', align: 'left' as const },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'productWeight', label: 'Product g', field: 'productWeight', align: 'left' as const },
  { name: 'packageWeight', label: 'Package g', field: 'packageWeight', align: 'left' as const },
  { name: 'offerPriceBdt', label: 'Offer BDT', field: 'offerPriceBdt', align: 'left' as const },
]

const formatBdt = (value: number | null) => (value == null ? '-' : `BDT ${value}`)

const loadFiles = async () => {
  const tenantId = tenantStore.selectedTenant?.id

  if (!tenantId) {
    costingFileStore.items = []
    return
  }

  await costingFileStore.fetchCostingFilesByTenant(tenantId)
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

const handleSaveEnrichment = async (item: CostingFileItem) => {
  savingItemId.value = item.id

  try {
    await costingFileStore.updateCostingFileItemEnrichment({
      id: item.id,
      name: item.name,
      imageUrl: item.image_url,
      productWeight: item.product_weight,
      packageWeight: item.package_weight,
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

onMounted(async () => {
  await loadFiles()
})
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
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

@media (max-width: 900px) {
  .costing-page__editor-grid {
    grid-template-columns: 1fr;
  }
}
</style>
