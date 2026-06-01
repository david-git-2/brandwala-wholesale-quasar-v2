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
  listCommerceOrders: (
    tenantId: number,
    payload: { page: number; page_size: number; customer_group_id?: number | null }
  ) =>
    wrap<{
      data: (CommerceOrder & { customer_group_name?: string | null })[]
      meta: {
        total: number
        page: number
        page_size: number
        total_pages: number
      }
    }>(
      () => commerceOrderRepository.listCommerceOrders(tenantId, payload),
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
    payload: Parameters<typeof commerceOrderRepository.updateCommerceOrderCharges>[1],
  ) =>
    wrap<CommerceOrder>(
      () => commerceOrderRepository.updateCommerceOrderCharges(orderId, payload),
      'Failed to update commerce order charges.',
    ),
  deleteCommerceOrder: (orderId: number) =>
    wrap<void>(
      () => commerceOrderRepository.deleteCommerceOrder(orderId),
      'Failed to delete commerce order.',
    ),
}
