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
          <q-select
            v-model="statusForm"
            :options="fileStatuses"
            label="File status"
            outlined
            dense
            :disable="!selectedFile || savingStatus"
            :loading="savingStatus"
            @update:model-value="handleSaveStatus"
          />
          <q-btn outline color="primary" label="Add item" :disable="!selectedFile" />
        </div>
      </section>

      <section v-if="selectedFile?.status === 'draft'" class="costing-page__draft-state">
        <div class="text-subtitle1">Items not added yet</div>
        <p class="text-body2 text-grey-7 q-mb-none">
          Add items now or wait for the customer to add items before continuing this costing file.
        </p>
      </section>

      <section v-else-if="selectedFile?.status === 'customer_submitted'" class="bw-page__stack">
        <div>
          <div class="text-subtitle1">Submitted items</div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Review the items submitted by the customer before moving this costing file forward.
          </p>
        </div>

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

          <template #body-cell-priceInWebGbp="props">
            <q-td :props="props">
              {{ props.row.priceInWebGbp }}
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

          <template #body-cell-quantity="props">
            <q-td :props="props">
              {{ props.row.quantity }}
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
      </section>

      <section v-else-if="selectedFile?.status === 'in_review'" class="costing-page__pricing-section">
        <div>
          <div class="text-subtitle1">Pricing inputs</div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Enter pricing values for this costing file.
          </p>
        </div>

        <div class="costing-page__pricing-grid">
          <div class="costing-page__field">
            <div class="costing-page__field-label">Cargo rate 1 KG</div>
            <q-input v-model.number="pricingForm.cargoRate1Kg" type="number" outlined dense />
          </div>
          <div class="costing-page__field">
            <div class="costing-page__field-label">Cargo rate 2 KG</div>
            <q-input v-model.number="pricingForm.cargoRate2Kg" type="number" outlined dense />
          </div>
          <div class="costing-page__field">
            <div class="costing-page__field-label">Conversion rate</div>
            <q-input v-model.number="pricingForm.conversionRate" type="number" outlined dense />
          </div>
          <div class="costing-page__field">
            <div class="costing-page__field-label">Admin profit rate</div>
            <q-input v-model.number="pricingForm.adminProfitRate" type="number" outlined dense />
          </div>
        </div>

        <div class="costing-page__pricing-actions">
          <q-btn
            color="primary"
            unelevated
            label="Save pricing"
            :loading="savingPricing"
            :disable="!selectedFile"
            @click="handleSavePricing"
          />
        </div>

        <q-table
          flat
          bordered
          row-key="id"
          :rows="reviewRows"
          :columns="reviewColumns"
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
        </q-table>
      </section>

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
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'

import AdminCostingFileItemEditDialog from 'src/modules/costingFile/components/AdminCostingFileItemEditDialog.vue'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItem, CostingFileStatus } from 'src/modules/costingFile/types'
import { calculateCostingItem } from 'src/modules/costingFile/utils/costingCalculations'

const route = useRoute()
const costingFileStore = useCostingFileStore()
const {
  selectedItem: selectedFile,
  costingFileItems,
  itemLoading: loadingItems,
} = storeToRefs(costingFileStore)

const savingStatus = ref(false)
const savingItemId = ref<number | null>(null)
const savingPricing = ref(false)
const statusForm = ref<CostingFileStatus>('draft')
const editDialogOpen = ref(false)
const editingItemId = ref<number | null>(null)
const pricingForm = reactive({
  cargoRate1Kg: null as number | null,
  cargoRate2Kg: null as number | null,
  conversionRate: null as number | null,
  adminProfitRate: null as number | null,
})

const fileStatuses: CostingFileStatus[] = ['draft', 'customer_submitted', 'in_review', 'priced', 'offered', 'completed', 'cancelled']

const subtitle = computed(() =>
  selectedFile.value ? `${selectedFile.value.name} items and pricing.` : 'Loading costing file details.'
)

const editingItem = computed<CostingFileItem | null>(
  () => costingFileItems.value.find((item) => item.id === editingItemId.value) ?? null,
)

const productRows = computed(() =>
  costingFileItems.value.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    imageUrl: item.image_url,
    websiteUrl: item.website_url,
    name: item.name ?? '-',
    priceInWebGbp: item.price_in_web_gbp == null ? '-' : `GBP ${item.price_in_web_gbp}`,
    productWeight: item.product_weight == null ? '-' : item.product_weight,
    packageWeight: item.package_weight == null ? '-' : item.package_weight,
    quantity: item.quantity,
  })),
)

const productColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const },
  { name: 'websiteUrl', label: 'Web link', field: 'websiteUrl', align: 'left' as const },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'priceInWebGbp', label: 'Web price', field: 'priceInWebGbp', align: 'left' as const },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'left' as const },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const },
]

const formatGbp = (value: number | null | undefined) => (value == null ? '-' : `GBP ${Number(value).toFixed(2)}`)
const formatBdt = (value: number | null | undefined) => (value == null ? '-' : `BDT ${value}`)

const reviewRows = computed(() =>
  costingFileItems.value.map((item, index) => {
    const calculated = calculateCostingItem(
      {
        cargoRate1Kg: pricingForm.cargoRate1Kg,
        cargoRate2Kg: pricingForm.cargoRate2Kg,
        conversionRate: pricingForm.conversionRate,
        adminProfitRate: pricingForm.adminProfitRate,
        offerPriceOverrideBdt: item.offer_price_override_bdt,
      },
      {
        productWeight: item.product_weight,
        packageWeight: item.package_weight,
        priceInWebGbp: item.price_in_web_gbp,
        deliveryPriceGbp: item.delivery_price_gbp,
        customerProfitRate: item.customer_profit_rate,
      },
    )
    const profitAmount = calculated.offerPriceBdt - calculated.costingPriceBdt
    const profitRate =
      calculated.costingPriceBdt > 0
        ? `${((profitAmount / calculated.costingPriceBdt) * 100).toFixed(2)}%`
        : '-'

    return {
      id: item.id,
      sl: index + 1,
      imageUrl: item.image_url,
      websiteUrl: item.website_url,
      quantity: item.quantity ?? '-',
      name: item.name ?? '-',
      productWeight: item.product_weight ?? '-',
      packageWeight: item.package_weight ?? '-',
      totalWeight: calculated.totalWeight,
      priceInWebGbp: formatGbp(item.price_in_web_gbp),
      deliveryPriceGbp: formatGbp(item.delivery_price_gbp),
      auxiliaryPriceGbp: formatGbp(calculated.auxiliaryPriceGbp),
      purchasePriceGbp: formatGbp(calculated.itemPriceGbp),
      costingPriceGbp: formatGbp(calculated.costingPriceGbp),
      costingPriceBdt: formatBdt(calculated.costingPriceBdt),
      offerPriceBdt: formatBdt(calculated.offerPriceBdt),
      profitRate,
      profitAmount: formatBdt(profitAmount),
    }
  }),
)

const reviewColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const, style: 'width: 48px; min-width: 48px;', headerStyle: 'width: 48px; min-width: 48px;' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const, style: 'width: 108px; min-width: 108px;', headerStyle: 'width: 108px; min-width: 108px;' },
  { name: 'websiteUrl', label: 'Web URL', field: 'websiteUrl', align: 'left' as const, style: 'width: 144px; min-width: 144px; max-width: 144px;', headerStyle: 'width: 144px; min-width: 144px; max-width: 144px;' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const, style: 'width: 56px; min-width: 56px;', headerStyle: 'width: 56px; min-width: 56px;' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const, style: 'width: 280px; min-width: 280px; max-width: 280px;', headerStyle: 'width: 280px; min-width: 280px; max-width: 280px;' },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'totalWeight', label: 'Total wt', field: 'totalWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'priceInWebGbp', label: 'Web price', field: 'priceInWebGbp', align: 'left' as const, style: 'width: 110px; min-width: 110px;', headerStyle: 'width: 110px; min-width: 110px;' },
  { name: 'deliveryPriceGbp', label: 'Delivery price', field: 'deliveryPriceGbp', align: 'left' as const, style: 'width: 116px; min-width: 116px;', headerStyle: 'width: 116px; min-width: 116px;' },
  { name: 'auxiliaryPriceGbp', label: 'Auxiliary price', field: 'auxiliaryPriceGbp', align: 'left' as const, style: 'width: 118px; min-width: 118px;', headerStyle: 'width: 118px; min-width: 118px;' },
  { name: 'purchasePriceGbp', label: 'Purchase price', field: 'purchasePriceGbp', align: 'left' as const, style: 'width: 122px; min-width: 122px;', headerStyle: 'width: 122px; min-width: 122px;' },
  { name: 'costingPriceGbp', label: 'Cost in GBP', field: 'costingPriceGbp', align: 'left' as const, style: 'width: 110px; min-width: 110px;', headerStyle: 'width: 110px; min-width: 110px;' },
  { name: 'costingPriceBdt', label: 'Cost in BDT', field: 'costingPriceBdt', align: 'left' as const, style: 'width: 110px; min-width: 110px;', headerStyle: 'width: 110px; min-width: 110px;' },
  { name: 'offerPriceBdt', label: 'Offer price', field: 'offerPriceBdt', align: 'left' as const, style: 'width: 110px; min-width: 110px;', headerStyle: 'width: 110px; min-width: 110px;' },
  { name: 'profitRate', label: 'Profit rate', field: 'profitRate', align: 'left' as const, style: 'width: 96px; min-width: 96px;', headerStyle: 'width: 96px; min-width: 96px;' },
  { name: 'profitAmount', label: 'Profit amount', field: 'profitAmount', align: 'left' as const, style: 'width: 116px; min-width: 116px;', headerStyle: 'width: 116px; min-width: 116px;' },
]

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!fileId) return

  await costingFileStore.fetchCostingFileWithItems(fileId)
}

const handleSaveStatus = async (value: CostingFileStatus | null = statusForm.value) => {
  if (!selectedFile.value || !value || value === selectedFile.value.status) return

  savingStatus.value = true
  try {
    statusForm.value = value
    const result = await costingFileStore.updateCostingFileStatus({ id: selectedFile.value.id, status: value })

    if (!result.success) {
      statusForm.value = selectedFile.value.status
    }
  } finally {
    savingStatus.value = false
  }
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
  } finally {
    savingPricing.value = false
  }
}

watch(
  selectedFile,
  (file) => {
    if (file) {
      statusForm.value = file.status
      pricingForm.cargoRate1Kg = file.cargo_rate_1kg
      pricingForm.cargoRate2Kg = file.cargo_rate_2kg
      pricingForm.conversionRate = file.conversion_rate
      pricingForm.adminProfitRate = file.admin_profit_rate
    }
  },
  { immediate: true },
)

watch(editDialogOpen, (isOpen) => {
  if (!isOpen) {
    editingItemId.value = null
  }
})

onMounted(async () => {
  await loadFile()
})
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
}

.costing-page > * {
  min-width: 0;
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
  flex: 0 0 auto;
}

.costing-page__toolbar :deep(.q-field) {
  min-width: 220px;
}

.costing-page__draft-state {
  display: grid;
  gap: 0.5rem;
  padding: 1rem 0;
  border-top: 1px solid var(--bw-theme-border);
}

.costing-page__pricing-section {
  display: grid;
  gap: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--bw-theme-border);
}

.costing-page__pricing-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 1rem;
}

.costing-page__field {
  display: grid;
  gap: 0.4rem;
}

.costing-page__field-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.costing-page__pricing-actions {
  display: flex;
  justify-content: flex-start;
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
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

.costing-page :deep(.q-table th:nth-child(4)),
.costing-page :deep(.q-table td:nth-child(4)) {
  width: 56px;
  max-width: 56px;
  white-space: nowrap;
}

@media (max-width: 900px) {
  .costing-page__header {
    flex-direction: column;
  }

  .costing-page__toolbar {
    justify-content: stretch;
  }

  .costing-page__toolbar > * {
    width: 100%;
  }

  .costing-page__pricing-grid {
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
