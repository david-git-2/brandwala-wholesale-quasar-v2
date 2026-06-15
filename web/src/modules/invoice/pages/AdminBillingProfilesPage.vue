<template>
  <q-page class="q-pa-md billing-profiles-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Billing Profiles</div>
            <div class="text-caption text-grey-8">Manage customer billing profiles used for invoicing</div>
          </div>
          <div class="col-auto">
            <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Create Billing Profile" @click="createOpen = true" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
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
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          label="Search Billing Profile"
          @clear="onSearchChange"
          @keyup.enter="onSearchChange"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="filterDrawerOpen = true">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>
    </div>

    <q-card flat class="floating-surface shadow-1">
      <q-markup-table flat wrap-cells class="billing-profiles-table">
      <thead>
        <tr>
          <th class="text-left">Name</th>
          <th class="text-left">Customer Group</th>
          <th class="text-left">Email</th>
          <th class="text-left">Phone</th>
          <th class="text-left">Address</th>
          <th class="text-left" style="width: 80px">Color</th>
          <th class="text-right" style="width: 80px">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!store.items.length && !store.loading">
          <td colspan="7" class="text-center text-grey-7">No billing profiles found.</td>
        </tr>
        <tr v-for="row in filteredItems" :key="row.id">
          <td>
            <div class="row items-center no-wrap">
              <span v-if="row.color" class="color-dot" :style="{ backgroundColor: row.color }" />
              <span>{{ row.name }}</span>
            </div>
          </td>
          <td>
            <q-chip
              v-if="row.customer_group_id"
              dense
              outline
              size="sm"
            >
              {{ customerGroupNameMap[row.customer_group_id] ?? '-' }}
            </q-chip>
            <span v-else class="text-grey-6 text-caption">Others</span>
          </td>
          <td>{{ row.email ?? '-' }}</td>
          <td>{{ row.phone ?? '-' }}</td>
          <td>{{ row.address ?? '-' }}</td>
          <td>
            <div v-if="row.color" class="row items-center q-gutter-x-xs no-wrap">
              <span class="color-preview" :style="{ backgroundColor: row.color }" />
              <span class="text-caption text-mono">{{ row.color }}</span>
            </div>
            <span v-else class="text-grey-6">-</span>
          </td>
          <td class="text-right">
            <q-btn flat round dense icon="more_vert">
              <q-menu auto-close>
                <q-list dense style="min-width: 140px">
                  <q-item clickable @click="onOpenEdit(row.id)">
                    <q-item-section>Edit</q-item-section>
                  </q-item>
                  <q-item clickable class="text-negative" @click="onOpenDelete(row.id)">
                    <q-item-section>Delete</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </td>
        </tr>
      </tbody>
      </q-markup-table>
    </q-card>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-input
        v-model="emailFilter"
        filled
        dense
        clearable
        class="soft-input q-mb-sm"
        label="Email Contains"
        @update:model-value="onSearchChange"
      />
      <q-input
        v-model="phoneFilter"
        filled
        dense
        clearable
        class="soft-input q-mb-md"
        label="Phone Contains"
        @update:model-value="onSearchChange"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

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
import FilterSidebar from 'src/components/FilterSidebar.vue'
import BillingProfileCreateDialog from '../components/BillingProfileCreateDialog.vue'
import BillingProfileEditDialog from '../components/BillingProfileEditDialog.vue'
import { useBillingProfileStore } from '../stores/billingProfileStore'
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore'
import type { BillingProfile, CreateBillingProfileInput } from '../types/billingProfile'

const authStore = useAuthStore()
const store = useBillingProfileStore()
const customerGroupStore = useCustomerGroupStore()

const createOpen = ref(false)
const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)
const searchText = ref('')
const emailFilter = ref('')
const phoneFilter = ref('')
const editOpen = ref(false)
const deleteOpen = ref(false)
const selectedId = ref<number | null>(null)

const selectedProfile = computed<BillingProfile | null>(() =>
  store.items.find((row) => row.id === selectedId.value) ?? null,
)
const filteredItems = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  const email = emailFilter.value.trim().toLowerCase()
  const phone = phoneFilter.value.trim().toLowerCase()
  return store.items.filter((row) => {
    const matchesSearch = !search || [
      row.name,
      row.email ?? '',
      row.phone ?? '',
      row.address ?? '',
    ].some((value) => value.toLowerCase().includes(search))
    const matchesEmail = !email || (row.email ?? '').toLowerCase().includes(email)
    const matchesPhone = !phone || (row.phone ?? '').toLowerCase().includes(phone)
    return matchesSearch && matchesEmail && matchesPhone
  })
})
const activeFilterCount = computed(() => {
  let count = 0
  if (emailFilter.value.trim()) count += 1
  if (phoneFilter.value.trim()) count += 1
  return count
})

const customerGroupNameMap = computed<Record<number, string>>(() =>
  customerGroupStore.groups.reduce<Record<number, string>>((acc, g) => {
    acc[g.id] = g.name
    return acc
  }, {}),
)

const load = async () => {
  if (!authStore.tenantId) return
  await Promise.all([
    store.fetchBillingProfiles({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 50,
      sortBy: 'created_at',
      sortOrder: 'desc',
    }),
    customerGroupStore.fetchCustomerGroupsByTenant(authStore.tenantId)
  ])
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
    color: string | null
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

const onSearchChange = () => {
  // local client-side filtering; no fetch required
}

const onCloseSearch = () => {
  showSearchInput.value = false
  searchText.value = ''
}

const onResetFilters = () => {
  emailFilter.value = ''
  phoneFilter.value = ''
}

onMounted(load)
</script>
<style scoped>
.billing-profiles-page { background: transparent; }
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
.hero-surface { border-radius: 16px; }
.pill-btn { border-radius: 999px; }
.slim-btn { min-height: 32px; padding-left: 10px; padding-right: 10px; }
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.toolbar-left { min-width: 0; }
.toolbar-search { width: min(320px, 75vw); }
.billing-profiles-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}
.color-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 8px;
  border: 1px solid rgba(0, 0, 0, 0.15);
  flex-shrink: 0;
}
.color-preview {
  display: inline-block;
  width: 18px;
  height: 18px;
  border-radius: 4px;
  border: 1px solid rgba(0, 0, 0, 0.15);
  flex-shrink: 0;
}
</style>
