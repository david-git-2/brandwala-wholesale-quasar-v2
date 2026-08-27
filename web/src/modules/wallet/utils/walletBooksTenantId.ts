import type { AuthTenantSnapshot } from 'src/modules/auth/stores/authStore';

/** Parent books tenant id for wallet queries (mirrors sales invoice pages). */
export function walletBooksTenantId(tenant: Pick<AuthTenantSnapshot, 'id' | 'parent_id'> | null | undefined): number {
  if (!tenant) return 0;
  return tenant.parent_id ?? tenant.id;
}
