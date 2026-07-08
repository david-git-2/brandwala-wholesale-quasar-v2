import { watch } from 'vue'
import {
  LEGACY_MEMBERSHIP_PREFERENCE_KEYS,
  MEMBERSHIP_UI_PATHS,
  type MembershipUiPathKey,
} from '../types/preferences'
import { arraysEqualAsSets } from '../utils/preferenceUtils'
import { useMembershipPreference } from './useMembershipPreference'

type LegacyPreferenceKey =
  | 'ui.productBasedCosting.fileDetailsVisibleColumns'
  | 'ui.thriftShipment.detailsVisibleColumns'
  | 'ui.procurementShipment.detailsVisibleColumns'

function resolvePreferencePath(
  preferencePath?: MembershipUiPathKey,
  preferenceKey?: LegacyPreferenceKey,
): readonly string[] {
  if (preferencePath) {
    return MEMBERSHIP_UI_PATHS[preferencePath]
  }
  if (preferenceKey) {
    const mapped = LEGACY_MEMBERSHIP_PREFERENCE_KEYS[preferenceKey]
    if (mapped) {
      return MEMBERSHIP_UI_PATHS[mapped]
    }
  }
  throw new Error('useMembershipColumnPreference requires preferencePath or preferenceKey.')
}

export function useMembershipColumnPreference<T extends string = string>(options: {
  preferencePath?: MembershipUiPathKey
  preferenceKey?: LegacyPreferenceKey
  allColumnNames: T[]
  alwaysVisibleColumns?: T[]
  defaultVisibleColumns: T[]
}) {
  const path = resolvePreferencePath(options.preferencePath, options.preferenceKey)

  const normalizeColumns = (columns: T[]) => {
    const filtered = columns.filter((col) => options.allColumnNames.includes(col))
    if (options.alwaysVisibleColumns) {
      options.alwaysVisibleColumns.forEach((col) => {
        if (options.allColumnNames.includes(col) && !filtered.includes(col)) {
          filtered.push(col)
        }
      })
    }
    return filtered.length ? filtered : [...options.defaultVisibleColumns]
  }

  const { value: visibleColumns } = useMembershipPreference<T[]>({
    path,
    defaultValue: [...options.defaultVisibleColumns],
    equals: arraysEqualAsSets,
  })

  watch(
    visibleColumns,
    (columns) => {
      const normalized = normalizeColumns(columns)
      if (!arraysEqualAsSets(columns, normalized)) {
        visibleColumns.value = normalized
      }
    },
    { deep: true, flush: 'sync' },
  )

  return {
    visibleColumns,
  }
}
