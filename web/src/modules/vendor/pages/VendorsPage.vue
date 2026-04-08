<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">{{ authStore.scope === 'platform' ? 'Platform' : 'Tenant' }}</div>
          <h1 class="text-h5 q-my-none">Vendors</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ descriptionText }}
          </p>
        </div>
        <div class="col-auto">
          <q-btn color="primary" icon="add" label="Add Vendor" unelevated @click="onClickAddVendor" />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card flat bordered>
        <q-card-section>
          <div class="text-subtitle1">Vendor List</div>
        </q-card-section>

        <q-card-section v-if="loading" class="text-grey-7">Loading vendors...</q-card-section>
        <q-card-section v-else-if="items.length === 0" class="text-grey-7">
          No vendors found.
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="items"
          :columns="columns"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-code="props">
            <q-td :props="props">
              <q-badge color="primary" outline>{{ props.row.code }}</q-badge>
            </q-td>
          </template>

          <template #body-cell-tenant_id="props">
            <q-td :props="props">
              <q-badge :color="props.row.tenant_id === null ? 'teal' : 'indigo'">
                {{ props.row.tenant_id === null ? 'Global' : `Tenant #${props.row.tenant_id}` }}
              </q-badge>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn flat round dense icon="edit" @click="onClickEditVendor(props.row)" />
              <q-btn
                flat
                round
                dense
                color="negative"
                icon="delete"
                @click="onClickDeleteVendor(props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <AddVendorDialog
      v-model="openEditDialog"
      :initial-data="selectedVendor"
      :tenant-id="resolvedTenantId"
      :markets="markets"
      :check-code-availability="checkVendorCodeAvailability"
      @save="handleSaveVendor"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete <strong>{{ vendorToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteVendor" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'
import type { QTableColumn } from 'quasar'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import AddVendorDialog from '../components/AddVendorDialog.vue'
import { useVendorStore } from '../stores/vendorStore'
import type { Vendor, VendorCreateInput, VendorDeleteInput, VendorUpdateInput } from '../types'

const authStore = useAuthStore()
const vendorStore = useVendorStore()
const { items, markets, loading, error } = storeToRefs(vendorStore)

const openEditDialog = ref(false)
const openDeleteDialog = ref(false)
const selectedVendor = ref<Vendor | null>(null)
const vendorToDelete = ref<Vendor | null>(null)

const resolvedTenantId = computed(() =>
  authStore.scope === 'platform' ? null : authStore.tenantId,
)

const descriptionText = computed(() => {
  if (authStore.scope === 'platform') {
    return 'Manage global vendors created by superadmin.'
  }

  return 'Manage vendors created for your tenant.'
})

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Name', field: 'name', align: 'left', sortable: true },
  { name: 'code', label: 'Code', field: 'code', align: 'left', sortable: true },
  { name: 'market_code', label: 'Market', field: 'market_code', align: 'left', sortable: true },
  { name: 'tenant_id', label: 'Scope', field: 'tenant_id', align: 'left', sortable: true },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'id', align: 'right' },
]

const refresh = async () => {
  await Promise.all([vendorStore.fetchMarkets(), vendorStore.fetchVendors()])
}

const onClickAddVendor = () => {
  selectedVendor.value = null
  openEditDialog.value = true
}

const onClickEditVendor = (vendor: Vendor) => {
  selectedVendor.value = { ...vendor }
  openEditDialog.value = true
}

const onClickDeleteVendor = (vendor: Vendor) => {
  vendorToDelete.value = vendor
  openDeleteDialog.value = true
}

const checkVendorCodeAvailability = async (code: string, excludeId?: number | null) => {
  const result = await vendorStore.checkCodeAvailability(code, excludeId)
  return Boolean(result.success && result.data)
}

const handleSaveVendor = async (payload: VendorCreateInput & { id?: number }) => {
  if (typeof payload.id === 'number') {
    const updatePayload: VendorUpdateInput = {
      id: payload.id,
      ...payload,
    }
    await vendorStore.updateVendor(updatePayload)
    return
  }

  const createPayload: VendorCreateInput = {
    ...payload,
  }
  await vendorStore.createVendor(createPayload)
}

const confirmDeleteVendor = async () => {
  if (!vendorToDelete.value) return

  const payload: VendorDeleteInput = {
    id: vendorToDelete.value.id,
  }

  await vendorStore.deleteVendor(payload)
  vendorToDelete.value = null
  openDeleteDialog.value = false
}

onMounted(() => {
  void refresh()
})
</script>
