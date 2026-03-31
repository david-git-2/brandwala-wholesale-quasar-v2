import { acceptHMRUpdate, defineStore } from 'pinia'
import { computed, ref } from 'vue'

import type { AuthScope } from '../composables/useOAuthLogin'

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
  role: 'superadmin' | 'admin' | 'staff' | 'viewer' | 'customer'
  tenantId: number | null
  isActive: boolean
  createdAt: string
  updatedAt: string
}

export interface AuthAccessSnapshot {
  scope: AuthScope
  matchedRole: AuthMemberSnapshot['role']
  user: AuthUserSnapshot
  member: AuthMemberSnapshot
  savedAt: string
}

type StoredAuthAccess = AuthAccessSnapshot & {
  schemaVersion: 1
}

const STORAGE_KEY = 'brandwala.auth.access.v1'

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
      parsed?.schemaVersion !== 1 ||
      !parsed?.scope ||
      !parsed?.matchedRole ||
      !parsed?.user ||
      !parsed?.member
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

  const access = computed(() => snapshot.value)
  const user = computed(() => snapshot.value?.user ?? null)
  const member = computed(() => snapshot.value?.member ?? null)
  const scope = computed(() => snapshot.value?.scope ?? null)
  const matchedRole = computed(() => snapshot.value?.matchedRole ?? null)
  const isAuthenticated = computed(() => Boolean(snapshot.value?.user))
  const hasAccess = computed(() => Boolean(snapshot.value?.member?.isActive))

  const saveAccess = (nextAccess: Omit<StoredAuthAccess, 'schemaVersion'>) => {
    snapshot.value = {
      ...nextAccess,
      schemaVersion: 1,
    }
    writeStorage(snapshot.value)
  }

  const clearAccess = () => {
    snapshot.value = null
    writeStorage(null)
  }

  return {
    access,
    clearAccess,
    hasAccess,
    isAuthenticated,
    member,
    matchedRole,
    saveAccess,
    scope,
    user,
  }
})

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useAuthStore, import.meta.hot))
}
