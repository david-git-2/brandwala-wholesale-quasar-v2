<template>
  <q-page class="q-pa-lg">
    <div class="q-mb-md row items-center justify-between">
      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          round
          icon="arrow_back"
          @click="goBack"
        />
        <div>
          <div class="text-h5 text-weight-bold">Tenant Details</div>
          <div v-if="tenant" class="text-grey-7">
            {{ tenant.name }} · {{ tenant.slug }}
          </div>
        </div>
      </div>

      <q-btn
        color="primary"
        outline
        :loading="pageLoading"
        label="Refresh"
        @click="loadPageData"
      />
    </div>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <div v-if="pageLoading" class="text-grey-7">
      Loading tenant details...
    </div>

    <div v-else-if="!tenant" class="text-grey-7">
      Tenant not found.
    </div>

    <div v-else class="row q-col-gutter-lg">
      <div class="col-12 col-lg-5">
        <q-card flat bordered>
          <q-card-section class="row items-start justify-between">
            <div>
              <div class="text-h6">{{ tenant.name }}</div>
              <div class="text-caption text-grey-7">{{ tenant.slug }}</div>
            </div>

            <q-badge :color="tenant.is_active ? 'positive' : 'grey-6'">
              {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </q-badge>
          </q-card-section>

          <q-separator />

          <q-card-section class="q-gutter-md">
            <div><strong>ID:</strong> #{{ tenant.id }}</div>
            <div><strong>Name:</strong> {{ tenant.name }}</div>
            <div><strong>Slug:</strong> {{ tenant.slug }}</div>
            <div>
              <strong>Status:</strong>
              {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </div>
          </q-card-section>

          <q-separator />

          <q-card-actions align="right">
            <q-btn
              color="primary"
              outline
              icon="edit"
              label="Edit"
              @click="onClickEditTenant"
            />
            <q-btn
              color="negative"
              outline
              icon="delete"
              label="Delete"
              @click="openDeleteDialog = true"
            />
          </q-card-actions>
        </q-card>
      </div>

      <div class="col-12 col-lg-7">
        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div class="text-h6">Tenant Admins</div>
            <q-btn
              color="primary"
              icon="person_add"
              label="Add Member"
              @click="onClickAddAdmin"
            />
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
                <q-item-label>{{ admin.email }}</q-item-label>
                <q-item-label caption>
                  Role: {{ admin.role }} ·
                  {{ admin.is_active ? 'Active' : 'Inactive' }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <div class="row items-center q-gutter-sm">
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
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>

        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div class="text-h6">Module Features</div>
            <q-btn
              color="primary"
              icon="add"
              label="Add Feature"
              @click="onClickAddFeature"
            />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="modulesLoading" class="text-grey-7">
            Loading module features...
          </q-card-section>

          <q-card-section v-else-if="modules.length === 0" class="text-grey-7">
            No module features found.
          </q-card-section>

          <q-list v-else separator>
            <q-item v-for="module in modules" :key="module.id">
              <q-item-section>
                <q-item-label>{{ module.module_key }}</q-item-label>
                <q-item-label caption>
                  #{{ module.id }} ·
                  {{ module.is_active ? 'Active' : 'Inactive' }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <div class="row items-center q-gutter-sm">
                  <q-toggle
                    :model-value="module.is_active"
                    :label="module.is_active ? 'Active' : 'Inactive'"
                    color="positive"
                    keep-color
                    @update:model-value="(value) => onToggleModuleActive(module, value)"
                  />

                  <q-btn
                    size="sm"
                    color="negative"
                    outline
                    icon="delete"
                    label="Delete"
                    @click="onClickDeleteModule(module)"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </div>

    <AddTenantDialog
      v-model="openEditDialog"
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
          <strong>{{ tenant?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteTenant" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openAddAdminDialog" persistent>
      <q-card style="min-width: 420px">
        <q-card-section>
          <div class="text-h6">Add Member</div>
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

    <q-dialog v-model="openAddFeatureDialog" persistent>
      <q-card style="min-width: 420px">
        <q-card-section>
          <div class="text-h6">Add Feature</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-select
            v-model="featureForm.module_key"
            label="Module Key"
            outlined
            dense
            :options="moduleStore.items.map((m) => m.key)"
          />

          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="featureForm.is_active"
              :label="featureForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openAddFeatureDialog = false" />
          <q-btn color="primary" label="Save" @click="handleSaveFeature" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteModuleDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete feature
          <strong>{{ moduleToDelete?.module_key }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteModuleDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteModule" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import { useTenantStore } from '../stores/tenantStore'
import { useTenantModuleStore } from '../stores/tenantModuleStore'
import { useMembershipStore } from 'src/modules/membership/stores/membershipStore'
import type { Membership } from 'src/modules/membership/types'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import type { Tenant, TenantModule, TenantUpdateInput } from '../types'
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore'

type TenantForm = {
  id?: number
  name: string
  slug: string
  is_active: boolean
}

const route = useRoute()
const router = useRouter()

const tenantStore = useTenantStore()
const tenantModuleStore = useTenantModuleStore()
const membershipStore = useMembershipStore()
const { items } = storeToRefs(tenantStore)
const { items: modules, loading: modulesLoading } = storeToRefs(tenantModuleStore)
const moduleStore = useModuleStore()

const openEditDialog = ref(false)
const openDeleteDialog = ref(false)
const openAddAdminDialog = ref(false)
const openDeleteAdminDialog = ref(false)
const openAddFeatureDialog = ref(false)
const openDeleteModuleDialog = ref(false)

const selectedTenant = ref<TenantForm | null>(null)
const adminToDelete = ref<Membership | null>(null)
const moduleToDelete = ref<TenantModule | null>(null)

const adminEmail = ref('')
const adminIsActive = ref(true)

const featureForm = ref({
  module_key: '',
  is_active: true,
})

const tenantAdmins = ref<Membership[]>([])
const tenantAdminsLoading = ref(false)
const pageLoading = ref(false)
const pageError = ref('')

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(() => {
  return items.value.find((item) => item.id === tenantId.value) ?? null
})

const loadTenantAdmins = async () => {
  if (!tenant.value?.id) return

  tenantAdminsLoading.value = true

  try {
    const result = await membershipStore.getTenantAdmins(tenant.value.id)

    if (!result.success) {
      tenantAdmins.value = []
      pageError.value = result.error || 'Failed to load tenant admins.'
      return
    }

    tenantAdmins.value = result.data ?? []
  } catch (err) {
    console.error(err)
    pageError.value = 'Failed to load tenant admins.'
    tenantAdmins.value = []
  } finally {
    tenantAdminsLoading.value = false
  }
}

const loadTenantModules = async () => {
  if (!tenant.value?.id) return

  const result = await tenantModuleStore.fetchTenantModules(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load module features.'
  }
}

const loadPageData = async () => {
  pageLoading.value = true
  pageError.value = ''

  try {
    await tenantStore.fetchTenants()

    if (!tenant.value) {
      pageError.value = 'Tenant not found.'
      return
    }

    await Promise.all([
      loadTenantAdmins(),
      loadTenantModules()
    ])
  } catch (err) {
    console.error(err)
    pageError.value = 'Failed to load tenant details.'
  } finally {
    pageLoading.value = false
  }
}

const goBack = () => {
  void router.push('/platform/tenants')
}

const onClickEditTenant = () => {
  if (!tenant.value) return

  selectedTenant.value = {
    id: tenant.value.id,
    name: tenant.value.name,
    slug: tenant.value.slug,
    is_active: tenant.value.is_active
  }

  openEditDialog.value = true
}

const handleSaveTenant = async (payload: TenantForm) => {
  if (payload.id === undefined) return

  const updatePayload: TenantUpdateInput = {
    id: payload.id,
    name: payload.name,
    slug: payload.slug,
    is_active: payload.is_active,
  }

  await tenantStore.updateTenant(updatePayload)
  openEditDialog.value = false
  await loadPageData()
}

const confirmDeleteTenant = async () => {
  if (!tenant.value) return

  await tenantStore.deleteTenant({ id: tenant.value.id })
  openDeleteDialog.value = false
  void router.push('/platform/tenants')
}

const onClickAddAdmin = () => {
  adminEmail.value = ''
  adminIsActive.value = true
  openAddAdminDialog.value = true
}

const handleSaveAdmin = async () => {
  if (!tenant.value?.id || !adminEmail.value) return

  await membershipStore.createMembership({
    tenant_id: tenant.value.id,
    email: adminEmail.value,
    role: 'admin',
    is_active: adminIsActive.value
  })

  openAddAdminDialog.value = false
  await loadTenantAdmins()
}

const onToggleAdminActive = async (admin: Membership, value: boolean) => {
  const previousValue = !value

  try {
    const result = await membershipStore.updateMembership({
      id: admin.id,
      is_active: value
    })

    if (!result.success) {
      admin.is_active = previousValue
      console.error('Failed to update admin status:', result.error)
    }
  } catch (err) {
    admin.is_active = previousValue
    console.error('Failed to update admin status:', err)
  }
}

const onClickDeleteAdmin = (admin: Membership) => {
  adminToDelete.value = admin
  openDeleteAdminDialog.value = true
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

    openDeleteAdminDialog.value = false
  } catch (err) {
    console.error('Failed to delete admin:', err)
  }
}

const onClickAddFeature = () => {
  featureForm.value = {
    module_key: '',
    is_active: true,
  }
  openAddFeatureDialog.value = true
}

const handleSaveFeature = async () => {
  if (!tenant.value?.id || !featureForm.value.module_key.trim()) return

  const result = await tenantModuleStore.createTenantModule({
    tenant_id: tenant.value.id,
    module_key: featureForm.value.module_key.trim(),
    is_active: featureForm.value.is_active,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to create feature.'
    return
  }

  openAddFeatureDialog.value = false
  await loadTenantModules()
}

const onToggleModuleActive = async (module: TenantModule, value: boolean) => {
  const previousValue = module.is_active
  module.is_active = value

  const result = await tenantModuleStore.updateTenantModule({
    id: module.id,
    is_active: value,
  })

  if (!result.success) {
    module.is_active = previousValue
    pageError.value = result.error ?? 'Failed to update feature.'
  }
}

const onClickDeleteModule = (module: TenantModule) => {
  moduleToDelete.value = module
  openDeleteModuleDialog.value = true
}

const confirmDeleteModule = async () => {
  if (!moduleToDelete.value) return

  const result = await tenantModuleStore.deleteTenantModule({
    id: moduleToDelete.value.id,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to delete feature.'
    return
  }

  openDeleteModuleDialog.value = false
  moduleToDelete.value = null
  await loadTenantModules()
}

onMounted(async () => {
  await moduleStore.fetchModules()
  void loadPageData()
})
</script>
