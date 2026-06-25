import { productRepository } from '../repositories/productRepository'
import type {
  ProductBrand,
  ProductBrandCreateInput,
  ProductBrandDeleteInput,
  ProductBrandUpdateInput,
  ProductCategory,
  ProductCategoryCreateInput,
  ProductCategoryDeleteInput,
  ProductCategoryUpdateInput,
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductListPage,
  ProductUpdateInput,
} from '../types'

type ListProductsParams = {
  page?: number
  pageSize?: number
  search?: string | null | undefined
  searchField?: 'name' | 'barcode' | 'product_code' | 'id'
  category?: string | null | undefined
  brand?: string | null | undefined
  sortPrice?: 'asc' | 'desc'
  tenantId?: number | null | undefined
  vendorCode?: string | null | undefined
  marketCode?: string | null | undefined
  isAvailable?: boolean | null | undefined
}

type ListProductLookupParams = {
  vendorCode?: string | null | undefined
  vendorId?: number | null | undefined
  tenantId?: number | null | undefined
}

type ProductServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
  meta?: ProductListPage['meta']
}

const listBrands = async (
  params: ListProductLookupParams = {}
): Promise<ProductServiceResult<string[]>> => {
  try {
    const data = await productRepository.listBrands(params)

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

const listCategories = async (
  params: ListProductLookupParams = {}
): Promise<ProductServiceResult<string[]>> => {
  try {
    const data = await productRepository.listCategories(params)

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
  tenantId?: number | null,
): Promise<ProductServiceResult<Product>> => {
  try {
    const data = await productRepository.getProductById(id, tenantId)
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

const listProductBrands = async (
  params: ListProductLookupParams = {},
): Promise<ProductServiceResult<ProductBrand[]>> => {
  try {
    const data = await productRepository.listProductBrands(params)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load product brands.',
    }
  }
}

const createProductBrand = async (
  payload: ProductBrandCreateInput,
): Promise<ProductServiceResult<ProductBrand>> => {
  try {
    const data = await productRepository.createProductBrand(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create product brand.',
    }
  }
}

const updateProductBrand = async (
  payload: ProductBrandUpdateInput,
): Promise<ProductServiceResult<ProductBrand>> => {
  try {
    const data = await productRepository.updateProductBrand(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update product brand.',
    }
  }
}

const deleteProductBrand = async (
  payload: ProductBrandDeleteInput,
): Promise<ProductServiceResult<null>> => {
  try {
    await productRepository.deleteProductBrand(payload)
    return { success: true, data: null }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete product brand.',
    }
  }
}

const listProductCategories = async (
  params: ListProductLookupParams = {},
): Promise<ProductServiceResult<ProductCategory[]>> => {
  try {
    const data = await productRepository.listProductCategories(params)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load product categories.',
    }
  }
}

const createProductCategory = async (
  payload: ProductCategoryCreateInput,
): Promise<ProductServiceResult<ProductCategory>> => {
  try {
    const data = await productRepository.createProductCategory(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create product category.',
    }
  }
}

const updateProductCategory = async (
  payload: ProductCategoryUpdateInput,
): Promise<ProductServiceResult<ProductCategory>> => {
  try {
    const data = await productRepository.updateProductCategory(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update product category.',
    }
  }
}

const deleteProductCategory = async (
  payload: ProductCategoryDeleteInput,
): Promise<ProductServiceResult<null>> => {
  try {
    await productRepository.deleteProductCategory(payload)
    return { success: true, data: null }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete product category.',
    }
  }
}

export const productService = {
  listBrands,
  listCategories,
  listProductBrands,
  createProductBrand,
  updateProductBrand,
  deleteProductBrand,
  listProductCategories,
  createProductCategory,
  updateProductCategory,
  deleteProductCategory,
  listProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
}
