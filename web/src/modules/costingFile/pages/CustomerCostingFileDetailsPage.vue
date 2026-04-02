<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section>
        <h1 class="text-h5 q-my-none">Costing file details</h1>
      </section>

      <q-card v-if="selectedFile" flat bordered>
        <q-card-section>
          <p class="q-my-none text-body2 text-grey-7">{{ selectedFile.name }} | {{ selectedFile.market }} | {{ selectedFile.status }}</p>
        </q-card-section>

        <q-card-section>
          <div class="costing-page__request-grid">
            <q-input v-model="requestForm.websiteUrl" label="Web link" outlined dense color="primary" />
            <q-input v-model.number="requestForm.quantity" label="Qty" type="number" outlined dense color="primary" />
            <q-btn
              color="primary"
              unelevated
              label="Save"
              :loading="creatingRequest"
              :disable="!canCreateRequestDraft"
              @click="handleAddRequestDraft"
            />
          </div>
        </q-card-section>

        <q-card-section>
          <q-markup-table v-if="requestDraftRows.length" flat bordered>
            <thead>
              <tr>
                <th>SL</th>
                <th>Web link</th>
                <th>Qty</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in requestDraftRows" :key="row.id">
                <td>{{ row.sl }}</td>
                <td>{{ row.websiteUrl }}</td>
                <td>{{ row.quantity }}</td>
                <td>
                  <q-btn flat round dense icon="delete" color="negative" @click="removeRequestDraft(Number(row.id))" />
                </td>
              </tr>
            </tbody>
          </q-markup-table>
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn
            color="primary"
            unelevated
            label="Submit"
            :loading="creatingRequest"
            :disable="!requestDrafts.length"
            @click="handleSubmitRequestList"
          />
        </q-card-actions>

        <q-table
          v-if="selectedFile.status !== 'draft'"
          flat
          bordered
          row-key="id"
          :rows="productRows"
          :columns="productColumns"
          :loading="loadingItems"
          hide-bottom
        />
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'

import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { showSuccessNotification } from 'src/utils/appFeedback'

const route = useRoute()
const costingFileStore = useCostingFileStore()
const {
  selectedItem: selectedFile,
  costingFileItems: itemForms,
  itemLoading: loadingItems,
} = storeToRefs(costingFileStore)

const creatingRequest = ref(false)
const nextDraftId = ref(1)

const requestDrafts = ref<{ id: number; websiteUrl: string; quantity: number }[]>([])

const requestForm = reactive({
  websiteUrl: '',
  quantity: 1,
})

const canCreateRequestDraft = computed(
  () => requestForm.websiteUrl.trim().length > 0 && Number(requestForm.quantity) > 0,
)

const requestDraftRows = computed(() =>
  requestDrafts.value.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    websiteUrl: item.websiteUrl,
    quantity: item.quantity,
    remove: item.id,
  })),
)

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

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!fileId) return
  await costingFileStore.fetchCostingFileWithItems(fileId)
}

const refreshSelectedFile = async () => {
  await loadFile()
}

const handleAddRequestDraft = () => {
  requestDrafts.value.push({
    id: nextDraftId.value,
    websiteUrl: requestForm.websiteUrl.trim(),
    quantity: Math.max(1, Number(requestForm.quantity || 1)),
  })
  nextDraftId.value += 1
  requestForm.websiteUrl = ''
  requestForm.quantity = 1
}

const removeRequestDraft = (draftId: number) => {
  requestDrafts.value = requestDrafts.value.filter((item) => item.id !== draftId)
}

const handleSubmitRequestList = async () => {
  if (!selectedFile.value || !requestDrafts.value.length) return

  creatingRequest.value = true
  try {
    for (const draft of requestDrafts.value) {
      const result = await costingFileStore.createCostingFileItemRequest({
        costingFileId: selectedFile.value.id,
        websiteUrl: draft.websiteUrl,
        quantity: draft.quantity,
      })

      if (!result.success) {
        return
      }
    }

    requestDrafts.value = []
    showSuccessNotification('Request list submitted.')
    await refreshSelectedFile()
  } finally {
    creatingRequest.value = false
  }
}

onMounted(async () => {
  await loadFile()
})
</script>

<style scoped>
.costing-page__request-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
}

@media (max-width: 900px) {
  .costing-page__request-grid {
    grid-template-columns: 1fr;
  }
}
</style>
