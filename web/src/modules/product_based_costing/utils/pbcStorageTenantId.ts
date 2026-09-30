/** Parent org tenant id for PBC file rows (matches DB trg_fn_pbc_files_auto_tenant_id). */

export function resolveProductBasedCostingStorageTenantId(
  selectedTenant: { id: number; parent_id: number | null } | null | undefined,
  fallbackTenantId?: number | null,
): number | null {
  if (selectedTenant) {
    return selectedTenant.parent_id ?? selectedTenant.id;
  }
  if (fallbackTenantId != null && !Number.isNaN(Number(fallbackTenantId))) {
    return Number(fallbackTenantId);
  }
  return null;
}
