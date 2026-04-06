<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Platform</div>
          <h1 class="text-h5 q-my-none">Super Admin Panel</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage platform-level Super Admin memberships.
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            icon="person_add"
            label="Add Super Admin"
            @click="onClickAddSuperadmin"
          />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <q-card v-if="loading" flat bordered>
        <q-card-section class="text-grey-7">Loading super admins...</q-card-section>
      </q-card>

      <q-card v-else-if="superadmins.length === 0" flat bordered>
        <q-card-section class="text-center">
          <div class="text-subtitle1">No super admins found</div>
          <div class="text-body2 text-grey-7 q-mt-sm">
            Add a super admin to grant platform workspace access.
          </div>
          <q-btn
            class="q-mt-md"
            color="primary"
            unelevated
            icon="person_add"
            label="Add Super Admin"
            @click="onClickAddSuperadmin"
          />
        </q-card-section>
      </q-card>

      <q-table
        v-else
        flat
        bordered
        row-key="id"
        :rows="superadmins"
        :columns="columns"
        :dense="$q.screen.lt.md"
      >
        <template #body-cell-email="props">
          <q-td :props="props">{{ props.row.email }}</q-td>
        </template>

        <template #body-cell-status="props">
          <q-td :props="props">
            <q-badge :color="props.row.is_active ? 'positive' : 'grey-6'">
              {{ props.row.is_active ? 'Active' : 'Inactive' }}
            </q-badge>
          </q-td>
        </template>

        <template #body-cell-created="props">
          <q-td :props="props">{{ formatDate(props.row.created_at) }}</q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-xs no-wrap">
              <q-btn
                flat
                round
                dense
                icon="edit"
                @click="onClickEditSuperadmin(props.row)"
              />
              <q-btn
                flat
                round
                dense
                color="negative"
                icon="delete"
                :disable="isCurrentUser(props.row.email)"
                @click="onClickDeleteSuperadmin(props.row)"
              />
            </div>
          </q-td>
        </template>
      </q-table>
    </section>
  </q-page>

  <q-dialog v-model="openEditDialog" persistent>
    <q-card style="min-width: 420px; max-width: 92vw;">
      <q-card-section>
        <div class="text-h6">{{ editMode ? 'Update Super Admin' : 'Add Super Admin' }}</div>
      </q-card-section>

      <q-card-section class="q-gutter-md">
        <q-input
          v-model="form.email"
          label="Email"
          type="email"
          outlined
          dense
          :rules="[
            (value) => !!String(value ?? '').trim() || 'Email is required',
            (value) =>
              /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(String(value ?? '').trim()) ||
              'Enter a valid email address'
          ]"
        />

        <q-toggle
          v-model="form.is_active"
          color="positive"
          keep-color
          :label="form.is_active ? 'Active' : 'Inactive'"
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="openEditDialog = false" />
        <q-btn color="primary" :label="editMode ? 'Update' : 'Save'" @click="handleSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>

  <q-dialog v-model="openDeleteDialog" persistent>
    <q-card style="min-width: 350px; max-width: 92vw;">
      <q-card-section>
        <div class="text-h6">Delete Super Admin</div>
      </q-card-section>

      <q-card-section>
        Are you sure you want to delete
        <strong>{{ selectedSuperadmin?.email }}</strong>?
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" @click="openDeleteDialog = false" />
        <q-btn color="negative" label="Delete" @click="confirmDelete" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { storeToRefs } from 'pinia'
import type { QTableColumn } from 'quasar'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useMembershipStore } from '../stores/membershipStore'
import type { Membership } from '../types'

type SuperadminForm = {
  id: number | null
  email: string
  is_active: boolean
}

const membershipStore = useMembershipStore()
const authStore = useAuthStore()
const { items, loading, error } = storeToRefs(membershipStore)

const openEditDialog = ref(false)
const openDeleteDialog = ref(false)
const selectedSuperadmin = ref<Membership | null>(null)
const editMode = ref(false)

const form = reactive<SuperadminForm>({
  id: null,
  email: '',
  is_active: true,
})

const columns: QTableColumn[] = [
  {
    name: 'email',
    label: 'Email',
    field: 'email',
    align: 'left',
    sortable: true,
  },
  {
    name: 'status',
    label: 'Status',
    field: 'is_active',
    align: 'left',
    sortable: true,
  },
  {
    name: 'created',
    label: 'Created',
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  {
    name: 'actions',
    label: 'Actions',
    field: 'id',
    align: 'right',
  },
]

const normalizeEmail = (email: string) => email.trim().toLowerCase()

const superadmins = computed(() =>
  items.value.filter((item) => item.role === 'superadmin'),
)

const isCurrentUser = (email: string) =>
  normalizeEmail(authStore.user?.email ?? '') === normalizeEmail(email)

const formatDate = (value?: string) => {
  if (!value) return 'N/A'

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

const resetForm = () => {
  form.id = null
  form.email = ''
  form.is_active = true
}

const refreshSuperadmins = async () => {
  await membershipStore.fetchSuperadmins()
}

const onClickAddSuperadmin = () => {
  editMode.value = false
  selectedSuperadmin.value = null
  resetForm()
  openEditDialog.value = true
}

const onClickEditSuperadmin = (membership: Membership) => {
  editMode.value = true
  selectedSuperadmin.value = membership
  form.id = membership.id
  form.email = membership.email
  form.is_active = membership.is_active
  openEditDialog.value = true
}

const handleSave = async () => {
  const email = normalizeEmail(form.email)
  if (!email) return

  if (editMode.value && form.id !== null) {
    await membershipStore.updateMembership({
      id: form.id,
      email,
      is_active: form.is_active,
      role: 'superadmin',
      tenant_id: null,
    })
  } else {
    await membershipStore.createMembership({
      email,
      is_active: form.is_active,
      role: 'superadmin',
      tenant_id: null,
    })
  }

  openEditDialog.value = false
  await refreshSuperadmins()
}

const onClickDeleteSuperadmin = (membership: Membership) => {
  if (isCurrentUser(membership.email)) {
    return
  }

  selectedSuperadmin.value = membership
  openDeleteDialog.value = true
}

const confirmDelete = async () => {
  if (!selectedSuperadmin.value) {
    return
  }

  await membershipStore.deleteMembership({ id: selectedSuperadmin.value.id })
  openDeleteDialog.value = false
  selectedSuperadmin.value = null
  await refreshSuperadmins()
}

onMounted(() => {
  void refreshSuperadmins()
})
</script>
