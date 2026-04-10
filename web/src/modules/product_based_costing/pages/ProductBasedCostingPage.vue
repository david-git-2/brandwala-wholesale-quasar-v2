<template>
  <q-page class="q-pa-lg">
    <div class="text-h6 q-mb-md">Product Based Costing</div>

    <div v-if="store.loading">loading</div>

    <div v-else-if="store.error">
      error: {{ store.error }}
    </div>

    <div v-else>
      <p>Product Based Costing Data</p>

      <div class="row q-gutter-sm">
        <q-btn
          color="primary"
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

function openEditDialog(row: CostingFileForm) {
  selectedRow.value = { ...row }
  dialogOpen.value = true
}

function handleDialogSubmit(payload: CostingFileForm) {
  if (payload.id) {
    console.log('Edit mode payload:', payload)
    store.updateProductBasedCostingFile(
      {id: payload.id,
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note}
    )
  } else {
    console.log('Create mode payload:', payload)
    store.createProductBasedCostingFile({
      name: payload.name,
      order_for: payload.order_for,
      note: payload.note
    })
  }
}

const onSelect = (item) => {
  const tenantSlug = route.params.tenantSlug

  router.push({
    name: 'product-based-costing-file-details-page',
    params: {
      tenantSlug,
      id: item.id,
    },
  })
}



const onDelete = (item) => {
  console.log('delete', item)
  store.deleteProductBasedCostingFile(item.id)
}
</script>
