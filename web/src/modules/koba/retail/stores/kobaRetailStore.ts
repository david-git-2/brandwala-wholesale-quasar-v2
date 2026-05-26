import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'
import { handleApiFailure } from 'src/utils/appFeedback'

// Types aligning with koba product schema
export interface KobaRetailProduct {
  id: string
  name: string
  description: string
  price: number
  image_url: string
  brand: string
  category: string
}

export interface KobaRetailState {
  items: KobaRetailProduct[]
  loading: boolean
  error: string | null
  meta: {
    totalCount: number
    pageSize: number
    currentPage: number
    totalPages: number
  }
}

export const useKobaRetailStore = defineStore('kobaRetail', {
  state: (): KobaRetailState => ({
    items: [],
    loading: false,
    error: null,
    meta: {
      totalCount: 0,
      pageSize: 12,
      currentPage: 1,
      totalPages: 0,
    },
  }),

  getters: {
    totalPages(state): number {
      return Math.ceil(state.meta.totalCount / state.meta.pageSize)
    },
  },

  actions: {
    async fetchProducts(page: number = 1) {
      this.loading = true
      this.error = null
      // store current page in meta
      this.meta.currentPage = page
      const from = (page - 1) * this.meta.pageSize
      const to = from + this.meta.pageSize - 1
      try {
        const { data, error, count } = await supabase
          .from('koba_products')
          .select('*', { count: 'exact' })
          .eq('tenant_id', 12)
          .eq('in_stock', true)
          .order('id')
          .range(from, to)

        if (error) {
          this.error = error.message ?? 'Failed to load Koba Retail products.'
          handleApiFailure({ success: false, error: this.error }, this.error)
          return
        }
        // map items
        this.items = (data ?? []).map((p: any) => ({
          ...p,
          id: String(p.id),
          // price stored as raw value (no division)
          price_gbp: Number(p.price),
          price_bdt: null,
        }))
        // update pagination meta
        const total = typeof count === 'number' ? count : Number(count) || 0
        this.meta.totalCount = total
      } finally {
        this.meta.totalPages = Math.ceil(total / this.meta.pageSize)
      }
    },
  },
})
