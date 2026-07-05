<template>
  <q-page class="q-pa-lg bg-slate-900 text-white">
    <!-- Header Block -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h4 text-weight-bolder tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-emerald-400">
          Shipments P&amp;L Analysis
        </div>
        <div class="text-subtitle2 text-slate-400 q-mt-xs">
          Select a shipment to analyze unit landed costs, sales revenue, unsold assets, and profit margins.
        </div>
      </div>
    </div>

    <!-- Filter Control Card -->
    <div class="glass-card q-pa-md q-mb-lg row items-center justify-between q-col-gutter-sm">
      <div class="col-12 col-md-5">
        <q-input
          v-model="search"
          placeholder="Search by shipment name or cargo ID..."
          dark
          dense
          outlined
          class="glass-input"
        >
          <template #append>
            <q-icon name="search" class="text-slate-400" />
          </template>
        </q-input>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-select
          v-model="statusFilter"
          :options="statusOptions"
          label="Status"
          dark
          dense
          outlined
          emit-value
          map-options
          class="glass-input"
        />
      </div>
    </div>

    <!-- Shipments Grid/Table -->
    <div class="glass-card overflow-hidden">
      <q-markup-table flat dark class="bg-transparent text-white" wrap-cells>
        <thead>
          <tr class="text-slate-400 border-b border-slate-800">
            <th class="text-left font-semibold py-4">Shipment ID</th>
            <th class="text-left font-semibold">Shipment Name</th>
            <th class="text-left font-semibold">Shipment Type</th>
            <th class="text-left font-semibold">Status</th>
            <th class="text-left font-semibold">Date Created</th>
            <th class="text-center font-semibold" style="width: 100px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading" class="border-b border-slate-800/50">
            <td colspan="6" class="text-center py-8 text-slate-400">
              <q-spinner-dots size="40px" color="teal" />
            </td>
          </tr>
          <tr v-else-if="!filteredShipments.length" class="border-b border-slate-800/50">
            <td colspan="6" class="text-center py-8 text-slate-500">
              No shipments found.
            </td>
          </tr>
          <tr
            v-for="row in filteredShipments"
            :key="row.id"
            class="hover:bg-slate-800/40 cursor-pointer transition-colors duration-200 border-b border-slate-800/50"
            @click="navigateToPnL(row.id)"
          >
            <td class="py-4 text-weight-bold text-teal-400">
              #{{ row.tenant_shipment_id || row.id }}
            </td>
            <td class="text-weight-bold text-slate-200">
              {{ row.name || 'Unnamed Shipment' }}
            </td>
            <td>
              <span class="text-capitalize text-slate-300 font-mono text-sm">
                {{ row.type || 'domestic' }}
              </span>
            </td>
            <td>
              <q-chip
                dense
                square
                :color="statusColor(row.status).bg"
                :text-color="statusColor(row.status).text"
                :icon="statusColor(row.status).icon"
                class="status-chip text-capitalize"
              >
                {{ row.status || 'unknown' }}
              </q-chip>
            </td>
            <td class="text-slate-400 text-caption">{{ formatDate(row.created_at) }}</td>
            <td class="text-center" @click.stop>
              <q-btn
                flat
                round
                dense
                color="teal"
                icon="o_insights"
                @click="navigateToPnL(row.id)"
              >
                <q-tooltip>Analyze Profitability &amp; P&amp;L</q-tooltip>
              </q-btn>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const shipments = ref<any[]>([])

// Filters
const search = ref('')
const statusFilter = ref('__all__')

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
  try {
    const parentId = await resolveParentTenantId(tenantId)
    const { data, error } = await supabase
      .from('global_shipments')
      .select('*')
      .eq('parent_tenant_id', parentId)
      .order('created_at', { ascending: false })

    if (error) throw error
    shipments.value = data || []
  } catch (err: any) {
    $q.notify({ type: 'negative', message: `Failed to load shipments: ${err.message}` })
  } finally {
    loading.value = false
  }
}

const resolveParentTenantId = async (id: number): Promise<number> => {
  const { data, error } = await supabase.rpc('resolve_parent_tenant_id', { p_tenant_id: id })
  if (error) return id
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
  if (s === 'completed' || s === 'delivered') return { bg: 'slate-800', text: 'teal-300', icon: 'check_circle' }
  if (s === 'in_transit' || s === 'transit' || s === 'shipped') return { bg: 'slate-800', text: 'blue-300', icon: 'local_shipping' }
  if (s === 'pending') return { bg: 'slate-800', text: 'amber-400', icon: 'pending' }
  if (s === 'cancelled') return { bg: 'slate-800', text: 'red-400', icon: 'cancel' }
  return { bg: 'slate-800', text: 'slate-400', icon: 'inventory_2' }
}

const formatDate = (val: string | null | undefined) => {
  if (!val) return '—'
  try {
    return new Date(val).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  } catch {
    return val
  }
}

onMounted(() => {
  void fetchShipments()
})
</script>

<style scoped>
.bg-slate-900 {
  background-color: #0f172a;
}
.text-slate-400 {
  color: #94a3b8;
}
.text-slate-500 {
  color: #64748b;
}
.text-slate-200 {
  color: #e2e8f0;
}
.text-slate-300 {
  color: #cbd5e1;
}
.border-slate-800 {
  border-color: #1e293b;
}
.border-slate-800\/50 {
  border-color: rgba(30, 41, 59, 0.5);
}
.hover\:bg-slate-800\/40:hover {
  background-color: rgba(30, 41, 59, 0.4);
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  font-size: 12px;
}

/* Glassmorphism Classes */
.glass-card {
  background: rgba(30, 41, 59, 0.4);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px border-solid rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}

.glass-input :deep(.q-field__control) {
  border-radius: 8px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px border-solid rgba(255, 255, 255, 0.08);
}
</style>
