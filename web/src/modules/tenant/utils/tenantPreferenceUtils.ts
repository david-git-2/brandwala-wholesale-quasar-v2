import type { PreferenceFieldDefinition } from '../types/preferenceFields';
import type { TenantPreferenceSchema } from '../types/preferences';

export function parseTenantPreference(raw: unknown): TenantPreferenceSchema {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return {};
  }

  return raw;
}

export function getNestedValue(source: Record<string, unknown>, path: readonly string[]): unknown {
  let current: unknown = source;

  for (const segment of path) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) {
      return undefined;
    }

    current = (current as Record<string, unknown>)[segment];
  }

  return current;
}

export function setNestedValue(
  target: Record<string, unknown>,
  path: readonly string[],
  value: unknown,
): Record<string, unknown> {
  if (path.length === 0) {
    return target;
  }

  const [head, ...rest] = path;

  if (!head) {
    return target;
  }

  if (rest.length === 0) {
    return {
      ...target,
      [head]: value,
    };
  }

  const child = target[head];
  const childRecord =
    child && typeof child === 'object' && !Array.isArray(child)
      ? (child as Record<string, unknown>)
      : {};

  return {
    ...target,
    [head]: setNestedValue(childRecord, rest, value),
  };
}

export function preferenceToFormState(
  fields: readonly PreferenceFieldDefinition[],
  preference: unknown,
): Record<string, unknown> {
  const parsed = parseTenantPreference(preference);
  const source = parsed as Record<string, unknown>;
  const formState: Record<string, unknown> = {};

  for (const field of fields) {
    formState[field.key] = getNestedValue(source, field.path) ?? null;
  }

  return formState;
}

export function formStateToPreference(
  fields: readonly PreferenceFieldDefinition[],
  formState: Record<string, unknown>,
  existing: unknown,
): TenantPreferenceSchema {
  const parsedExisting = parseTenantPreference(existing);
  let next = { ...parsedExisting } as Record<string, unknown>;

  for (const field of fields) {
    const value = formState[field.key];

    if (value === null || value === undefined || value === '') {
      continue;
    }

    next = setNestedValue(next, field.path, value);
  }

  return next;
}

export function resolveActiveCurrencyId(
  currencyId: number | null | undefined,
  activeCurrencyIds: readonly number[],
): number | null {
  if (!currencyId) {
    return null;
  }

  return activeCurrencyIds.includes(currencyId) ? currencyId : null;
}
