import { billingProfileRepository } from '../repositories/billingProfileRepository'
import type {
  BillingProfile,
  BillingProfileListPage,
  BillingProfileListQuery,
  BillingProfileServiceResult,
  CreateBillingProfileInput,
  DeleteBillingProfileInput,
  UpdateBillingProfileInput,
} from '../types/billingProfile'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<BillingProfileServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const billingProfileService = {
  listBillingProfiles: (payload: BillingProfileListQuery = {}) =>
    wrap<BillingProfileListPage>(
      () => billingProfileRepository.listBillingProfiles(payload),
      'Failed to load billing profiles.',
    ),
  createBillingProfile: (payload: CreateBillingProfileInput) =>
    wrap<BillingProfile>(
      () => billingProfileRepository.createBillingProfile(payload),
      'Failed to create billing profile.',
    ),
  updateBillingProfile: (payload: UpdateBillingProfileInput) =>
    wrap<BillingProfile>(
      () => billingProfileRepository.updateBillingProfile(payload),
      'Failed to update billing profile.',
    ),
  deleteBillingProfile: (payload: DeleteBillingProfileInput) =>
    wrap<void>(
      () => billingProfileRepository.deleteBillingProfile(payload),
      'Failed to delete billing profile.',
    ),
}
