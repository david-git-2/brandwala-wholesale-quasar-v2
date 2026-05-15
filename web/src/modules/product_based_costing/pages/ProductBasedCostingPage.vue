<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Product Based Costing</div>
            <div class="text-caption text-grey-8">Manage costing files and open details</div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Create Costing File"
              @click="openCreateDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="store.loading" />

    <div v-else-if="store.error">
      error: {{ store.error }}
    </div>

    <div v-else>
      <div class="row items-center justify-between q-mb-sm">
        <div class="row items-center q-gutter-sm toolbar-left">
          <q-btn
            v-if="!showSearchInput"
            flat
            round
            dense
            icon="search"
            aria-label="Show search"
            @click="showSearchInput = true"
          />

          <q-input
            v-else
            v-model="searchText"
            outlined
            dense
            class="soft-input toolbar-search"
            label="Search"
            clearable
            autofocus
            @keyup.enter="onApplyFilters"
            @clear="onApplyFilters"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn
                flat
                round
                dense
                icon="close"
                aria-label="Hide search"
                @click="
                  () => {
                    searchText = ''
                    showSearchInput = false
                    onApplyFilters()
                  }
                "
              />
            </template>
          </q-input>

          <q-btn
            flat
            round
            dense
            icon="filter_alt"
            aria-label="Filters"
            @click="openFilterDrawer"
          >
            <q-badge
              v-if="activeFilterCount > 0"
              color="primary"
              rounded
              floating
            >
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>

        <q-btn-toggle
          v-model="viewMode"
          dense
          unelevated
          no-caps
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="[
            { icon: 'table_rows', value: 'table' },
            { icon: 'grid_view', value: 'card' },
          ]"
        />
      </div>

      <q-card v-if="viewMode === 'table'" flat class="floating-surface shadow-1">
        <q-table
          flat
          :rows="store.items"
          :columns="tableColumns"
          row-key="id"
          :loading="store.loading"
          :pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          @request="onTableRequest"
          class="costing-list-table"
        >
          <template #body="slotProps">
            <q-tr
              :props="slotProps"
              class="cursor-pointer"
              :style="statusSurfaceStyle(slotProps.row.status)"
              @click="onSelect(slotProps.row)"
            >
              <q-td key="id" :props="slotProps">#{{ slotProps.row.id }}</q-td>
              <q-td key="name" :props="slotProps">{{ slotProps.row.name ?? '-' }}</q-td>
              <q-td key="order_for" :props="slotProps">{{ slotProps.row.order_for ?? '-' }}</q-td>
              <q-td key="status" :props="slotProps">
                <q-chip
                  dense
                  square
                  :style="statusChipStyle(slotProps.row.status)"
                  class="costing-status-chip"
                >
                  <span class="status-dot" :style="{ backgroundColor: statusDotColor(slotProps.row.status) }" />
                  {{ slotProps.row.status ?? 'pending' }}
                </q-chip>
              </q-td>
              <q-td key="actions" :props="slotProps" class="text-right">
                <q-btn flat round dense icon="more_vert" aria-label="Costing file actions" @click.stop>
                  <q-menu auto-close>
                    <q-list dense style="min-width: 120px">
                      <q-item clickable v-ripple @click="onCopy(slotProps.row)">
                        <q-item-section>Copy</q-item-section>
                      </q-item>
                      <q-item clickable v-ripple @click="openEditDialog(slotProps.row)">
                        <q-item-section>Edit</q-item-section>
                      </q-item>
                      <q-item clickable v-ripple @click="onDelete(slotProps.row)">
                        <q-item-section class="text-negative">Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </q-td>
            </q-tr>
          </template>
        </q-table>
      </q-card>
      <div v-else>
        <CostingFileCard
          :items="store.items"
          @select="onSelect"
          @copy="onCopy"
          @edit="openEditDialog"
          @delete="onDelete"
        />
      </div>

      <div v-if="viewMode !== 'table' && store.total_pages > 1" class="row justify-center q-mt-md">
        <q-pagination
          v-model="page"
          :max="store.total_pages"
          :max-pages="8"
          boundary-numbers
          direction-links
          @update:model-value="onPageChange"
        />
      </div>
    </div>

    <ProductBasedCostingFileDialog
      v-model="dialogOpen"
      :data="selectedRow"
      @submit="handleDialogSubmit"
    />

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="draftStatusFilter"
        :options="statusFilterOptions"
        outlined
        dense
        class="soft-input q-mb-md"
        emit-value
        map-options
        label="Status"
        @update:model-value="onDrawerStatusChange"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar, type QTableColumn } from 'quasar'
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import { useRouter, useRoute } from 'vue-router'
import type { ProductBasedCostingFile } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { productBasedCostingService } from '../services/productBasedCostingService'
import CostingFileCard from '../components/CostingFileCard.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'


const store = useProductBasedCostingStore()
const $q = useQuasar()
const page = ref(1)
const searchText = ref('')
const showSearchInput = ref(false)
const statusFilter = ref<string>('__all__')
const draftStatusFilter = ref<string>('__all__')
const filterDrawerOpen = ref(false)
const viewMode = ref<'table' | 'card'>('table')
const tablePagination = ref({
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
})
const tableColumns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'order_for', label: 'Created For', field: 'order_for', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
]

const statusFilterOptions = [
  { label: 'All', value: '__all__' },
  { label: 'Pending', value: '__pending__' },
  { label: 'Offered', value: 'offered' },
  { label: 'Processing', value: 'processing' },
  { label: 'Cancelled', value: 'cancelled' },
]

const activeFilterCount = computed(() => (statusFilter.value !== '__all__' ? 1 : 0))

const loadFiles = async () => {
  const payload: {
    page: number
    page_size: number
    search?: string
    status?: string | null
  } = {
    page: page.value,
    page_size: store.page_size,
  }

  const searchValue = searchText.value.trim()
  if (searchValue) {
    payload.search = searchValue
  }

  if (statusFilter.value === '__pending__') {
    payload.status = null
  } else if (statusFilter.value !== '__all__') {
    payload.status = statusFilter.value
  }

  await store.fetchProductBasedCostingFiles(payload)
  tablePagination.value = {
    ...tablePagination.value,
    page: store.page,
    rowsPerPage: store.page_size,
    rowsNumber: store.total,
  }
}

onMounted(() => {
  void loadFiles()
})

const router = useRouter()
const route = useRoute()

type CostingFileForm = {
  id: number | null
  name: string
  order_for: string
  note: string
  vendor_code: string | null
  market_code: string | null
}

const dialogOpen = ref(false)
const selectedRow = ref<CostingFileForm | null>(null)



function openCreateDialog() {
  selectedRow.value = null
  dialogOpen.value = true
}

function openEditDialog(row: ProductBasedCostingFile) {
  selectedRow.value = {
    id: row.id,
    name: row.name ?? '',
    order_for: row.order_for ?? '',
    note: row.note ?? '',
    vendor_code: row.vendor_code ?? null,
    market_code: row.market_code ?? null,
  }
  dialogOpen.value = true
}

async function handleDialogSubmit(payload: CostingFileForm) {
  if (payload.id) {
    console.log('Edit mode payload:', payload)
    await store.updateProductBasedCostingFile(
      {id: payload.id,
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code}
    )
  } else {
    console.log('Create mode payload:', payload)
    await store.createProductBasedCostingFile({
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note,
      vendor_code: payload.vendor_code,
      market_code: payload.market_code
    })
  }
  await loadFiles()
}

const onSelect = async (item: ProductBasedCostingFile) => {
  const tenantSlug = route.params.tenantSlug

  await router.push({
    name: 'product-based-costing-file-details-page',
    params: {
      tenantSlug,
      id: item.id,
    },
  })
}



const onDelete = async (item: ProductBasedCostingFile) => {
  console.log('delete', item)
  await store.deleteProductBasedCostingFile(item.id)
  await loadFiles()
}

const onCopy = async (item: ProductBasedCostingFile) => {
  const fileName = (item.name ?? '').trim()
  const nextName = fileName.length > 0 ? `${fileName} Copy` : `File #${item.id} Copy`

  const fileCreateResult = await productBasedCostingService.createProductBasedCostingFile({
    tenant_id: item.tenant_id ?? null,
    name: nextName,
    order_for: item.order_for ?? null,
    note: item.note ?? null,
    vendor_code: item.vendor_code ?? null,
    market_code: item.market_code ?? null,
    cargo_rate_kg_gbp: item.cargo_rate_kg_gbp ?? null,
    profit_rate: item.profit_rate ?? null,
    conversion_rate: item.conversion_rate ?? null,
    // Copy should always start as a draft file.
    status: 'pending',
  })

  if (!fileCreateResult.success || !fileCreateResult.data?.id) {
    return
  }

  const sourceItemsResult = await productBasedCostingService.listProductBasedCostingItems(item.id)
  if (!sourceItemsResult.success) {
    await loadFiles()
    return
  }

  const copiedFileId = fileCreateResult.data.id
  const sourceItems = sourceItemsResult.data ?? []
  const copyItemTasks = sourceItems.map((sourceItem) =>
    productBasedCostingService.createProductBasedCostingItem({
      product_based_costing_file_id: copiedFileId,
      product_id: sourceItem.product_id ?? null,
      name: sourceItem.name ?? null,
      image_url: sourceItem.image_url ?? null,
      note: sourceItem.note ?? null,
      quantity: sourceItem.quantity ?? null,
      barcode: sourceItem.barcode ?? null,
      product_code: sourceItem.product_code ?? null,
      brand: sourceItem.brand ?? null,
      vendor_code: sourceItem.vendor_code ?? null,
      market_code: sourceItem.market_code ?? null,
      web_link: sourceItem.web_link ?? null,
      price_gbp: sourceItem.price_gbp ?? null,
      product_weight: sourceItem.product_weight ?? null,
      package_weight: sourceItem.package_weight ?? null,
      offer_price: sourceItem.offer_price ?? null,
      // Reset copied items to draft state.
      status: 'pending',
      input_type: sourceItem.input_type ?? null,
      assigned_shipment_id: null,
    }),
  )

  await Promise.allSettled(copyItemTasks)
  await loadFiles()

  $q.notify({
    type: 'positive',
    message: `Copied as #${copiedFileId} ${nextName}`,
  })
}

const onApplyFilters = async () => {
  page.value = 1
  await loadFiles()
}

const normalizeStatus = (status: string | null | undefined) => {
  const value = (status ?? '').trim().toLowerCase()
  return value || 'pending'
}

const statusSurfaceStyle = (status: string | null | undefined) => {
  const value = normalizeStatus(status)
  if (value === 'pending') {
    return {
      backgroundColor: '#fffbf2',
      boxShadow: 'inset 6px 0 0 #d8a54a',
    }
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#f3f7ff',
      boxShadow: 'inset 6px 0 0 #6f93d8',
    }
  }
  if (value === 'processing') {
    return {
      backgroundColor: '#f2fbf6',
      boxShadow: 'inset 6px 0 0 #59aa7d',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#fff4f6',
      boxShadow: 'inset 6px 0 0 #c97586',
    }
  }
  return {
    backgroundColor: '#f8f9fb',
    boxShadow: 'inset 6px 0 0 #8ea0b8',
  }
}

const statusChipStyle = (status: string | null | undefined) => {
  const value = normalizeStatus(status)
  if (value === 'pending') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
      boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
    }
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
      boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
    }
  }
  if (value === 'processing') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
      boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
      boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
    }
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
    boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  }
}

const statusDotColor = (status: string | null | undefined) => {
  const value = normalizeStatus(status)
  if (value === 'pending') return '#9a6a24'
  if (value === 'offered') return '#3f67b3'
  if (value === 'processing') return '#2f8b5d'
  if (value === 'cancelled') return '#a64c62'
  return '#66758c'
}

const onResetFilters = async () => {
  searchText.value = ''
  statusFilter.value = '__all__'
  draftStatusFilter.value = '__all__'
  page.value = 1
  filterDrawerOpen.value = false
  await loadFiles()
}

const onPageChange = async (nextPage: number) => {
  page.value = nextPage
  await loadFiles()
}

const onTableRequest = async (payload: {
  pagination: { page: number; rowsPerPage: number; rowsNumber?: number }
}) => {
  page.value = payload.pagination.page
  store.page_size = payload.pagination.rowsPerPage
  await loadFiles()
}

const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value
  filterDrawerOpen.value = true
}

const onApplyDrawerFilters = async () => {
  statusFilter.value = draftStatusFilter.value
  page.value = 1
  await loadFiles()
}

const onDrawerStatusChange = async () => {
  await onApplyDrawerFilters()
}
</script>

<style scoped>
.costing-list-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.costing-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}

</style>
