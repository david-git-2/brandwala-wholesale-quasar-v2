import { orderRepository } from '../repositories/orderRepository'
import type {
  Order,
  OrderCreateInput,
  OrderDeleteInput,
  OrderGetByIdInput,
  OrderItem,
  OrderItemBulkUpdateInput,
  OrderItemCreateInput,
  OrderItemDeleteInput,
  OrderItemUpdateInput,
  OrderListPage,
  OrderListInput,
  OrderServiceResult,
  OrderUpdateInput,
  OrderWithItems,
} from '../types'

const listOrders = async (
  payload: OrderListInput = {},
): Promise<OrderServiceResult<OrderListPage>> => {
  try {
    const data = await orderRepository.listOrders(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load orders.',
    }
  }
}

const createOrder = async (
  payload: OrderCreateInput,
): Promise<OrderServiceResult<Order>> => {
  try {
    const data = await orderRepository.createOrder(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create order.',
    }
  }
}

const getOrderById = async (
  payload: OrderGetByIdInput,
): Promise<OrderServiceResult<OrderWithItems>> => {
  try {
    const data = await orderRepository.getOrderById(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load order.',
    }
  }
}

const updateOrder = async (
  payload: OrderUpdateInput,
): Promise<OrderServiceResult<Order>> => {
  try {
    const data = await orderRepository.updateOrder(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update order.',
    }
  }
}

const updateOrderItem = async (
  payload: OrderItemUpdateInput,
): Promise<OrderServiceResult<OrderItem>> => {
  try {
    const data = await orderRepository.updateOrderItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update order item.',
    }
  }
}

const createOrderItems = async (
  payload: OrderItemCreateInput[],
): Promise<OrderServiceResult<OrderItem[]>> => {
  try {
    const data = await orderRepository.createOrderItems(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create order items.',
    }
  }
}

const bulkUpdateOrderItems = async (
  payload: OrderItemBulkUpdateInput,
): Promise<OrderServiceResult<OrderItem[]>> => {
  try {
    const data = await orderRepository.bulkUpdateOrderItems(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error ? error.message : 'Failed to bulk update order items.',
    }
  }
}

const deleteOrder = async (
  payload: OrderDeleteInput,
): Promise<OrderServiceResult<void>> => {
  try {
    await orderRepository.deleteOrder(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete order.',
    }
  }
}

const deleteOrderItem = async (
  payload: OrderItemDeleteInput,
): Promise<OrderServiceResult<void>> => {
  try {
    await orderRepository.deleteOrderItem(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete order item.',
    }
  }
}

const clearInvoiceFromOrders = async (
  invoiceId: number,
): Promise<OrderServiceResult<void>> => {
  try {
    await orderRepository.clearInvoiceFromOrders(invoiceId)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to clear invoice from orders.',
    }
  }
}

const getOrderProductSnapshots = async (
  productIds: number[],
): Promise<
  OrderServiceResult<
    Array<{
      id: number
      barcode: string | null
      product_code: string | null
      product_weight: number | null
      package_weight: number | null
    }>
  >
> => {
  try {
    const data = await orderRepository.getOrderProductSnapshots(productIds)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load product snapshots.',
    }
  }
}

export const orderService = {
  listOrders,
  createOrder,
  getOrderById,
  updateOrder,
  createOrderItems,
  bulkUpdateOrderItems,
  updateOrderItem,
  deleteOrder,
  deleteOrderItem,
  clearInvoiceFromOrders,
  getOrderProductSnapshots,
}
