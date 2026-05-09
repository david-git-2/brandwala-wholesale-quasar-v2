import { invoiceRepository } from '../repositories/invoiceRepository'
import type {
  AddPaymentAllocationInput,
  CreatePaymentWithAllocationsInput,
  CreateInvoiceItemInput,
  CreateInvoiceInput,
  DeleteInvoiceItemInput,
  DeleteInvoiceInput,
  Invoice,
  InvoiceItem,
  InvoiceListPage,
  InvoiceListQuery,
  InvoiceServiceResult,
  Payment,
  PaymentAllocation,
  UpdateInvoiceItemInput,
  UpdateInvoiceInput,
  UpdatePaymentAllocationAmountInput,
} from '../types/index'

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
  listInvoiceItems: (payload: InvoiceListQuery = {}) =>
    wrap<InvoiceListPage<InvoiceItem>>(
      () => invoiceRepository.listInvoiceItems(payload),
      'Failed to load invoice items.',
    ),
  listPayments: (payload: InvoiceListQuery = {}) =>
    wrap<InvoiceListPage<Payment>>(
      () => invoiceRepository.listPayments(payload),
      'Failed to load payments.',
    ),
  listPaymentAllocations: (payload: InvoiceListQuery = {}) =>
    wrap<InvoiceListPage<PaymentAllocation>>(
      () => invoiceRepository.listPaymentAllocations(payload),
      'Failed to load payment allocations.',
    ),
  createPaymentWithAllocations: (payload: CreatePaymentWithAllocationsInput) =>
    wrap<Payment>(
      () => invoiceRepository.createPaymentWithAllocations(payload),
      'Failed to create payment.',
    ),
  addPaymentAllocation: (payload: AddPaymentAllocationInput) =>
    wrap<PaymentAllocation>(
      () => invoiceRepository.addPaymentAllocation(payload),
      'Failed to add payment allocation.',
    ),
  updatePaymentAllocationAmount: (payload: UpdatePaymentAllocationAmountInput) =>
    wrap<PaymentAllocation>(
      () => invoiceRepository.updatePaymentAllocationAmount(payload),
      'Failed to update payment allocation.',
    ),
  createInvoice: (payload: CreateInvoiceInput) =>
    wrap<Invoice>(() => invoiceRepository.createInvoice(payload), 'Failed to create invoice.'),
  updateInvoice: (payload: UpdateInvoiceInput) =>
    wrap<Invoice>(() => invoiceRepository.updateInvoice(payload), 'Failed to update invoice.'),
  deleteInvoice: (payload: DeleteInvoiceInput) =>
    wrap<void>(() => invoiceRepository.deleteInvoice(payload), 'Failed to delete invoice.'),
  createInvoiceItem: (payload: CreateInvoiceItemInput) =>
    wrap<InvoiceItem>(
      () => invoiceRepository.createInvoiceItem(payload),
      'Failed to create invoice item.',
    ),
  updateInvoiceItem: (payload: UpdateInvoiceItemInput) =>
    wrap<InvoiceItem>(
      () => invoiceRepository.updateInvoiceItem(payload),
      'Failed to update invoice item.',
    ),
  deleteInvoiceItem: (payload: DeleteInvoiceItemInput) =>
    wrap<void>(() => invoiceRepository.deleteInvoiceItem(payload), 'Failed to delete invoice item.'),
}
