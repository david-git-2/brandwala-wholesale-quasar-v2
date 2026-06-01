import { commerceAccountingRepository } from '../repositories/commerceAccountingRepository'
import type { CommerceAccounting, CommerceAccountingServiceResult } from '../types'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<CommerceAccountingServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const commerceAccountingService = {
  listCommerceAccounting: (tenantId: number) =>
    wrap<CommerceAccounting[]>(
      () => commerceAccountingRepository.listCommerceAccounting(tenantId),
      'Failed to load commerce accounting records.',
    ),
  updateAccountingPaymentStatus: (entryId: number, isPaid: boolean) =>
    wrap<CommerceAccounting>(
      () => commerceAccountingRepository.updateAccountingPaymentStatus(entryId, isPaid),
      'Failed to update commerce accounting payment status.',
    ),
}
