import { defineStore } from 'pinia'

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { orderService } from '../services/orderService'
import type {
  Order,
  OrderDeleteInput,
  OrderGetByIdInput,
  OrderItem,
  OrderItemBulkUpdateInput,
  OrderItemDeleteInput,
  OrderItemUpdateInput,
  OrderListInput,
  OrderServiceResult,
  OrderStoreState,
  OrderUpdateInput,
} from '../types'

const ceil2 = (n: number) => Math.ceil(n * 100) / 100
const ceilInt = (n: number) => Math.ceil(n)
const roundUpTo5 = (n: number) => Math.ceil(n / 5) * 5

const toNumberSafe = (value: unknown) => {
  const parsed = Number(value ?? 0)
  return Number.isFinite(parsed) ? parsed : 0
}

const hasOwn = (obj: object, key: string) => Object.prototype.hasOwnProperty.call(obj, key)

const buildExpandedOrderItemPatch = (
  base: OrderItem,
  patch: Partial<Omit<OrderItem, 'id' | 'order_id' | 'created_at' | 'updated_at'>>,
  context: {
    cargoRate: number
    conversionRate: number
    profitRate: number
    negotiateEnabled: boolean
  },
) => {
  const mergedPriceGbp = patch.price_gbp ?? base.price_gbp ?? null
  const mergedProductWeight = patch.product_weight ?? base.product_weight ?? null
  const mergedPackageWeight = patch.package_weight ?? base.package_weight ?? null
  const mergedOrderedQuantity = patch.ordered_quantity ?? base.ordered_quantity

  const totalWeight = toNumberSafe(mergedProductWeight) + toNumberSafe(mergedPackageWeight)
  const pricingDriversChanged =
    hasOwn(patch, 'price_gbp') || hasOwn(patch, 'product_weight') || hasOwn(patch, 'package_weight')
  const manualFirstOfferProvided = hasOwn(patch, 'first_offer_bdt')
  const recalculatedCostGbp = ceil2(
    (totalWeight / 1000) * context.cargoRate + toNumberSafe(mergedPriceGbp),
  )
  const recalculatedCostBdt = ceilInt(recalculatedCostGbp * context.conversionRate)
  const autoFirstOffer = roundUpTo5((recalculatedCostBdt * context.profitRate) / 100 + recalculatedCostBdt)
  const mergedCostGbp =
    pricingDriversChanged
      ? recalculatedCostGbp
      : (patch.cost_gbp ?? base.cost_gbp ?? null)
  const mergedCostBdt =
    pricingDriversChanged
      ? recalculatedCostBdt
      : (patch.cost_bdt ?? base.cost_bdt ?? null)

  const mergedFirstOffer =
    manualFirstOfferProvided
      ? patch.first_offer_bdt ?? autoFirstOffer
      : pricingDriversChanged
        ? autoFirstOffer
        : (base.first_offer_bdt ?? autoFirstOffer)

  const mergedCustomerOffer =
    context.negotiateEnabled
      ? (patch.customer_offer_bdt ?? base.customer_offer_bdt ?? null)
      : mergedFirstOffer
  const mergedFinalOffer =
    context.negotiateEnabled
      ? (patch.final_offer_bdt ?? base.final_offer_bdt ?? null)
      : mergedFirstOffer

  return {
    ordered_quantity: mergedOrderedQuantity,
    price_gbp: mergedPriceGbp,
    product_weight: mergedProductWeight,
    package_weight: mergedPackageWeight,
    cost_gbp: mergedCostGbp,
    cost_bdt: mergedCostBdt,
    first_offer_bdt: mergedFirstOffer,
    customer_offer_bdt: mergedCustomerOffer,
    final_offer_bdt: mergedFinalOffer,
  }
}

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
        const selectedItem = this.selected?.order_items.find((item) => item.id === payload.id)
        const context = {
          cargoRate: toNumberSafe(this.selected?.cargo_rate),
          conversionRate: toNumberSafe(this.selected?.conversion_rate),
          profitRate: toNumberSafe(this.selected?.profit_rate),
          negotiateEnabled: this.selected?.negotiate !== false,
        }
        const expandedPayload =
          selectedItem == null
            ? payload
            : {
                id: payload.id,
                patch: buildExpandedOrderItemPatch(selectedItem, payload.patch, context),
              }

        const result = await orderService.updateOrderItem(expandedPayload)

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

    async updateOrderItemRaw(payload: OrderItemUpdateInput) {
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
        const orderItemsById = new Map((this.selected?.order_items ?? []).map((item) => [item.id, item]))
        const context = {
          cargoRate: toNumberSafe(this.selected?.cargo_rate),
          conversionRate: toNumberSafe(this.selected?.conversion_rate),
          profitRate: toNumberSafe(this.selected?.profit_rate),
          negotiateEnabled: this.selected?.negotiate !== false,
        }
        const expandedPayload = payload.map((entry) => {
          const base = orderItemsById.get(entry.id)
          if (!base) {
            return entry
          }

          const { id, ...patch } = entry
          return {
            id,
            ...buildExpandedOrderItemPatch(base, patch, context),
          }
        })

        const result = await orderService.bulkUpdateOrderItems(expandedPayload)

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

    async bulkUpdateOrderItemsRaw(payload: OrderItemBulkUpdateInput) {
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
        barcode?: string | null
        product_code?: string | null
        product_weight?: number | null
        package_weight?: number | null
        quantity: number
        minimum_quantity?: number | null
      }>
    }): Promise<OrderServiceResult<Order>> {
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
          invoice_id: null,
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
        const productIds = items
          .map((item) => item.product_id)
          .filter((id): id is number => typeof id === 'number')
        const productSnapshotResult = await orderService.getOrderProductSnapshots(productIds)
        const productSnapshotMap = new Map(
          (productSnapshotResult.data ?? []).map((row) => [row.id, row]),
        )

        const createItemsResult = await orderService.createOrderItems(
          items.map((item) => {
            const productSnapshot =
              item.product_id != null ? productSnapshotMap.get(item.product_id) : null

            return {
              order_id: order.id,
              shipment_id: null,
              name: item.name,
              image_url: item.image_url ?? null,
              barcode: item.barcode ?? productSnapshot?.barcode ?? null,
              product_code: item.product_code ?? productSnapshot?.product_code ?? null,
              price_gbp: item.price_gbp ?? null,
              cost_gbp: null,
              cost_bdt: null,
              first_offer_bdt: null,
              customer_offer_bdt: null,
              final_offer_bdt: null,
              product_weight: item.product_weight ?? productSnapshot?.product_weight ?? null,
              package_weight: item.package_weight ?? productSnapshot?.package_weight ?? null,
              minimum_quantity: Math.max(1, Number(item.minimum_quantity ?? 1) || 1),
              product_id: item.product_id ?? null,
              ordered_quantity: Math.max(0, Number(item.quantity) || 0),
              delivered_quantity: 0,
              returned_quantity: 0,
            }
          }),
        )

        if (!createItemsResult.success) {
          const error = createItemsResult.error ?? 'Failed to create order items.'
          this.error = error
          handleApiFailure(createItemsResult, this.error)
          return { success: false, error }
        }

        showSuccessNotification('Order submitted successfully.')
        return { success: true as const, data: order }
      } finally {
        this.saving = false
      }
    },
  },
})
