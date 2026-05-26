import { defineStore } from 'pinia'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { kobaCartService } from '../services/kobaCartService'
import { kobaOrderService } from '../services/kobaOrderService'
import type { KobaCart, KobaCartItem } from '../repositories/kobaCartRepository'

export interface KobaCartProductInput {
  id: string
  sku?: string | null
  barcode?: string | null
  name: string
  brand?: string | null
  image_url?: string | null
  case_size?: number | null
  price_gbp?: number | null
  price?: number | null
  commission?: number | null
  commission_percentage?: number | null
}

export interface KobaCartState {
  cart: KobaCart | null
  items: KobaCartItem[]
  loading: boolean
  saving: boolean
  error: string | null
}

const KOBA_TENANT_ID = 12

export const useKobaCartStore = defineStore('kobaCart', {
  state: (): KobaCartState => ({
    cart: null,
    items: [],
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    async fetchCart() {
      const authStore = useAuthStore()
      const tenantId = authStore.tenantId ?? KOBA_TENANT_ID
      const marketId = null // default marketId for Koba

      this.loading = true
      this.error = null

      try {
        const result = await kobaCartService.getCart(tenantId, marketId)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load Koba cart.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.cart = result.data.cart
          this.items = result.data.items
        } else {
          this.cart = null
          this.items = []
        }
        return result
      } finally {
        this.loading = false
      }
    },

    async addToCart(product: KobaCartProductInput, quantity: number) {
      const authStore = useAuthStore()
      const tenantId = authStore.tenantId ?? KOBA_TENANT_ID
      const userEmail = authStore.user?.email
      const marketId = null

      if (!userEmail) {
        this.error = 'User email is required to add items to cart.'
        return { success: false, error: this.error }
      }

      this.saving = true
      this.error = null

      try {
        // 1. Resolve or create cart
        let activeCart = this.cart
        if (!activeCart) {
          const cartResult = await kobaCartService.createCart(tenantId, userEmail, marketId)
          if (!cartResult.success || !cartResult.data) {
            this.error = cartResult.error ?? 'Failed to create active cart.'
            handleApiFailure(cartResult, this.error)
            return cartResult
          }
          activeCart = cartResult.data
          this.cart = activeCart
        }

        // 2. Insert cart item
        const itemPayload: Partial<KobaCartItem> = {
          cart_id: activeCart.id,
          koba_product_id: product.id,
          product_id: product.id, // unique key for this product in cart
          product_code: product.sku || null,
          barcode: product.barcode || null,
          name: product.name,
          brand: product.brand || null,
          image_url: product.image_url || null,
          case_size: product.case_size ?? 1,
          unit_price_gbp: product.price_gbp ?? product.price ?? 0,
          commission: product.commission ?? 0,
          commission_percentage: product.commission_percentage ?? 0,
          quantity,
        }

        const result = await kobaCartService.createCartItem(itemPayload)
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to add item to cart.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items.push(result.data)
        showSuccessNotification('Item added to Koba cart.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateItemQty(itemId: number, quantity: number) {
      this.saving = true
      this.error = null

      try {
        const result = await kobaCartService.updateCartItem(itemId, { quantity })
        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to update item quantity.'
          handleApiFailure(result, this.error)
          return result
        }

        const index = this.items.findIndex((item) => item.id === itemId)
        if (index >= 0) {
          this.items.splice(index, 1, result.data)
        }

        showSuccessNotification('Cart quantity updated.')
        return result
      } finally {
        this.saving = false
      }
    },

    async removeItem(itemId: number) {
      this.saving = true
      this.error = null

      try {
        const result = await kobaCartService.deleteCartItem(itemId)
        if (!result.success) {
          this.error = result.error ?? 'Failed to remove item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== itemId)
        showSuccessNotification('Item removed from cart.')
        return result
      } finally {
        this.saving = false
      }
    },

    async clearCart() {
      if (!this.cart) return { success: true }
      this.saving = true
      this.error = null

      try {
        const result = await kobaCartService.clearCartItems(this.cart.id)
        if (!result.success) {
          this.error = result.error ?? 'Failed to clear cart.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = []
        showSuccessNotification('Cart cleared.')
        return result
      } finally {
        this.saving = false
      }
    },

    async checkout(shipping: {
      name: string
      phone: string
      district: string
      thana: string
      address: string
      free_delivery: boolean
    }) {
      const authStore = useAuthStore()
      const tenantId = authStore.tenantId ?? KOBA_TENANT_ID
      const marketId = null

      this.saving = true
      this.error = null

      try {
        const result = await kobaOrderService.placeOrder({
          tenant_id: tenantId,
          market_id: marketId,
          shipping_name: shipping.name,
          shipping_phone: shipping.phone,
          shipping_district: shipping.district,
          shipping_thana: shipping.thana,
          shipping_address: shipping.address,
          free_delivery: shipping.free_delivery,
        })

        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to place order.'
          handleApiFailure(result, this.error)
          return result
        }

        this.cart = null
        this.items = []
        showSuccessNotification('Koba order placed successfully!')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
