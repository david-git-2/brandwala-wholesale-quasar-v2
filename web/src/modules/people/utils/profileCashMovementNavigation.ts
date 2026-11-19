import type { Router, RouteLocationRaw } from 'vue-router';
import type { MoneyPayKind } from 'src/modules/bills_pays/types/moneyPayDialog';
import { cashbookNavEntityType } from './profileCashbookEnabled';

export type ProfileCashMovementNavKind = Extract<MoneyPayKind, 'deposit' | 'withdrawal'>;

export function cashbookMovementRouteName(kind: ProfileCashMovementNavKind): string {
  return kind === 'deposit' ? 'app-cashbook-deposit-page' : 'app-cashbook-withdraw-page';
}

export function navigateToProfileCashMovement(
  router: Router,
  input: {
    kind: ProfileCashMovementNavKind;
    entityType: string;
    entityId: number;
    tenantSlug?: string;
    returnTo: string;
    partyName?: string;
    prefillCurrency?: string;
    prefillAmount?: number;
  },
) {
  const navType = cashbookNavEntityType(input.entityType);
  const params: Record<string, string> = {
    entityType: navType,
    entityId: String(input.entityId),
  };
  if (input.tenantSlug?.trim()) {
    params.tenantSlug = input.tenantSlug.trim();
  }
  const query: Record<string, string> = {
    returnTo: input.returnTo,
  };
  if (input.partyName?.trim()) {
    query.partyName = input.partyName.trim();
  }
  const ccy = input.prefillCurrency?.trim().toUpperCase();
  if (ccy) {
    query.prefillCurrency = ccy;
  }
  if (input.prefillAmount != null && Number.isFinite(input.prefillAmount) && input.prefillAmount > 0) {
    query.prefillAmount = String(Math.round(input.prefillAmount * 100) / 100);
  }
  void router.push({
    name: cashbookMovementRouteName(input.kind),
    params,
    query,
  });
}