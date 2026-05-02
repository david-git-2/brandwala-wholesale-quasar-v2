import { invoiceRepository } from '../repositories/invoiceRepository'
import type {
  CreateInvoiceInput,
  DeleteInvoiceInput,
  Invoice,
  InvoiceListPage,
  InvoiceListQuery,
  InvoiceServiceResult,
  UpdateInvoiceInput,
} from '../types'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<InvoiceServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const invoiceService = {
  listInvoices: (payload: InvoiceListQuery = {}) =>
    wrap<InvoiceListPage<Invoice>>(
      () => invoiceRepository.listInvoices(payload),
      'Failed to load invoices.',
    ),
  createInvoice: (payload: CreateInvoiceInput) =>
    wrap<Invoice>(() => invoiceRepository.createInvoice(payload), 'Failed to create invoice.'),
  updateInvoice: (payload: UpdateInvoiceInput) =>
    wrap<Invoice>(() => invoiceRepository.updateInvoice(payload), 'Failed to update invoice.'),
  deleteInvoice: (payload: DeleteInvoiceInput) =>
    wrap<void>(() => invoiceRepository.deleteInvoice(payload), 'Failed to delete invoice.'),
}
