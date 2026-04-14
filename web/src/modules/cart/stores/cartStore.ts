import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { cartService } from '../services/cartService'
import type {
  AddItemToCartInput,
  CartCreateInput,
  CartDeleteInput,
  CartItemCreateInput,
  CartItemDeleteInput,
  CartItemUpdateInput,
  CartStoreState,
  CartUpdateInput,
} from '../types'

export const useCartStore = defineStore('cart', {
  state: (): CartStoreState => ({
    carts: [],
    items: [],
    cartSnapshot: null,
    cartDetails: null,
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchCarts() {
      this.loading = true
      this.error = null

      try {
        const result = await cartService.listCarts()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load carts.'
          handleApiFailure(result, this.error)
          return result
        }

        this.carts = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createCart(payload: CartCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await cartService.createCart(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create cart.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.carts.push(result.data)
        }

        showSuccessNotification('Cart created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateCart(payload: CartUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await cartService.updateCart(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update cart.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.carts.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.carts.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Cart updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteCart(payload: CartDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await cartService.deleteCart(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete cart.'
          handleApiFailure(result, this.error)
          return result
        }

        this.carts = this.carts.filter((item) => item.id !== payload.id)
        showSuccessNotification('Cart deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchCartItems(cartId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await cartService.listCartItems(cartId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load cart items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createCartItem(payload: CartItemCreateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await cartService.createCartItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create cart item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.push(result.data)
        }

        showSuccessNotification('Cart item created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateCartItem(payload: CartItemUpdateInput) {
      this.saving = true
      this.error = null

      try {
        const result = await cartService.updateCartItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update cart item.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((item) => item.id === result.data?.id)

          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Cart item updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteCartItem(payload: CartItemDeleteInput) {
      this.saving = true
      this.error = null

      try {
        const result = await cartService.deleteCartItem(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete cart item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        showSuccessNotification('Cart item deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async clearCartItems(itemIds: number[]) {
      this.saving = true
      this.error = null

      try {
        for (const id of itemIds) {
          const result = await cartService.deleteCartItem({ id })

          if (!result.success) {
            this.error = result.error ?? 'Failed to clear cart items.'
            handleApiFailure(result, this.error)
            return result
          }
        }

        const idSet = new Set(itemIds)
        this.items = this.items.filter((item) => !idSet.has(item.id))
        showSuccessNotification('Cart cleared successfully.')
        return { success: true as const }
      } finally {
        this.saving = false
      }
    },

    async fetchCart(cartId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await cartService.getCart(cartId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load cart.'
          handleApiFailure(result, this.error)
          return result
        }

        this.cartSnapshot = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchCartDetails(cartId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await cartService.getCartDetails(cartId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load cart details.'
          handleApiFailure(result, this.error)
          return result
        }

        this.cartDetails = result.data ?? null
        return result
      } finally {
        this.loading = false
      }
    },

    async addItemToCart(payload: AddItemToCartInput) {
      this.saving = true
      this.error = null

      try {
        const quantity = Math.max(1, Math.floor(payload.quantity))
        const minimumQuantity = Math.max(1, Math.floor(payload.minimum_quantity ?? 1))
        const result = await cartService.addItemToCart({
          ...payload,
          quantity,
          minimum_quantity: minimumQuantity,
        })

        if (!result.success) {
          this.error = result.error ?? 'Failed to add item to cart.'
          handleApiFailure(result, this.error)
          return result
        }

        const cart = result.data?.cart
        const item = result.data?.item

        if (cart) {
          const cartIndex = this.carts.findIndex((entry) => entry.id === cart.id)
          if (cartIndex >= 0) {
            this.carts.splice(cartIndex, 1, cart)
          } else {
            this.carts.push(cart)
          }
        }

        if (item) {
          const itemIndex = this.items.findIndex((entry) => entry.id === item.id)
          if (itemIndex >= 0) {
            this.items.splice(itemIndex, 1, item)
          } else {
            this.items.push(item)
          }
        }

        showSuccessNotification('Added to cart.')
        return result
      } finally {
        this.saving = false
      }
    },

    async fetchItemsForContext(payload: {
      tenant_id: number
      store_id?: number | null
      customer_group_id?: number | null
    }) {
      this.loading = true
      this.error = null

      try {
        const cartResult = await cartService.findCart(payload)

        if (!cartResult.success) {
          this.error = cartResult.error ?? 'Failed to find cart.'
          handleApiFailure(cartResult, this.error)
          return cartResult
        }

        const cart = cartResult.data ?? null
        if (!cart) {
          this.items = []
          return { success: true, data: [] as typeof this.items }
        }

        const itemsResult = await cartService.listCartItems(cart.id)
        if (!itemsResult.success) {
          this.error = itemsResult.error ?? 'Failed to load cart items.'
          handleApiFailure(itemsResult, this.error)
          return itemsResult
        }

        this.items = itemsResult.data ?? []
        return itemsResult
      } finally {
        this.loading = false
      }
    },
  },
})
