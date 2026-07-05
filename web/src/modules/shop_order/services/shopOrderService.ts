import { shopOrderRepository } from '../repositories/shopOrderRepository'
import type { ShopOrder, ShopOrderItem, ShopServiceResult } from '../types'

const submitOrder = async (
  cartId: number,
  recipientName: string,
  recipientPhone: string,
  shippingAddress: string,
  billingProfileId: number | null,
): Promise<ShopServiceResult<{ order_id: number; order_no: string; status: string }>> => {
  try {
    const data = await shopOrderRepository.submitShopOrderFromCart(
      cartId,
      recipientName,
      recipientPhone,
      shippingAddress,
      billingProfileId,
    )
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to submit order.',
    }
  }
}

const staffPriceOrder = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffPriceShopOrder(orderId, items)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to set pricing.',
    }
  }
}

const customerCounter = async (
  orderId: number,
  items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.customerCounterOffer(orderId, items)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place counter offer.',
    }
  }
}

const staffCounter = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffCounterOffer(orderId, items)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to counter offer.',
    }
  }
}

const confirmOrder = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.confirmShopOrder(orderId)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to confirm order.',
    }
  }
}

const getOrderDetails = async (orderId: number): Promise<ShopServiceResult<{ order: ShopOrder; items: ShopOrderItem[] }>> => {
  try {
    const data = await shopOrderRepository.getShopOrderById(orderId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch order details.',
    }
  }
}

const fetchCustomerOrders = async (
  shopId: number,
  opts?: { limit?: number; offset?: number },
): Promise<ShopServiceResult<ShopOrder[]>> => {
  try {
    const data = await shopOrderRepository.listShopOrdersForCustomer(shopId, opts)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list customer orders.',
    }
  }
}

const fetchStaffOrders = async (
  tenantId: number,
  opts?: { limit?: number; offset?: number; search?: string | null; status?: string | null },
): Promise<ShopServiceResult<ShopOrder[]>> => {
  try {
    const data = await shopOrderRepository.listShopOrdersForStaff(tenantId, opts)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list staff orders.',
    }
  }
}

const placeOrderForProcurement = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.placeShopOrderForProcurement(orderId)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place order for procurement.',
    }
  }
}

const fulfillOrderToInvoice = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.fulfillShopOrderToInvoice(orderId)
    return { success: true, data: undefined }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fulfill order to invoice.',
    }
  }
}

const browseShopCatalog = async (
  shopSlug: string,
  opts?: {
    search?: string | null
    category?: string | null
    brand?: string | null
    limit?: number
    offset?: number
  },
): Promise<ShopServiceResult<any>> => {
  try {
    const data = await shopOrderRepository.browseShopCatalog(shopSlug, opts)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch catalog.',
    }
  }
}

export const shopOrderService = {
  submitOrder,
  staffPriceOrder,
  customerCounter,
  staffCounter,
  confirmOrder,
  getOrderDetails,
  fetchCustomerOrders,
  fetchStaffOrders,
  placeOrderForProcurement,
  fulfillOrderToInvoice,
  browseShopCatalog,
}
