import { acceptHMRUpdate, defineStore } from 'pinia'
import { computed, ref } from 'vue'

import type { AuthScope } from '../composables/useOAuthLogin'
import type { AccessRole } from '../guards/accessGuard'
import {
  clearTenantWorkspaceStorage,
  useTenantStore,
} from 'src/modules/tenant/stores/tenantStore'

export interface AuthUserSnapshot {
  id: string
  email: string
  fullName: string | null
  avatarUrl: string | null
  provider: string | null
}

export interface AuthMemberSnapshot {
  id: number
  email: string
  role: AccessRole
  actorType: 'membership' | 'customer_group_member'
  name: string | null
  tenantId: number | null
  customerGroupId: number | null
  isActive: boolean
  createdAt: string | null
  updatedAt: string | null
}

export interface AuthTenantSnapshot {
  id: number
  name: string
  slug: string
  isActive: boolean
}

export interface AuthCustomerGroupSnapshot {
  id: number
  name: string
  isActive: boolean
}

export interface AuthAccessSnapshot {
  scope: AuthScope
  matchedRole: AuthMemberSnapshot['role']
  user: AuthUserSnapshot
  member: AuthMemberSnapshot
  tenant: AuthTenantSnapshot | null
  customerGroup: AuthCustomerGroupSnapshot | null
  activeModuleKeys: string[]
  savedAt: string
}

type StoredAuthAccess = AuthAccessSnapshot & {
  schemaVersion: 2
}

const STORAGE_KEY = 'brandwala.auth.access.v2'

const readStorage = (): StoredAuthAccess | null => {
  if (typeof window === 'undefined') {
    return null
  }

  const rawValue = window.localStorage.getItem(STORAGE_KEY)
  if (!rawValue) {
    return null
  }

  try {
    const parsed = JSON.parse(rawValue) as Partial<StoredAuthAccess>

    if (
      parsed?.schemaVersion !== 2 ||
      !parsed?.scope ||
      !parsed?.matchedRole ||
      !parsed?.user ||
      !parsed?.member ||
      !Array.isArray(parsed?.activeModuleKeys)
    ) {
      return null
    }

    return parsed as StoredAuthAccess
  } catch {
    return null
  }
}

const writeStorage = (snapshot: StoredAuthAccess | null) => {
  if (typeof window === 'undefined') {
    return
  }

  if (!snapshot) {
    window.localStorage.removeItem(STORAGE_KEY)
    return
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot))
}

export const useAuthStore = defineStore('auth', () => {
  const snapshot = ref<StoredAuthAccess | null>(readStorage())
  const tenantStore = useTenantStore()

  const access = computed(() => snapshot.value)
  const user = computed(() => snapshot.value?.user ?? null)
  const member = computed(() => snapshot.value?.member ?? null)
  const tenant = computed(() => snapshot.value?.tenant ?? null)
  const selectedTenant = computed(() =>
    snapshot.value?.scope === 'app'
      ? tenantStore.selectedTenant
      : snapshot.value?.tenant ?? null,
  )
  const availableAdminTenants = computed(() => tenantStore.availableAdminTenants)
  const customerGroup = computed(() => snapshot.value?.customerGroup ?? null)
  const activeModuleKeys = computed(() => snapshot.value?.activeModuleKeys ?? [])
  const scope = computed(() => snapshot.value?.scope ?? null)
  const matchedRole = computed(() => snapshot.value?.matchedRole ?? null)
  const isAuthenticated = computed(() => Boolean(snapshot.value?.user))
  const hasAccess = computed(() => Boolean(snapshot.value?.member?.isActive))
  const actorId = computed(() => snapshot.value?.member?.id ?? null)
  const actorType = computed(() => snapshot.value?.member?.actorType ?? null)
  const membershipId = computed(() =>
    snapshot.value?.member?.actorType === 'membership'
      ? snapshot.value.member.id
      : null,
  )
  const customerGroupMemberId = computed(() =>
    snapshot.value?.member?.actorType === 'customer_group_member'
      ? snapshot.value.member.id
      : null,
  )
  const tenantId = computed(
    () =>
      selectedTenant.value?.id ??
      snapshot.value?.tenant?.id ??
      snapshot.value?.member?.tenantId ??
      null,
  )
  const tenantSlug = computed(
    () =>
      selectedTenant.value?.slug ??
      snapshot.value?.tenant?.slug ??
      null,
  )
  const customerGroupId = computed(
    () =>
      snapshot.value?.customerGroup?.id ??
      snapshot.value?.member?.customerGroupId ??
      null,
  )

  const saveAccess = (nextAccess: Omit<StoredAuthAccess, 'schemaVersion'>) => {
    snapshot.value = {
      ...nextAccess,
      schemaVersion: 2,
    }
    writeStorage(snapshot.value)
  }

  const clearAccess = () => {
    snapshot.value = null
    writeStorage(null)
    clearTenantWorkspaceStorage()
  }

  return {
    access,
    clearAccess,
    customerGroup,
    customerGroupMemberId,
    customerGroupId,
    hasAccess,
    isAuthenticated,
    member,
    actorId,
    actorType,
    availableAdminTenants,
    membershipId,
    matchedRole,
    saveAccess,
    selectedTenant,
    scope,
    tenant,
    tenantId,
    tenantSlug,
    user,
    activeModuleKeys,
  }
})

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useAuthStore, import.meta.hot))
}
