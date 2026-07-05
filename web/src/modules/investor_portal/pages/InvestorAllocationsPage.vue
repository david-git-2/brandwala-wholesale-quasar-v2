<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Capital Deployment"
        subtitle="Detailed record of capital allocation across shipment batches"
      />
    </q-card>

    <PageInitialLoader v-if="loading" message="Loading allocations..." />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <template v-else>
      <q-card flat class="floating-surface shadow-1 q-pa-md">
        <q-markup-table flat bordered wrap-cells>
          <thead>
            <tr>
              <th class="text-left">SL</th>
              <th class="text-left">Shipment batch</th>
              <th class="text-left">Status</th>
              <th class="text-right">Cost share %</th>
              <th class="text-right">Allocated cost</th>
              <th class="text-right">Computed profit</th>
              <th class="text-left">Profit status</th>
              <th class="text-left">Created at</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!allocations.length">
              <td colspan="8" class="text-center text-grey-7">No allocations found.</td>
            </tr>
            <tr v-for="(row, index) in allocations" :key="row.id">
              <td>{{ offset + index + 1 }}</td>
              <td class="text-left">#{{ row.global_shipment_id }} - {{ row.shipment_name ?? 'Unnamed shipment' }}</td>
              <td class="text-left text-capitalize">{{ row.shipment_status }}</td>
              <td class="text-right">{{ row.cost_share_pct }}%</td>
              <td class="text-right">{{ formatCurrency(row.allocated_cost) }}</td>
              <td class="text-right">{{ formatCurrency(row.computed_profit) }}</td>
              <td class="text-left text-capitalize">{{ row.profit_status }}</td>
              <td class="text-left">{{ formatDate(row.created_at) }}</td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="row items-center justify-end q-mt-md q-gutter-sm">
          <q-btn
            flat
            round
            dense
            icon="chevron_left"
            :disable="page === 1"
            @click="prevPage"
          />
          <span class="text-caption">Page {{ page }} of {{ totalPages }}</span>
          <q-btn
            flat
            round
            dense
            icon="chevron_right"
            :disable="page >= totalPages"
            @click="nextPage"
          />
        </div>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'

import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvestorPortalStore } from '../stores/investorPortalStore'

const authStore = useAuthStore()
const investorPortalStore = useInvestorPortalStore()
const { allocations, totalAllocationsCount } = storeToRefs(investorPortalStore)

const loading = ref(true)
const error = ref<string | null>(null)

const page = ref(1)
const limit = 20
const offset = computed(() => (page.value - 1) * limit)
const totalPages = computed(() => Math.ceil(totalAllocationsCount.value / limit) || 1)

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT', maximumFractionDigits: 0 }).format(
    Number(value ?? 0),
  )

const formatDate = (value: string) => {
  if (!value) return '-'
  return new Date(value).toLocaleDateString()
}

const loadData = async () => {
  loading.value = true
  const tenantId = authStore.tenantId
  const investorId = authStore.member?.id

  if (!tenantId || !investorId) {
    error.value = 'Auth session context invalid.'
    loading.value = false
    return
  }

  const result = await investorPortalStore.fetchAllocations(tenantId, investorId, limit, offset.value)
  if (!result.success) {
    error.value = result.error ?? 'Failed to load allocations.'
  }
  loading.value = false
}

const nextPage = () => {
  if (page.value < totalPages.value) {
    page.value++
    void loadData()
  }
}

const prevPage = () => {
  if (page.value > 1) {
    page.value--
    void loadData()
  }
}

onMounted(() => {
  void loadData()
})
</script>
