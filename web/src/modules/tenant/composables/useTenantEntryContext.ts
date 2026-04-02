import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { tenantService } from '../services/tenantService'
import type { TenantEntry } from '../types'
import { getTenantLookupFromRoute } from '../utils/tenantRouteContext'

export function useTenantEntryContext() {
  const route = useRoute()
  const loading = ref(false)
  const error = ref<string | null>(null)
  const tenant = ref<TenantEntry | null>(null)

  const lookup = computed(() => getTenantLookupFromRoute(route))

  const resolveTenant = async () => {
    if (!lookup.value.source) {
      tenant.value = null
      error.value = 'Use the shop link shared by your business so we can open the correct tenant workspace.'
      return
    }

    loading.value = true
    error.value = null

    try {
      const result = await tenantService.resolveTenantForEntry({
        slug: lookup.value.tenantSlug,
        hostname: lookup.value.hostname,
      })

      if (!result.success) {
        tenant.value = null
        error.value = result.error ?? 'Unable to resolve the tenant for this shop entry.'
        return
      }

      if (!result.data) {
        tenant.value = null
        error.value = 'This shop link does not match any active tenant entry.'
        return
      }

      tenant.value = result.data
    } finally {
      loading.value = false
    }
  }

  watch(lookup, () => {
    void resolveTenant()
  }, { immediate: true })

  return {
    error,
    loading,
    lookup,
    tenant,
    hasResolvedTenant: computed(() => Boolean(tenant.value)),
    resolvedTenantSlug: computed(() => tenant.value?.slug ?? lookup.value.tenantSlug),
  }
}
