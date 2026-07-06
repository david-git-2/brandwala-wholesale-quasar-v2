<template>
  <q-page class="q-pa-md admin-settings-roles-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">{{ pageTitle }}</div>
            <div class="text-caption text-grey-8">
              Configure unified permission roles and access templates for your workspace.
            </div>
          </div>
          <div class="col-auto">
            <q-btn
              color="primary"
              class="pill-btn"
              no-caps
              icon="add"
              label="Add Role"
              @click="openCreateRoleDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <!-- Roles Grid / Table -->
    <div v-if="loading" class="row justify-center q-my-lg">
      <q-spinner-dots size="40px" color="primary" />
    </div>

    <div v-else-if="roles.length === 0" class="text-center text-grey-7 q-pa-xl">
      <q-icon name="admin_panel_settings" size="48px" class="q-mb-sm" />
      <div>No roles found for this scope.</div>
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="role in roles" :key="role.id" class="col-12 col-md-6 col-lg-4">
        <q-card flat class="floating-surface shadow-1 full-height column justify-between">
          <q-card-section>
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ role.name }}</div>
              <div class="row q-gutter-xs">
                <q-chip v-if="role.is_system" label="System" dense color="blue-2" text-color="blue-9" />
                <q-chip v-if="role.is_admin" label="Admin" dense color="purple-2" text-color="purple-9" />
              </div>
            </div>
            <div class="text-caption text-grey-6 q-mb-md">Slug: {{ role.slug }}</div>
            <div class="text-caption text-grey-7">
              {{ role.is_admin ? 'Administrator role has implicit access to all module actions.' : 'Access rules are configurable via the grants matrix.' }}
            </div>
          </q-card-section>

          <div>
            <q-separator />
            <q-card-actions class="justify-between">
              <div>
                <q-btn
                  v-if="!role.is_admin"
                  flat
                  no-caps
                  color="primary"
                  icon="admin_panel_settings"
                  label="Configure Grants"
                  @click="navigateToGrants(role.id)"
                />
                <span v-else class="text-caption text-grey-5 q-px-sm">Full Access</span>
              </div>
              <div class="row q-gutter-xs">
                <q-btn
                  v-if="!role.is_system"
                  flat
                  round
                  dense
                  icon="edit"
                  color="grey-7"
                  @click="openEditRoleDialog(role)"
                />
                <q-btn
                  v-if="!role.is_system"
                  flat
                  round
                  dense
                  icon="delete"
                  color="negative"
                  @click="openDeleteRoleDialog(role)"
                />
              </div>
            </q-card-actions>
          </div>
        </q-card>
      </div>
    </div>

    <!-- Create/Edit Role Dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <div class="text-h6">{{ isEdit ? 'Edit Role' : 'Create Role' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-none">
          <q-input
            v-model="form.name"
            label="Role Name"
            outlined
            dense
            class="q-mb-md"
            :rules="[val => !!val || 'Name is required']"
          />

          <q-input
            v-model="form.slug"
            label="Role Slug"
            outlined
            dense
            class="q-mb-md"
            hint="Alphanumeric characters and hyphens only (e.g. support-staff)"
            :disable="isEdit"
            :rules="[
              val => !!val || 'Slug is required',
              val => /^[a-z0-9-]+$/.test(val) || 'Invalid slug format'
            ]"
          />

          <q-toggle
            v-model="form.is_admin"
            label="Administrator Role"
            color="purple"
            class="q-mb-md"
            :disable="isEdit && form.is_system"
          />
        </q-card-section>

        <q-card-actions align="right" class="text-primary">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat :label="isEdit ? 'Save' : 'Create'" :loading="submitting" @click="saveRole" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Role Confirmation Dialog -->
    <q-dialog v-model="deleteDialogOpen" persistent>
      <q-card>
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1">Delete Role</span>
        </q-card-section>

        <q-card-section class="q-pt-none">
          Are you sure you want to delete the role <strong>{{ selectedRole?.name }}</strong>? This action cannot be undone.
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat label="Delete" color="negative" :loading="deleting" @click="confirmDeleteRole" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { showSuccessNotification } from 'src/utils/appFeedback'

const props = defineProps<{
  scope: 'app' | 'shop'
}>()

const router = useRouter()
const authStore = useAuthStore()

const roles = ref<any[]>([])
const loading = ref(false)
const submitting = ref(false)
const deleting = ref(false)
const pageError = ref<string | null>(null)

// Dialog fields
const dialogOpen = ref(false)
const deleteDialogOpen = ref(false)
const isEdit = ref(false)
const selectedRole = ref<any>(null)

const form = ref({
  name: '',
  slug: '',
  is_admin: false,
})

const pageTitle = computed(() => {
  return props.scope === 'shop' ? 'Shop Access Roles' : 'Workspace Access Roles'
})

const loadRoles = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  loading.value = true
  pageError.value = null

  try {
    const { data, error } = await supabase.rpc('list_tenant_roles', {
      p_tenant_id: tenantId,
      p_scope: props.scope,
    })

    if (error) {
      pageError.value = error.message
    } else {
      roles.value = data || []
    }
  } catch (err: any) {
    pageError.value = err.message || 'Failed to fetch roles'
  } finally {
    loading.value = false
  }
}

const openCreateRoleDialog = () => {
  isEdit.value = false
  selectedRole.value = null
  form.value = {
    name: '',
    slug: '',
    is_admin: false,
  }
  dialogOpen.value = true
}

const openEditRoleDialog = (role: any) => {
  isEdit.value = true
  selectedRole.value = role
  form.value = {
    name: role.name,
    slug: role.slug,
    is_admin: role.is_admin,
  }
  dialogOpen.value = true
}

const openDeleteRoleDialog = (role: any) => {
  selectedRole.value = role
  deleteDialogOpen.value = true
}

const saveRole = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId || !form.value.name.trim() || !form.value.slug.trim()) return

  submitting.value = true
  pageError.value = null

  try {
    if (isEdit.value && selectedRole.value) {
      const { error } = await supabase.rpc('update_tenant_role', {
        p_role_id: selectedRole.value.id,
        p_name: form.value.name,
        p_is_admin: form.value.is_admin,
      })

      if (error) {
        pageError.value = error.message
        return
      }

      showSuccessNotification('Role updated successfully.')
    } else {
      const { error } = await supabase.rpc('create_tenant_role', {
        p_tenant_id: tenantId,
        p_scope: props.scope,
        p_name: form.value.name,
        p_slug: form.value.slug,
        p_is_admin: form.value.is_admin,
      })

      if (error) {
        pageError.value = error.message
        return
      }

      showSuccessNotification('Role created successfully.')
    }

    dialogOpen.value = false
    await loadRoles()
  } catch (err: any) {
    pageError.value = err.message || 'Failed to save role'
  } finally {
    submitting.value = false
  }
}

const confirmDeleteRole = async () => {
  if (!selectedRole.value) return

  deleting.value = true
  pageError.value = null

  try {
    const { error } = await supabase.rpc('delete_tenant_role', {
      p_role_id: selectedRole.value.id,
    })

    if (error) {
      pageError.value = error.message
      return
    }

    showSuccessNotification('Role deleted successfully.')
    deleteDialogOpen.value = false
    await loadRoles()
  } catch (err: any) {
    pageError.value = err.message || 'Failed to delete role'
  } finally {
    deleting.value = false
  }
}

const navigateToGrants = (roleId: number) => {
  const tenantSlug = authStore.tenantSlug
  if (tenantSlug) {
    void router.push(`/${tenantSlug}/app/settings/roles/${roleId}/grants`)
  } else {
    void router.push(`/app/settings/roles/${roleId}/grants`)
  }
}

onMounted(() => {
  void loadRoles()
})
</script>

<style scoped>
.pill-btn {
  border-radius: 999px;
}
.floating-surface {
  border-radius: 12px;
}
.hero-surface {
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
}
</style>
