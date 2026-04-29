<template>
  <q-page class="q-pa-lg">
    <div class="text-h6 q-mb-md">Product Based Costing</div>

    <PageInitialLoader v-if="store.loading" />

    <div v-else-if="store.error">
      error: {{ store.error }}
    </div>

    <div v-else>
      <p>Product Based Costing Data</p>

      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-4">
          <q-input
            v-model="searchText"
            outlined
            dense
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
            emit-value
            map-options
            label="Status"
            @update:model-value="onApplyFilters"
          />
        </div>
        <div class="col-12 col-md-3 row items-center q-gutter-sm">
          <q-btn flat label="Reset" @click="onResetFilters" />
        </div>
      </div>

      <div class="row justify-end q-mb-md">
        <q-btn
          color="primary"
          no-caps
          label="Create Costing File"
          @click="openCreateDialog"

        />


      </div>

      <CostingFileCard :items="store.items"  @select="onSelect"
  @edit="openEditDialog"
  @delete="onDelete"/>

      <div v-if="store.total_pages > 1" class="row justify-center q-mt-md">
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
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import CostingFileCard from '../components/CostingFileCard.vue'
import { useRouter, useRoute } from 'vue-router'
import type { ProductBasedCostingFile } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'


const store = useProductBasedCostingStore()
const page = ref(1)
const searchText = ref('')
const statusFilter = ref<string | null>(null)

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
      note: payload.note}
    )
  } else {
    console.log('Create mode payload:', payload)
    await store.createProductBasedCostingFile({
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note
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

const onApplyFilters = async () => {
  page.value = 1
  await loadFiles()
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
</script>
