import type { DepositRpcResult } from '../repositories/moneyKernelRepository';

export type ApplyDepositCacheInput = {
  booksTenantId: number;
  profileId: number;
  billId?: number | null;
  locationCode?: string | null;
  legLocationPointId?: number | null;
  legBooksRate?: number | null;
  deposit: DepositRpcResult;
};