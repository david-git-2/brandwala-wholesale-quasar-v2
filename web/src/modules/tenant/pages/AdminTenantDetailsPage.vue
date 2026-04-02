<template>
  <q-page class="q-pa-lg">
    <div class="q-mb-md row items-center justify-between">
      <div class="row items-center q-gutter-sm">
        <q-btn flat round icon="arrow_back" @click="goBack" />
        <div>
          <div class="text-h5 text-weight-bold">Tenant Details</div>
          <div v-if="tenant" class="text-grey-7">
            {{ tenant.name }} · {{ tenant.slug }}
          </div>
        </div>
      </div>
    </div>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <div v-if="pageLoading" class="text-grey-7">Loading tenant details...</div>

    <div v-else-if="!tenant" class="text-grey-7">Tenant not found.</div>

    <div v-else class="row q-col-gutter-lg">
      <div class="col-12 col-lg-4">
        <q-card flat bordered class="q-mb-lg">
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
        </q-card>

        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Customer Groups</div>
              <div class="text-caption text-grey-7">
                Organize customer-side access by company or buying team.
              </div>
            </div>

            <q-btn color="primary" icon="groups" label="Add Group" @click="openCreateGroupDialog" />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="customerGroupsLoading" class="text-grey-7">
            Loading customer groups...
          </q-card-section>

          <q-card-section v-else-if="customerGroups.length === 0" class="text-grey-7">
            No customer groups found.
          </q-card-section>

          <q-list v-else separator>
            <q-item
              v-for="group in customerGroups"
              :key="group.id"
              clickable
              :active="selectedCustomerGroupId === group.id"
              active-class="customer-group-item--active"
              class="customer-group-item"
              @click="selectCustomerGroup(group.id)"
            >
              <q-item-section avatar>
                <div
                  class="customer-group-chip"
                  :style="{ backgroundColor: group.accent_color || '#B45F34' }"
                />
              </q-item-section>

              <q-item-section>
                <q-item-label>{{ group.name }}</q-item-label>
                <q-item-label caption>
                  #{{ group.id }} · {{ group.is_active ? 'Active' : 'Inactive' }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <div class="row items-center q-gutter-xs">
                  <q-btn flat round dense icon="edit" @click.stop="openEditGroupDialog(group)" />
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="delete"
                    @click.stop="openDeleteGroupDialog(group)"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="col-12 col-lg-8">
        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Internal Members</div>
              <div class="text-caption text-grey-7">
                Customer-side users now belong to customer groups, not tenant memberships.
              </div>
            </div>

            <q-btn color="primary" icon="person_add" label="Add Staff" @click="onClickAddMember('staff')" />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="tenantMembersLoading" class="text-grey-7">
            Loading members...
          </q-card-section>

          <q-card-section v-else-if="tenantMembers.length === 0" class="text-grey-7">
            No members found.
          </q-card-section>

          <q-card-section v-else>
            <div class="text-subtitle1 text-weight-bold q-mb-sm">Staff</div>
            <q-list v-if="staffMembers.length" separator>
              <q-item v-for="member in staffMembers" :key="member.id">
                <q-item-section>
                  <q-item-label>{{ member.email }}</q-item-label>
                  <q-item-label caption>
                    Role: {{ member.role }} ·
                    {{ member.is_active ? 'Active' : 'Inactive' }}
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <div class="row items-center q-gutter-sm">
                    <q-toggle
                      v-model="member.is_active"
                      :label="member.is_active ? 'Active' : 'Inactive'"
                      color="positive"
                      keep-color
                      @update:model-value="(value) => onToggleMemberActive(member, value)"
                    />

                    <q-btn
                      size="sm"
                      color="negative"
                      outline
                      icon="delete"
                      @click="onClickDeleteMember(member)"
                    />
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
            <div v-else class="text-grey-6">No staff found.</div>
          </q-card-section>
        </q-card>

        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Customer Group Members</div>
              <div class="text-caption text-grey-7">
                Add customer admins, negotiators, and staff inside the selected group.
              </div>
            </div>

            <q-btn
              color="primary"
              icon="person_add"
              label="Add Customer User"
              :disable="!selectedCustomerGroup"
              @click="openCreateCustomerMemberDialog"
            />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="!selectedCustomerGroup" class="text-grey-7">
            Select a customer group to manage its members.
          </q-card-section>

          <template v-else>
            <q-card-section class="row items-center justify-between">
              <div class="row items-center q-gutter-sm">
                <div
                  class="customer-group-chip customer-group-chip--large"
                  :style="{ backgroundColor: selectedCustomerGroup.accent_color || '#B45F34' }"
                />
                <div>
                  <div class="text-subtitle1 text-weight-bold">
                    {{ selectedCustomerGroup.name }}
                  </div>
                  <div class="text-caption text-grey-7">
                    Accent: {{ selectedCustomerGroup.accent_color || 'Not set' }}
                  </div>
                </div>
              </div>

              <q-toggle
                :model-value="selectedCustomerGroup.is_active"
                :label="selectedCustomerGroup.is_active ? 'Active' : 'Inactive'"
                color="positive"
                keep-color
                @update:model-value="onToggleSelectedCustomerGroupActive"
              />
            </q-card-section>

            <q-separator />

            <q-card-section v-if="customerGroupMembersLoading" class="text-grey-7">
              Loading customer group members...
            </q-card-section>

            <q-card-section
              v-else-if="customerGroupMembers.length === 0"
              class="text-grey-7"
            >
              No members found for this customer group.
            </q-card-section>

            <q-list v-else separator>
              <q-item v-for="member in customerGroupMembers" :key="member.id">
                <q-item-section>
                  <q-item-label>{{ member.name }}</q-item-label>
                  <q-item-label caption>
                    {{ member.email }} · {{ formatCustomerRole(member.role) }} ·
                    {{ member.is_active ? 'Active' : 'Inactive' }}
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <div class="row items-center q-gutter-xs">
                    <q-toggle
                      :model-value="member.is_active"
                      :label="member.is_active ? 'Active' : 'Inactive'"
                      color="positive"
                      keep-color
                      @update:model-value="
                        (value) => onToggleCustomerGroupMemberActive(member, value)
                      "
                    />
                    <q-btn flat round dense icon="edit" @click="openEditCustomerMemberDialog(member)" />
                    <q-btn
                      flat
                      round
                      dense
                      color="negative"
                      icon="delete"
                      @click="openDeleteCustomerMemberDialog(member)"
                    />
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </template>
        </q-card>

        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div class="text-h6">Module Features</div>
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
                  #{{ module.id }} · {{ module.is_active ? 'Active' : 'Inactive' }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-badge :color="module.is_active ? 'positive' : 'grey-6'">
                  {{ module.is_active ? 'Active' : 'Inactive' }}
                </q-badge>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </div>

    <q-dialog v-model="openAddMemberDialog" persistent>
      <q-card style="min-width: 420px">
        <q-card-section>
          <div class="text-h6">Add Staff</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="memberEmail" label="Email" type="email" outlined dense />
          <q-input :model-value="selectedMemberRole" label="Role" outlined dense readonly />
          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="memberIsActive"
              :label="memberIsActive ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openAddMemberDialog = false" />
          <q-btn color="primary" label="Save" @click="handleSaveMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteMemberDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete member
          <strong>{{ memberToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteMemberDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCustomerGroupDialog" persistent>
      <q-card style="min-width: 460px">
        <q-card-section>
          <div class="text-h6">
            {{ customerGroupForm.id ? 'Edit Customer Group' : 'Add Customer Group' }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="customerGroupForm.name" label="Group name" outlined dense />
          <q-input
            v-model="customerGroupForm.accent_color"
            label="Accent color"
            outlined
            dense
            placeholder="#B45F34"
          >
            <template #append>
              <q-icon
                name="palette"
                class="cursor-pointer"
                :style="{ color: customerGroupPreviewColor }"
              >
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-card flat bordered class="customer-group-color-picker">
                    <q-card-section class="q-pa-sm">
                      <q-color
                        v-model="customerGroupForm.accent_color"
                        default-view="palette"
                        format-model="hex"
                        no-header-tabs
                        no-footer
                      />
                    </q-card-section>
                  </q-card>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <div class="customer-group-color-row">
            <div class="customer-group-color-preview">
              <div
                class="customer-group-chip customer-group-chip--large"
                :style="{ backgroundColor: customerGroupPreviewColor }"
              />
              <div class="text-caption text-grey-7">
                Preview: {{ customerGroupPreviewColor }}
              </div>
            </div>
            <div class="customer-group-swatches">
              <button
                v-for="swatch in customerGroupAccentPresets"
                :key="swatch"
                type="button"
                class="customer-group-swatch"
                :class="{
                  'customer-group-swatch--active': customerGroupPreviewColor === swatch,
                }"
                :style="{ backgroundColor: swatch }"
                @click="customerGroupForm.accent_color = swatch"
              />
            </div>
          </div>
          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="customerGroupForm.is_active"
              :label="customerGroupForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
          <div v-if="!customerGroupForm.id" class="customer-group-admin-block q-gutter-md">
            <div>
              <div class="text-subtitle2 text-weight-medium">First customer admin</div>
              <div class="text-caption text-grey-7">
                Add the first customer admin now, or leave this blank and add them later.
              </div>
            </div>
            <q-input v-model="customerGroupAdminForm.name" label="Admin name" outlined dense />
            <q-input
              v-model="customerGroupAdminForm.email"
              label="Admin email"
              type="email"
              outlined
              dense
            />
            <div class="row items-center justify-between">
              <div class="text-subtitle2">Admin status</div>
              <q-toggle
                v-model="customerGroupAdminForm.is_active"
                :label="customerGroupAdminForm.is_active ? 'Active' : 'Inactive'"
                color="positive"
                keep-color
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openCustomerGroupDialog = false" />
          <q-btn color="primary" label="Save" @click="saveCustomerGroup" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCustomerGroupDialog" persistent>
      <q-card style="min-width: 360px">
        <q-card-section>
          <div class="text-h6">Delete Customer Group</div>
        </q-card-section>

        <q-card-section>
          Delete customer group <strong>{{ customerGroupToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteCustomerGroupDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteCustomerGroup" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCustomerMemberDialog" persistent>
      <q-card style="min-width: 460px">
        <q-card-section>
          <div class="text-h6">
            {{
              customerGroupMemberForm.id
                ? 'Edit Customer Group Member'
                : 'Add Customer Group Member'
            }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="customerGroupMemberForm.name" label="Name" outlined dense />
          <q-input
            v-model="customerGroupMemberForm.email"
            label="Email"
            type="email"
            outlined
            dense
          />
          <q-select
            v-model="customerGroupMemberForm.role"
            :options="customerRoleOptions"
            emit-value
            map-options
            label="Role"
            outlined
            dense
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="customerGroupMemberForm.is_active"
              :label="customerGroupMemberForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openCustomerMemberDialog = false" />
          <q-btn color="primary" label="Save" @click="saveCustomerGroupMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCustomerMemberDialogOpen" persistent>
      <q-card style="min-width: 360px">
        <q-card-section>
          <div class="text-h6">Delete Customer Group Member</div>
        </q-card-section>

        <q-card-section>
          Delete customer member <strong>{{ customerGroupMemberToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteCustomerMemberDialogOpen = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteCustomerGroupMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { watch } from 'vue'

import { useMembershipStore } from 'src/modules/membership/stores/membershipStore'
import type { Membership } from 'src/modules/membership/types'
import { useCustomerGroupStore } from '../stores/customerGroupStore'
import { useTenantModuleStore } from '../stores/tenantModuleStore'
import { useTenantStore } from '../stores/tenantStore'
import type {
  CustomerGroup,
  CustomerGroupMember,
  CustomerGroupRole,
  Tenant,
} from '../types'

const route = useRoute()
const router = useRouter()

const tenantStore = useTenantStore()
const tenantModuleStore = useTenantModuleStore()
const membershipStore = useMembershipStore()
const customerGroupStore = useCustomerGroupStore()

const { items } = storeToRefs(tenantStore)
const { items: modules, loading: modulesLoading } = storeToRefs(tenantModuleStore)
const {
  groups: customerGroups,
  members: customerGroupMembers,
  loading: customerGroupsLoading,
  membersLoading: customerGroupMembersLoading,
} = storeToRefs(customerGroupStore)

const openAddMemberDialog = ref(false)
const openDeleteMemberDialog = ref(false)
const openCustomerGroupDialog = ref(false)
const openDeleteCustomerGroupDialog = ref(false)
const openCustomerMemberDialog = ref(false)
const openDeleteCustomerMemberDialogOpen = ref(false)

const memberToDelete = ref<Membership | null>(null)
const customerGroupToDelete = ref<CustomerGroup | null>(null)
const customerGroupMemberToDelete = ref<CustomerGroupMember | null>(null)

const memberEmail = ref('')
const memberIsActive = ref(true)
const selectedMemberRole = ref<'staff'>('staff')

const tenantMembers = ref<Membership[]>([])
const tenantMembersLoading = ref(false)
const pageLoading = ref(false)
const pageError = ref('')
const selectedCustomerGroupId = ref<number | null>(null)

const customerGroupForm = ref<{
  id: number | null
  name: string
  accent_color: string
  is_active: boolean
}>({
  id: null,
  name: '',
  accent_color: '',
  is_active: true,
})

const customerGroupAdminForm = ref<{
  name: string
  email: string
  is_active: boolean
}>({
  name: '',
  email: '',
  is_active: true,
})

const customerGroupMemberForm = ref<{
  id: number | null
  name: string
  email: string
  role: CustomerGroupRole
  is_active: boolean
}>({
  id: null,
  name: '',
  email: '',
  role: 'staff',
  is_active: true,
})

const customerRoleOptions = [
  { label: 'Customer Admin', value: 'admin' },
  { label: 'Customer Negotiator', value: 'negotiator' },
  { label: 'Customer Staff', value: 'staff' },
] satisfies { label: string; value: CustomerGroupRole }[]

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
)

const selectedCustomerGroup = computed<CustomerGroup | null>(
  () =>
    customerGroups.value.find((group) => group.id === selectedCustomerGroupId.value) ??
    null,
)

const staffMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'staff'),
)

const defaultCustomerGroupAccent = '#B45F34'

const customerGroupAccentPresets = [
  '#B45F34',
  '#8E4B2B',
  '#C46A3C',
  '#6F7C4F',
  '#2F6E73',
  '#7D4E8B',
] as const

const customerGroupPreviewColor = computed(() => {
  const color = customerGroupForm.value.accent_color.trim()
  return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color)
    ? color.toUpperCase()
    : defaultCustomerGroupAccent
})

const formatCustomerRole = (role: CustomerGroupRole) => {
  if (role === 'admin') return 'Customer Admin'
  if (role === 'negotiator') return 'Customer Negotiator'
  return 'Customer Staff'
}

const resetCustomerGroupForm = () => {
  customerGroupForm.value = {
    id: null,
    name: '',
    accent_color: '',
    is_active: true,
  }

  customerGroupAdminForm.value = {
    name: '',
    email: '',
    is_active: true,
  }
}

const resetCustomerGroupMemberForm = () => {
  customerGroupMemberForm.value = {
    id: null,
    name: '',
    email: '',
    role: 'staff',
    is_active: true,
  }
}

const loadTenantMembers = async () => {
  if (!tenant.value?.id) return

  tenantMembersLoading.value = true

  try {
    const result = await membershipStore.fetchMembershipsByTenantId(tenant.value.id)

    if (!result.success) {
      tenantMembers.value = []
      pageError.value = result.error || 'Failed to load members.'
      return
    }

    tenantMembers.value = (result.data ?? []).filter(
      (item: Membership) => item.role === 'staff',
    )
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load members.'
    tenantMembers.value = []
  } finally {
    tenantMembersLoading.value = false
  }
}

const loadTenantModules = async () => {
  if (!tenant.value?.id) return

  const result = await tenantModuleStore.fetchTenantModules(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load module features.'
  }
}

const loadCustomerGroups = async () => {
  if (!tenant.value?.id) return

  const result = await customerGroupStore.fetchCustomerGroupsByTenant(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load customer groups.'
    return
  }

  const nextSelectedId =
    customerGroups.value.find((group) => group.id === selectedCustomerGroupId.value)?.id ??
    customerGroups.value[0]?.id ??
    null

  selectedCustomerGroupId.value = nextSelectedId

  if (nextSelectedId !== null) {
    await loadCustomerGroupMembers(nextSelectedId)
  } else {
    customerGroupStore.members = []
  }
}

const loadCustomerGroupMembers = async (customerGroupId: number) => {
  const result =
    await customerGroupStore.fetchCustomerGroupMembersByGroup(customerGroupId)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load customer group members.'
  }
}

const loadPageData = async () => {
  pageLoading.value = true
  pageError.value = ''

  try {
    await tenantStore.fetchTenantDetailsByMembership({
      tenantId: tenantId.value,
    })

    if (!tenant.value) {
      pageError.value = 'Tenant not found.'
      return
    }

    await Promise.all([loadTenantMembers(), loadTenantModules(), loadCustomerGroups()])
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load tenant details.'
  } finally {
    pageLoading.value = false
  }
}

const goBack = () => {
  void router.push('/app/tenants')
}

watch(
  tenant,
  (value) => {
    if (!value) {
      return
    }

    tenantStore.setSelectedTenant({
      id: value.id,
      slug: value.slug,
    })
  },
  { immediate: true },
)

const onClickAddMember = (role: 'staff') => {
  selectedMemberRole.value = role
  memberEmail.value = ''
  memberIsActive.value = true
  openAddMemberDialog.value = true
}

const handleSaveMember = async () => {
  if (!tenant.value?.id || !memberEmail.value.trim()) return

  const result = await membershipStore.createMembership({
    tenant_id: tenant.value.id,
    email: memberEmail.value,
    role: selectedMemberRole.value,
    is_active: memberIsActive.value,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to create member.'
    return
  }

  openAddMemberDialog.value = false
  await loadTenantMembers()
}

const onToggleMemberActive = async (member: Membership, value: boolean) => {
  const previousValue = !value

  try {
    const result = await membershipStore.updateMembership({
      id: member.id,
      is_active: value,
    })

    if (!result.success) {
      member.is_active = previousValue
      pageError.value = result.error ?? 'Failed to update member status.'
    }
  } catch (error) {
    member.is_active = previousValue
    console.error(error)
    pageError.value = 'Failed to update member status.'
  }
}

const onClickDeleteMember = (member: Membership) => {
  memberToDelete.value = member
  openDeleteMemberDialog.value = true
}

const confirmDeleteMember = async () => {
  if (!memberToDelete.value) return

  try {
    const result = await membershipStore.deleteMembership({
      id: memberToDelete.value.id,
    })

    if (!result.success) {
      pageError.value = result.error ?? 'Failed to delete member.'
      return
    }

    tenantMembers.value = tenantMembers.value.filter(
      (item) => item.id !== memberToDelete.value?.id,
    )

    openDeleteMemberDialog.value = false
    memberToDelete.value = null
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to delete member.'
  }
}

const selectCustomerGroup = (customerGroupId: number) => {
  selectedCustomerGroupId.value = customerGroupId
  void loadCustomerGroupMembers(customerGroupId)
}

const openCreateGroupDialog = () => {
  resetCustomerGroupForm()
  openCustomerGroupDialog.value = true
}

const openEditGroupDialog = (group: CustomerGroup) => {
  customerGroupForm.value = {
    id: group.id,
    name: group.name,
    accent_color: group.accent_color ?? '',
    is_active: group.is_active,
  }
  openCustomerGroupDialog.value = true
}

const saveCustomerGroup = async () => {
  if (!tenant.value?.id || !customerGroupForm.value.name.trim()) return

  const shouldCreateFirstAdmin =
    !customerGroupForm.value.id &&
    (customerGroupAdminForm.value.name.trim() || customerGroupAdminForm.value.email.trim())

  if (
    shouldCreateFirstAdmin &&
    (!customerGroupAdminForm.value.name.trim() ||
      !customerGroupAdminForm.value.email.trim())
  ) {
    pageError.value = 'Add both admin name and email, or leave both blank.'
    return
  }

  const result = customerGroupForm.value.id
    ? await customerGroupStore.updateCustomerGroup({
        id: customerGroupForm.value.id,
        name: customerGroupForm.value.name,
        accent_color: customerGroupForm.value.accent_color,
        is_active: customerGroupForm.value.is_active,
      })
    : await customerGroupStore.createCustomerGroup({
        tenant_id: tenant.value.id,
        name: customerGroupForm.value.name,
        accent_color: customerGroupForm.value.accent_color,
        is_active: customerGroupForm.value.is_active,
      })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to save customer group.'
    return
  }

  const savedGroupId = result.data?.id ?? customerGroupForm.value.id

  if (shouldCreateFirstAdmin && savedGroupId) {
    const adminResult = await customerGroupStore.createCustomerGroupMember({
      customer_group_id: savedGroupId,
      name: customerGroupAdminForm.value.name,
      email: customerGroupAdminForm.value.email,
      role: 'admin',
      is_active: customerGroupAdminForm.value.is_active,
    })

    if (!adminResult.success) {
      pageError.value = adminResult.error ?? 'Customer group was created, but the admin could not be added.'
      selectedCustomerGroupId.value = savedGroupId
      openCustomerGroupDialog.value = false
      await loadCustomerGroups()
      await loadCustomerGroupMembers(savedGroupId)
      return
    }
  }

  openCustomerGroupDialog.value = false
  await loadCustomerGroups()

  if (savedGroupId) {
    selectedCustomerGroupId.value = savedGroupId
    await loadCustomerGroupMembers(savedGroupId)
  }
}

const openDeleteGroupDialog = (group: CustomerGroup) => {
  customerGroupToDelete.value = group
  openDeleteCustomerGroupDialog.value = true
}

const confirmDeleteCustomerGroup = async () => {
  if (!customerGroupToDelete.value) return

  const deletedId = customerGroupToDelete.value.id
  const result = await customerGroupStore.deleteCustomerGroup({ id: deletedId })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to delete customer group.'
    return
  }

  openDeleteCustomerGroupDialog.value = false
  customerGroupToDelete.value = null

  if (selectedCustomerGroupId.value === deletedId) {
    selectedCustomerGroupId.value = customerGroups.value[0]?.id ?? null
  }

  if (selectedCustomerGroupId.value !== null) {
    await loadCustomerGroupMembers(selectedCustomerGroupId.value)
  }
}

const onToggleCustomerGroupActive = async (
  group: CustomerGroup,
  value: boolean,
) => {
  const previousValue = group.is_active
  group.is_active = value

  const result = await customerGroupStore.updateCustomerGroup({
    id: group.id,
    is_active: value,
  })

  if (!result.success) {
    group.is_active = previousValue
    pageError.value = result.error ?? 'Failed to update customer group.'
  }
}

const onToggleSelectedCustomerGroupActive = async (value: boolean) => {
  if (!selectedCustomerGroup.value) return

  await onToggleCustomerGroupActive(selectedCustomerGroup.value, value)
}

const openCreateCustomerMemberDialog = () => {
  resetCustomerGroupMemberForm()
  openCustomerMemberDialog.value = true
}

const openEditCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberForm.value = {
    id: member.id,
    name: member.name,
    email: member.email,
    role: member.role,
    is_active: member.is_active,
  }
  openCustomerMemberDialog.value = true
}

const saveCustomerGroupMember = async () => {
  if (!selectedCustomerGroup.value) return

  if (
    !customerGroupMemberForm.value.name.trim() ||
    !customerGroupMemberForm.value.email.trim()
  ) {
    return
  }

  const result = customerGroupMemberForm.value.id
    ? await customerGroupStore.updateCustomerGroupMember({
        id: customerGroupMemberForm.value.id,
        name: customerGroupMemberForm.value.name,
        email: customerGroupMemberForm.value.email,
        role: customerGroupMemberForm.value.role,
        is_active: customerGroupMemberForm.value.is_active,
      })
    : await customerGroupStore.createCustomerGroupMember({
        customer_group_id: selectedCustomerGroup.value.id,
        name: customerGroupMemberForm.value.name,
        email: customerGroupMemberForm.value.email,
        role: customerGroupMemberForm.value.role,
        is_active: customerGroupMemberForm.value.is_active,
      })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to save customer group member.'
    return
  }

  openCustomerMemberDialog.value = false
  await loadCustomerGroupMembers(selectedCustomerGroup.value.id)
}

const onToggleCustomerGroupMemberActive = async (
  member: CustomerGroupMember,
  value: boolean,
) => {
  const previousValue = member.is_active
  member.is_active = value

  const result = await customerGroupStore.updateCustomerGroupMember({
    id: member.id,
    is_active: value,
  })

  if (!result.success) {
    member.is_active = previousValue
    pageError.value = result.error ?? 'Failed to update customer member.'
  }
}

const openDeleteCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberToDelete.value = member
  openDeleteCustomerMemberDialogOpen.value = true
}

const confirmDeleteCustomerGroupMember = async () => {
  if (!customerGroupMemberToDelete.value || !selectedCustomerGroup.value) return

  const result = await customerGroupStore.deleteCustomerGroupMember({
    id: customerGroupMemberToDelete.value.id,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to delete customer member.'
    return
  }

  openDeleteCustomerMemberDialogOpen.value = false
  customerGroupMemberToDelete.value = null
  await loadCustomerGroupMembers(selectedCustomerGroup.value.id)
}

onMounted(() => {
  void loadPageData()
})
</script>

<style scoped>
.customer-group-admin-block {
  padding-top: 0.5rem;
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.customer-group-item {
  border-radius: 12px;
  margin: 0.25rem 0.5rem;
}

.customer-group-item--active {
  background: rgb(180 95 52 / 0.1);
  color: inherit;
}

.customer-group-item--active :deep(.q-item__label--caption) {
  color: rgba(31, 41, 55, 0.72);
}

.customer-group-chip {
  width: 18px;
  height: 18px;
  border-radius: 999px;
  border: 2px solid rgba(255, 255, 255, 0.9);
  box-shadow: 0 0 0 1px rgba(31, 41, 55, 0.12);
}

.customer-group-chip--large {
  width: 28px;
  height: 28px;
}

.customer-group-color-picker {
  border-radius: 16px;
}

.customer-group-color-row {
  display: grid;
  gap: 0.75rem;
}

.customer-group-color-preview {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.customer-group-swatches {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.customer-group-swatch {
  width: 28px;
  height: 28px;
  padding: 0;
  border: 2px solid rgba(31, 41, 55, 0.08);
  border-radius: 999px;
  cursor: pointer;
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.65) inset;
}

.customer-group-swatch--active {
  border-color: rgba(31, 41, 55, 0.55);
  transform: scale(1.05);
}
</style>
