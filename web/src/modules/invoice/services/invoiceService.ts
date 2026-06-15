import { invoiceRepository } from '../repositories/invoiceRepository'
import type {
  AddPaymentAllocationInput,
  ApplyInvoiceItemReturnInput,
  ApplyInvoiceItemReturnResult,
  CreatePaymentWithAllocationsInput,
  CreateInvoiceItemInput,
  CreateInvoiceInput,
  DeleteInvoiceItemInput,
  DeletePaymentInput,
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
  UpdatePaymentInput,
  UpdatePaymentAllocationAmountInput,
  InvoiceBrand,
  CreateInvoiceBrandInput,
  InvoiceBox,
  CreateInvoiceBoxInput,
} from '../types/index'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<InvoiceServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    const getErrorMessage = (unknownError: unknown): string | null => {
      if (unknownError instanceof Error && unknownError.message) {
        return unknownError.message
      }
      if (unknownError && typeof unknownError === 'object') {
        const maybe = unknownError as { message?: unknown; details?: unknown; error_description?: unknown }
        if (typeof maybe.message === 'string' && maybe.message.trim()) return maybe.message
        if (typeof maybe.details === 'string' && maybe.details.trim()) return maybe.details
        if (typeof maybe.error_description === 'string' && maybe.error_description.trim()) {
          return maybe.error_description
        }
      }
      return null
    }

    return {
      success: false,
      error: getErrorMessage(error) ?? fallback,
    }
  }
}

export const invoiceService = {
  listInvoices: (payload: InvoiceListQuery = {}) =>
    wrap<InvoiceListPage<Invoice>>(
      () => invoiceRepository.listInvoices(payload),
      'Failed to load invoices.',
    ),
  getInvoiceById: (id: number) =>
    wrap<Invoice>(() => invoiceRepository.getInvoiceById(id), 'Failed to retrieve invoice.'),
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
  updatePayment: (payload: UpdatePaymentInput) =>
    wrap<Payment>(() => invoiceRepository.updatePayment(payload), 'Failed to update payment.'),
  deletePayment: (payload: DeletePaymentInput) =>
    wrap<void>(() => invoiceRepository.deletePayment(payload), 'Failed to delete payment.'),
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
  recomputeInvoicePaymentStatus: (invoiceId: number) =>
    wrap<void>(
      () => invoiceRepository.recomputeInvoicePaymentStatus(invoiceId),
      'Failed to recompute invoice payment status.',
    ),
  applyInvoiceItemReturn: (payload: ApplyInvoiceItemReturnInput) =>
    wrap<ApplyInvoiceItemReturnResult>(
      () => invoiceRepository.applyInvoiceItemReturn(payload),
      'Failed to apply invoice item return.',
    ),
  listInvoiceBrands: (payload: { tenant_id?: number } = {}) =>
    wrap<(InvoiceBrand & { tenants?: { name: string } })[]>(
      () => invoiceRepository.listInvoiceBrands(payload),
      'Failed to load invoice brands.',
    ),
  createInvoiceBrand: (payload: CreateInvoiceBrandInput) =>
    wrap<InvoiceBrand>(
      () => invoiceRepository.createInvoiceBrand(payload),
      'Failed to create brand.',
    ),
  updateInvoiceBrand: (payload: { id: number; patch: Partial<Omit<InvoiceBrand, 'id' | 'tenant_id' | 'created_at' | 'updated_at'>> }) =>
    wrap<InvoiceBrand>(
      () => invoiceRepository.updateInvoiceBrand(payload),
      'Failed to update brand.',
    ),
  deleteInvoiceBrand: (payload: { id: number }) =>
    wrap<void>(
      () => invoiceRepository.deleteInvoiceBrand(payload),
      'Failed to delete brand.',
    ),
  listInvoiceBoxes: (payload: { invoice_id: number; tenant_id?: number }) =>
    wrap<InvoiceBox[]>(
      () => invoiceRepository.listInvoiceBoxes(payload),
      'Failed to load box weights.',
    ),
  createInvoiceBox: (payload: CreateInvoiceBoxInput) =>
    wrap<InvoiceBox>(
      () => invoiceRepository.createInvoiceBox(payload),
      'Failed to add box weight.',
    ),
  deleteInvoiceBox: (payload: { id: number }) =>
    wrap<void>(
      () => invoiceRepository.deleteInvoiceBox(payload),
      'Failed to delete box weight.',
    ),
}
