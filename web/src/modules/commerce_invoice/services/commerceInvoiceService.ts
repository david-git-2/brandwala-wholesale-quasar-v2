import { commerceInvoiceRepository } from '../repositories/commerceInvoiceRepository'
import type {
  CommerceInvoice,
  CommerceInvoiceDetails,
  CommerceInvoiceServiceResult,
} from '../types'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<CommerceInvoiceServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const commerceInvoiceService = {
  listCommerceInvoices: (tenantId: number) =>
    wrap<CommerceInvoice[]>(
      () => commerceInvoiceRepository.listCommerceInvoices(tenantId),
      'Failed to load commerce invoices.',
    ),
  updateInvoicePayment: (invoiceId: number, amountPaid: number) =>
    wrap<CommerceInvoice>(
      () => commerceInvoiceRepository.updateInvoicePayment(invoiceId, amountPaid),
      'Failed to update commerce invoice payment.',
    ),
  getCommerceInvoiceDetails: (invoiceId: number) =>
    wrap<CommerceInvoiceDetails>(
      () => commerceInvoiceRepository.getCommerceInvoiceDetails(invoiceId),
      'Failed to load commerce invoice details.',
    ),
  createManualInvoice: (payload: {
    tenant_id: number
    customer_group_id: number
    recipient_name: string
    recipient_phone: string
    shipping_address: string
    delivery_charge: number
    wrapping_charge: number
    cod: number
  }) =>
    wrap<CommerceInvoice>(
      () => commerceInvoiceRepository.createManualInvoice(payload),
      'Failed to create manual invoice.',
    ),
  addCommerceInvoiceItem: (
    invoiceId: number,
    orderId: number,
    item: {
      product_id: number
      quantity: number
      cost_bdt: number
      sell_price_bdt: number
      recipient_price_bdt: number
      image_url?: string | null
      inventory_item_id?: number | null
    },
  ) =>
    wrap<void>(
      () => commerceInvoiceRepository.addCommerceInvoiceItem(invoiceId, orderId, item),
      'Failed to add item to commerce invoice.',
    ),
  updateOrderItemInventoryAssignment: (invoiceId: number, orderItemId: number, inventoryItemId: number) =>
    wrap<Record<string, unknown>>(
      () => commerceInvoiceRepository.updateOrderItemInventoryAssignment(invoiceId, orderItemId, inventoryItemId),
      'Failed to assign inventory item.',
    ),
  unassignOrderItemInventory: (invoiceId: number, orderItemId: number) =>
    wrap<Record<string, unknown>>(
      () => commerceInvoiceRepository.unassignOrderItemInventory(invoiceId, orderItemId),
      'Failed to unassign inventory item.',
    ),
  removeCommerceInvoiceItem: (orderItemId: number, invoiceId: number) =>
    wrap<void>(
      () => commerceInvoiceRepository.removeCommerceInvoiceItem(orderItemId, invoiceId),
      'Failed to remove item from commerce invoice.',
    ),
  updateCommerceInvoiceCharges: (
    invoiceId: number,
    charges: {
      delivery_charge: number
      wrapping_charge: number
      cod: number
      delivered_by?: string
      amount_paid?: number
      discount_amount?: number
    },
  ) =>
    wrap<void>(
      () => commerceInvoiceRepository.updateCommerceInvoiceCharges(invoiceId, charges),
      'Failed to update invoice charges.',
    ),
  deleteCommerceInvoice: (invoiceId: number) =>
    wrap<void>(
      () => commerceInvoiceRepository.deleteCommerceInvoice(invoiceId),
      'Failed to delete commerce invoice.',
    ),
  updateCommerceInvoiceStatus: (invoiceId: number, status: 'draft' | 'ready' | 'handed_to_customer') =>
    wrap<CommerceInvoice>(
      () => commerceInvoiceRepository.updateCommerceInvoiceStatus(invoiceId, status),
      'Failed to update commerce invoice status.',
    ),
}
