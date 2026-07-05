import { ref, watch, onMounted } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useMembershipPreferenceStore } from '../stores/membershipPreferenceStore'

function getNestedPreference(preference: any, key: string): string[] | undefined {
  if (key === 'ui.productBasedCosting.fileDetailsVisibleColumns') {
    return preference?.ui?.productBasedCosting?.fileDetailsVisibleColumns
  }
  if (key === 'ui.thriftShipment.detailsVisibleColumns') {
    return preference?.ui?.thriftShipment?.detailsVisibleColumns
  }
  return undefined
}

function setNestedPreferencePatch(key: string, value: string[]): any {
  if (key === 'ui.productBasedCosting.fileDetailsVisibleColumns') {
    return {
      ui: {
        productBasedCosting: {
          fileDetailsVisibleColumns: value,
        },
      },
    }
  }
  if (key === 'ui.thriftShipment.detailsVisibleColumns') {
    return {
      ui: {
        thriftShipment: {
          detailsVisibleColumns: value,
        },
      },
    }
  }
  return {}
}

export function useMembershipColumnPreference(options: {
  preferenceKey: 'ui.productBasedCosting.fileDetailsVisibleColumns' | 'ui.thriftShipment.detailsVisibleColumns'
  allColumnNames: string[]
  alwaysVisibleColumns?: string[]
  defaultVisibleColumns: string[]
}) {
  const authStore = useAuthStore()
  const store = useMembershipPreferenceStore()
  const visibleColumns = ref<string[]>([...options.defaultVisibleColumns])

  const hydrateColumns = () => {
    const rawVal = getNestedPreference(store.preference, options.preferenceKey)
    if (rawVal && Array.isArray(rawVal)) {
      const filtered = rawVal.filter((col) => options.allColumnNames.includes(col))
      if (options.alwaysVisibleColumns) {
        options.alwaysVisibleColumns.forEach((col) => {
          if (options.allColumnNames.includes(col) && !filtered.includes(col)) {
            filtered.push(col)
          }
        })
      }
      visibleColumns.value = filtered
    } else {
      visibleColumns.value = [...options.defaultVisibleColumns]
    }
  }

  onMounted(() => {
    hydrateColumns()
  })

  watch(
    () => store.preference,
    () => {
      hydrateColumns()
    },
    { deep: true }
  )

  let isSaving = false

  const debouncedSave = (() => {
    let timeoutId: ReturnType<typeof setTimeout> | null = null
    return () => {
      if (timeoutId) clearTimeout(timeoutId)
      timeoutId = setTimeout(async () => {
        const membershipId = authStore.membershipId
        if (!membershipId) {
          return
        }

        const rawVal = getNestedPreference(store.preference, options.preferenceKey)
        const currentSet = new Set(visibleColumns.value)
        const storedSet = new Set(rawVal || [])
        const isSame = currentSet.size === storedSet.size && [...currentSet].every(x => storedSet.has(x))
        if (isSame) return

        isSaving = true
        try {
          const patch = setNestedPreferencePatch(options.preferenceKey, [...visibleColumns.value])
          store.patchPreference(membershipId, patch)
          await store.savePreference(membershipId)
        } finally {
          isSaving = false
        }
      }, 500)
    }
  })()

  watch(
    visibleColumns,
    () => {
      if (!isSaving) {
        debouncedSave()
      }
    },
    { deep: true }
  )

  return {
    visibleColumns,
  }
}
