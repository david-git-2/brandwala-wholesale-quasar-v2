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
        <q-list separator v-if="searchResults.length">
          <q-item
            v-for="item in searchResults"
            :key="item.id"
            clickable
            @click="onSelectResult(item)"
            class="search-result-item"
          >
            <q-item-section avatar>
              <q-avatar rounded size="48px" class="bg-grey-2 shadow-1">
                <img
                  :src="item.image_url || 'https://placehold.co/48x48?text=No+Image'"
                  alt="product image"
                  style="object-fit: contain;"
                />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold row items-center justify-between">
                <span>{{ item.name }}</span>
                <span v-if="item.cost !== null" class="text-caption text-grey-8 text-weight-bold">
                  Cost: BDT {{ item.cost }}
                </span>
              </q-item-label>
              <q-item-label caption class="text-grey-7 row q-gutter-x-md">
                <span v-if="item.product_code">Code: {{ item.product_code }}</span>
                <span v-if="item.barcode">Barcode: {{ item.barcode }}</span>
                <span>ID: {{ item.id }}</span>
              </q-item-label>
              <div class="row items-center q-gutter-xs q-mt-xs">
                <q-chip dense square color="green-1" text-color="green-8" class="text-overline text-weight-bold">
                  Usable: {{ item.quantities.usable }}
                </q-chip>
                <q-chip v-if="item.quantities.open_box" dense square color="blue-1" text-color="blue-8" class="text-overline text-weight-bold">
                  Open Box: {{ item.quantities.open_box }}
                </q-chip>
                <q-chip v-if="item.quantities.damaged" dense square color="red-1" text-color="red-8" class="text-overline text-weight-bold">
                  Damaged: {{ item.quantities.damaged }}
                </q-chip>
                <q-chip v-if="item.tenant_name" dense square color="purple-1" text-color="purple-8" class="text-overline text-weight-bold">
                  Tenant: {{ item.tenant_name }}
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
