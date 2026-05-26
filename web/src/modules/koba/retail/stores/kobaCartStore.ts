import { defineStore } from 'pinia'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'

import { kobaCartService } from '../services/kobaCartService'
import { kobaOrderService } from '../services/kobaOrderService'

import type {
  KobaCart,
  KobaCartItem,
} from '../repositories/kobaCartRepository'

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

  getters: {
    itemCount: (state) =>
      state.items.reduce((sum, item) => sum + item.quantity, 0),

    subtotal: (state) =>
      state.items.reduce(
        (sum, item) =>
          sum + (Number(item.unit_price_gbp || 0) * item.quantity),
        0
      ),
  },

  actions: {
    async fetchCart() {
      const authStore = useAuthStore()

      const tenantId = authStore.tenantId ?? KOBA_TENANT_ID

      const customerGroupId =
        authStore.customerGroupId != null
          ? Number(authStore.customerGroupId)
          : null

      this.loading = true
      this.error = null

      try {
        const result = await kobaCartService.getCart(
          tenantId,
          customerGroupId
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to load Koba cart.'
          handleApiFailure(result, this.error)
          return result
        }

        this.cart = result.data?.cart ?? null
        this.items = result.data?.items ?? []

        return result
      } finally {
        this.loading = false
      }
    },

    async addToCart(
      product: KobaCartProductInput,
      quantity: number
    ) {
      const authStore = useAuthStore()

      const tenantId = authStore.tenantId ?? KOBA_TENANT_ID

      const customerGroupId =
        authStore.customerGroupId != null
          ? Number(authStore.customerGroupId)
          : null

      if (!customerGroupId) {
        this.error = 'Customer group is required.'
        return {
          success: false,
          error: this.error,
        }
      }

      this.saving = true
      this.error = null

      try {
        // Resolve or create cart
        const cartResult =
          await kobaCartService.getOrCreateCart(
            tenantId,
            customerGroupId
          )

        if (!cartResult.success || !cartResult.data) {
          this.error =
            cartResult.error ?? 'Failed to load cart.'

          handleApiFailure(cartResult, this.error)

          return cartResult
        }

        this.cart = cartResult.data.cart

        // Check if item already exists
        const existingItem = this.items.find(
          (item) => item.product_id === product.id
        )

        if (existingItem) {
          return await this.updateItemQty(
            existingItem.id,
            existingItem.quantity + quantity
          )
        }

        const itemPayload: Partial<KobaCartItem> = {
          cart_id: this.cart.id,

          koba_product_id: product.id,

          product_id: product.id,

          product_code: product.sku || null,

          barcode: product.barcode || null,

          name: product.name,

          brand: product.brand || null,

          image_url: product.image_url || null,

          case_size: product.case_size ?? 1,

          unit_price_gbp:
            product.price_gbp ??
            product.price ??
            0,

          commission:
            product.commission ?? 0,

          commission_percentage:
            product.commission_percentage ?? 0,

          quantity,
        }

        const result =
          await kobaCartService.createCartItem(
            itemPayload
          )

        if (!result.success || !result.data) {
          this.error =
            result.error ??
            'Failed to add item to cart.'

          handleApiFailure(result, this.error)

          return result
        }

        this.items.push(result.data)

        showSuccessNotification(
          'Item added to Koba cart.'
        )

        return result
      } finally {
        this.saving = false
      }
    },

    async updateItemQty(
      itemId: number,
      quantity: number
    ) {
      this.saving = true
      this.error = null

      try {
        if (quantity <= 0) {
          return await this.removeItem(itemId)
        }

        const result =
          await kobaCartService.updateCartItem(
            itemId,
            { quantity }
          )

        if (!result.success || !result.data) {
          this.error =
            result.error ??
            'Failed to update item quantity.'

          handleApiFailure(result, this.error)

          return result
        }

        const index = this.items.findIndex(
          (item) => item.id === itemId
        )

        if (index >= 0) {
          this.items.splice(index, 1, result.data)
        }

        showSuccessNotification(
          'Cart quantity updated.'
        )

        return result
      } finally {
        this.saving = false
      }
    },

    async removeItem(itemId: number) {
      this.saving = true
      this.error = null

      try {
        const result =
          await kobaCartService.deleteCartItem(
            itemId
          )

        if (!result.success) {
          this.error =
            result.error ??
            'Failed to remove item.'

          handleApiFailure(result, this.error)

          return result
        }

        this.items = this.items.filter(
          (item) => item.id !== itemId
        )

        showSuccessNotification(
          'Item removed from cart.'
        )

        return result
      } finally {
        this.saving = false
      }
    },

    async clearCart() {
      if (!this.cart) {
        return { success: true }
      }

      this.saving = true
      this.error = null

      try {
        const result =
          await kobaCartService.clearCartItems(
            this.cart.id
          )

        if (!result.success) {
          this.error =
            result.error ??
            'Failed to clear cart.'

          handleApiFailure(result, this.error)

          return result
        }

        this.items = []

        showSuccessNotification(
          'Cart cleared.'
        )

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
      extra_profit_user?: number
      extra_profit_company?: number
      delivery_adjustment?: number
      cod_charge?: number
      packing_charge?: number
      invoice_charge?: number
      net_order_commission?: number
    }) {
      const authStore = useAuthStore()

      const tenantId =
        authStore.tenantId ?? KOBA_TENANT_ID

      const customerGroupId =
        authStore.customerGroupId != null
          ? Number(authStore.customerGroupId)
          : null

      this.saving = true
      this.error = null

      try {
        const result =
          await kobaOrderService.placeOrder({
            tenant_id: tenantId,

            customer_group_id:
              customerGroupId,

            shipping_name:
              shipping.name,

            shipping_phone:
              shipping.phone,

            shipping_district:
              shipping.district,

            shipping_thana:
              shipping.thana,

            shipping_address:
              shipping.address,

            free_delivery:
              shipping.free_delivery,

            extra_profit_user: shipping.extra_profit_user,
            extra_profit_company: shipping.extra_profit_company,
            delivery_adjustment: shipping.delivery_adjustment,
            cod_charge: shipping.cod_charge,
            packing_charge: shipping.packing_charge,
            invoice_charge: shipping.invoice_charge,
            net_order_commission: shipping.net_order_commission,
          })

        if (!result.success || !result.data) {
          this.error =
            result.error ??
            'Failed to place order.'

          handleApiFailure(result, this.error)

          return result
        }

        this.cart = null
        this.items = []

        showSuccessNotification(
          'Koba order placed successfully!'
        )

        return result
      } finally {
        this.saving = false
      }
    },
  },
})