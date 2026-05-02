<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5 text-weight-bold">Billing Profiles</div>
      <q-btn color="primary" no-caps label="Create Billing Profile" @click="createOpen = true" />
    </div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">Name</th>
          <th class="text-left">Email</th>
          <th class="text-left">Phone</th>
          <th class="text-left">Address</th>
          <th class="text-right" style="width: 220px">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!store.items.length && !store.loading">
          <td colspan="5" class="text-center text-grey-7">No billing profiles found.</td>
        </tr>
        <tr v-for="row in store.items" :key="row.id">
          <td>{{ row.name }}</td>
          <td>{{ row.email ?? '-' }}</td>
          <td>{{ row.phone ?? '-' }}</td>
          <td>{{ row.address ?? '-' }}</td>
          <td class="text-right">
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              label="Edit"
              class="q-mr-xs"
              @click="onOpenEdit(row.id)"
            />
            <q-btn
              flat
              dense
              no-caps
              color="negative"
              label="Delete"
              @click="onOpenDelete(row.id)"
            />
          </td>
        </tr>
      </tbody>
    </q-markup-table>

    <BillingProfileCreateDialog
      v-model="createOpen"
      :tenant-id="authStore.tenantId"
      :saving="store.saving"
      @submit="onCreate"
    />

    <BillingProfileEditDialog
      v-model="editOpen"
      :profile="selectedProfile"
      :saving="store.saving"
      @submit="onEdit"
    />

    <q-dialog v-model="deleteOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Billing Profile</q-card-section>
        <q-card-section>
          Are you sure you want to delete this billing profile?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="negative" no-caps label="Delete" :loading="store.saving" @click="onDelete" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import BillingProfileCreateDialog from '../components/BillingProfileCreateDialog.vue'
import BillingProfileEditDialog from '../components/BillingProfileEditDialog.vue'
import { useBillingProfileStore } from '../stores/billingProfileStore'
import type { BillingProfile, CreateBillingProfileInput } from '../types/billingProfile'

const authStore = useAuthStore()
const store = useBillingProfileStore()

const createOpen = ref(false)
const editOpen = ref(false)
const deleteOpen = ref(false)
const selectedId = ref<number | null>(null)

const selectedProfile = computed<BillingProfile | null>(() =>
  store.items.find((row) => row.id === selectedId.value) ?? null,
)

const load = async () => {
  if (!authStore.tenantId) return
  await store.fetchBillingProfiles({
    tenant_id: authStore.tenantId,
    page: 1,
    page_size: 50,
    sortBy: 'created_at',
    sortOrder: 'desc',
  })
}

const onCreate = async (payload: CreateBillingProfileInput) => {
  const result = await store.createBillingProfile(payload)
  if (result.success) {
    createOpen.value = false
  }
}

const onOpenEdit = (id: number) => {
  selectedId.value = id
  editOpen.value = true
}

const onEdit = async (payload: {
  id: number
  patch: {
    name: string
    email: string | null
    phone: string | null
    address: string | null
    customer_group_id: number | null
  }
}) => {
  const result = await store.updateBillingProfile(payload)
  if (result.success) {
    editOpen.value = false
    selectedId.value = null
  }
}

const onOpenDelete = (id: number) => {
  selectedId.value = id
  deleteOpen.value = true
}

const onDelete = async () => {
  if (!selectedId.value) return
  const result = await store.deleteBillingProfile(selectedId.value)
  if (result.success) {
    deleteOpen.value = false
    selectedId.value = null
  }
}

onMounted(load)
</script>
