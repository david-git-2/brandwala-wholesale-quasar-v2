import { productRepository } from '../repositories/productRepository'
import type {
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductServiceResult,
  ProductUpdateInput,
} from '../types'

const listProducts = async (): Promise<ProductServiceResult<Product[]>> => {
  try {
    const data = await productRepository.listProducts()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load products.',
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
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
}
