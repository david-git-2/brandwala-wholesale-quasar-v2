import { commerceInvoiceRepository } from '../repositories/commerceInvoiceRepository'
import type { CommerceInvoice, CommerceInvoiceServiceResult } from '../types'

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
}
