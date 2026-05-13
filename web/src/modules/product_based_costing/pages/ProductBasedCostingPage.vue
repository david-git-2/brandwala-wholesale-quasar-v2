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
      <q-card flat class="q-mb-md floating-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row q-col-gutter-sm items-center">
            <div class="col-12 col-md-5">
              <q-input
                v-model="searchText"
                outlined
                dense
                class="soft-input"
                label="Search"
                clearable
                @keyup.enter="onApplyFilters"
              />
            </div>
            <div class="col-12 col-md-3">
              <q-select
                v-model="statusFilter"
                :options="statusFilterOptions"
                outlined
                dense
                class="soft-input"
                emit-value
                map-options
                label="Status"
                @update:model-value="onApplyFilters"
              />
            </div>
            <div class="col-12 col-md-auto">
              <q-btn flat no-caps size="sm" class="pill-btn slim-btn" label="Reset" @click="onResetFilters" />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <div class="row justify-end q-mb-sm">
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
            <q-tr :props="slotProps" class="cursor-pointer" @click="onSelect(slotProps.row)">
              <q-td key="id" :props="slotProps">#{{ slotProps.row.id }}</q-td>
              <q-td key="name" :props="slotProps">{{ slotProps.row.name ?? '-' }}</q-td>
              <q-td key="order_for" :props="slotProps">{{ slotProps.row.order_for ?? '-' }}</q-td>
              <q-td key="status" :props="slotProps">
                <q-chip
                  dense
                  square
                  :color="statusChipColor(slotProps.row.status)"
                  text-color="white"
                  class="costing-status-chip"
                >
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
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useQuasar, type QTableColumn } from 'quasar'
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import { useRouter, useRoute } from 'vue-router'
import type { ProductBasedCostingFile } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { productBasedCostingService } from '../services/productBasedCostingService'
import CostingFileCard from '../components/CostingFileCard.vue'


const store = useProductBasedCostingStore()
const $q = useQuasar()
const page = ref(1)
const searchText = ref('')
const statusFilter = ref<string | null>(null)
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
  { label: 'All', value: null as string | null },
  { label: 'Pending', value: 'pending' },
  { label: 'Offered', value: 'offered' },
  { label: 'Processing', value: 'processing' },
  { label: 'Cancelled', value: 'cancelled' },
]

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

  if (statusFilter.value !== null) {
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
  const sourceItems = sourceItemsResult.data?.data ?? []
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

const statusChipColor = (status: string | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'pending') return 'grey-7'
  if (value === 'offered') return 'indigo'
  if (value === 'processing') return 'teal'
  if (value === 'cancelled') return 'negative'
  return 'primary'
}

const onResetFilters = async () => {
  searchText.value = ''
  statusFilter.value = null
  page.value = 1
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
  border-radius: 4px !important;
}
</style>
