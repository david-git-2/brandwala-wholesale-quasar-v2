/** Mirrors `cashbookAxesForProfile` in cashbookRepository (client-side). */
export type CashbookNavProfile = {
  profileId: number;
  profileType?: string | null;
  subjectId?: number | null;
};

export function cashbookNavAxesFromProfile(
  profile: CashbookNavProfile,
): { entityType: string; entityId: number } {
  const profileType = profile.profileType?.trim().toLowerCase() || 'customer';
  const subjectId = profile.subjectId ?? 0;
  switch (profileType) {
    case 'tenant':
      return {
        entityType: 'tenant',
        entityId: subjectId > 0 ? subjectId : profile.profileId,
      };
    case 'vendor':
      return { entityType: 'vendor', entityId: subjectId > 0 ? subjectId : profile.profileId };
    case 'cargo':
      return {
        entityType: 'cargo_company',
        entityId: subjectId > 0 ? subjectId : profile.profileId,
      };
    case 'courier':
      return { entityType: 'courier', entityId: subjectId > 0 ? subjectId : profile.profileId };
    case 'investor':
      return { entityType: 'investor', entityId: subjectId > 0 ? subjectId : profile.profileId };
    case 'customer':
    default:
      return { entityType: 'customer', entityId: profile.profileId };
  }
}

/** AP payer is tenant; AR payer is customer profile; receive-side tenant uses operating tenant id. */
export function cashbookNavAxesForBillDeposit(input: {
  profileId: number;
  isApBill: boolean;
  isPayerLeg: boolean;
  operatingTenantId: number;
  arDualCashbook: boolean;
}): { entityType: string; entityId: number } {
  if (input.isApBill && input.isPayerLeg) {
    return { entityType: 'tenant', entityId: input.operatingTenantId };
  }
  if (!input.isApBill && input.isPayerLeg && input.arDualCashbook) {
    return cashbookNavAxesFromProfile({ profileId: input.profileId, profileType: 'customer' });
  }
  if (!input.isApBill && !input.isPayerLeg) {
    return { entityType: 'tenant', entityId: input.operatingTenantId };
  }
  return cashbookNavAxesFromProfile({ profileId: input.profileId });
}