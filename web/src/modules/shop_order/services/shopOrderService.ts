import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { ShopOrder, ShopOrderItem, ShopServiceResult } from '../types';

const submitOrder = async (
  cartId: number,
  recipientName: string,
  recipientPhone: string,
  shippingAddress: string,
  billingProfileId: number | null,
  isPrepaid?: boolean,
  deliveryInstructions?: string | null,
  codChargeAmount?: number,
  deliveryChargeAmount?: number,
  printChargeAmount?: number,
  packingChargeAmount?: number,
  discountAmount?: number,
): Promise<ShopServiceResult<{ order_id: number; order_no: string; status: string }>> => {
  try {
    const data = await shopOrderRepository.submitShopOrderFromCart(
      cartId,
      recipientName,
      recipientPhone,
      shippingAddress,
      billingProfileId,
      isPrepaid,
      deliveryInstructions,
      codChargeAmount,
      deliveryChargeAmount,
      printChargeAmount,
      packingChargeAmount,
      discountAmount,
    );
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to submit order.',
    };
  }
};

const staffPriceOrder = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffPriceShopOrder(orderId, items);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to set pricing.',
    };
  }
};

const customerCounter = async (
  orderId: number,
  items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.customerCounterOffer(orderId, items);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place counter offer.',
    };
  }
};

const staffCounter = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffCounterOffer(orderId, items);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to counter offer.',
    };
  }
};

const confirmOrder = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.confirmShopOrder(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to confirm order.',
    };
  }
};

const getOrderDetails = async (
  orderId: number,
): Promise<ShopServiceResult<{ order: ShopOrder; items: ShopOrderItem[] }>> => {
  try {
    const data = await shopOrderRepository.getShopOrderById(orderId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch order details.',
    };
  }
};

const fetchCustomerOrders = async (
  shopId: number,
  opts?: { limit?: number; offset?: number },
): Promise<ShopServiceResult<ShopOrder[]>> => {
  try {
    const data = await shopOrderRepository.listShopOrdersForCustomer(shopId, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list customer orders.',
    };
  }
};

const fetchStaffOrders = async (
  tenantId: number,
  opts?: { limit?: number; offset?: number; search?: string | null; status?: string | null; shopId?: number | null },
): Promise<ShopServiceResult<ShopOrder[]>> => {
  try {
    const data = await shopOrderRepository.listShopOrdersForStaff(tenantId, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list staff orders.',
    };
  }
};

const placeOrderForProcurement = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.placeShopOrderForProcurement(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place order for procurement.',
    };
  }
};

const fulfillOrderToInvoice = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.fulfillShopOrderToInvoice(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fulfill order to invoice.',
    };
  }
};

const deleteOrder = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.deleteShopOrder(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete order.',
    };
  }
};

const browseShopCatalog = async (
  shopSlug: string,
  opts?: {
    search?: string | null;
    category?: string | null;
    brand?: string | null;
    limit?: number;
    offset?: number;
  },
): Promise<ShopServiceResult<any>> => {
  try {
    const data = await shopOrderRepository.browseShopCatalog(shopSlug, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch catalog.',
    };
  }
};

const listShopsForCustomer = async (
  tenantId?: number | null,
): Promise<
  ShopServiceResult<Awaited<ReturnType<typeof shopOrderRepository.listShopsForCustomer>>>
> => {
  try {
    const data = await shopOrderRepository.listShopsForCustomer(tenantId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list accessible shops.',
    };
  }
};

const updateOrderCharges = async (
  orderId: number,
  payload: {
    delivery_charge_amount: number;
    deduct_delivery_from_margin: boolean;
    cod_charge_amount: number;
    deduct_cod_from_margin: boolean;
    print_charge_amount: number;
    deduct_print_from_margin: boolean;
    packing_charge_amount: number;
    deduct_packing_from_margin: boolean;
  },
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.updateOrderCharges(orderId, payload);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update order charges.',
    };
  }
};

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
  deleteOrder,
  browseShopCatalog,
  listShopsForCustomer,
  updateOrderCharges,
};
