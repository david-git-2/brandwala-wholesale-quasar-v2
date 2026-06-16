import { commerceBillingProfileRepository } from '../repositories/commerceBillingProfileRepository'
import type {
  CommerceBillingProfile,
  CommerceBillingProfileListPage,
  CommerceBillingProfileListQuery,
  CreateCommerceBillingProfileInput,
  DeleteCommerceBillingProfileInput,
  UpdateCommerceBillingProfileInput,
} from '../repositories/commerceBillingProfileRepository'

export interface CommerceBillingProfileServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<CommerceBillingProfileServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const commerceBillingProfileService = {
  listCommerceBillingProfiles: (payload: CommerceBillingProfileListQuery = {}) =>
    wrap<CommerceBillingProfileListPage>(
      () => commerceBillingProfileRepository.listCommerceBillingProfiles(payload),
      'Failed to load commerce billing profiles.',
    ),
  createCommerceBillingProfile: (payload: CreateCommerceBillingProfileInput) =>
    wrap<CommerceBillingProfile>(
      () => commerceBillingProfileRepository.createCommerceBillingProfile(payload),
      'Failed to create commerce billing profile.',
    ),
  updateCommerceBillingProfile: (payload: UpdateCommerceBillingProfileInput) =>
    wrap<CommerceBillingProfile>(
      () => commerceBillingProfileRepository.updateCommerceBillingProfile(payload),
      'Failed to update commerce billing profile.',
    ),
  deleteCommerceBillingProfile: (payload: DeleteCommerceBillingProfileInput) =>
    wrap<void>(
      () => commerceBillingProfileRepository.deleteCommerceBillingProfile(payload),
      'Failed to delete commerce billing profile.',
    ),
}
