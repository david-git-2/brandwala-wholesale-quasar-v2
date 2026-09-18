export type TenantHierarchyKind = 'parent' | 'child' | 'standalone';

type TenantRef = {
  id: number;
  parent_id: number | null;
};

export const isCompanyTenant = (tenant: TenantRef): boolean => tenant.parent_id === null;

export const filterCompanyTenants = <T extends TenantRef>(tenants: readonly T[]): T[] =>
  tenants.filter(isCompanyTenant);

/** Map a brand (child) tenant to its company when the company row is in the pool. */
export const resolveCompanyTenant = <T extends TenantRef>(
  tenant: T | null | undefined,
  pool: readonly T[],
): T | null => {
  if (!tenant) {
    return null;
  }

  if (isCompanyTenant(tenant)) {
    return tenant;
  }

  return pool.find((row) => row.id === tenant.parent_id) ?? null;
};

export const resolveTenantHierarchyKind = (
  current: TenantRef | null | undefined,
  pool: readonly TenantRef[] = [],
): TenantHierarchyKind => {
  if (!current) return 'standalone';
  if (current.parent_id != null) return 'child';
  if (pool.some((tenant) => tenant.parent_id === current.id)) return 'parent';
  if (current.parent_id === null) return 'parent';
  return 'standalone';
};
