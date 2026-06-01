import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { commerceCartService } from '../services/commerceCartService'
import type { AddCommerceItemInput, CommerceCartStoreState } from '../types'

export const useCommerceCartStore = defineStore('commerceCart', {
  state: (): CommerceCartStoreState => ({
    items: [],
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchItemsForContext(payload: {
      tenant_id: number
      store_id?: number | null
      customer_group_id?: number | null
    }) {
      if (!payload.customer_group_id) {
        this.items = []
        return { success: true, data: [] }
      }

      this.loading = true
      this.error = null

      try {
        const result = await commerceCartService.listCartItems(
          payload.tenant_id,
          payload.customer_group_id,
          payload.store_id ?? null,
        )

        if (!result.success) {
          this.error = result.error ?? 'Failed to load commerce cart items.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async addItemToCart(payload: {
      tenant_id: number
      store_id: number | null
      customer_group_id: number | null
      product_id: number
      quantity: number
      minimum_quantity?: number
    }) {
      if (!payload.customer_group_id) {
        showSuccessNotification('Unable to add item: customer group not found.')
        return { success: false, error: 'Customer group required' }
      }

      this.saving = true
      this.error = null

      try {
        const input: AddCommerceItemInput = {
          tenant_id: payload.tenant_id,
          store_id: payload.store_id,
          customer_group_id: payload.customer_group_id,
          product_id: payload.product_id,
          quantity: payload.quantity,
        }
        if (payload.minimum_quantity !== undefined) {
          input.minimum_quantity = payload.minimum_quantity
        }
        const result = await commerceCartService.addToCommerceCart(input)

        if (!result.success) {
          this.error = result.error ?? 'Failed to add item to commerce cart.'
          handleApiFailure(result, this.error)
          return result
        }

        const addedItem = result.data
        if (addedItem) {
          const index = this.items.findIndex((item) => item.product_id === addedItem.product_id)
          if (index >= 0) {
            this.items.splice(index, 1, addedItem)
          } else {
            this.items.push(addedItem)
          }
        }

        showSuccessNotification('Added to commerce cart.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateCartItem(payload: { id: number; quantity: number }) {
      this.saving = true
      this.error = null

      try {
        const result = await commerceCartService.updateCommerceCartQty({
          id: payload.id,
          quantity: payload.quantity,
        })

        if (!result.success) {
          this.error = result.error ?? 'Failed to update item quantity.'
          handleApiFailure(result, this.error)
          return result
        }

        const data = result.data
        if (data) {
          const item = this.items.find((x) => x.id === data.id)
          if (item) {
            item.quantity = data.quantity
          }
        }

        showSuccessNotification('Commerce cart quantity updated.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteCartItem(payload: { id: number }) {
      this.saving = true
      this.error = null

      try {
        const result = await commerceCartService.deleteCommerceCartItem({ id: payload.id })

        if (!result.success) {
          this.error = result.error ?? 'Failed to remove cart item.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((item) => item.id !== payload.id)
        showSuccessNotification('Removed from commerce cart.')
        return result
      } finally {
        this.saving = false
      }
    },

    async clearCartItems(tenantId: number, customerGroupId: number) {
      this.saving = true
      this.error = null

      try {
        const result = await commerceCartService.clearCommerceCart({
          tenant_id: tenantId,
          customer_group_id: customerGroupId,
        })

        if (!result.success) {
          this.error = result.error ?? 'Failed to clear commerce cart.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = []
        showSuccessNotification('Commerce cart cleared.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
