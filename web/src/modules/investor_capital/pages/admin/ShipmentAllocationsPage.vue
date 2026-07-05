<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Tenant</div>
          <h1 class="text-h5 q-my-none">Shipment Cost Share Allocations</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Track investor funding coverage and parent remainder shares across batches.
          </p>
        </div>
      </section>

      <q-card flat bordered>
        <q-table
          flat
          row-key="id"
          :rows="shipmentStore.shipments"
          :columns="columns"
          :loading="shipmentStore.loading || loadingShares"
          :pagination="{ rowsPerPage: 20 }"
          :dense="$q.screen.lt.md"
          @row-click="(evt, row) => onSelectShipment(row.id)"
          class="cursor-pointer"
        >
          <template #body-cell-id="props">
            <q-td :props="props" class="text-weight-bold text-primary">
              #{{ props.row.tenant_shipment_id || props.row.id }}
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props" class="text-weight-bold">
              {{ props.row.name ?? '-' }}
            </q-td>
          </template>

          <template #body-cell-coverage="props">
            <q-td :props="props" class="text-right text-weight-bold text-positive">
              {{ getCoverage(props.row.id) }}%
            </q-td>
          </template>

          <template #body-cell-remainder="props">
            <q-td :props="props" class="text-right text-weight-bold" :class="getRemainder(props.row.id) > 0 ? 'text-warning' : 'text-grey-6'">
              {{ getRemainder(props.row.id) }}%
            </q-td>
          </template>

          <template #body-cell-created_at="props">
            <q-td :props="props">
              {{ formatDate(props.row.created_at) }}
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { QTableColumn } from 'quasar'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const router = useRouter()
const route = useRoute()

const loadingShares = ref(false)
const shipmentShares = ref<Record<number, number>>({})

const columns: QTableColumn[] = [
  { name: 'id', label: 'Shipment ID', field: 'tenant_shipment_id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: true },
  { name: 'coverage', label: 'Investor Coverage %', field: 'id', align: 'right' },
  { name: 'remainder', label: 'Parent Remainder %', field: 'id', align: 'right' },
  { name: 'created_at', label: 'Created At', field: 'created_at', align: 'left', sortable: true },
]

const loadData = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loadingShares.value = true
  await Promise.all([
    shipmentStore.fetchShipments(tenantId),
    fetchShares(tenantId),
  ])
  loadingShares.value = false
}

const fetchShares = async (tenantId: number) => {
  const { data, error } = await supabase
    .from('shipment_investments')
    .select('global_shipment_id, cost_share_pct')
    .eq('tenant_id', tenantId)
    .eq('status', 'active')

  if (!error && data) {
    const next: Record<number, number> = {}
    for (const item of data) {
      const sId = item.global_shipment_id
      const pct = Number(item.cost_share_pct ?? 0)
      next[sId] = (next[sId] || 0) + pct
    }
    shipmentShares.value = next
  }
}

const getCoverage = (shipmentId: number) => {
  return (shipmentShares.value[shipmentId] || 0).toFixed(2)
}

const getRemainder = (shipmentId: number) => {
  const cov = shipmentShares.value[shipmentId] || 0
  return Math.max(0, 100 - cov).toFixed(2)
}

const formatDate = (val: string | null | undefined) => {
  if (!val) return '—'
  return new Date(val).toLocaleDateString()
}

const onSelectShipment = async (shipmentId: number) => {
  await router.push({
    name: 'app-capital-shipment-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: shipmentId,
    },
  })
}

onMounted(() => {
  void loadData()
})
</script>
