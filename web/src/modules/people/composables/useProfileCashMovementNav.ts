import { useRoute, useRouter } from 'vue-router';
import {
  navigateToProfileCashMovement,
  type ProfileCashMovementNavKind,
} from '../utils/profileCashMovementNavigation';

export function useProfileCashMovementNav() {
  const router = useRouter();
  const route = useRoute();

  const tenantSlug = () =>
    typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;

  const goToCashMovement = (input: {
    kind: ProfileCashMovementNavKind;
    entityType: string;
    entityId: number;
    partyName?: string;
    returnTo?: string;
    prefillCurrency?: string;
    prefillAmount?: number;
  }) => {
    navigateToProfileCashMovement(router, {
      kind: input.kind,
      entityType: input.entityType,
      entityId: input.entityId,
      tenantSlug: tenantSlug(),
      returnTo: input.returnTo?.trim() || route.fullPath,
      partyName: input.partyName,
      prefillCurrency: input.prefillCurrency,
      prefillAmount: input.prefillAmount,
    });
  };

  return { goToCashMovement };
}