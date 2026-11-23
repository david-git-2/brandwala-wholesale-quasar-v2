import { supabase } from 'src/boot/supabase';
import { cashbookRepository } from 'src/modules/finance/submodules/bills_pays/repositories/cashbookRepository';

export async function resolveMoneyProfileId(
  booksTenantId: number,
  entityType: string,
  entityId: number,
): Promise<number> {
  if (entityType === 'customer') return entityId;

  if (entityType === 'tenant') {
    const { data, error } = await supabase
      .from('profiles')
      .select('id')
      .eq('tenant_id', booksTenantId)
      .eq('profile_type', 'tenant')
      .eq('subject_id', booksTenantId)
      .maybeSingle();
    if (error) throw error;
    if (!data?.id) throw new Error('Tenant cash profile not found.');
    return data.id;
  }

  if (entityType === 'investor') {
    const { data, error } = await supabase
      .from('profiles')
      .select('id')
      .eq('tenant_id', booksTenantId)
      .eq('profile_type', 'investor')
      .eq('subject_id', entityId)
      .maybeSingle();
    if (error) throw error;
    if (!data?.id) throw new Error('Investor cash profile not found.');
    return data.id;
  }

  throw new Error('Cashbook is not enabled for this party.');
}

/** Cashbook child routes (`tenant` | `customer` | `investor` | `vendor` | `courier`). */
export async function resolveCashbookRouteProfileId(
  operatingTenantId: number,
  booksTenantId: number,
  routeEntityType: string,
  entityId: number,
): Promise<number> {
  const directTypes = new Set(['customer', 'tenant', 'investor']);
  if (directTypes.has(routeEntityType)) {
    return resolveMoneyProfileId(booksTenantId, routeEntityType, entityId);
  }
  const bundle = await cashbookRepository.getPaymentProfileForStaff({
    tenantId: operatingTenantId,
    entityType: routeEntityType,
    entityId,
    ledgerLimit: 0,
    paysLimit: 5,
  });
  const profileId = bundle.pays.find((row) => row.profile_id != null && row.profile_id > 0)?.profile_id;
  if (profileId) return profileId;
  throw new Error('Cash profile not found for this party.');
}