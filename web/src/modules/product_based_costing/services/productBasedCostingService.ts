import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository'
import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileUpdateInput,
  ProductBasedCostingItem,
  ProductBasedCostingItemCreateInput,
  ProductBasedCostingItemUpdateInput,
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
  id: number,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingFile>> => {
  try {
    const data = await productBasedCostingRepository.deleteProductBasedCostingFile(id)

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

const getProductBasedCostingFileById = async (
  id: number,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingFile>> => {
  try {
    const data = await productBasedCostingRepository.getProductBasedCostingFileById(id)

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
          : 'Failed to load product based costing file.',
    }
  }
}

const listProductBasedCostingItems = async (
  productBasedCostingFileId: number,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingItem[]>> => {
  try {
    const data = await productBasedCostingRepository.listProductBasedCostingItems(
      productBasedCostingFileId,
    )

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
          : 'Failed to load product based costing items.',
    }
  }
}

const createProductBasedCostingItem = async (
  payload: ProductBasedCostingItemCreateInput,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingItem>> => {
  try {
    const data = await productBasedCostingRepository.createProductBasedCostingItem(payload)

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
          : 'Failed to create product based costing item.',
    }
  }
}

const updateProductBasedCostingItem = async (
  payload: ProductBasedCostingItemUpdateInput,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingItem>> => {
  try {
    const data = await productBasedCostingRepository.updateProductBasedCostingItem(payload)

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
          : 'Failed to update product based costing item.',
    }
  }
}

const deleteProductBasedCostingItem = async (
  id: number,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingItem>> => {
  try {
    const data = await productBasedCostingRepository.deleteProductBasedCostingItem(id)

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
          : 'Failed to delete product based costing item.',
    }
  }
}

const getProductBasedCostingItemById = async (
  id: number,
): Promise<ProductBasedCostingServiceResult<ProductBasedCostingItem>> => {
  try {
    const data = await productBasedCostingRepository.getProductBasedCostingItemById(id)

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
          : 'Failed to load product based costing item.',
    }
  }
}

export const productBasedCostingService = {
  listProductBasedCostingFiles,
  createProductBasedCostingFile,
  updateProductBasedCostingFile,
  deleteProductBasedCostingFile,
  getProductBasedCostingFileById,

  listProductBasedCostingItems,
  createProductBasedCostingItem,
  updateProductBasedCostingItem,
  deleteProductBasedCostingItem,
  getProductBasedCostingItemById,
}
