import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { orderService } from '../services/orderService'
import type {
  OrderDeleteInput,
  OrderGetByIdInput,
  OrderItemDeleteInput,
  OrderItemUpdateInput,
  OrderListInput,
  OrderStoreState,
  OrderUpdateInput,
} from '../types'

export const useOrderStore = defineStore('order', {
  state: (): OrderStoreState => ({
    items: [],
    selected: null,
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchOrders(payload: OrderListInput = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await orderService.listOrders(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load orders.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchOrderById(payload: OrderGetByIdInput) {
      this.loading = true
      this.error = null

      try {
        const result = await orderService.getOrderById(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load order.'
          handleApiFailure(result, this.error)
          return result
        }

        this.selected = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async updateOrder(payload: OrderUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.updateOrder(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update order.'
          handleApiFailure(result, this.error)
          return result
        }

        const updated = result.data
        if (updated) {
          const index = this.items.findIndex((item) => item.id === updated.id)
          if (index >= 0) {
            this.items.splice(index, 1, updated)
          }

          if (this.selected?.id === updated.id) {
            this.selected = {
              ...updated,
              order_items: this.selected.order_items,
            }
          }
        }

        showSuccessNotification('Order updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateOrderItem(payload: OrderItemUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.updateOrderItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update order item.'
          handleApiFailure(result, this.error)
          return result
        }

        const updated = result.data
        if (updated && this.selected) {
          const index = this.selected.order_items.findIndex((item) => item.id === updated.id)
          if (index >= 0) {
            this.selected.order_items.splice(index, 1, updated)
          }
        }

        showSuccessNotification('Order item updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteOrder(payload: OrderDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.deleteOrder(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete order.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        if (this.selected?.id === payload.id) {
          this.selected = null
        }

        showSuccessNotification('Order deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteOrderItem(payload: OrderItemDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.deleteOrderItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete order item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (this.selected) {
          this.selected.order_items = this.selected.order_items.filter(
            (item) => item.id !== payload.id,
          )
        }

        showSuccessNotification('Order item deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
