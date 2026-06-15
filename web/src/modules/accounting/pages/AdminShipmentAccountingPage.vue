<template>
  <q-page class="q-pa-md shipment-acct-list-page" style="background: transparent;">
    <!-- Hero Header -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-h6 text-weight-bold">Shipment Accounting</div>
        <div class="text-caption text-grey-7">Select a shipment to view detailed P&amp;L accounting</div>
      </div>
    </div>

    <!-- Loading skeleton -->
    <template v-if="shipmentStore.loading">
      <div class="row q-col-gutter-md q-mb-md">
        <div v-for="n in 3" :key="n" class="col-12 col-sm-4">
          <q-card flat class="floating-surface shadow-1">
            <q-card-section>
              <q-skeleton type="text" width="60%" />
              <q-skeleton type="text" width="40%" class="q-mt-xs" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </template>

    <!-- Main Table Card -->
    <q-card flat class="floating-surface shadow-1">
      <q-card-section class="q-pa-none">
        <q-markup-table flat class="shipment-acct-list-table">
          <thead>
            <tr>
              <th class="text-left" style="width: 48px">#</th>
              <th class="text-left">Shipment</th>
              <th class="text-left">Name</th>
              <th class="text-left">Status</th>
              <th class="text-left">Created</th>
              <th class="text-right" style="width: 60px"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!shipmentStore.shipments.length && !shipmentStore.loading">
              <td colspan="6" class="text-center text-grey-6 q-py-xl">
                <q-icon name="inventory_2" size="32px" color="grey-4" class="q-mb-sm block" />
                <div class="text-body2">No shipments found.</div>
              </td>
            </tr>
            <tr
              v-for="(shipment, index) in shipmentStore.shipments"
              :key="shipment.id"
              class="cursor-pointer shipment-row"
              @click="onSelectShipment(shipment.id)"
            >
              <td class="text-grey-6 text-caption">{{ index + 1 }}</td>
              <td>
                <span class="text-weight-medium text-primary">#{{ shipment.tenant_shipment_id }}</span>
              </td>
              <td>
                <span class="text-weight-medium">{{ shipment.name ?? '—' }}</span>
              </td>
              <td>
                <q-chip
                  dense
                  square
                  :color="statusColor(shipment.status).bg"
                  :text-color="statusColor(shipment.status).text"
                  :icon="statusColor(shipment.status).icon"
                  class="status-chip text-capitalize"
                >
                  {{ shipment.status ?? 'unknown' }}
                </q-chip>
              </td>
              <td class="text-grey-7 text-caption">{{ formatDate(shipment.created_at) }}</td>
              <td class="text-right">
                <q-icon name="chevron_right" color="grey-5" size="18px" />
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const router = useRouter()
const route = useRoute()

const statusColor = (status: string | null | undefined) => {
  const s = (status ?? '').trim().toLowerCase()
  if (s === 'completed' || s === 'delivered') return { bg: 'green-1', text: 'green-9', icon: 'check_circle' }
  if (s === 'in_transit' || s === 'transit' || s === 'shipped') return { bg: 'blue-1', text: 'blue-9', icon: 'local_shipping' }
  if (s === 'pending') return { bg: 'orange-1', text: 'orange-9', icon: 'pending' }
  if (s === 'cancelled') return { bg: 'red-1', text: 'red-9', icon: 'cancel' }
  return { bg: 'grey-2', text: 'grey-8', icon: 'inventory_2' }
}

const formatDate = (val: string | null | undefined) => {
  if (!val) return '—'
  try {
    return new Date(val).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
  } catch {
    return val
  }
}

const loadShipments = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }
  await shipmentStore.fetchShipments(tenantId)
}

const onSelectShipment = async (shipmentId: number) => {
  await router.push({
    name: 'app-accounting-shipment-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: shipmentId,
    },
  })
}

onMounted(() => {
  void loadShipments()
})
</script>

<style scoped>
.shipment-acct-list-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.shipment-acct-list-table :deep(th) {
  background: color-mix(in srgb, #fff 96%, #f7f9fc 4%);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #7a8499;
  padding: 10px 16px;
}

.shipment-acct-list-table :deep(td) {
  padding: 12px 16px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.06);
}

.shipment-row {
  transition: background 0.15s ease;
}

.shipment-row:hover {
  background: rgba(25, 118, 210, 0.04);
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  font-size: 12px;
  letter-spacing: 0.01em;
}
</style>
