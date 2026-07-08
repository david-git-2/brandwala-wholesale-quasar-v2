import type { MembershipPreferenceSchema } from '../types/preferences'

export function parseMembershipPreference(raw: unknown): MembershipPreferenceSchema {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return {}
  }
  return raw as MembershipPreferenceSchema
}

export function getPreferencePath(
  preference: MembershipPreferenceSchema,
  path: readonly string[],
): unknown {
  let current: unknown = preference

  for (const segment of path) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) {
      return undefined
    }
    current = (current as Record<string, unknown>)[segment]
  }

  return current
}

export function setPreferencePath(
  preference: MembershipPreferenceSchema,
  path: readonly string[],
  value: unknown,
): MembershipPreferenceSchema {
  if (path.length === 0) {
    return preference
  }

  const [head, ...rest] = path
  if (!head) {
    return preference
  }

  const source = preference as Record<string, unknown>

  if (rest.length === 0) {
    return {
      ...preference,
      [head]: value,
    } as MembershipPreferenceSchema
  }

  const child = source[head]
  const childRecord =
    child && typeof child === 'object' && !Array.isArray(child)
      ? (child as Record<string, unknown>)
      : {}

  return {
    ...preference,
    [head]: setPreferencePath(childRecord as MembershipPreferenceSchema, rest, value),
  } as MembershipPreferenceSchema
}

export function arraysEqualAsSets(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) {
    return false
  }
  const setB = new Set(b)
  return a.every((item) => setB.has(item))
}

export function clonePreferenceValue<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

export function valuesEqual<T>(a: T, b: T): boolean {
  return JSON.stringify(a) === JSON.stringify(b)
}
