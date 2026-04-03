import { ref } from 'vue'
import { useRouter } from 'vue-router'

import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { showWarningDialog } from 'src/utils/appFeedback'
import { useTenantStore } from '../stores/tenantStore'
import type { Tenant } from '../types'

export function useAdminTenantSelection() {
  const router = useRouter()
  const authStore = useAuthStore()
  const tenantStore = useTenantStore()
  const selectingTenantId = ref<number | null>(null)

  const selectTenantWorkspace = async (
    tenant: Pick<Tenant, 'id' | 'slug' | 'name'>,
    options?: {
      navigate?: boolean
    },
  ) => {
    if (!authStore.user?.email || !authStore.member) {
      showWarningDialog('Sign in again before selecting a tenant workspace.', 'Session required')
      return false
    }

    selectingTenantId.value = tenant.id

    try {
      const membershipId =
        authStore.member?.actorType === 'membership' && authStore.member.tenantId === tenant.id
          ? authStore.member.id
          : null

      const { data, error } = await supabase.rpc('get_app_bootstrap_context', {
        p_email: authStore.user.email,
        p_tenant_id: tenant.id,
        p_membership_id: membershipId,
      })

      if (error) {
        showWarningDialog(error.message, 'Tenant selection failed')
        return false
      }

      const bootstrap = Array.isArray(data) ? data[0] : data

      if (
        !bootstrap ||
        bootstrap.member_id === null ||
        bootstrap.tenant_id === null ||
        !bootstrap.tenant_name ||
        !bootstrap.tenant_slug ||
        !bootstrap.member_role
      ) {
        showWarningDialog(
          'This account could not load the selected tenant workspace.',
          'Tenant selection failed',
        )
        return false
      }

      authStore.saveAccess({
        scope: 'app',
        matchedRole: bootstrap.member_role,
        user: authStore.user,
        member: {
          id: bootstrap.member_id,
          email: bootstrap.member_email?.trim().toLowerCase() ?? authStore.user.email,
          role: bootstrap.member_role,
          actorType: 'membership',
          name: null,
          tenantId: bootstrap.tenant_id,
          customerGroupId: null,
          isActive: Boolean(bootstrap.member_is_active),
          createdAt: authStore.member.createdAt,
          updatedAt: authStore.member.updatedAt,
        },
        tenant: {
          id: bootstrap.tenant_id,
          name: bootstrap.tenant_name,
          slug: bootstrap.tenant_slug,
          isActive: Boolean(bootstrap.tenant_is_active),
        },
        customerGroup: null,
        activeModuleKeys: Array.isArray(bootstrap.active_module_keys)
          ? bootstrap.active_module_keys
          : [],
        savedAt: new Date().toISOString(),
      })

      tenantStore.setSelectedTenant({
        id: bootstrap.tenant_id,
        slug: bootstrap.tenant_slug,
      })

      if (options?.navigate !== false) {
        if (bootstrap.member_role === 'admin') {
          await router.push(`/${bootstrap.tenant_slug}/app/tenants/${bootstrap.tenant_id}`)
        } else {
          await router.push(`/${bootstrap.tenant_slug}/app/dashboard`)
        }
      }

      return true
    } finally {
      selectingTenantId.value = null
    }
  }

  const ensureSelectedTenantWorkspace = async () => {
    if (authStore.scope !== 'app') {
      return false
    }

    const selectedTenant = tenantStore.selectedTenant

    if (!selectedTenant) {
      return false
    }

    if (authStore.tenant?.id === selectedTenant.id) {
      return true
    }

    return selectTenantWorkspace(selectedTenant, { navigate: false })
  }

  return {
    ensureSelectedTenantWorkspace,
    selectTenantWorkspace,
    selectingTenantId,
  }
}
