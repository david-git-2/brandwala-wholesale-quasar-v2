import { commerceOrderRepository } from '../repositories/commerceOrderRepository'
import type { CommerceOrder, CommerceOrderItem, CommerceOrderStatus, CommerceOrderSettings, CommerceOrderServiceResult } from '../types'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<CommerceOrderServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const commerceOrderService = {
  listCommerceOrders: (tenantId: number, customerGroupId?: number | null) =>
    wrap<CommerceOrder[]>(
      () => commerceOrderRepository.listCommerceOrders(tenantId, customerGroupId),
      'Failed to load commerce orders.',
    ),
  getCommerceOrderDetails: (orderId: number) =>
    wrap<{ order: CommerceOrder; items: CommerceOrderItem[] }>(
      () => commerceOrderRepository.getCommerceOrderDetails(orderId),
      'Failed to load commerce order details.',
    ),
  updateCommerceOrderStatus: (orderId: number, status: CommerceOrderStatus) =>
    wrap<CommerceOrder>(
      () => commerceOrderRepository.updateCommerceOrderStatus(orderId, status),
      'Failed to update commerce order status.',
    ),
  placeCommerceOrder: (payload: Parameters<typeof commerceOrderRepository.placeCommerceOrder>[0]) =>
    wrap<number>(
      () => commerceOrderRepository.placeCommerceOrder(payload),
      'Failed to place commerce order.',
    ),
  getCommerceOrderSettings: (tenantId: number) =>
    wrap<CommerceOrderSettings | null>(
      () => commerceOrderRepository.getCommerceOrderSettings(tenantId),
      'Failed to load commerce order settings.',
    ),
  upsertCommerceOrderSettings: (
    tenantId: number,
    payload: Omit<CommerceOrderSettings, 'tenant_id' | 'created_at' | 'updated_at'>,
  ) =>
    wrap<CommerceOrderSettings>(
      () => commerceOrderRepository.upsertCommerceOrderSettings(tenantId, payload),
      'Failed to save commerce order settings.',
    ),
  updateCommerceOrderCharges: (
    orderId: number,
    payload: {
      delivery_charge: number
      wrapping_charge: number
      cod: number
      shipment_payment: number
    },
  ) =>
    wrap<CommerceOrder>(
      () => commerceOrderRepository.updateCommerceOrderCharges(orderId, payload),
      'Failed to update commerce order charges.',
    ),
}
