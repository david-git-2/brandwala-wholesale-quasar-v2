import type { QueryClient } from '@tanstack/vue-query';
import type { BillDetailBundle } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import type { BillPayCashbookLeg } from '../types/billPayCashbookLegs';
import { type DepositRpcResult, parseDepositRpcResult } from '../repositories/moneyKernelRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { profileCashbookBundlesQueryKey } from 'src/modules/people/composables/useProfileCashbookBundlesQuery';
import type { ProfileCashbookBundleRow } from 'src/modules/people/types/profileCashbookBundle';

export type ApplyDepositCacheInput = {
  booksTenantId: number;
  profileId: number;
  billId?: number | null;
  locationCode?: string | null;
  legLocationPointId?: number | null;
  legBooksRate?: number | null;
  deposit: DepositRpcResult;
};

function patchLegPots(leg: BillPayCashbookLeg, input: ApplyDepositCacheInput): BillPayCashbookLeg {
  const potId = input.deposit.pot_id;
  const pointName =
    input.legLocationPointId != null
      ? leg.points.find((p) => p.id === input.legLocationPointId)?.name?.trim() || null
      : null;
  const idx = leg.pots.findIndex((p) => p.id === potId);
  if (idx >= 0) {
    const pots = [...leg.pots];
    const booksRate =
      input.legBooksRate != null && input.legBooksRate > 0
        ? input.legBooksRate
        : pots[idx].books_rate;
    pots[idx] = {
      ...pots[idx],
      amount: input.deposit.balance_after,
      books_rate: booksRate,
    };
    return { ...leg, pots };
  }
  const booksRate =
    input.legBooksRate != null && input.legBooksRate > 0 ? input.legBooksRate : null;
  return {
    ...leg,
    pots: [
      ...leg.pots,
      {
        id: potId,
        cashbook_point_id: input.legLocationPointId ?? 0,
        currency_code: input.deposit.currency_code,
        amount: input.deposit.balance_after,
        books_rate: booksRate,
        drawer_group: null,
        point_code: input.locationCode?.trim() || null,
        point_name: pointName,
      },
    ],
  };
}

function patchLegForProfile(
  leg: BillPayCashbookLeg | null,
  profileId: number,
  input: ApplyDepositCacheInput,
): BillPayCashbookLeg | null {
  if (!leg || leg.profile_id !== profileId) return leg;
  return patchLegPots(leg, input);
}

export function applyDepositCacheUpdate(queryClient: QueryClient, input: ApplyDepositCacheInput): void {
  const bundlesKey = profileCashbookBundlesQueryKey(input.booksTenantId, input.profileId);
  queryClient.setQueryData<ProfileCashbookBundleRow[] | undefined>(bundlesKey, (old) => {
    const rows = old ?? [];
    const potId = input.deposit.pot_id;
    const idx = rows.findIndex((b) => b.bundleId === potId);
    if (idx >= 0) {
      const next = [...rows];
      next[idx] = { ...next[idx], amount: input.deposit.balance_after };
      return next;
    }
    const loc = input.locationCode?.trim() || 'main';
    const booksRate =
      input.legBooksRate != null && input.legBooksRate > 0
        ? input.legBooksRate
        : input.deposit.currency_code === 'BDT'
          ? 1
          : 1;
    return [
      ...rows,
      {
        bundleId: potId,
        cashLocationId: 0,
        locationCode: loc,
        locationName: '',
        deskPointId: input.legLocationPointId ?? null,
        currencyCode: input.deposit.currency_code,
        amount: input.deposit.balance_after,
        booksRate,
      },
    ];
  });

  const billId = input.billId;
  if (billId == null || billId <= 0) return;

  queryClient.setQueryData<BillDetailBundle | undefined>(billsQueryKeys.detailBundle(billId), (old) => {
    if (!old?.payCashbookLegs) return old;
    return {
      ...old,
      payCashbookLegs: {
        ...old.payCashbookLegs,
        from_leg: patchLegForProfile(old.payCashbookLegs.from_leg, input.profileId, input),
        to_leg: patchLegForProfile(old.payCashbookLegs.to_leg, input.profileId, input),
      },
    };
  });
}

export function applyDepositCacheFromRpc(
  queryClient: QueryClient,
  input: Omit<ApplyDepositCacheInput, 'deposit'> & { rpc: Record<string, unknown> },
): DepositRpcResult {
  const deposit = parseDepositRpcResult(input.rpc);
  applyDepositCacheUpdate(queryClient, { ...input, deposit });
  return deposit;
}
