import { defineStore } from 'pinia'

import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'
import { productService } from '../services/productService'
import type {
  Product,
  ProductCreateInput,
  ProductDeleteInput,
  ProductUpdateInput,
} from '../types'

type FetchProductsParams = {
  page?: number
  pageSize?: number
  search?: string
  category?: string | null | undefined
  brand?: string | null | undefined
  sortPrice?: 'asc' | 'desc'
  tenantId?: number | null | undefined
  vendorCode?: string | null | undefined
  append?: boolean
}

type ProductStoreState = {
  items: Product[]
  loading: boolean
  saving: boolean
  error: string | null
  total: number
  page: number
  pageSize: number
  search: string
  category: string
  brand: string
  sortPrice: 'asc' | 'desc'
  tenantId: number | undefined
  vendorCode: string | undefined
}

export const useProductStore = defineStore('product', {
  state: (): ProductStoreState => ({
    items: [],
    loading: false,
    saving: false,
    error: null,
    total: 0,
    page: 1,
    pageSize: 20,
    search: '',
    category: '',
    brand: '',
    sortPrice: 'asc',
    tenantId: undefined,
    vendorCode: undefined,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    setFilters(params: FetchProductsParams) {
      if (params.page !== undefined) this.page = params.page
      if (params.pageSize !== undefined) this.pageSize = params.pageSize
      if (params.search !== undefined) this.search = params.search
      if (params.category !== undefined) this.category = params.category ?? ''
      if (params.brand !== undefined) this.brand = params.brand ?? ''
      if (params.sortPrice !== undefined) this.sortPrice = params.sortPrice
      if (params.tenantId !== undefined) this.tenantId = params.tenantId ?? undefined
      if (params.vendorCode !== undefined) this.vendorCode = params.vendorCode ?? undefined
    },

    resetFilters() {
      this.page = 1
      this.pageSize = 20
      this.search = ''
      this.category = ''
      this.brand = ''
      this.sortPrice = 'asc'
      this.tenantId = undefined
      this.vendorCode = undefined
    },

    async fetchProducts(params?: FetchProductsParams) {
      this.loading = true
      this.error = null

      try {
        if (params) {
          this.setFilters(params)
        }

        const result = await productService.listProducts({
          page: this.page,
          pageSize: this.pageSize,
          search: this.search,
          category: this.category || null,
          brand: this.brand || null,
          sortPrice: this.sortPrice,
          tenantId: this.tenantId ?? null,
          vendorCode: this.vendorCode || null,
        })

        if (!result.success) {
          this.error = result.error ?? 'Failed to load products.'
          handleApiFailure(result, this.error)
          return result
        }

        const incomingItems = result.data ?? []

        if (params?.append) {
          const existingById = new Set(this.items.map((item) => item.id))
          const nextItems = [...this.items]

          for (const item of incomingItems) {
            if (!existingById.has(item.id)) {
              nextItems.push(item)
            }
          }

          this.items = nextItems
        } else {
          this.items = incomingItems
        }
        this.total = result.total ?? 0
        this.page = result.page ?? this.page
        this.pageSize = result.pageSize ?? this.pageSize

        return result
      } finally {
        this.loading = false
      }
    },

    async createProduct(payload: ProductCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productService.createProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create product.'
          handleApiFailure(result, this.error)
          return result
        }

        showSuccessNotification('Product created successfully.')

        await this.fetchProducts({
          page: this.page,
          pageSize: this.pageSize,
          search: this.search,
          category: this.category,
          brand: this.brand,
          sortPrice: this.sortPrice,
          tenantId: this.tenantId ?? null,
          vendorCode: this.vendorCode ?? null,
        })

        return result
      } finally {
        this.saving = false
      }
    },

    async updateProduct(payload: ProductUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productService.updateProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update product.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedProduct = result.data

        if (!updatedProduct) {
          return result
        }

        const index = this.items.findIndex((item) => item.id === updatedProduct.id)

        if (index >= 0) {
          this.items.splice(index, 1, updatedProduct)
        }

        showSuccessNotification('Product updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteProduct(payload: ProductDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await productService.deleteProduct(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete product.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        this.total = Math.max(0, this.total - 1)

        showSuccessNotification('Product deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
