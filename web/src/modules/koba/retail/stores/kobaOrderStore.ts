import { defineStore } from 'pinia'

import { useAuthStore } from 'src/modules/auth/stores/authStore'

import { handleApiFailure } from 'src/utils/appFeedback'

import { kobaOrderService } from '../services/kobaOrderService'

import type {
  KobaOrder,
  KobaOrderItem,
  KobaOrderStatus,
} from '../repositories/kobaOrderRepository'

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

  getters: {
    pendingOrders: (state) =>
      state.orders.filter(
        (order) => order.status === 'pending'
      ),

    completedOrders: (state) =>
      state.orders.filter(
        (order) =>
          order.status === 'delivered'
      ),
  },

  actions: {
    async fetchOrders(
      page: number = 1,
      status: KobaOrderStatus | null = null
    ) {
      const authStore = useAuthStore()

      const tenantId =
        authStore.tenantId ??
        KOBA_TENANT_ID

      const customerGroupId =
        authStore.customerGroupId != null
          ? Number(
              authStore.customerGroupId
            )
          : null

      this.loading = true

      this.error = null

      try {
        const result =
          await kobaOrderService.listOrders(
            tenantId,
            customerGroupId,
            page,
            this.meta.page_size,
            status
          )

        if (
          !result.success ||
          !result.data
        ) {
          this.error =
            result.error ??
            'Failed to load orders.'

          handleApiFailure(
            result,
            this.error
          )

          return result
        }

        this.orders =
          result.data.data

        this.meta =
          result.data.meta

        return result
      } finally {
        this.loading = false
      }
    },

    async fetchOrderDetails(
      orderId: number
    ) {
      this.loading = true

      this.error = null

      try {
        const result =
          await kobaOrderService.getOrderWithItems(
            orderId
          )

        if (
          !result.success ||
          !result.data
        ) {
          this.error =
            result.error ??
            'Failed to load order details.'

          handleApiFailure(
            result,
            this.error
          )

          return result
        }

        this.orderDetail =
          result.data

        return result
      } finally {
        this.loading = false
      }
    },

    async updateOrderStatus(
      orderId: number,
      status: KobaOrderStatus
    ) {
      const result = await kobaOrderService.updateOrderStatus(orderId, status)

      if (result.success && result.data && this.orderDetail) {
        this.orderDetail = {
          ...this.orderDetail,
          order: {
            ...this.orderDetail.order,
            status: result.data.status,
            updated_at: result.data.updated_at,
          },
        }

        // Also reflect in the orders list if it's there
        const idx = this.orders.findIndex((o) => o.id === orderId)
        if (idx !== -1) {
          this.orders[idx] = {
            ...this.orders[idx]!,
            status: result.data.status,
            updated_at: result.data.updated_at,
          }
        }
      }

      if (!result.success) {
        handleApiFailure(result, result.error ?? 'Failed to update status.')
      }

      return result
    },

    async updateItemConfirmedQty(
      itemId: number,
      confirmedQuantity: number
    ) {
      const result = await kobaOrderService.updateItemConfirmedQty(itemId, confirmedQuantity)

      if (result.success && result.data && this.orderDetail) {
        this.orderDetail = {
          ...this.orderDetail,
          items: this.orderDetail.items.map((item) =>
            item.id === itemId
              ? {
                  ...item,
                  confirmed_quantity: result.data!.confirmed_quantity,
                  updated_at: result.data!.updated_at,
                }
              : item
          ),
        }
      }

      if (!result.success) {
        handleApiFailure(result, result.error ?? 'Failed to update confirmed quantity.')
      }

      return result
    },

    async updateItemDeliveredQty(
      itemId: number,
      deliveredQuantity: number
    ) {
      const result = await kobaOrderService.updateItemDeliveredQty(itemId, deliveredQuantity)

      if (result.success && result.data && this.orderDetail) {
        this.orderDetail = {
          ...this.orderDetail,
          items: this.orderDetail.items.map((item) =>
            item.id === itemId
              ? {
                  ...item,
                  delivered_quantity: result.data!.delivered_quantity,
                  updated_at: result.data!.updated_at,
                }
              : item
          ),
        }
      }

      if (!result.success) {
        handleApiFailure(result, result.error ?? 'Failed to update delivered quantity.')
      }

      return result
    },

    async softDeleteOrder(orderId: number) {
      const result = await kobaOrderService.softDeleteOrder(orderId)

      if (result.success && result.data && this.orderDetail) {
        this.orderDetail = {
          ...this.orderDetail,
          order: {
            ...this.orderDetail.order,
            status: result.data.status,
            updated_at: result.data.updated_at,
          },
        }

        const idx = this.orders.findIndex((o) => o.id === orderId)
        if (idx !== -1) {
          this.orders[idx] = {
            ...this.orders[idx]!,
            status: result.data.status,
            updated_at: result.data.updated_at,
          }
        }
      }

      if (!result.success) {
        handleApiFailure(result, result.error ?? 'Failed to delete order.')
      }

      return result
    },

    clearOrderDetails() {
      this.orderDetail = null
    },

    clearOrders() {
      this.orders = []

      this.meta = {
        total: 0,
        page: 1,
        page_size: 20,
        total_pages: 1,
      }
    },
  },
})