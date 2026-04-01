<template>
  <q-page class="q-pa-lg">
    <div class="q-mb-md text-h5 text-weight-bold">Tenants</div>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <div class="row justify-center">
      <div class="col-12 col-lg-6">
        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div class="text-subtitle1 text-weight-medium">Tenant records</div>
            <q-btn
              color="primary"
              outline
              :loading="loading"
              label="Refresh"
              @click="refreshTenants"
            />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="loading" class="text-grey-7">
            Loading tenants...
          </q-card-section>

          <q-card-section v-else-if="items.length === 0" class="text-grey-7">
            No tenants found.
          </q-card-section>

          <q-list v-else separator>
            <q-item v-for="tenant in items" :key="tenant.id">
              <q-item-section>
                <q-item-label>{{ tenant.name }}</q-item-label>
                <q-item-label caption>
                  {{ tenant.slug }} · {{ tenant.is_active ? 'Active' : 'Inactive' }}
                </q-item-label>
              </q-item-section>

              <q-item-section side class="q-gutter-sm">
                <q-badge :color="tenant.is_active ? 'positive' : 'grey-6'">
                  #{{ tenant.id }}
                </q-badge>

                <div class="row q-gutter-sm justify-end">
                  <q-btn
                    size="sm"
                    color="primary"
                    outline
                    icon="group"
                    label="Get Admins"
                    @click="getTenantAdmins(tenant)"
                  />
                  <q-btn
                    size="sm"
                    color="primary"
                    outline
                    icon="person_add"
                    label="Add Admin"
                    @click="onClickAddAdmin(tenant)"
                  />
                  <q-btn
                    size="sm"
                    color="primary"
                    outline
                    icon="edit"
                    label="Edit"
                    @click="onClickEditTenant(tenant)"
                  />
                  <q-btn
                    size="sm"
                    color="negative"
                    outline
                    icon="delete"
                    label="Delete"
                    @click="onClickDeleteTenant(tenant)"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </div>

    <q-page-sticky position="bottom-right" :offset="[18, 18]">
      <q-fab color="primary" icon="add" @click="onClickAddTenant" />
    </q-page-sticky>

    <AddTenantDialog
      v-model="openAddDialog"
      :initial-data="selectedTenant"
      @save="handleSaveTenant"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete
          <strong>{{ tenantToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteTenant" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openAddAdminDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Add Admin</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="adminEmail"
            label="Admin Email"
            type="email"
            outlined
            dense
          />

          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>

            <q-toggle
              v-model="adminIsActive"
              :label="adminIsActive ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openAddAdminDialog = false" />
          <q-btn color="primary" label="Save" @click="handleSaveAdmin" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openTenantAdminsDialog" persistent>
      <q-card style="min-width: 700px; max-width: 95vw;">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">
            Tenant Admins
            <span v-if="selectedTenantForAdminsView" class="text-grey-7">
              - {{ selectedTenantForAdminsView.name }}
            </span>
          </div>
          <q-btn flat round dense icon="close" @click="openTenantAdminsDialog = false" />
        </q-card-section>

        <q-separator />

        <q-card-section v-if="tenantAdminsLoading" class="text-grey-7">
          Loading admins...
        </q-card-section>

        <q-card-section v-else-if="tenantAdmins.length === 0" class="text-grey-7">
          No admins found.
        </q-card-section>

        <q-list v-else separator>
          <q-item v-for="admin in tenantAdmins" :key="admin.id">
            <q-item-section>
              <div class="row items-center justify-between full-width">
                <div class="text-body1">
                  {{ admin.email }}
                </div>

                <div class="row items-center q-gutter-md">
                  <q-toggle
                    v-model="admin.is_active"
                    :label="admin.is_active ? 'Active' : 'Inactive'"
                    color="positive"
                    keep-color
                    @update:model-value="(value) => onToggleAdminActive(admin, value)"
                  />

                  <q-btn
                    size="sm"
                    color="negative"
                    outline
                    icon="delete"
                    label="Delete"
                    @click="onClickDeleteAdmin(admin)"
                  />
                </div>
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteAdminDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete admin
          <strong>{{ adminToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteAdminDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteAdmin" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from '../stores/tenantStore'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import { useMembershipStore } from 'src/modules/membership/store/membershipStore'

type TenantForm = {
  id?: number
  name: string
  slug: string
  is_active: boolean
}

type MembershipItem = {
  id: number
  tenant_id: number
  role: string
  is_active: boolean
  created_at: string
  updated_at: string
  email: string
}

const tenantStore = useTenantStore()
const { items, loading, error } = storeToRefs(tenantStore)
const refreshTenants = () => tenantStore.fetchTenants()
const authStore = useAuthStore()
const membershipStore = useMembershipStore()

const debugSessionEmail = ref('unknown')
const debugMemberRole = ref('unknown')
const debugScope = ref('unknown')

const openAddDialog = ref(false)
const openDeleteDialog = ref(false)
const openAddAdminDialog = ref(false)
const openTenantAdminsDialog = ref(false)
const openDeleteAdminDialog = ref(false)

const selectedTenant = ref<TenantForm | null>(null)
const tenantToDelete = ref<TenantForm | null>(null)
const selectedTenantForAdmin = ref<TenantForm | null>(null)
const selectedTenantForAdminsView = ref<TenantForm | null>(null)
const adminToDelete = ref<MembershipItem | null>(null)

const adminIsActive = ref(true)
const adminEmail = ref('')

const tenantAdmins = ref<MembershipItem[]>([])
const tenantAdminsLoading = ref(false)

const loadDebugState = async () => {
  const { data } = await supabase.auth.getSession()
  debugSessionEmail.value = data.session?.user?.email ?? 'no-session'
  debugMemberRole.value = authStore.member?.role ?? 'no-store-role'
  debugScope.value = authStore.scope ?? 'no-store-scope'
}

const onClickAddTenant = () => {
  selectedTenant.value = null
  openAddDialog.value = true
}

const onClickEditTenant = (tenant: TenantForm) => {
  selectedTenant.value = {
    id: tenant.id,
    name: tenant.name,
    slug: tenant.slug,
    is_active: tenant.is_active
  }
  openAddDialog.value = true
}

const onClickDeleteTenant = (tenant: TenantForm) => {
  tenantToDelete.value = tenant
  openDeleteDialog.value = true
}

const onClickAddAdmin = (tenant: TenantForm) => {
  selectedTenantForAdmin.value = tenant
  adminEmail.value = ''
  adminIsActive.value = true
  openAddAdminDialog.value = true
}

const onClickDeleteAdmin = (admin: MembershipItem) => {
  adminToDelete.value = admin
  openDeleteAdminDialog.value = true
}

const confirmDeleteTenant = async () => {
  if (tenantToDelete.value) {
    await tenantStore.deleteTenant(tenantToDelete.value)
    console.log('Delete tenant:', tenantToDelete.value)
  }
  openDeleteDialog.value = false
}

const handleSaveTenant = async (payload: TenantForm) => {
  if (payload.id) {
    await tenantStore.updateTenant(payload)
    console.log('Edit tenant data received in parent:', payload)
  } else {
    await tenantStore.createTenant(payload)
    console.log('New tenant data received in parent:', payload)
  }
}

const handleSaveAdmin = async () => {
  console.log('Add admin:', {
    email: adminEmail.value,
    is_active: adminIsActive.value,
    tenant: selectedTenantForAdmin.value
  })

  await membershipStore.createMembership({
    tenant_id: selectedTenantForAdmin.value!.id!,
    email: adminEmail.value,
    role: 'admin',
    is_active: adminIsActive.value
  })

  openAddAdminDialog.value = false
}

const getTenantAdmins = async (tenant: TenantForm) => {
  selectedTenantForAdminsView.value = tenant
  tenantAdminsLoading.value = true

  try {
    const result = await membershipStore.getTenantAdmins(tenant.id!)

    if (!result.success) {
      console.error(result.error)
      tenantAdmins.value = []
      return
    }

    tenantAdmins.value = result.data ?? []
    console.log('Admins for tenant', tenant.id, result.data)
    openTenantAdminsDialog.value = true
  } finally {
    tenantAdminsLoading.value = false
  }
}

const onToggleAdminActive = async (admin: MembershipItem, value: boolean) => {
  const previousValue = !value

  try {
    const result = await membershipStore.updateMembership({
      id: admin.id,
      is_active: value
    })

    if (!result.success) {
      admin.is_active = previousValue
      console.error('Failed to update admin status:', result.error)
      return
    }

    console.log('Admin active status updated:', {
      id: admin.id,
      email: admin.email,
      is_active: value
    })
  } catch (error) {
    admin.is_active = previousValue
    console.error('Failed to update admin status:', error)
  }
}

const confirmDeleteAdmin = async () => {
  if (!adminToDelete.value) return

  try {
    const result = await membershipStore.deleteMembership({
      id: adminToDelete.value.id
    })

    if (!result.success) {
      console.error('Failed to delete admin:', result.error)
      return
    }

    tenantAdmins.value = tenantAdmins.value.filter(
      (item) => item.id !== adminToDelete.value?.id
    )

    console.log('Deleted admin:', adminToDelete.value)
    openDeleteAdminDialog.value = false
  } catch (error) {
    console.error('Failed to delete admin:', error)
  }
}

onMounted(() => {
  void loadDebugState()
  void refreshTenants()
})
</script>
