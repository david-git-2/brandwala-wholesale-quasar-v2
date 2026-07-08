export interface MembershipPreferenceSchema {
  ui?: {
    productBasedCosting?: {
      fileDetailsVisibleColumns?: string[]
    }
    thriftShipment?: {
      detailsVisibleColumns?: string[]
    }
    procurementShipment?: {
      detailsVisibleColumns?: string[]
    }
  }
}

export function parseMembershipPreference(raw: unknown): MembershipPreferenceSchema {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return {}
  }
  return raw
}
