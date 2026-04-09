import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository'
import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileDeleteInput,
  ProductBasedCostingFileUpdateInput,
  ProductBasedCostingServiceResult,
} from '../types'

const listProductBasedCostingFiles = async (): Promise<
  ProductBasedCostingServiceResult<ProductBasedCostingFile[]>
> => {
  try {
    const data = await productBasedCostingRepository.listProductBasedCostingFiles()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load product based costing files.',
    }
  }
}

const createProductBasedCostingFile = async (
  payload: ProductBasedCostingFileCreateInput,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingFile>> => {
  try {
    const data = await productBasedCostingRepository.createProductBasedCostingFile(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to create product based costing file.',
    }
  }
}

const updateProductBasedCostingFile = async (
  payload: ProductBasedCostingFileUpdateInput,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingFile>> => {
  try {
    const data = await productBasedCostingRepository.updateProductBasedCostingFile(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to update product based costing file.',
    }
  }
}

const deleteProductBasedCostingFile = async (
  payload: ProductBasedCostingFileDeleteInput,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingFile>> => {
  try {
    const data = await productBasedCostingRepository.deleteProductBasedCostingFile(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to delete product based costing file.',
    }
  }
}

export const productBasedCostingService = {
  listProductBasedCostingFiles,
  createProductBasedCostingFile,
  updateProductBasedCostingFile,
  deleteProductBasedCostingFile,
}
