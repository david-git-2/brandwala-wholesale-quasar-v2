<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack costing-page">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Costing File</div>
          <h1 class="text-h5 q-my-none">Costing file details</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>
        <div class="col-auto">
          <q-btn flat color="primary" label="Back" :to="{ name: 'admin-costing-file-page' }" />
        </div>
      </section>

      <q-card
        v-if="selectedFile"
        flat
        bordered
      >
        <q-card-section>
          <div class="text-subtitle1">Costing file details</div>
          <div class="text-body2 text-grey-7">{{ selectedFile.name }} | {{ selectedFile.market }}</div>
        </q-card-section>

        <q-card-section>
        <div class="costing-page__detail-grid">
          <q-input :model-value="selectedFile.name" label="File name" outlined dense readonly />
          <q-input :model-value="selectedFile.market" label="Market" outlined dense readonly />
          <q-select v-model="statusForm" label="File status" outlined dense :options="fileStatuses" />
          <q-input v-model.number="pricingForm.cargoRate1Kg" label="Cargo rate 1 KG" type="number" outlined dense />
          <q-input v-model.number="pricingForm.cargoRate2Kg" label="Cargo rate 2 KG" type="number" outlined dense />
          <q-input v-model.number="pricingForm.conversionRate" label="Conversion rate" type="number" outlined dense />
          <q-input v-model.number="pricingForm.adminProfitRate" label="Admin profit rate %" type="number" outlined dense />
        </div>
        </q-card-section>

        <q-card-actions align="left">
          <q-btn outline color="primary" label="Save status" :loading="savingStatus" @click="handleSaveStatus" />
          <q-btn color="primary" unelevated label="Save pricing" :loading="savingPricing" @click="handleSavePricing" />
        </q-card-actions>

        <q-card-section>
          <q-table
            flat
            bordered
            row-key="id"
            :rows="productRows"
            :columns="productColumns"
            :loading="loadingItems"
            hide-bottom
          />
        </q-card-section>

        <q-card-section class="costing-page__editor-list">
          <div v-for="item in itemForms" :key="item.id" class="costing-page__editor">
            <div class="costing-page__editor-title">Item {{ item.id }}</div>

            <div class="costing-page__editor-grid">
              <q-input :model-value="item.website_url" label="Website URL" outlined dense readonly />
              <q-input :model-value="item.quantity" label="Quantity" type="number" outlined dense readonly />
              <q-input v-model="item.name" label="Name" outlined dense />
              <q-select v-model="item.status" label="Item status" outlined dense :options="itemStatuses" />
              <q-input v-model="item.image_url" label="Image URL" outlined dense />
              <q-input v-model.number="item.product_weight" label="Product weight" type="number" outlined dense />
              <q-input v-model.number="item.package_weight" label="Package weight" type="number" outlined dense />
              <q-input v-model.number="item.price_in_web_gbp" label="Web price GBP" type="number" outlined dense />
              <q-input v-model.number="item.delivery_price_gbp" label="Delivery price GBP" type="number" outlined dense />
              <q-input v-model.number="item.customer_profit_rate" label="Customer profit rate %" type="number" outlined dense />
              <q-input v-model.number="item.offer_price_override_bdt" label="Offer override BDT" type="number" outlined dense clearable />
              <q-input :model-value="formatBdt(item.offer_price_bdt)" label="Final offer" outlined dense readonly />
            </div>

            <div class="costing-page__actions">
              <q-btn outline color="primary" label="Save enrichment" :loading="savingItemId === item.id && savingItemAction === 'enrichment'" @click="handleSaveEnrichment(item)" />
              <q-btn outline color="primary" label="Save status" :loading="savingItemId === item.id && savingItemAction === 'status'" @click="handleSaveItemStatus(item)" />
              <q-btn outline color="primary" label="Save customer profit" :loading="savingItemId === item.id && savingItemAction === 'profit'" @click="handleSaveCustomerProfit(item)" />
              <q-btn color="primary" unelevated label="Save offer override" :loading="savingItemId === item.id && savingItemAction === 'offer'" @click="handleSaveOffer(item)" />
            </div>
          </div>
        </q-card-section>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileDetails, CostingFileItem, CostingFileItemStatus, CostingFileStatus } from 'src/modules/costingFile/types'

type ItemEditor = CostingFileItem

const route = useRoute()
const costingFileStore = useCostingFileStore()
const {
  selectedItem: selectedFile,
  costingFileItems,
  itemLoading: loadingItems,
} = storeToRefs(costingFileStore)

const savingStatus = ref(false)
const savingPricing = ref(false)
const savingItemId = ref<number | null>(null)
const savingItemAction = ref<'enrichment' | 'status' | 'profit' | 'offer' | null>(null)

const itemForms = ref<ItemEditor[]>([])

const pricingForm = reactive({
  cargoRate1Kg: null as number | null,
  cargoRate2Kg: null as number | null,
  conversionRate: null as number | null,
  adminProfitRate: null as number | null,
})

const statusForm = ref<CostingFileStatus>('draft')

const subtitle = computed(() =>
  selectedFile.value ? `${selectedFile.value.name} items and pricing.` : 'Loading costing file details.'
)

const fileStatuses: CostingFileStatus[] = ['draft', 'customer_submitted', 'in_review', 'priced', 'offered', 'completed', 'cancelled']
const itemStatuses: CostingFileItemStatus[] = ['pending', 'accepted', 'rejected']

const productRows = computed(() =>
  itemForms.value.map((item) => ({
    id: item.id,
    websiteUrl: item.website_url,
    quantity: item.quantity,
    name: item.name ?? '-',
    status: item.status,
    offerPriceBdt: formatBdt(item.offer_price_bdt),
    customerProfitRate: item.customer_profit_rate ?? 0,
  })),
)

const productColumns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' as const },
  { name: 'websiteUrl', label: 'Website URL', field: 'websiteUrl', align: 'left' as const },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  { name: 'offerPriceBdt', label: 'Offer BDT', field: 'offerPriceBdt', align: 'left' as const },
  { name: 'customerProfitRate', label: 'Customer Profit %', field: 'customerProfitRate', align: 'left' as const },
]

const formatBdt = (value: number | null) => (value == null ? '-' : `BDT ${value}`)

const syncSelectedFileForms = (file: CostingFileDetails | null) => {
  if (!file) return

  statusForm.value = file.status
  pricingForm.cargoRate1Kg = file.cargo_rate_1kg
  pricingForm.cargoRate2Kg = file.cargo_rate_2kg
  pricingForm.conversionRate = file.conversion_rate
  pricingForm.adminProfitRate = file.admin_profit_rate
}

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!fileId) return

  const fileResult = await costingFileStore.fetchCostingFileWithItems(fileId)
  if (!fileResult.success) return
}

const refreshSelectedFile = async () => {
  await loadFile()
}

const handleSaveStatus = async () => {
  if (!selectedFile.value) return
  savingStatus.value = true
  try {
    await costingFileStore.updateCostingFileStatus({ id: selectedFile.value.id, status: statusForm.value })
    await refreshSelectedFile()
  } finally {
    savingStatus.value = false
  }
}

const handleSavePricing = async () => {
  if (!selectedFile.value) return
  savingPricing.value = true
  try {
    await costingFileStore.updateCostingFilePricing({
      id: selectedFile.value.id,
      cargoRate1Kg: pricingForm.cargoRate1Kg,
      cargoRate2Kg: pricingForm.cargoRate2Kg,
      conversionRate: pricingForm.conversionRate,
      adminProfitRate: pricingForm.adminProfitRate,
    })
    await refreshSelectedFile()
  } finally {
    savingPricing.value = false
  }
}

const withItemSaveState = async (itemId: number, action: 'enrichment' | 'status' | 'profit' | 'offer', callback: () => Promise<void>) => {
  savingItemId.value = itemId
  savingItemAction.value = action
  try {
    await callback()
  } finally {
    savingItemId.value = null
    savingItemAction.value = null
  }
}

const handleSaveEnrichment = async (item: ItemEditor) =>
  withItemSaveState(item.id, 'enrichment', async () => {
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
  })

const handleSaveItemStatus = async (item: ItemEditor) =>
  withItemSaveState(item.id, 'status', async () => {
    await costingFileStore.updateCostingFileItemStatus({ id: item.id, status: item.status })
    await refreshSelectedFile()
  })

const handleSaveCustomerProfit = async (item: ItemEditor) =>
  withItemSaveState(item.id, 'profit', async () => {
    await costingFileStore.updateCostingFileItemCustomerProfit({
      id: item.id,
      customerProfitRate: item.customer_profit_rate,
    })
    await refreshSelectedFile()
  })

const handleSaveOffer = async (item: ItemEditor) =>
  withItemSaveState(item.id, 'offer', async () => {
    await costingFileStore.updateCostingFileItemOffer({
      id: item.id,
      offerPriceOverrideBdt: item.offer_price_override_bdt,
    })
    await refreshSelectedFile()
  })

watch(
  selectedFile,
  (file) => {
    syncSelectedFileForms(file ?? null)
  },
  { immediate: true },
)

watch(
  costingFileItems,
  (items) => {
    itemForms.value = (items ?? []).map((item) => ({ ...item }))
  },
  { immediate: true },
)

onMounted(async () => {
  await loadFile()
})
</script>

<style scoped>
.costing-page { display: grid; gap: 1.25rem; }
.costing-page__detail-grid, .costing-page__editor-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; }
.costing-page__editor-list { display: grid; gap: 1rem; margin-top: 1rem; }
.costing-page__editor { border: 1px solid var(--bw-theme-border); border-radius: 12px; padding: 1rem; }
.costing-page__editor-title { margin-bottom: 0.75rem; font-weight: 700; }
.costing-page__actions { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-top: 1rem; }
@media (max-width: 900px) {
  .costing-page__detail-grid, .costing-page__editor-grid { grid-template-columns: 1fr; }
}
</style>
