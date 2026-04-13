<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h6">Manage Access</div>
      <q-btn label="Create Access" color="primary" @click="openCreate" />
    </div>

    <q-table
      flat
      bordered
      row-key="id"
      :rows="storeStore.accessItems"
      :columns="columns"
      :loading="storeStore.loading"
    >
      <template #body-cell-store_id="props">
        <q-td :props="props">
          {{ getStoreLabel(props.row.store_id) }}
        </q-td>
      </template>

      <template #body-cell-customer_group_id="props">
        <q-td :props="props">
          {{ getGroupLabel(props.row.customer_group_id) }}
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
            icon="delete"
            color="negative"
            @click="openDelete(props.row.id)"
          />
        </q-td>
      </template>
    </q-table>

    <q-dialog v-model="createDialogOpen">
      <q-card style="min-width: 420px; max-width: 90vw">
        <q-card-section>
          <div class="text-h6">Create Access</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-select
            v-model="form.store_id"
            label="Store"
            emit-value
            map-options
            option-value="value"
            option-label="label"
            :options="storeOptions"
          />

          <q-select
            v-model="form.customer_group_id"
            label="Customer Group"
            emit-value
            map-options
            option-value="value"
            option-label="label"
            :options="groupOptions"
          />

          <q-toggle v-model="form.status" label="Active" color="positive" />
          <q-toggle v-model="form.see_price" label="See Price" color="primary" />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="createDialogOpen = false" />
          <q-btn color="primary" label="Save" :loading="saving" @click="handleCreate" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteDialogOpen">
      <q-card style="min-width: 360px; max-width: 90vw">
        <q-card-section>
          <div class="text-h6">Delete Access</div>
        </q-card-section>

        <q-card-section>Are you sure you want to delete this access?</q-card-section>

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

import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useStoreStore } from '../stores/storeStore'
import type { StoreAccess } from '../types'

const $q = useQuasar()

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
  customer_group_id: null as number | null,
  status: true,
  see_price: false,
})

const columns: QTableColumn<StoreAccess>[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'store_id', label: 'Store', field: 'store_id', align: 'left' },
  {
    name: 'customer_group_id',
    label: 'Customer Group',
    field: 'customer_group_id',
    align: 'left',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'see_price', label: 'See Price', field: 'see_price', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
]

const storeOptions = computed(() =>
  storeStore.items.map((store) => ({
    label: `${store.name} (#${store.id})`,
    value: store.id,
  })),
)

const groupOptions = computed(() =>
  customerGroupStore.groups.map((group) => ({
    label: `${group.name} (#${group.id})`,
    value: group.id,
  })),
)

const getStoreLabel = (storeId: number) =>
  storeStore.items.find((store) => store.id === storeId)?.name ?? `#${storeId}`

const getGroupLabel = (groupId: number) =>
  customerGroupStore.groups.find((group) => group.id === groupId)?.name ?? `#${groupId}`

const fetchAccessRows = async () => {
  await storeStore.fetchStoreAccessAdmin(null)
}

const openCreate = () => {
  form.value = {
    store_id: storeStore.items[0]?.id ?? null,
    customer_group_id: customerGroupStore.groups[0]?.id ?? null,
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
  if (!form.value.store_id || !form.value.customer_group_id) {
    $q.notify({ type: 'warning', message: 'Select store and customer group.' })
    return
  }

  saving.value = true
  try {
    const result = await storeStore.createStoreAccess({
      store_id: form.value.store_id,
      customer_group_id: form.value.customer_group_id,
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
