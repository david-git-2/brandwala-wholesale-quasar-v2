<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-black">Investor Shipments</div>
            <div class="text-caption text-grey-8">Cost-share and computed profit per shipment</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
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
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          label="Search investor or shipment"
          @clear="onCloseSearch"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>
      </div>
    </div>

    <PageInitialLoader v-if="loading && !rows.length" />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>{{ error }}</q-banner>

    <q-card v-else flat class="floating-surface shadow-1">
      <q-table
        flat
        row-key="id"
        :rows="filteredRows"
        :columns="columns"
        :pagination="{ rowsPerPage: 0 }"
        hide-bottom
      >
        <template #body-cell-shipment_id="props">
          <q-td :props="props">
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              :label="`#${shipmentLabel(props.row.shipment_id)}`"
              @click="goToShipmentDetails(props.row.shipment_id)"
            />
          </q-td>
        </template>
        <template #body-cell-investor_id="props">
          <q-td :props="props">{{ investorName(props.row.investor_id) }}</q-td>
        </template>
        <template #body-cell-invested_amount="props">
          <q-td :props="props" class="text-right">{{ formatAmount(props.row.invested_amount) }}</q-td>
        </template>
        <template #body-cell-cost_share_pct="props">
          <q-td :props="props" class="text-right">{{ props.row.cost_share_pct ?? '—' }}%</q-td>
        </template>
        <template #body-cell-computed_profit="props">
          <q-td
            :props="props"
            class="text-right text-weight-medium"
            :class="Number(props.row.computed_profit) >= 0 ? 'text-positive' : 'text-negative'"
          >
            {{ formatAmount(props.row.computed_profit) }}
          </q-td>
        </template>
        <template #body-cell-profit_status="props">
          <q-td :props="props">
            <span class="entry-status-chip">{{ props.row.profit_status }}</span>
          </q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn flat round dense icon="open_in_new" @click="goToShipmentDetails(props.row.shipment_id)">
              <q-tooltip>Manage on shipment</q-tooltip>
            </q-btn>
          </q-td>
        </template>
        <template #no-data>
          <div class="full-width text-center text-grey-7 q-py-md">No shipment investments.</div>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { QTableColumn } from 'quasar'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvestorStore } from 'src/modules/investor/stores/investorStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { formatAmountBdt } from 'src/utils/currency'

import { globalRepository } from '../repositories/globalRepository'
import type { GlobalShipmentInvestmentRow } from '../types'

const authStore = useAuthStore()
const investorStore = useInvestorStore()
const shipmentStore = useShipmentStore()
const router = useRouter()
const route = useRoute()

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<GlobalShipmentInvestmentRow[]>([])
const showSearchInput = ref(false)
const searchText = ref('')

const columns: QTableColumn[] = [
  { name: 'shipment_id', label: 'Shipment', field: 'shipment_id', align: 'left' },
  { name: 'investor_id', label: 'Investor', field: 'investor_id', align: 'left' },
  { name: 'invested_amount', label: 'Invested', field: 'invested_amount', align: 'right' },
  { name: 'cost_share_pct', label: 'Share %', field: 'cost_share_pct', align: 'right' },
  { name: 'computed_profit', label: 'Profit', field: 'computed_profit', align: 'right' },
  { name: 'profit_status', label: 'Status', field: 'profit_status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
]

const formatAmount = (value: number) => formatAmountBdt(value)

const investorName = (investorId: number) => {
  const investor = investorStore.investors.find((item) => item.id === investorId)
  return investor?.name ?? `Investor #${investorId}`
}

const shipmentLabel = (shipmentId: number) => {
  const shipment = shipmentStore.shipments.find((item) => item.id === shipmentId)
  return shipment?.tenant_shipment_id ?? shipmentId
}

const filteredRows = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  if (!search) return rows.value

  return rows.value.filter((row) => {
    const investor = investorName(row.investor_id).toLowerCase()
    const shipment = String(shipmentLabel(row.shipment_id))
    return investor.includes(search) || shipment.includes(search)
  })
})

const goToShipmentDetails = async (shipmentId: number) => {
  await router.push({
    name: 'app-investor-shipment-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: shipmentId,
    },
  })
}

const onCloseSearch = () => {
  showSearchInput.value = false
  searchText.value = ''
}

const load = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
  try {
    const [investments] = await Promise.all([
      globalRepository.listGlobalShipmentInvestments(tenantId),
      investorStore.fetchInvestorsByTenant(tenantId),
      shipmentStore.fetchShipments(tenantId),
    ])
    rows.value = investments
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load investments.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
