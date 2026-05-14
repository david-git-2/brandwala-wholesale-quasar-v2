import { productRepository } from '../repositories/productRepository'
import type {
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductListPage,
  ProductUpdateInput,
} from '../types'

type ListProductsParams = {
  page?: number
  pageSize?: number
  search?: string
  searchField?: 'name' | 'barcode' | 'product_code' | 'id'
  category?: string | null | undefined
  brand?: string | null | undefined
  sortPrice?: 'asc' | 'desc'
  tenantId?: number | null | undefined
  vendorCode?: string | null | undefined
  marketCode?: string | null | undefined
  isAvailable?: boolean | null | undefined
}

type ProductServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
  meta?: ProductListPage['meta']
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
      meta: result.meta,
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

const getProductById = async (
  id: number,
): Promise<ProductServiceResult<Product>> => {
  try {
    const data = await productRepository.getProductById(id)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load product.',
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
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
}
