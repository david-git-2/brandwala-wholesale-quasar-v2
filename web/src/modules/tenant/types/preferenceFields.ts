export type PreferenceFieldType =
  | 'currency_select'
  | 'boolean'
  | 'text'
  | 'number'
  | 'select'

export interface PreferenceFieldDefinition {
  key: string
  path: readonly string[]
  label: string
  hint?: string
  type: PreferenceFieldType
  section: string
  required?: boolean
  options?: { label: string; value: string | number }[]
}
