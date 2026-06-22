import type { PreferenceFieldDefinition } from '../types/preferenceFields'

export const TENANT_PREFERENCE_FIELDS: PreferenceFieldDefinition[] = [
  {
    key: 'thrift.default_purchase_currency',
    path: ['thrift', 'default_purchase_currency'],
    label: 'Default purchase currency',
    hint: 'Pre-filled when creating a new thrift shipment',
    type: 'currency_select',
    section: 'Thrift',
    required: true,
  },
  {
    key: 'thrift.default_cost_currency',
    path: ['thrift', 'default_cost_currency'],
    label: 'Default cost currency',
    hint: 'Pre-filled when creating a new thrift shipment',
    type: 'currency_select',
    section: 'Thrift',
    required: true,
  },
]
