<template>
  <q-page class="q-pa-md">
    <div class="row items-center q-gutter-sm q-mb-md">
      <q-btn flat round icon="arrow_back" @click="goBack" />
      <div class="text-h6">Manage Access - Group: <span class="text-primary font-bold">{{ groupName }}</span></div>
      <q-space />
      <q-btn label="Create Access" color="primary" @click="openCreate" />
    </div>

    <q-table
      flat
      bordered
      row-key="id"
      :rows="groupAccessItems"
      :columns="columns"
      :loading="storeStore.loading"
      no-data-label="No store access configured for this group."
      :pagination="pagination"
    >
      <template #body-cell-store_id="props">
        <q-td :props="props">
          {{ getStoreLabel(props.row.store_id) }}
        </q-td>
      </template>

      <template #body-cell-status="props">
        <q-td :props="props">
          <q-toggle
            :model-value="props.row.status"
            color="positive"
            keep-color
            @update:model-value="(value) => onToggleStatus(props.row.id, Boolean(value))"
          />
        </q-td>
      </template>

      <template #body-cell-see_price="props">
        <q-td :props="props">
          <q-toggle
            :model-value="props.row.see_price"
            color="primary"
            keep-color
            @update:model-value="(value) => onToggleSeePrice(props.row.id, Boolean(value))"
          />
        </q-td>
      </template>

      <template #body-cell-actions="props">
        <q-td align="right">
          <q-btn
            flat
            round
            dense
            icon="o_delete"
            color="negative"
            @click="openDelete(props.row.id)"
          />
        </q-td>
      </template>
    </q-table>

    <q-dialog v-model="createDialogOpen">
      <q-card style="min-width: 420px; max-width: 90vw">
        <q-card-section>
          <div class="text-h6">Create Access for {{ groupName }}</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <div>
            <div class="text-caption text-grey-8 q-mb-xs">Store</div>
            <q-select
              v-model="form.store_id"
              label="Select Store"
              outlined
              dense
              emit-value
              map-options
              option-value="value"
              option-label="label"
              :options="availableStoresOptions"
              no-data-label="All stores have access maps defined already."
            />
          </div>

          <q-toggle v-model="form.status" label="Active" color="positive" />
          <q-toggle v-model="form.see_price" label="See Price" color="primary" />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="createDialogOpen = false" />
          <q-btn color="primary" label="Save" :loading="saving" :disabled="!form.store_id" @click="handleCreate" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteDialogOpen">
      <q-card style="min-width: 360px; max-width: 90vw">
        <q-card-section>
          <div class="text-h6">Delete Access</div>
        </q-card-section>

        <q-card-section>Are you sure you want to delete this access map?</q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="deleteDialogOpen = false" />
          <q-btn color="negative" label="Delete" :loading="deleting" @click="handleDelete" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar, type QTableColumn } from 'quasar'
import { useRoute, useRouter } from 'vue-router'

import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useStoreStore } from '../stores/storeStore'
import type { StoreAccess } from '../types'

const $q = useQuasar()
const route = useRoute()
const router = useRouter()

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const customerGroupStore = useCustomerGroupStore()
const storeStore = useStoreStore()

const createDialogOpen = ref(false)
const deleteDialogOpen = ref(false)
const deleting = ref(false)
const saving = ref(false)
const selectedDeleteId = ref<number | null>(null)

const form = ref({
  store_id: null as number | null,
  status: true,
  see_price: false,
})

const pagination = ref({
  rowsPerPage: 0
})

const columns: QTableColumn<StoreAccess>[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'store_id', label: 'Store', field: 'store_id', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'see_price', label: 'See Price', field: 'see_price', align: 'left' },
  { name: 'actions', label: 'Actions', field: (row) => row.id, align: 'right' },
]

const groupName = computed(() => {
  const groupId = Number(route.params.groupId)
  return customerGroupStore.groups.find((g) => g.id === groupId)?.name ?? `#${groupId}`
})

const groupAccessItems = computed(() => {
  const groupId = Number(route.params.groupId)
  return storeStore.accessItems.filter((item) => item.customer_group_id === groupId)
})

const availableStoresOptions = computed(() => {
  const configuredStoreIds = new Set(groupAccessItems.value.map((item) => item.store_id))
  return storeStore.items
    .filter((store) => !configuredStoreIds.has(store.id))
    .map((store) => ({
      label: `${store.name} (#${store.id})`,
      value: store.id,
    }))
})

const getStoreLabel = (storeId: number) =>
  storeStore.items.find((store) => store.id === storeId)?.name ?? `#${storeId}`

const fetchAccessRows = async () => {
  const tenantId = tenantStore.selectedTenant?.id ?? null
  await storeStore.fetchStoreAccessAdmin(null, tenantId)
}

const goBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/stores/manage-access`)
}

const openCreate = () => {
  form.value = {
    store_id: availableStoresOptions.value[0]?.value ?? null,
    status: true,
    see_price: false,
  }
  createDialogOpen.value = true
}

const openDelete = (id: number) => {
  selectedDeleteId.value = id
  deleteDialogOpen.value = true
}

const handleCreate = async () => {
  if (!form.value.store_id) {
    $q.notify({ type: 'warning', message: 'Select a store.' })
    return
  }

  saving.value = true
  try {
    const groupId = Number(route.params.groupId)
    const result = await storeStore.createStoreAccess({
      store_id: form.value.store_id,
      customer_group_id: groupId,
      status: form.value.status,
      see_price: form.value.see_price,
    })

    if (!result.success) {
      return
    }

    createDialogOpen.value = false
    await fetchAccessRows()
  } finally {
    saving.value = false
  }
}

const onToggleStatus = async (id: number, status: boolean) => {
  const result = await storeStore.updateStoreAccess({ id, status })

  if (!result.success) {
    return
  }

  await fetchAccessRows()
}

const onToggleSeePrice = async (id: number, seePrice: boolean) => {
  const result = await storeStore.updateStoreAccess({
    id,
    see_price: seePrice,
  })

  if (!result.success) {
    return
  }

  await fetchAccessRows()
}

const handleDelete = async () => {
  if (!selectedDeleteId.value) {
    return
  }

  deleting.value = true
  try {
    const result = await storeStore.deleteStoreAccess({ id: selectedDeleteId.value })

    if (!result.success) {
      return
    }

    deleteDialogOpen.value = false
    selectedDeleteId.value = null
    await fetchAccessRows()
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  const tenantId = tenantStore.selectedTenant?.id ?? 0

  await Promise.all([
    storeStore.fetchStoresAdmin(tenantId),
    customerGroupStore.fetchCustomerGroupsByTenant(tenantId),
  ])

  await fetchAccessRows()
})
</script>
