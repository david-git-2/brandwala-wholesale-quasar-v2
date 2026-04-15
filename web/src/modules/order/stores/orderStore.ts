import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { orderService } from '../services/orderService'
import type {
  OrderDeleteInput,
  OrderGetByIdInput,
  OrderItemBulkUpdateInput,
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
    total: 0,
    page: 1,
    page_size: 20,
    total_pages: 1,
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

        this.items = result.data?.data ?? []
        this.total = result.data?.meta.total ?? 0
        this.page = result.data?.meta.page ?? (payload.page ?? 1)
        this.page_size = result.data?.meta.page_size ?? (payload.page_size ?? 20)
        this.total_pages = result.data?.meta.total_pages ?? 1
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

    async updateOrderItemsFirstOffer(payload: Array<{ id: number; first_offer_bdt: number }>) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.bulkUpdateOrderItems(
          payload.map((item) => ({
            id: item.id,
            first_offer_bdt: item.first_offer_bdt,
          })),
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to update first offer prices.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedRows = result.data ?? []
        if (this.selected && updatedRows.length) {
          const updatedMap = new Map(updatedRows.map((row) => [row.id, row]))
          this.selected.order_items = this.selected.order_items.map((row) =>
            updatedMap.get(row.id) ?? row,
          )
        }

        showSuccessNotification('First offer prices updated successfully.')
        return { success: true as const }
      } finally {
        this.saving = false
      }
    },

    async updateOrderItemsWeights(
      payload: Array<{
        id: number
        product_weight?: number | null
        package_weight?: number | null
      }>,
    ) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.bulkUpdateOrderItems(
          payload.map((item) => ({
            id: item.id,
            product_weight: item.product_weight ?? null,
            package_weight: item.package_weight ?? null,
          })),
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to update item weights.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedRows = result.data ?? []
        if (this.selected && updatedRows.length) {
          const updatedMap = new Map(updatedRows.map((row) => [row.id, row]))
          this.selected.order_items = this.selected.order_items.map((row) =>
            updatedMap.get(row.id) ?? row,
          )
        }

        showSuccessNotification('Item weights updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async bulkUpdateOrderItems(payload: OrderItemBulkUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await orderService.bulkUpdateOrderItems(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to bulk update order items.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedRows = result.data ?? []
        if (this.selected && updatedRows.length) {
          const updatedMap = new Map(updatedRows.map((row) => [row.id, row]))
          this.selected.order_items = this.selected.order_items.map((row) =>
            updatedMap.get(row.id) ?? row,
          )
        }

        showSuccessNotification('Order items updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async placeOrderFromCart(payload: {
      tenant_id: number
      store_id?: number | null
      customer_group_id: number
      customer_group_name: string
      accent_color?: string | null
      can_see_price?: boolean
      items: Array<{
        product_id?: number | null
        name: string
        image_url?: string | null
        price_gbp?: number | null
        quantity: number
        minimum_quantity?: number | null
      }>
    }) {
      this.saving = true
      this.error = null

      try {
        const items = payload.items ?? []
        if (!items.length) {
          const result = { success: false as const, error: 'Cart has no items.' }
          this.error = result.error
          handleApiFailure(result, result.error)
          return result
        }

        const createOrderResult = await orderService.createOrder({
          name: payload.customer_group_name,
          customer_group_id: payload.customer_group_id,
          can_see_price: Boolean(payload.can_see_price),
          accent_color: payload.accent_color ?? null,
          cargo_rate: null,
          conversion_rate: null,
          profit_rate: null,
          negotiate: false,
          status: 'customer_submit',
          store_id: payload.store_id ?? null,
        })

        if (!createOrderResult.success || !createOrderResult.data) {
          this.error = createOrderResult.error ?? 'Failed to create order.'
          handleApiFailure(createOrderResult, this.error)
          return createOrderResult
        }

        const order = createOrderResult.data

        const createItemsResult = await orderService.createOrderItems(
          items.map((item) => {
            return {
              order_id: order.id,
              name: item.name,
              image_url: item.image_url ?? null,
              barcode: null,
              product_code: null,
              price_gbp: item.price_gbp ?? null,
              cost_gbp: null,
              cost_bdt: null,
              first_offer_bdt: null,
              customer_offer_bdt: null,
              final_offer_bdt: null,
              product_weight: null,
              package_weight: null,
              minimum_quantity: Math.max(1, Number(item.minimum_quantity ?? 1) || 1),
              product_id: item.product_id ?? null,
              ordered_quantity: Math.max(0, Number(item.quantity) || 0),
              delivered_quantity: 0,
              returned_quantity: 0,
            }
          }),
        )

        if (!createItemsResult.success) {
          this.error = createItemsResult.error ?? 'Failed to create order items.'
          handleApiFailure(createItemsResult, this.error)
          return createItemsResult
        }

        showSuccessNotification('Order placed successfully.')
        return { success: true as const, data: order }
      } finally {
        this.saving = false
      }
    },
  },
})
