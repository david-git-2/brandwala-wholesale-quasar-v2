import { vendorRepository } from '../repositories/vendorRepository'
import type {
  Vendor,
  VendorCreateInput,
  VendorDeleteInput,
  VendorMarket,
  VendorServiceResult,
  VendorUpdateInput,
} from '../types'

const listVendors = async (): Promise<VendorServiceResult<Vendor[]>> => {
  try {
    const data = await vendorRepository.listVendors()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load vendors.',
    }
  }
}

const listVendorMarkets = async (): Promise<VendorServiceResult<VendorMarket[]>> => {
  try {
    const data = await vendorRepository.listVendorMarkets()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load markets.',
    }
  }
}

const isVendorCodeAvailable = async (
  code: string,
  excludeId?: number | null,
): Promise<VendorServiceResult<boolean>> => {
  try {
    const data = await vendorRepository.isVendorCodeAvailable(code, excludeId)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to check vendor code.',
    }
  }
}

const createVendor = async (
  payload: VendorCreateInput,
): Promise<VendorServiceResult<Vendor>> => {
  try {
    const data = await vendorRepository.createVendor(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create vendor.',
    }
  }
}

const updateVendor = async (
  payload: VendorUpdateInput,
): Promise<VendorServiceResult<Vendor>> => {
  try {
    const data = await vendorRepository.updateVendor(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update vendor.',
    }
  }
}

const deleteVendor = async (
  payload: VendorDeleteInput,
): Promise<VendorServiceResult<null>> => {
  try {
    await vendorRepository.deleteVendor(payload)

    return {
      success: true,
      data: null,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete vendor.',
    }
  }
}

export const vendorService = {
  listVendors,
  listVendorMarkets,
  isVendorCodeAvailable,
  createVendor,
  updateVendor,
  deleteVendor,
}
