export type TenantHierarchyKind = 'parent' | 'child' | 'standalone';

type TenantRef = {
  id: number;
  parent_id: number | null;
};

export const resolveTenantHierarchyKind = (
  current: TenantRef | null | undefined,
  pool: readonly TenantRef[],
): TenantHierarchyKind => {
  if (!current) return 'standalone';
  if (current.parent_id != null) return 'child';
  if (pool.some((tenant) => tenant.parent_id === current.id)) return 'parent';
  return 'standalone';
};
