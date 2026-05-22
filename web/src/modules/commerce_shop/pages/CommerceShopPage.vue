<template>
  <q-page class="q-pa-md commerce-shop-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Commerce Shop</div>
            <div class="text-caption text-grey-8">
              Products shown from inventory (active and usable stock only)
            </div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Refresh"
              :loading="inventoryStore.loading"
              @click="fetchInventoryItems"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1 q-mb-sm">
      <q-card-section class="q-py-xs">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-5">
            <q-input
              v-model="searchText"
              dense
              filled
              clearable
              class="soft-input"
              label="Search by name / barcode / product code"
            />
          </div>
          <div class="col-12 col-md-3">
            <q-select
              v-model="selectedShipmentId"
              :options="shipmentOptions"
              dense
              filled
              clearable
              emit-value
              map-options
              class="soft-input"
              label="Shipment"
            />
          </div>
          <div class="col-12 col-md-4 text-right text-caption text-grey-8">
            Showing {{ filteredRows.length }} item(s)
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-table
        flat
        row-key="id"
        :rows="filteredRows"
        :columns="columns"
        :loading="inventoryStore.loading"
        :pagination="{ rowsPerPage: 20 }"
        class="commerce-shop-page__table"
      >
        <template #body-cell-image="props">
          <q-td :props="props">
            <q-avatar rounded size="42px">
              <img :src="props.row.image_url || 'https://placehold.co/56x56?text=No+Image'" alt="product image" />
            </q-avatar>
          </q-td>
        </template>
        <template #body-cell-shipment="props">
          <q-td :props="props">
            {{ props.row.shipment?.shipment?.name ?? '-' }}
          </q-td>
        </template>
        <template #no-data>
          <div class="full-width text-center text-grey-7 q-py-md">No inventory-backed products found.</div>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { handleApiFailure } from 'src/utils/appFeedback'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()
const shipmentStore = useShipmentStore()

const searchText = ref('')
const selectedShipmentId = ref<number | null>(null)

const columns = [
  { name: 'image', label: 'Image', field: 'image_url', align: 'left' as const, style: 'width: 72px; min-width: 72px;' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'barcode', label: 'Barcode', field: 'barcode', align: 'left' as const },
  { name: 'product_code', label: 'Product Code', field: 'product_code', align: 'left' as const },
  { name: 'shipment', label: 'Shipment', field: 'shipment', align: 'left' as const },
  { name: 'usable', label: 'Usable Qty', field: (row: { quantities: { usable: number } }) => row.quantities.usable, align: 'right' as const },
  { name: 'open_box', label: 'Open Box Qty', field: (row: { quantities: { open_box: number } }) => row.quantities.open_box, align: 'right' as const },
  { name: 'available', label: 'Available Qty', field: (row: { quantities: { available: number } }) => row.quantities.available, align: 'right' as const },
]

const shipmentOptions = computed(() => [
  { label: 'All Shipments', value: null as number | null },
  ...shipmentStore.shipments
    .filter((shipment) => shipment.inventory_added === true)
    .map((shipment) => ({
      label: `#${shipment.id} ${shipment.name}`,
      value: shipment.id,
    })),
])

const filteredRows = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  return inventoryStore.items
    .filter((item) => item.status === 'active' && Number(item.quantities.usable ?? 0) > 0)
    .filter((item) => {
      if (selectedShipmentId.value == null) return true
      const shipmentId = Number(item.shipment?.shipment?.id ?? 0)
      return shipmentId === selectedShipmentId.value
    })
    .filter((item) => {
      if (!search) return true
      return (
        (item.name ?? '').toLowerCase().includes(search) ||
        (item.barcode ?? '').toLowerCase().includes(search) ||
        (item.product_code ?? '').toLowerCase().includes(search)
      )
    })
})

const fetchInventoryItems = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  await inventoryStore.fetchInventoryItems({
    tenant_id: tenantId,
    page: 1,
    page_size: 200,
    sortBy: 'id',
    sortOrder: 'desc',
    filters: { status: 'active' },
  })
}

onMounted(async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  await Promise.all([
    shipmentStore.fetchShipments(tenantId),
    fetchInventoryItems(),
  ])
})
</script>

<style scoped>
.commerce-shop-page {
  background: transparent;
}
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.hero-surface {
  border-radius: 16px;
}
.pill-btn { border-radius: 999px; }
.slim-btn { min-height: 32px; padding-left: 10px; padding-right: 10px; }
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
