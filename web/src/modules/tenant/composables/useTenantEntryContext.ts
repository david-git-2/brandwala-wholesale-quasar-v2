import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { tenantService } from '../services/tenantService'
import type { Tenant } from '../types'
import { getTenantLookupFromRoute } from '../utils/tenantRouteContext'

export function useTenantEntryContext() {
  const route = useRoute()
  const loading = ref(false)
  const error = ref<string | null>(null)
  const tenant = ref<Tenant | null>(null)

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
        error.value = 'This shop link does not match any active tenant entry yet.'
        return
      }

      tenant.value = result.data

      if (!result.data.is_active) {
        error.value = 'This tenant workspace is currently inactive.'
      }
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
