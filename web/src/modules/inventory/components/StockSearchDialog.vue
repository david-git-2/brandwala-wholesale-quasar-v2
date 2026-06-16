<template>
  <q-dialog v-model="isOpen" backdrop-filter="blur(4px)">
    <q-card class="search-card floating-surface shadow-2">
      <q-card-section class="q-py-md row items-center justify-between">
        <div class="row items-center q-gutter-sm">
          <q-icon name="inventory_2" size="24px" color="primary" />
          <div class="text-h6 text-weight-bold">Search Stock Cross-Tenants</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none">
        <div class="row q-col-gutter-sm items-center">
          <div class="col-12 col-sm-4">
            <q-select
              v-model="searchBy"
              :options="searchByOptions"
              outlined
              dense
              emit-value
              map-options
              option-value="value"
              option-label="label"
              label="Search By"
              @update:model-value="onCriteriaChange"
            />
          </div>
          <div class="col-12 col-sm-8">
            <q-input
              v-model="searchQuery"
              :placeholder="getPlaceholder"
              outlined
              dense
              autofocus
              class="search-input"
              @update:model-value="onSearchInput"
            >
              <template #append>
                <q-spinner v-if="searchLoading" size="20px" color="primary" />
              </template>
            </q-input>
          </div>
        </div>
      </q-card-section>

      <q-card-section class="q-py-none scroll-area">
        <q-list separator v-if="groupedSearchResults.length">
          <q-item
            v-for="group in groupedSearchResults"
            :key="group.key"
            class="search-result-item q-py-sm"
          >
            <q-item-section avatar>
              <q-avatar rounded size="48px" class="bg-grey-2 shadow-1">
                <img
                  :src="group.image_url || 'https://placehold.co/48x48?text=No+Image'"
                  alt="product image"
                  style="object-fit: contain;"
                />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold row items-center justify-between">
                <span>{{ group.name }}</span>
                <span v-if="group.cost !== null" class="text-caption text-grey-8 text-weight-bold">
                  Cost: BDT {{ group.cost }}
                </span>
              </q-item-label>
              <q-item-label caption class="text-grey-7 row q-gutter-x-md">
                <span v-if="group.product_code">Code: {{ group.product_code }}</span>
                <span v-if="group.barcode">Barcode: {{ group.barcode }}</span>
                <span v-if="group.shipment?.shipment">Shipment: #{{ group.shipment.shipment.tenant_shipment_id ?? group.shipment.shipment.id }} - {{ group.shipment.shipment.name }}</span>
              </q-item-label>
              <div class="row items-center q-gutter-xs q-mt-xs">
                <q-chip
                  v-if="group.subtypes.standard && group.subtypes.standard.quantities.usable > 0"
                  clickable
                  @click="onSelectResult(group.subtypes.standard)"
                  dense
                  square
                  color="green-1"
                  text-color="green-8"
                  class="text-overline text-weight-bold animate-hover"
                >
                  Usable: {{ group.subtypes.standard.quantities.usable }}
                </q-chip>
                <q-chip
                  v-if="group.subtypes.boxless && group.subtypes.boxless.quantities.open_box > 0"
                  clickable
                  @click="onSelectResult(group.subtypes.boxless)"
                  dense
                  square
                  color="blue-1"
                  text-color="blue-8"
                  class="text-overline text-weight-bold animate-hover"
                >
                  Boxless: {{ group.subtypes.boxless.quantities.open_box }}
                </q-chip>
                <q-chip
                  v-if="group.subtypes.box_damage && group.subtypes.box_damage.quantities.open_box > 0"
                  clickable
                  @click="onSelectResult(group.subtypes.box_damage)"
                  dense
                  square
                  color="orange-1"
                  text-color="orange-8"
                  class="text-overline text-weight-bold animate-hover"
                >
                  Box Damage: {{ group.subtypes.box_damage.quantities.open_box }}
                </q-chip>
                <q-chip
                  v-if="group.subtypes.expired && group.subtypes.expired.quantities.expired > 0"
                  clickable
                  @click="onSelectResult(group.subtypes.expired)"
                  dense
                  square
                  color="purple-1"
                  text-color="purple-8"
                  class="text-overline text-weight-bold animate-hover"
                >
                  Expired: {{ group.subtypes.expired.quantities.expired }}
                </q-chip>
                <q-chip v-if="group.tenant_name" dense square color="grey-2" text-color="grey-8" class="text-overline text-weight-bold">
                  Tenant: {{ group.tenant_name }}
                </q-chip>
              </div>
            </q-item-section>
          </q-item>
        </q-list>

        <div v-else-if="searchQuery.trim()" class="text-center q-pa-xl text-grey-6">
          <q-icon name="info" size="36px" class="q-mb-xs" />
          <div>No stock items found matching your search.</div>
        </div>

        <div v-else class="text-center q-pa-xl text-grey-5">
          <q-icon name="manage_search" size="48px" class="q-mb-sm" />
          <div>Search for stock batches across all workspaces you belong to. Select search criteria above.</div>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>

  <!-- Open details modal directly if a search result is clicked -->
  <InventoryDetailsDialog
    v-model="detailsOpen"
    :item="selectedItem"
    @refresh="onItemUpdated"
  />
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { inventoryService } from 'src/modules/inventory/services/inventoryService'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import InventoryDetailsDialog from './InventoryDetailsDialog.vue'

type SearchCriteria = 'name' | 'barcode' | 'product_code' | 'product_id'

const props = defineProps<{
  modelValue: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void
}>()

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
})

const searchBy = ref<SearchCriteria>('name')
const searchQuery = ref('')
const searchResults = ref<InventoryItemWithStock[]>([])
const searchLoading = ref(false)

const detailsOpen = ref(false)
const selectedItem = ref<InventoryItemWithStock | null>(null)

const searchByOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Barcode', value: 'barcode' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Product ID', value: 'product_id' },
]

interface GroupedInventoryStock {
  key: string
  name: string
  image_url: string | null
  product_id: number | null
  barcode: string | null
  product_code: string | null
  cost: number | null
  tenant_name: string | null
  tenant_id: number
  shipment: InventoryItemWithStock['shipment']
  subtypes: {
    standard?: InventoryItemWithStock
    boxless?: InventoryItemWithStock
    box_damage?: InventoryItemWithStock
    expired?: InventoryItemWithStock
  }
}

const cleanName = (name: string) => {
  return name
    .replace(/\s*\(Boxless\)$/i, '')
    .replace(/\s*\(Box Damage\)$/i, '')
    .replace(/\s*\(Expired\)$/i, '')
    .replace(/\s*\(Stolen\/Missing\)$/i, '')
    .replace(/\s*\(Stolen\)$/i, '')
}

const getSubtypeFromItem = (item: { name: string }) => {
  const name = item.name || ''
  if (name.endsWith(' (Boxless)')) return 'boxless'
  if (name.endsWith(' (Box Damage)')) return 'box_damage'
  if (name.endsWith(' (Expired)')) return 'expired'
  if (name.endsWith(' (Stolen/Missing)') || name.endsWith(' (Stolen)')) return 'stolen'
  return 'standard'
}

const groupedSearchResults = computed<GroupedInventoryStock[]>(() => {
  const groups: Record<string, GroupedInventoryStock> = {}

  for (const item of searchResults.value) {
    const subtype = getSubtypeFromItem(item)
    if (subtype === 'stolen') continue

    const baseName = cleanName(item.name)
    const shipmentId = item.shipment?.shipment?.id ? String(Number(item.shipment.shipment.id)) : 'none'
    const key = `${item.tenant_id}_${item.product_id || baseName}_${shipmentId}`

    let group = groups[key]
    if (!group) {
      group = {
        key,
        name: baseName,
        image_url: item.image_url ?? null,
        product_id: item.product_id,
        barcode: item.barcode,
        product_code: item.product_code,
        cost: item.cost,
        tenant_name: item.tenant_name ?? null,
        tenant_id: item.tenant_id,
        shipment: item.shipment,
        subtypes: {},
      }
      groups[key] = group
    }

    group.subtypes[subtype] = item

    if (subtype === 'standard') {
      group.image_url = item.image_url || group.image_url
      group.barcode = item.barcode || group.barcode
      group.product_code = item.product_code || group.product_code
      group.cost = item.cost !== null ? item.cost : group.cost
    }
  }

  return Object.values(groups)
})

const getPlaceholder = computed(() => {
  switch (searchBy.value) {
    case 'name':
      return 'Search by product name...'
    case 'barcode':
      return 'Search by barcode...'
    case 'product_code':
      return 'Search by product code...'
    case 'product_id':
      return 'Search by numeric product ID...'
    default:
      return 'Type to search...'
  }
})

let debounceTimer: ReturnType<typeof setTimeout> | null = null

const runSearch = async () => {
  const query = searchQuery.value.trim()
  if (!query) {
    searchResults.value = []
    return
  }

  searchLoading.value = true
  try {
    const isProductIdSearch = searchBy.value === 'product_id'
    const productIdValue = Number(query)
    if (isProductIdSearch && !Number.isFinite(productIdValue)) {
      searchResults.value = []
      return
    }

    const res = await inventoryService.listGlobalInventoryItems({
      filters: {
        [searchBy.value]: isProductIdSearch ? productIdValue : query,
      },
      operators: {
        [searchBy.value]: isProductIdSearch ? 'eq' : 'ilike',
      },
      page: 1,
      page_size: 20,
      sortBy: 'id',
      sortOrder: 'desc',
    })

    if (res.success && res.data) {
      searchResults.value = res.data.data
    } else {
      searchResults.value = []
    }
  } catch (error) {
    console.error('Error during global stock search:', error)
    searchResults.value = []
  } finally {
    searchLoading.value = false
  }
}

const onSearchInput = () => {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    void runSearch()
  }, 350)
}

const onCriteriaChange = () => {
  if (searchQuery.value.trim()) {
    void runSearch()
  }
}

const onSelectResult = (item: InventoryItemWithStock) => {
  selectedItem.value = item
  detailsOpen.value = true
}

const onItemUpdated = () => {
  // Re-run search to get fresh quantities/data if we saved any details
  void runSearch()
}

watch(
  () => props.modelValue,
  (newVal) => {
    if (!newVal) {
      searchQuery.value = ''
      searchResults.value = []
      selectedItem.value = null
    }
  },
)
</script>

<style scoped>
.search-card {
  width: 90vw;
  max-width: 650px;
  background: rgba(255, 255, 255, 0.94);
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(10px);
}

.search-input {
  border-radius: 8px;
}

.scroll-area {
  max-height: 400px;
  overflow-y: auto;
  padding-bottom: 12px;
}

.search-result-item {
  border-radius: 8px;
  margin: 4px 8px;
  transition: background 0.15s ease;
}

.search-result-item:hover {
  background: rgba(37, 99, 235, 0.05);
}
</style>
