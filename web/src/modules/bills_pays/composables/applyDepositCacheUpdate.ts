import type { QueryClient } from '@tanstack/vue-query';
import type { BillDetailBundle } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { type DepositRpcResult, parseDepositRpcResult } from '../repositories/moneyKernelRepository';
import { useBillPayCashbookLegsStore } from '../stores/billPayCashbookLegsStore';
import { billsQueryKeys } from '../services/billsQueryKeys';
import { cashbookQueryKeys } from '../services/cashbookQueryKeys';
import { profileCashbookBundlesQueryKey } from 'src/modules/people/composables/useProfileCashbookBundlesQuery';
import type { ProfileCashbookBundleRow } from 'src/modules/people/types/profileCashbookBundle';
import { patchBillPayCashbookLegs } from './patchBillPayCashbookLegs';
import type { ApplyDepositCacheInput } from '../types/applyDepositCacheInput';

export type { ApplyDepositCacheInput } from '../types/applyDepositCacheInput';

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
    if (!old) return old;
    const payCashbookLegs = patchBillPayCashbookLegs(old.payCashbookLegs, input);
    return {
      ...old,
      payCashbookLegs,
    };
  });

  useBillPayCashbookLegsStore().applyDepositPatch(input);
}

export function applyDepositCacheFromRpc(
  queryClient: QueryClient,
  input: Omit<ApplyDepositCacheInput, 'deposit'> & { rpc: Record<string, unknown> },
): DepositRpcResult {
  const deposit = parseDepositRpcResult(input.rpc);
  applyDepositCacheUpdate(queryClient, { ...input, deposit });
  return deposit;
}

/** Refetch operating account, bundles, locations, and pay dialog legs for one profile. */
export function invalidateProfileCashbookStaffQueries(
  queryClient: QueryClient,
  input: {
    operatingTenantId: number;
    booksTenantId: number;
    entityType: string;
    entityId: number;
    profileId: number;
  },
): void {
  if (input.operatingTenantId <= 0 || input.entityId <= 0 || input.profileId <= 0) return;
  const { operatingTenantId, booksTenantId, entityType, entityId, profileId } = input;

  void queryClient.invalidateQueries({
    queryKey: [
      ...cashbookQueryKeys.root,
      'payment_profile',
      operatingTenantId,
      entityType,
      entityId,
    ],
  });
  void queryClient.invalidateQueries({
    queryKey: [
      ...cashbookQueryKeys.root,
      'profile_activity',
      operatingTenantId,
      entityType,
      entityId,
    ],
  });
  void queryClient.invalidateQueries({
    queryKey: profileCashbookBundlesQueryKey(booksTenantId, profileId),
  });
  void queryClient.invalidateQueries({
    queryKey: [...cashbookQueryKeys.root, 'leg_pots', booksTenantId, profileId],
  });
  void queryClient.invalidateQueries({
    queryKey: [...cashbookQueryKeys.root, 'account_profile', booksTenantId, profileId],
  });
}