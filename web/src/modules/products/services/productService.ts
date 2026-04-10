import { productRepository } from '../repositories/productRepository'
import type {
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductUpdateInput,
} from '../types'

type ListProductsParams = {
  page?: number
  pageSize?: number
  search?: string
  category?: string
  brand?: string
  sortPrice?: 'asc' | 'desc'
  tenantId?: number
}

type ProductServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
  total?: number
  page?: number
  pageSize?: number
}

const listBrands = async (): Promise<ProductServiceResult<string[]>> => {
  try {
    const data = await productRepository.listBrands()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load brands.',
    }
  }
}

const listCategories = async (): Promise<ProductServiceResult<string[]>> => {
  try {
    const data = await productRepository.listCategories()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load categories.',
    }
  }
}

const listProducts = async (
  params: ListProductsParams
): Promise<ProductServiceResult<Product[]>> => {
  try {
    const result = await productRepository.listProducts(params)

    return {
      success: true,
      data: result.data,
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load products.',
    }
  }
}

const createProduct = async (
  payload: ProductCreateInput,
): Promise<ProductServiceResult<Product>> => {
  try {
    const data = await productRepository.createProduct(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create product.',
    }
  }
}

const updateProduct = async (
  payload: ProductUpdateInput,
): Promise<ProductServiceResult<Product>> => {
  try {
    const data = await productRepository.updateProduct(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update product.',
    }
  }
}

const deleteProduct = async (
  payload: ProductDeleteInput,
): Promise<ProductServiceResult<Product>> => {
  try {
    const data = await productRepository.deleteProduct(payload)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete product.',
    }
  }
}

export const productService = {
  listBrands,
  listCategories,
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
}
