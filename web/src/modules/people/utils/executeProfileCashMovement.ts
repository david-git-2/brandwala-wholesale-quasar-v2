import type { QueryClient } from '@tanstack/vue-query';
import { moneyKernelRepository } from 'src/modules/finance/submodules/bills_pays/repositories/moneyKernelRepository';
import { createPayIdempotencyKey } from 'src/modules/finance/submodules/bills_pays/repositories/paysRepository';
import type { MoneyPayKind, MoneyPaySubmitPayload } from 'src/modules/finance/submodules/bills_pays/types/moneyPayDialog';
import { buildKernelPayMovementMeta } from 'src/modules/finance/submodules/bills_pays/utils/kernelPayMovementMeta';
import {
  applyDepositCacheUpdate,
  invalidateProfileCashbookStaffQueries,
} from 'src/modules/finance/submodules/bills_pays/composables/applyDepositCacheUpdate';
import { ProfileDepositPartialError } from './profileDepositPartialError';
import type { DepositRpcResult } from 'src/modules/finance/submodules/bills_pays/repositories/moneyKernelRepository';
import { cashbookQueryKeys } from 'src/modules/finance/submodules/bills_pays/services/cashbookQueryKeys';

export type ProfileCashDepositSuccess =
  | {
      kind: 'deposit';
      batch: true;
      postedCount: number;
      totalBooksAmount: number;
      deposit: DepositRpcResult | null;
      booksTenantId: number;
      profileId: number;
      locationCode: string | null;
      legLocationPointId: number | null;
      legBooksRate: number | null;
    }
  | {
      kind: 'deposit';
      batch: false;
      deposit: DepositRpcResult;
      booksTenantId: number;
      profileId: number;
      locationCode: string | null;
      legLocationPointId: number | null;
      legBooksRate: number | null;
    };

export type ProfileCashMovementSuccess = ProfileCashDepositSuccess | { kind: 'withdrawal' };

export async function executeProfileCashMovement(
  input: {
    kind: MoneyPayKind;
    profileId: number;
    booksTenantId: number;
    payload: MoneyPaySubmitPayload;
  },
  queryClient: QueryClient,
): Promise<ProfileCashMovementSuccess> {
  const { kind, profileId, booksTenantId, payload } = input;
  const currency =
    payload.legCurrencyCode?.trim().toUpperCase()
    || payload.sourceCurrencyCode?.trim().toUpperCase()
    || 'BDT';

  if (kind === 'deposit') {
    if (payload.legLocationPointId == null) throw new Error('Choose a deposit location.');
    const selectedPotId = payload.toPotId;
    if (selectedPotId != null && selectedPotId <= 0) {
      throw new Error('Choose a bundle.');
    }
    const locationCode = payload.legLocationCode?.trim() || undefined;
    const sharedDate = payload.paymentDate?.trim() || '';
    const depositLines = payload.depositLines?.filter((l) => l.amount > 0) ?? [];

    if (depositLines.length > 0) {
      let postedCount = 0;
      let lastDeposit: DepositRpcResult | null = null;
      const totalCount = depositLines.length;
      try {
        for (const line of depositLines) {
          const linePayload: MoneyPaySubmitPayload = {
            ...payload,
            amount: line.amount,
            methodCode: line.methodCode,
            reference: line.reference ?? null,
            note: line.note ?? null,
            instrumentFields: line.instrumentFields,
            paymentDate: line.paymentDate?.trim() || sharedDate,
          };
          const meta = buildKernelPayMovementMeta(linePayload, {
            source: 'people_cash_movement',
          });
          const deposit = await moneyKernelRepository.deposit({
            tenantId: booksTenantId,
            profileId,
            amount: line.amount,
            currencyCode: currency,
            potId: selectedPotId != null && selectedPotId > 0 ? selectedPotId : null,
            locationCode: selectedPotId != null && selectedPotId > 0 ? null : locationCode,
            booksRate: payload.legBooksRate ?? null,
            meta,
            idempotencyKey: createPayIdempotencyKey(),
          });
          applyDepositCacheUpdate(queryClient, {
            booksTenantId,
            profileId,
            locationCode: locationCode ?? null,
            legLocationPointId: payload.legLocationPointId,
            legBooksRate: payload.legBooksRate ?? null,
            deposit,
          });
          postedCount += 1;
          lastDeposit = deposit;
        }
      } catch (error: unknown) {
        const detail = error instanceof Error ? error.message : 'Could not post deposit.';
        if (postedCount > 0) {
          throw new ProfileDepositPartialError(
            `Posted ${postedCount} of ${totalCount}. ${detail}`,
            postedCount,
            totalCount,
          );
        }
        throw error;
      }
      const totalBooks = depositLines.reduce((sum, l) => sum + l.amount, 0);
      return {
        kind: 'deposit',
        batch: true,
        postedCount: totalCount,
        totalBooksAmount: totalBooks,
        deposit: lastDeposit,
        booksTenantId,
        profileId,
        locationCode: locationCode ?? null,
        legLocationPointId: payload.legLocationPointId,
        legBooksRate: payload.legBooksRate ?? null,
      };
    }

    const amount = payload.amount;
    if (amount <= 0) throw new Error('Enter an amount greater than zero.');
    const key = createPayIdempotencyKey();
    const meta = buildKernelPayMovementMeta(payload, {
      source: 'people_cash_movement',
    });
    const deposit = await moneyKernelRepository.deposit({
      tenantId: booksTenantId,
      profileId,
      amount,
      currencyCode: currency,
      potId: selectedPotId != null && selectedPotId > 0 ? selectedPotId : null,
      locationCode: selectedPotId != null && selectedPotId > 0 ? null : locationCode,
      booksRate: payload.legBooksRate ?? null,
      meta,
      idempotencyKey: key,
    });
    return {
      kind: 'deposit',
      batch: false,
      deposit,
      booksTenantId,
      profileId,
      locationCode: locationCode ?? null,
      legLocationPointId: payload.legLocationPointId,
      legBooksRate: payload.legBooksRate ?? null,
    };
  }

  const amount = payload.amount;
  if (amount <= 0) throw new Error('Enter an amount greater than zero.');
  const key = createPayIdempotencyKey();
  const meta = buildKernelPayMovementMeta(payload, {
    source: 'people_cash_movement',
  });

  const potId = payload.fromPotId;
  if (potId == null) throw new Error('Choose which bundle to withdraw from.');
  await moneyKernelRepository.withdraw({
    tenantId: booksTenantId,
    profileId,
    amount,
    currencyCode: currency,
    potId,
    meta,
    idempotencyKey: key,
  });
  return { kind: 'withdrawal' };
}

export function afterProfileCashMovementSuccess(
  queryClient: QueryClient,
  input: {
    kind: MoneyPayKind;
    result: ProfileCashMovementSuccess | void;
    operatingTenantId: number;
    booksTenantId: number;
    entityType: string;
    entityId: number;
    profileId: number | null;
  },
) {
  const pid =
    input.result && typeof input.result === 'object' && 'profileId' in input.result
      ? Number(input.result.profileId)
      : input.profileId;
  if (
    input.result
    && typeof input.result === 'object'
    && 'kind' in input.result
    && input.result.kind === 'deposit'
    && 'batch' in input.result
    && input.result.batch === false
  ) {
    applyDepositCacheUpdate(queryClient, {
      booksTenantId: input.result.booksTenantId,
      profileId: input.result.profileId,
      locationCode: input.result.locationCode,
      legLocationPointId: input.result.legLocationPointId,
      legBooksRate: input.result.legBooksRate,
      deposit: input.result.deposit,
    });
  }
  if (pid != null && pid > 0) {
    invalidateProfileCashbookStaffQueries(queryClient, {
      operatingTenantId: input.operatingTenantId,
      booksTenantId: input.booksTenantId,
      entityType: input.entityType,
      entityId: input.entityId,
      profileId: pid,
    });
  } else {
    void queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
  }
}