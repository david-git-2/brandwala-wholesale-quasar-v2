import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { shopOrderService } from '../services/shopOrderService'
import type { Shop, ShopOrder, ShopOrderItem } from '../types'

export interface ShopOrderState {
  orders: ShopOrder[]
  currentOrder: ShopOrder | null
  currentOrderItems: ShopOrderItem[]
  loading: boolean
  saving: boolean
  error: string | null
  shops: Shop[]
  loadingShops: boolean
}

export const useShopOrderStore = defineStore('shopOrder', {
  state: (): ShopOrderState => ({
    orders: [],
    currentOrder: null,
    currentOrderItems: [],
    loading: false,
    saving: false,
    error: null,
    shops: [],
    loadingShops: false,
  }),

  actions: {
    clearCurrentOrder() {
      this.currentOrder = null
      this.currentOrderItems = []
      this.error = null
    },

    async submitOrder(
      cartId: number,
      recipientName: string,
      recipientPhone: string,
      shippingAddress: string,
      billingProfileId: number | null,
    ) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.submitOrder(
          cartId,
          recipientName,
          recipientPhone,
          shippingAddress,
          billingProfileId,
        )
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification(`Order ${res.data.order_no} created successfully.`)
        return res
      } finally {
        this.saving = false
      }
    },

    async fetchOrderDetails(orderId: number) {
      this.loading = true
      this.error = null
      try {
        const res = await shopOrderService.getOrderDetails(orderId)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        this.currentOrder = res.data.order
        this.currentOrderItems = res.data.items
        return res
      } finally {
        this.loading = false
      }
    },

    async fetchCustomerOrders(shopId: number, opts?: { limit?: number; offset?: number }) {
      this.loading = true
      this.error = null
      try {
        const res = await shopOrderService.fetchCustomerOrders(shopId, opts)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        this.orders = res.data
        return res
      } finally {
        this.loading = false
      }
    },

    async fetchStaffOrders(
      tenantId: number,
      opts?: { limit?: number; offset?: number; search?: string | null; status?: string | null },
    ) {
      this.loading = true
      this.error = null
      try {
        const res = await shopOrderService.fetchStaffOrders(tenantId, opts)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        this.orders = res.data
        return res
      } finally {
        this.loading = false
      }
    },

    async priceOrder(
      orderId: number,
      items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
    ) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.staffPriceOrder(orderId, items)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification('Pricing saved successfully.')
        await this.fetchOrderDetails(orderId)
        return res
      } finally {
        this.saving = false
      }
    },

    async sendCustomerCounter(
      orderId: number,
      items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>,
    ) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.customerCounter(orderId, items)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification('Counter offer sent successfully.')
        await this.fetchOrderDetails(orderId)
        return res
      } finally {
        this.saving = false
      }
    },

    async sendStaffCounter(
      orderId: number,
      items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
    ) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.staffCounter(orderId, items)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification('Counter offer sent successfully.')
        await this.fetchOrderDetails(orderId)
        return res
      } finally {
        this.saving = false
      }
    },

    async confirmOrder(orderId: number) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.confirmOrder(orderId)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification('Order confirmed successfully.')
        await this.fetchOrderDetails(orderId)
        return res
      } finally {
        this.saving = false
      }
    },

    async placeOrderForProcurement(orderId: number) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.placeOrderForProcurement(orderId)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification('Order placed for procurement successfully.')
        await this.fetchOrderDetails(orderId)
        return res
      } finally {
        this.saving = false
      }
    },

    async fulfillOrderToInvoice(orderId: number) {
      this.saving = true
      this.error = null
      try {
        const res = await shopOrderService.fulfillOrderToInvoice(orderId)
        if (!res.success) {
          this.error = res.error
          handleApiFailure(res, res.error)
          return res
        }
        showSuccessNotification('Order fulfilled to invoice successfully.')
        await this.fetchOrderDetails(orderId)
        return res
      } finally {
        this.saving = false
      }
    },

    async fetchShopsByTenant(tenantId: number, opts: { active?: boolean | null; search?: string | null } = {}) {
      this.loadingShops = true
      this.error = null
      try {
        const { shopOrderRepository } = await import('../repositories/shopOrderRepository')
        const data = await shopOrderRepository.listShops(tenantId, opts)
        this.shops = data
        return { success: true, data }
      } catch (err: any) {
        this.error = err.message
        return { success: false, error: err.message }
      } finally {
        this.loadingShops = false
      }
    },

    async createShop(payload: any) {
      this.saving = true
      this.error = null
      try {
        const { shopOrderRepository } = await import('../repositories/shopOrderRepository')
        const data = await shopOrderRepository.upsertShop(payload)
        this.shops.push(data)
        showSuccessNotification('Shop created successfully.')
        return { success: true, data }
      } catch (err: any) {
        this.error = err.message
        return { success: false, error: err.message }
      } finally {
        this.saving = false
      }
    },

    async updateShop(payload: any) {
      this.saving = true
      this.error = null
      try {
        const { shopOrderRepository } = await import('../repositories/shopOrderRepository')
        const data = await shopOrderRepository.upsertShop(payload)
        const idx = this.shops.findIndex((s) => s.id === data.id)
        if (idx !== -1) {
          this.shops[idx] = data
        }
        showSuccessNotification('Shop updated successfully.')
        return { success: true, data }
      } catch (err: any) {
        this.error = err.message
        return { success: false, error: err.message }
      } finally {
        this.saving = false
      }
    },

    clearError() {
      this.error = null
    },
  },
})
