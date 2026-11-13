/** Profile party types that hold a kernel cashbook (see docs/features/money/spec.md). */
const CASHBOOK_ENABLED_TYPES = new Set([
  'tenant',
  'customer',
  'investor',
]);

export function isProfileCashbookEnabled(entityType: string | null | undefined): boolean {
  if (!entityType) return false;
  const t = entityType === 'cargo_company' ? 'cargo' : entityType;
  return CASHBOOK_ENABLED_TYPES.has(t);
}

/** Route param for cashbook child pages (`app-cashbook-*`). */
export function cashbookNavEntityType(entityType: string): string {
  if (entityType === 'cargo_company') return 'vendor';
  return entityType;
}
