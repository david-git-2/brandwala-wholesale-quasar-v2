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
        </q-card>
      </div>

      <div class="col-12 col-lg-7">
        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div class="text-h6">Members</div>

            <div class="row q-gutter-sm">
              <q-btn
                color="primary"
                icon="person_add"
                label="Add Staff"
                @click="onClickAddMember('staff')"
              />
              <q-btn
                color="secondary"
                icon="person_add"
                label="Add Customer"
                @click="onClickAddMember('customer')"
              />
              <q-btn
                color="accent"
                icon="person_add"
                label="Add Viewer"
                @click="onClickAddMember('viewer')"
              />
            </div>
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
            <q-list v-if="staffMembers.length" separator class="q-mb-md">
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
            <div v-else class="text-grey-6 q-mb-md">No staff found.</div>

            <q-separator class="q-my-md" />

            <div class="text-subtitle1 text-weight-bold q-mb-sm">Customers</div>
            <q-list v-if="customerMembers.length" separator class="q-mb-md">
              <q-item v-for="member in customerMembers" :key="member.id">
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
            <div v-else class="text-grey-6 q-mb-md">No customers found.</div>

            <q-separator class="q-my-md" />

            <div class="text-subtitle1 text-weight-bold q-mb-sm">Viewers</div>
            <q-list v-if="viewerMembers.length" separator>
              <q-item v-for="member in viewerMembers" :key="member.id">
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
            <div v-else class="text-grey-6">No viewers found.</div>
          </q-card-section>
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
                  #{{ module.id }} ·
                  {{ module.is_active ? 'Active' : 'Inactive' }}
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
          <div class="text-h6">Add {{ selectedRoleLabel }}</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="memberEmail"
            label="Email"
            type="email"
            outlined
            dense
          />

          <q-input
            :model-value="selectedMemberRole"
            label="Role"
            outlined
            dense
            readonly
          />

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
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import { useTenantStore } from '../stores/tenantStore'
import { useMembershipStore } from 'src/modules/membership/store/membershipStore'
import type { Tenant } from '../types'
import type { Membership } from 'src/modules/membership/types'

const route = useRoute()
const router = useRouter()

const tenantStore = useTenantStore()
const membershipStore = useMembershipStore()
const { items, modules, modulesLoading } = storeToRefs(tenantStore)

const openAddMemberDialog = ref(false)
const openDeleteMemberDialog = ref(false)

const memberToDelete = ref<Membership | null>(null)

const memberEmail = ref('')
const memberIsActive = ref(true)
const selectedMemberRole = ref<'staff' | 'customer' | 'viewer'>('staff')

const tenantMembers = ref<Membership[]>([])
const tenantMembersLoading = ref(false)
const pageLoading = ref(false)
const pageError = ref('')

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(() => {
  return items.value.find((item) => item.id === tenantId.value) ?? null
})

const selectedRoleLabel = computed(() => {
  if (selectedMemberRole.value === 'staff') return 'Staff'
  if (selectedMemberRole.value === 'customer') return 'Customer'
  return 'Viewer'
})

const staffMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'staff')
)

const customerMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'customer')
)

const viewerMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'viewer')
)

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

    tenantMembers.value = (result.data ?? []).filter((item: Membership) =>
      ['staff', 'customer', 'viewer'].includes(item.role)
    )
  } catch (err) {
    console.error(err)
    pageError.value = 'Failed to load members.'
    tenantMembers.value = []
  } finally {
    tenantMembersLoading.value = false
  }
}

const loadTenantModules = async () => {
  if (!tenant.value?.id) return

  const result = await tenantStore.fetchTenantModules(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load module features.'
  }
}

const loadPageData = async () => {
  pageLoading.value = true
  pageError.value = ''

  try {
    await tenantStore.fetchTenantDetailsByMembership({
      tenantId: tenantId.value
    })

    if (!tenant.value) {
      pageError.value = 'Tenant not found.'
      return
    }

    await Promise.all([
      loadTenantMembers(),
      loadTenantModules(),
    ])
  } catch (err) {
    console.error(err)
    pageError.value = 'Failed to load tenant details.'
  } finally {
    pageLoading.value = false
  }
}

const goBack = () => {
  void router.push('/app/tenants')
}

const onClickAddMember = (role: 'staff' | 'customer' | 'viewer') => {
  selectedMemberRole.value = role
  memberEmail.value = ''
  memberIsActive.value = true
  openAddMemberDialog.value = true
}

const handleSaveMember = async () => {
  if (!tenant.value?.id || !memberEmail.value) return

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
  } catch (err) {
    member.is_active = previousValue
    console.error(err)
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
      (item) => item.id !== memberToDelete.value?.id
    )

    openDeleteMemberDialog.value = false
    memberToDelete.value = null
  } catch (err) {
    console.error(err)
    pageError.value = 'Failed to delete member.'
  }
}

onMounted(() => {
  void loadPageData()
})
</script>
