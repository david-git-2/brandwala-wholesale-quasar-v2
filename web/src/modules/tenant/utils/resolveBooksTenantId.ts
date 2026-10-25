/** Books (capital) tenant id: parent when on a child tenant, else the tenant itself. */
export function resolveBooksTenantId(
  tenantId: number,
  parentTenantId?: number | null,
): number {
  return parentTenantId ?? tenantId;
}
