import { defineStore } from 'pinia'

import { supabase } from 'src/boot/supabase'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { cartService } from 'src/modules/cart/services/cartService'
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

    async placeOrderFromCart(payload: {
      tenant_id: number
      store_id?: number | null
      customer_group_id: number
      customer_group_name: string
      accent_color?: string | null
    }) {
      this.saving = true
      this.error = null

      try {
        const cartResult = await cartService.findCart({
          tenant_id: payload.tenant_id,
          store_id: payload.store_id ?? null,
          customer_group_id: payload.customer_group_id,
        })

        if (!cartResult.success) {
          this.error = cartResult.error ?? 'Failed to find cart.'
          handleApiFailure(cartResult, this.error)
          return cartResult
        }

        const cart = cartResult.data ?? null
        if (!cart) {
          const result = { success: false as const, error: 'Cart not found.' }
          this.error = result.error
          handleApiFailure(result, result.error)
          return result
        }

        const cartDetailsResult = await cartService.getCartDetails(cart.id)
        if (!cartDetailsResult.success) {
          this.error = cartDetailsResult.error ?? 'Failed to load cart details.'
          handleApiFailure(cartDetailsResult, this.error)
          return cartDetailsResult
        }

        const cartDetails = cartDetailsResult.data
        const items = cartDetails?.items ?? []

        if (!items.length) {
          const result = { success: false as const, error: 'Cart has no items.' }
          this.error = result.error
          handleApiFailure(result, result.error)
          return result
        }

        const { data: groupData } = await supabase
          .from('customer_groups')
          .select('name,accent_color')
          .eq('id', payload.customer_group_id)
          .maybeSingle()

        const customerGroupName =
          (groupData as { name?: string | null } | null)?.name?.trim() ||
          payload.customer_group_name
        const accentColor =
          (groupData as { accent_color?: string | null } | null)?.accent_color ??
          payload.accent_color ??
          null

        const createOrderResult = await orderService.createOrder({
          name: customerGroupName,
          customer_group_id: payload.customer_group_id,
          can_see_price: Boolean(cartDetails?.cart?.can_see_price),
          accent_color: accentColor,
          cargo_rate: null,
          conversion_rate: null,
          profit_rate: null,
          negotiate: false,
          status: 'customer_submit',
          store_id: payload.store_id ?? cartDetails?.cart?.store_id ?? null,
        })

        if (!createOrderResult.success || !createOrderResult.data) {
          this.error = createOrderResult.error ?? 'Failed to create order.'
          handleApiFailure(createOrderResult, this.error)
          return createOrderResult
        }

        const order = createOrderResult.data

        const createItemsResult = await orderService.createOrderItems(
          items.map((item) => ({
            order_id: order.id,
            name: item.name,
            image_url: item.image_url ?? null,
            price_gbp: item.price_gbp ?? null,
            cost_gbp: null,
            cost_bdt: null,
            first_offer_bdt: null,
            customer_offer_bdt: null,
            final_offer_bdt: null,
            product_weight: Number(
              (
                (item as Record<string, unknown>).product as
                  | { product_weight?: number | null }
                  | null
                  | undefined
              )?.product_weight ?? null,
            ) || null,
            package_weight: Number(
              (
                (item as Record<string, unknown>).product as
                  | { package_weight?: number | null }
                  | null
                  | undefined
              )?.package_weight ?? null,
            ) || null,
            minimum_quantity: item.minimum_quantity,
            product_id: item.product_id ?? null,
            ordered_quantity: item.quantity,
            delivered_quantity: 0,
            returned_quantity: 0,
          })),
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
