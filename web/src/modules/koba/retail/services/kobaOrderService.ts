import { kobaOrderRepository } from '../repositories/kobaOrderRepository'
import type {
  KobaOrder,
  KobaOrderItem,
  KobaOrderListPage,
  KobaOrderStatus,
  PlaceOrderInput,
  PlaceOrderResult,
} from '../repositories/kobaOrderRepository'

export interface KobaOrderServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}

const placeOrder = async (
  payload: PlaceOrderInput
): Promise<KobaOrderServiceResult<PlaceOrderResult>> => {
  try {
    const data = await kobaOrderRepository.placeOrder(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to place Koba order.',
    }
  }
}

const listOrders = async (
  tenantId: number,
  customerGroupId: number | null = null,
  page: number = 1,
  pageSize: number = 20,
  status: KobaOrderStatus | null = null
): Promise<KobaOrderServiceResult<KobaOrderListPage>> => {
  try {
    const data = await kobaOrderRepository.listOrders(
      tenantId,
      customerGroupId,
      page,
      pageSize,
      status
    )

    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load Koba orders.',
    }
  }
}

const getOrderWithItems = async (
  orderId: number
): Promise<
  KobaOrderServiceResult<{
    order: KobaOrder
    items: KobaOrderItem[]
  }>
> => {
  try {
    const [order, items] = await Promise.all([
      kobaOrderRepository.getOrderById(orderId),
      kobaOrderRepository.getOrderItems(orderId),
    ])

    return {
      success: true,
      data: {
        order,
        items,
      },
    }
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to load Koba order details.',
    }
  }
}

export const kobaOrderService = {
  placeOrder,
  listOrders,
  getOrderWithItems,
}