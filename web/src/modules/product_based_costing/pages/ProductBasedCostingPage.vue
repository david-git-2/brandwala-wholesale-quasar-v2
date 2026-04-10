<template>
  <q-page class="q-pa-lg">
    <div class="text-h6 q-mb-md">Product Based Costing</div>

    <div v-if="store.loading">loading</div>

    <div v-else-if="store.error">
      error: {{ store.error }}
    </div>

    <div v-else>
      <p>Product Based Costing Data</p>

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


const store = useProductBasedCostingStore()

onMounted(() => {
  void store.fetchProductBasedCostingFiles()
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
}
</script>
