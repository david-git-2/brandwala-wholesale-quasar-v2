import { kobaOrderRepository } from '../repositories/kobaOrderRepository';
import type {
  KobaOrder,
  KobaOrderItem,
  KobaOrderListPage,
  KobaOrderStatus,
  PlaceOrderInput,
  PlaceOrderResult,
} from '../repositories/kobaOrderRepository';

export interface KobaOrderServiceResult<T> {
  success: boolean;
  data?: T;
  error?: string;
}

const placeOrder = async (
  payload: PlaceOrderInput,
): Promise<KobaOrderServiceResult<PlaceOrderResult>> => {
  try {
    const data = await kobaOrderRepository.placeOrder(payload);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place Koba order.',
    };
  }
};

const listOrders = async (
  tenantId: number,
  customerGroupId: number | null = null,
  page: number = 1,
  pageSize: number = 20,
  status: KobaOrderStatus | null = null,
): Promise<KobaOrderServiceResult<KobaOrderListPage>> => {
  try {
    const data = await kobaOrderRepository.listOrders(
      tenantId,
      customerGroupId,
      page,
      pageSize,
      status,
    );

    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load Koba orders.',
    };
  }
};

const getOrderWithItems = async (
  orderId: number,
): Promise<
  KobaOrderServiceResult<{
    order: KobaOrder;
    items: KobaOrderItem[];
  }>
> => {
  try {
    const [order, items] = await Promise.all([
      kobaOrderRepository.getOrderById(orderId),
      kobaOrderRepository.getOrderItems(orderId),
    ]);

    return {
      success: true,
      data: {
        order,
        items,
      },
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load Koba order details.',
    };
  }
};

const updateOrderStatus = async (
  orderId: number,
  status: KobaOrderStatus,
): Promise<KobaOrderServiceResult<Pick<KobaOrder, 'id' | 'status' | 'updated_at'>>> => {
  try {
    const data = await kobaOrderRepository.updateOrderStatus(orderId, status);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update order status.',
    };
  }
};

const updateItemConfirmedQty = async (
  itemId: number,
  confirmedQuantity: number,
): Promise<
  KobaOrderServiceResult<Pick<KobaOrderItem, 'id' | 'confirmed_quantity' | 'updated_at'>>
> => {
  try {
    const data = await kobaOrderRepository.updateItemConfirmedQty(itemId, confirmedQuantity);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update confirmed quantity.',
    };
  }
};

const updateItemDeliveredQty = async (
  itemId: number,
  deliveredQuantity: number,
): Promise<
  KobaOrderServiceResult<Pick<KobaOrderItem, 'id' | 'delivered_quantity' | 'updated_at'>>
> => {
  try {
    const data = await kobaOrderRepository.updateItemDeliveredQty(itemId, deliveredQuantity);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update delivered quantity.',
    };
  }
};

const softDeleteOrder = async (
  orderId: number,
): Promise<KobaOrderServiceResult<Pick<KobaOrder, 'id' | 'status' | 'updated_at'>>> => {
  try {
    const data = await kobaOrderRepository.softDeleteOrder(orderId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete order.',
    };
  }
};

export const kobaOrderService = {
  placeOrder,
  listOrders,
  getOrderWithItems,
  updateOrderStatus,
  updateItemConfirmedQty,
  updateItemDeliveredQty,
  softDeleteOrder,
};
