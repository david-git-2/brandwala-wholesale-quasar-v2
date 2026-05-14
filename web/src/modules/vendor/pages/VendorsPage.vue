<template>
  <q-page class="q-pa-md vendor-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Vendor Management</div>
            <div class="text-caption text-grey-8">Manage vendors and maintain supplier details</div>
          </div>
          <div class="col-auto">
            <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Add Vendor" @click="onClickAddVendor" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <q-card flat class="q-mb-md floating-surface shadow-1">
      <q-card-section>
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
            outlined
            dense
            class="soft-input toolbar-search"
            label="Search vendors"
            clearable
            autofocus
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn
                flat
                round
                dense
                icon="close"
                aria-label="Hide search"
                @click="onCloseSearch"
              />
            </template>
          </q-input>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-card-section>
        <div v-if="loading" class="text-grey-7">Loading vendors...</div>
        <div v-else-if="filteredItems.length === 0" class="text-grey-7">No vendors found.</div>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="filteredItems"
          :columns="columns"
          :dense="$q.screen.lt.md"
          :pagination="{ rowsPerPage: 0 }"
          hide-pagination
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
              <q-btn flat round dense icon="more_vert" aria-label="Vendor actions" @click.stop>
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable v-ripple @click="onClickEditVendor(props.row)">
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="onClickDeleteVendor(props.row)">
                      <q-item-section class="text-negative">Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </q-td>
          </template>
        </q-table>

      </q-card-section>
    </q-card>

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
const showSearchInput = ref(false)
const searchText = ref('')

const resolvedTenantId = computed(() =>
  authStore.scope === 'platform' ? null : authStore.tenantId,
)

const filteredItems = computed(() => {
  const term = searchText.value.trim().toLowerCase()
  if (!term) return items.value

  return items.value.filter((vendor) =>
    [vendor.name, vendor.code, vendor.market_code, vendor.email, vendor.phone]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(term)),
  )
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

const onCloseSearch = () => {
  showSearchInput.value = false
  searchText.value = ''
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

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(34, 56, 101, 0.08);
}

.toolbar-search {
  width: min(320px, 75vw);
}
</style>
