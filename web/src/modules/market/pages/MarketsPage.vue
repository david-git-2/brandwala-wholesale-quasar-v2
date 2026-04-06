<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Catalog</div>
          <h1 class="text-h5 q-my-none">Markets</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage platform ISO markets. System rows are protected.
          </p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" unelevated icon="add" label="Add Market" @click="onClickAddMarket" />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Market Catalog</div>
        </q-card-section>

        <q-card-section v-if="loading" class="text-grey-7">Loading markets...</q-card-section>

        <q-card-section v-else-if="items.length === 0" class="text-center">
          <div class="text-subtitle1">No markets found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">Create the first market to start the catalog.</div>
          <q-btn class="q-mt-md" color="primary" unelevated icon="add" label="Create Market" @click="onClickAddMarket" />
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="items"
          :columns="columns"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-name="props">
            <q-td :props="props">
              <div class="text-weight-medium">{{ props.row.name }}</div>
            </q-td>
          </template>

          <template #body-cell-code="props">
            <q-td :props="props">
              <q-badge color="primary" outline>{{ props.row.code }}</q-badge>
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props">
              <q-badge :color="props.row.is_active ? 'positive' : 'grey-6'">
                {{ props.row.is_active ? 'Active' : 'Inactive' }}
              </q-badge>
            </q-td>
          </template>

          <template #body-cell-is_system="props">
            <q-td :props="props">
              <q-badge :color="props.row.is_system ? 'teal' : 'grey-6'">
                {{ props.row.is_system ? 'System' : 'Custom' }}
              </q-badge>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <div class="row items-center justify-end q-gutter-xs no-wrap">
                <q-btn
                  flat
                  round
                  dense
                  icon="edit"
                  :disable="props.row.is_system"
                  @click="onClickEditMarket(props.row)"
                />
                <q-btn
                  flat
                  round
                  dense
                  color="negative"
                  icon="delete"
                  :disable="props.row.is_system"
                  @click="onClickDeleteMarket(props.row)"
                />
              </div>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <AddMarketDialog
      v-model="openAddDialog"
      :initial-data="selectedMarket"
      :existing-markets="items"
      @save="handleSaveMarket"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete
          <strong>{{ marketToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteMarket" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import type { QTableColumn } from 'quasar'

import { showWarningDialog } from 'src/utils/appFeedback'
import AddMarketDialog from '../components/AddMarketDialog.vue'
import { useMarketStore } from '../stores/marketStore'
import type {
  Market,
  MarketCreateInput,
  MarketDeleteInput,
  MarketUpdateInput,
} from '../types'

type MarketForm = {
  id?: number
  name: string
  code: string
  is_active: boolean
  is_system: boolean
  region: string
}

const marketStore = useMarketStore()
const { items, loading, error } = storeToRefs(marketStore)

const columns: QTableColumn[] = [
  {
    name: 'id',
    label: 'ID',
    field: 'id',
    align: 'left',
    sortable: true,
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'code',
    label: 'Code',
    field: 'code',
    align: 'left',
    sortable: true,
  },
  {
    name: 'region',
    label: 'Region',
    field: 'region',
    align: 'left',
    sortable: true,
  },
  {
    name: 'is_active',
    label: 'Status',
    field: 'is_active',
    align: 'left',
    sortable: true,
  },
  {
    name: 'is_system',
    label: 'Type',
    field: 'is_system',
    align: 'left',
    sortable: true,
  },
  {
    name: 'actions',
    label: 'Actions',
    field: 'id',
    align: 'right',
  },
]

const openAddDialog = ref(false)
const openDeleteDialog = ref(false)
const selectedMarket = ref<MarketForm | null>(null)
const marketToDelete = ref<Market | null>(null)

const onClickAddMarket = () => {
  selectedMarket.value = null
  openAddDialog.value = true
}

const onClickEditMarket = (market: Market) => {
  if (market.is_system) {
    showWarningDialog('System markets cannot be edited.', 'System market protected')
    return
  }

  selectedMarket.value = { ...market }
  openAddDialog.value = true
}

const onClickDeleteMarket = (market: Market) => {
  if (market.is_system) {
    showWarningDialog('System markets cannot be deleted.', 'System market protected')
    return
  }

  marketToDelete.value = market
  openDeleteDialog.value = true
}

const refreshMarkets = () => marketStore.fetchMarkets()

const handleSaveMarket = async (payload: MarketForm) => {
  if (payload.id !== undefined) {
    const updatePayload: MarketUpdateInput = {
      id: payload.id,
      name: payload.name,
      code: payload.code,
      is_active: payload.is_active,
      is_system: payload.is_system,
      region: payload.region,
    }

    await marketStore.updateMarket(updatePayload)
    return
  }

  const createPayload: MarketCreateInput = {
    name: payload.name,
    code: payload.code,
    is_active: payload.is_active,
    is_system: payload.is_system,
    region: payload.region,
  }

  await marketStore.createMarket(createPayload)
}

const confirmDeleteMarket = async () => {
  if (marketToDelete.value) {
    const deletePayload: MarketDeleteInput = {
      id: marketToDelete.value.id,
    }

    await marketStore.deleteMarket(deletePayload)
  }

  openDeleteDialog.value = false
}

onMounted(() => {
  void refreshMarkets()
})
</script>
