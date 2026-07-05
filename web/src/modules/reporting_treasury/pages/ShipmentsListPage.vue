<template>
  <TreasuryPageShell
    title="Shipments P&amp;L Analysis"
    subtitle="Select a shipment to analyze unit landed costs, sales revenue, unsold assets, and profit margins."
    :error="error"
  >
    <div class="q-gutter-y-lg">
      <!-- Filter Control Card -->
      <TreasuryFilterBar>
        <div class="row q-col-gutter-md items-center justify-between">
          <div class="col-12 col-md-5">
            <q-input
              v-model="search"
              placeholder="Search by shipment name or cargo ID..."
              dense
              outlined
            >
              <template #append>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6 col-md-3">
            <q-select
              v-model="statusFilter"
              :options="statusOptions"
              label="Status"
              dense
              outlined
              emit-value
              map-options
            />
          </div>
        </div>
      </TreasuryFilterBar>

      <!-- Shipments Table -->
      <q-card flat bordered>
        <q-table
          flat
          row-key="id"
          :rows="filteredShipments"
          :columns="columns"
          :loading="loading"
          :pagination="{ rowsPerPage: 20 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-id="props">
            <q-td :props="props" class="text-weight-bold text-primary">
              #{{ props.row.tenant_shipment_id || props.row.id }}
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props" class="text-weight-bold">
              {{ props.row.name || 'Unnamed Shipment' }}
            </q-td>
          </template>

          <template #body-cell-type="props">
            <q-td :props="props">
              <span class="text-capitalize font-mono text-sm">
                {{ props.row.type || 'domestic' }}
              </span>
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                :color="statusColor(props.row.status).bg"
                :text-color="statusColor(props.row.status).text"
                :icon="statusColor(props.row.status).icon"
                class="status-chip text-capitalize"
              >
                {{ props.row.status || 'unknown' }}
              </q-chip>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-center">
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="o_insights"
                @click="navigateToPnL(props.row.id)"
              >
                <q-tooltip>Analyze Profitability &amp; P&amp;L</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </div>
  </TreasuryPageShell>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import type { QTableColumn } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import TreasuryPageShell from '../components/TreasuryPageShell.vue'
import TreasuryFilterBar from '../components/TreasuryFilterBar.vue'

const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref<string | null>(null)
const shipments = ref<any[]>([])

// Filters
const search = ref('')
const statusFilter = ref('__all__')

const columns: QTableColumn[] = [
  { name: 'id', label: 'Shipment ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Shipment Name', field: 'name', align: 'left', sortable: true },
  { name: 'type', label: 'Shipment Type', field: 'type', align: 'left', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: true },
  { name: 'created_at', label: 'Date Created', field: 'created_at', align: 'left', sortable: true },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center' },
]

const statusOptions = [
  { label: 'All Statuses', value: '__all__' },
  { label: 'Pending', value: 'pending' },
  { label: 'In Transit', value: 'in_transit' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]

// Load Shipments
const fetchShipments = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  error.value = null
  try {
    const parentId = await resolveParentTenantId(tenantId)
    const { data, error: err } = await supabase
      .from('global_shipments')
      .select('*')
      .eq('parent_tenant_id', parentId)
      .order('created_at', { ascending: false })

    if (err) throw err
    shipments.value = data || []
  } catch (err: any) {
    error.value = err.message
    $q.notify({ type: 'negative', message: `Failed to load shipments: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const resolveParentTenantId = async (id: number): Promise<number> => {
  const { data, error: err } = await supabase.rpc('resolve_parent_tenant_id', { p_tenant_id: id })
  if (err) return id
  return Number(data)
}

// Filtered shipments
const filteredShipments = computed(() => {
  return shipments.value.filter((s) => {
    const nameText = s.name || ''
    const matchesSearch =
      !search.value ||
      nameText.toLowerCase().includes(search.value.toLowerCase())

    const matchesStatus =
      statusFilter.value === '__all__' || s.status === statusFilter.value

    return matchesSearch && matchesStatus
  })
})

const navigateToPnL = (id: number) => {
  void router.push({
    name: 'app-finance-shipment-details-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      id,
    },
  })
}

const statusColor = (status: string | null | undefined) => {
  const s = (status ?? '').trim().toLowerCase()
  if (s === 'completed' || s === 'delivered') return { bg: 'green-1', text: 'green-9', icon: 'check_circle' }
  if (s === 'in_transit' || s === 'transit' || s === 'shipped') return { bg: 'blue-1', text: 'blue-9', icon: 'local_shipping' }
  if (s === 'pending') return { bg: 'amber-1', text: 'amber-9', icon: 'pending' }
  if (s === 'cancelled') return { bg: 'red-1', text: 'red-9', icon: 'cancel' }
  return { bg: 'grey-2', text: 'grey-8', icon: 'inventory_2' }
}

onMounted(() => {
  void fetchShipments()
})
</script>

<style scoped>
.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  font-size: 12px;
}
</style>
