import { defineStore } from 'pinia'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { handleApiFailure } from 'src/utils/appFeedback'
import { kobaOrderService } from '../services/kobaOrderService'
import type { KobaOrder, KobaOrderItem } from '../repositories/kobaOrderRepository'

export interface KobaOrderState {
  orders: KobaOrder[]
  orderDetail: {
    order: KobaOrder
    items: KobaOrderItem[]
  } | null
  loading: boolean
  error: string | null
  meta: {
    total: number
    page: number
    page_size: number
    total_pages: number
  }
}

const KOBA_TENANT_ID = 12

export const useKobaOrderStore = defineStore('kobaOrder', {
  state: (): KobaOrderState => ({
    orders: [],
    orderDetail: null,
    loading: false,
    error: null,
    meta: {
      total: 0,
      page: 1,
      page_size: 20,
      total_pages: 1,
    },
  }),

  actions: {
    async fetchOrders(page: number = 1, status: string | null = null) {
      const authStore = useAuthStore()
      const tenantId = authStore.tenantId ?? KOBA_TENANT_ID
      const marketId = null

      this.loading = true
      this.error = null

      try {
        const result = await kobaOrderService.listOrders(tenantId, marketId, page, this.meta.page_size, status)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to load orders.'
          handleApiFailure(result, this.error)
          return result
        }

        this.orders = result.data.data
        this.meta = result.data.meta
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchOrderDetails(orderId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await kobaOrderService.getOrderWithItems(orderId)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to load order details.'
          handleApiFailure(result, this.error)
          return result
        }

        this.orderDetail = result.data
        return result
      } finally {
        this.loading = false
      }
    },
  },
})
