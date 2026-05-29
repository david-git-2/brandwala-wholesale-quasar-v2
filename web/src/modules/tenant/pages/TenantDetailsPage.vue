<template>
  <q-page class="q-pa-md tenant-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center q-col-gutter-sm">
          <q-btn
            flat
            round
            dense
            icon="arrow_back"
            color="primary"
            @click="goBack"
          />
          <div class="min-w-0 q-ml-sm">
            <div class="text-h6 text-weight-bold">Tenant Details</div>
            <div v-if="tenant" class="text-caption text-grey-8">
              {{ tenant.name }} · {{ tenant.slug }}
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <PageInitialLoader v-if="pageLoading" />

    <template v-else>
      <div v-if="!tenant" class="text-grey-7 q-pa-lg text-center">
        Tenant not found.
      </div>

      <section v-else class="row q-col-gutter-md">
        <div class="col-12 col-lg-5">
          <q-card flat class="tenant-details-page__card floating-surface shadow-1">
            <q-card-section class="row items-start justify-between q-pa-md">
              <div>
                <div class="text-subtitle1 text-weight-bold text-grey-9">{{ tenant.name }}</div>
                <div class="text-caption text-grey-7">{{ tenant.slug }}</div>
              </div>

              <q-chip
                dense
                square
                class="costing-status-chip"
                :style="tenant.is_active ? activeStatusStyle : inactiveStatusStyle"
              >
                <span class="status-dot" :style="{ backgroundColor: tenant.is_active ? '#2f8b5d' : '#66758c' }" />
                {{ tenant.is_active ? 'Active' : 'Inactive' }}
              </q-chip>
            </q-card-section>

            <q-separator />

            <q-card-section class="q-pa-md q-gutter-sm">
              <div class="row items-center justify-between q-py-xs border-bottom">
                <div class="text-grey-8">Tenant ID</div>
                <div class="text-weight-bold">#{{ tenant.id }}</div>
              </div>
              <div class="row items-center justify-between q-py-xs border-bottom">
                <div class="text-grey-8">Slug</div>
                <div class="text-weight-bold">{{ tenant.slug }}</div>
              </div>
              <div class="row items-center justify-between q-py-xs border-bottom">
                <div class="text-grey-8">Public Domain</div>
                <div class="text-weight-bold text-primary">{{ tenant.public_domain || 'Not set' }}</div>
              </div>
              <div class="row items-center justify-between q-py-xs border-bottom">
                <div class="text-grey-8">Status</div>
                <q-chip
                  dense
                  square
                  class="costing-status-chip"
                  :style="tenant.is_active ? activeStatusStyle : inactiveStatusStyle"
                >
                  <span class="status-dot" :style="{ backgroundColor: tenant.is_active ? '#2f8b5d' : '#66758c' }" />
                  {{ tenant.is_active ? 'Active' : 'Inactive' }}
                </q-chip>
              </div>
            </q-card-section>

            <q-separator />

            <q-card-actions align="right" class="q-pa-md tenant-details-page__actions">
              <q-btn
                color="primary"
                outline
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                icon="edit"
                label="Edit"
                @click="onClickEditTenant"
              />
              <q-btn
                color="negative"
                outline
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                icon="delete"
                label="Delete"
                @click="openDeleteDialog = true"
              />
            </q-card-actions>
          </q-card>
        </div>

        <div class="col-12 col-lg-7">
          <q-card flat class="q-mb-md tenant-details-page__card floating-surface shadow-1">
            <q-card-section class="row items-center justify-between q-pa-md tenant-details-page__section-head">
              <div class="text-subtitle1 text-weight-bold text-grey-9">Tenant Admins</div>
              <q-btn
                color="primary"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                icon="person_add"
                label="Add Member"
                @click="onClickAddAdmin"
              />
            </q-card-section>

            <q-separator />

            <q-card-section v-if="tenantAdminsLoading" class="text-grey-7 q-pa-md text-center">
              <q-spinner color="primary" size="2em" />
              <div class="q-mt-xs">Loading admins...</div>
            </q-card-section>

            <q-card-section v-else-if="tenantAdmins.length === 0" class="text-grey-7 q-pa-md text-center">
              No admins found.
            </q-card-section>

            <q-table
              v-else
              flat
              row-key="id"
              :rows="tenantAdmins"
              :columns="tenantAdminColumns"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-details-page__table costing-list-table"
            >
              <template #body-cell-email="props">
                <q-td :props="props">
                  {{ props.row.email }}
                </q-td>
              </template>

              <template #body-cell-role="props">
                <q-td :props="props">
                  {{ props.row.role }}
                </q-td>
              </template>

              <template #body-cell-active="props">
                <q-td :props="props">
                  <q-toggle
                    v-model="props.row.is_active"
                    color="positive"
                    keep-color
                    @update:model-value="(value) => onToggleAdminActive(props.row, value)"
                  />
                </q-td>
              </template>

              <template #body-cell-delete="props">
                <q-td :props="props">
                  <q-btn
                    size="sm"
                    color="negative"
                    flat
                    round
                    icon="delete"
                    @click="onClickDeleteAdmin(props.row)"
                  />
                </q-td>
              </template>
            </q-table>
          </q-card>

          <q-card flat class="tenant-details-page__card floating-surface shadow-1">
            <q-card-section class="row items-center justify-between q-pa-md tenant-details-page__section-head">
              <div class="text-subtitle1 text-weight-bold text-grey-9">Module Features</div>
            </q-card-section>

            <q-separator />

            <q-card-section v-if="modulesLoading" class="text-grey-7 q-pa-md text-center">
              <q-spinner color="primary" size="2em" />
              <div class="q-mt-xs">Loading module features...</div>
            </q-card-section>

            <q-card-section v-else class="q-pa-md">
              <div class="row q-col-gutter-md">
                <div class="col-12 col-md-6">
                  <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">Available Features</div>
                  <q-list bordered separator class="rounded-borders">
                    <q-item v-for="feature in availableModules" :key="feature.id">
                      <q-item-section>
                        <q-item-label class="text-weight-medium">{{ feature.name }}</q-item-label>
                        <q-item-label caption>{{ feature.key }}</q-item-label>
                      </q-item-section>
                      <q-item-section side>
                        <q-btn
                          color="primary"
                          dense
                          flat
                          no-caps
                          label="Add"
                          @click="addTenantFeature(feature.key)"
                        />
                      </q-item-section>
                    </q-item>
                    <q-item v-if="availableModules.length === 0">
                      <q-item-section class="text-grey-7">No available features.</q-item-section>
                    </q-item>
                  </q-list>
                </div>
                <div class="col-12 col-md-6">
                  <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">Tenant Features</div>
                  <q-list bordered separator class="rounded-borders">
                    <q-item v-for="feature in modules" :key="feature.id">
                      <q-item-section>
                        <q-item-label class="text-weight-medium">{{ feature.module_key }}</q-item-label>
                        <q-item-label caption>{{ feature.is_active ? 'Active' : 'Inactive' }}</q-item-label>
                      </q-item-section>
                      <q-item-section side>
                        <q-btn
                          color="negative"
                          dense
                          flat
                          no-caps
                          label="Remove"
                          @click="removeTenantFeature(feature.id)"
                        />
                      </q-item-section>
                    </q-item>
                    <q-item v-if="modules.length === 0">
                      <q-item-section class="text-grey-7">No tenant features assigned.</q-item-section>
                    </q-item>
                  </q-list>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </section>
    </template>

    <AddTenantDialog
      v-model="openEditDialog"
      :initial-data="selectedTenant"
      @save="handleSaveTenant"
    />

    <q-dialog v-model="openDeleteDialog" persistent>
      <q-card style="min-width: 350px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete
          <strong>{{ tenant?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openDeleteDialog = false" />
          <q-btn color="negative" unelevated class="pill-btn" no-caps label="Delete" @click="confirmDeleteTenant" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openAddAdminDialog" persistent>
      <q-card style="min-width: 420px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Add Member</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="adminEmail"
            label="Admin Email"
            type="email"
            outlined
            dense
            class="soft-input"
          />

          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="adminIsActive"
              :label="adminIsActive ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openAddAdminDialog = false" />
          <q-btn color="primary" unelevated class="pill-btn" no-caps label="Save" @click="handleSaveAdmin" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteAdminDialog" persistent>
      <q-card style="min-width: 350px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete admin
          <strong>{{ adminToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openDeleteAdminDialog = false" />
          <q-btn color="negative" unelevated class="pill-btn" no-caps label="Delete" @click="confirmDeleteAdmin" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useTenantStore } from '../stores/tenantStore'
import { useTenantModuleStore } from '../stores/tenantModuleStore'
import { useMembershipStore } from 'src/modules/membership/stores/membershipStore'
import type { Membership } from 'src/modules/membership/types'
import AddTenantDialog from '../components/AddTenantDialog.vue'
import type { Tenant, TenantUpdateInput } from '../types'
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore'

type TenantForm = {
  id?: number
  name: string
  slug: string
  public_domain: string | null
  is_active: boolean
  created_at?: string
  updated_at?: string
}

const route = useRoute()
const router = useRouter()
const $q = useQuasar()

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

const selectedTenant = ref<TenantForm | null>(null)
const adminToDelete = ref<Membership | null>(null)

const adminEmail = ref('')
const adminIsActive = ref(true)

const tenantAdmins = ref<Membership[]>([])
const tenantAdminsLoading = ref(false)
const pageLoading = ref(false)
const pageError = ref('')

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(() => {
  return items.value.find((item) => item.id === tenantId.value) ?? null
})

const tenantAdminColumns = [
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role', field: 'role', align: 'left' as const },
  { name: 'active', label: 'Active', field: 'is_active', align: 'left' as const },
  { name: 'delete', label: 'Delete', field: 'id', align: 'left' as const },
]

const tenantModuleKeys = computed(
  () => new Set(modules.value.map((item) => item.module_key)),
)

const availableModules = computed(() =>
  moduleStore.items.filter((item) => item.is_active && !tenantModuleKeys.value.has(item.key)),
)

const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
}

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
}

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
    public_domain: tenant.value.public_domain,
    is_active: tenant.value.is_active,
    created_at: tenant.value.created_at,
    updated_at: tenant.value.updated_at,
  }

  openEditDialog.value = true
}

const handleSaveTenant = async (payload: TenantForm) => {
  if (payload.id === undefined) return

  const updatePayload: TenantUpdateInput = {
    id: payload.id,
    name: payload.name,
    slug: payload.slug,
    public_domain: payload.public_domain,
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

const addTenantFeature = async (moduleKey: string) => {
  if (!tenant.value?.id) return
  const result = await tenantModuleStore.createTenantModule({
    tenant_id: tenant.value.id,
    module_key: moduleKey,
    is_active: true,
  })
  if (!result.success) {
    pageError.value = result.error ?? 'Failed to add feature.'
  }
}

const removeTenantFeature = async (moduleId: number) => {
  const result = await tenantModuleStore.deleteTenantModule({ id: moduleId })
  if (!result.success) {
    pageError.value = result.error ?? 'Failed to remove feature.'
  }
}

onMounted(async () => {
  await moduleStore.fetchModules()
  void loadPageData()
})
</script>

<style scoped>
.tenant-details-page {
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

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.05);
}

.costing-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.tenant-details-page__header {
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.tenant-details-page__header-main {
  min-width: 0;
}

.tenant-details-page__card :deep(.q-card__section) {
  padding: 0.75rem;
}

.tenant-details-page__actions {
  gap: 0.5rem;
}

.tenant-details-page__list-item {
  padding-top: 0.35rem;
  padding-bottom: 0.35rem;
}

.tenant-details-page__item-actions {
  flex-wrap: wrap;
  justify-content: flex-end;
}

.tenant-details-page__table :deep(th),
.tenant-details-page__table :deep(td) {
  white-space: nowrap;
}

@media (max-width: 1023px) {
  .tenant-details-page__section-head {
    gap: 0.75rem;
  }
}

@media (max-width: 599px) {
  .tenant-details-page__table :deep(th),
  .tenant-details-page__table :deep(td) {
    padding: 0.35rem 0.45rem;
    font-size: 0.875rem;
  }

  .tenant-details-page__header {
    align-items: stretch;
  }

  .tenant-details-page__header-main {
    width: 100%;
  }

  .tenant-details-page__actions,
  .tenant-details-page__item-actions,
  .tenant-details-page__section-head {
    width: 100%;
  }

  .tenant-details-page__item-side {
    width: 100%;
    align-items: flex-start;
    padding-top: 0.75rem;
  }

  .tenant-details-page__actions,
  .tenant-details-page__item-actions {
    width: 100%;
    justify-content: flex-start;
    flex-wrap: wrap;
  }

  .tenant-details-page__list-item {
    align-items: flex-start;
    flex-wrap: wrap;
    padding-bottom: 0.65rem;
  }
}
</style>
