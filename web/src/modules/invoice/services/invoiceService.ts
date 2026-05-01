import { invoiceRepository } from '../repositories/invoiceRepository'
import type {
  CreateInvoiceAccountingPaymentInput,
  CreateInvoiceInput,
  CreateInvoiceItemInput,
  CreateInventoryAccountingEntryInput,
  DeleteInvoiceAccountingPaymentInput,
  DeleteInvoiceInput,
  DeleteInvoiceItemInput,
  DeleteInventoryAccountingEntryInput,
  Invoice,
  InvoiceAccountingPayment,
  InvoiceItem,
  InvoiceListPage,
  InvoiceListQuery,
  InventoryAccountingEntry,
  InvoiceServiceResult,
  UpdateInvoiceAccountingPaymentInput,
  UpdateInvoiceInput,
  UpdateInvoiceItemInput,
  UpdateInventoryAccountingEntryInput,
} from '../types'

const wrap = async <T>(fn: () => Promise<T>, fallback: string): Promise<InvoiceServiceResult<T>> => {
  try { return { success: true, data: await fn() } } catch (error) { return { success: false, error: error instanceof Error ? error.message : fallback } }
}

export const invoiceService = {
  listInvoices: (payload: InvoiceListQuery = {}) => wrap<InvoiceListPage<Invoice>>(() => invoiceRepository.listInvoices(payload), 'Failed to load invoices.'),
  createInvoice: (payload: CreateInvoiceInput) => wrap<Invoice>(() => invoiceRepository.createInvoice(payload), 'Failed to create invoice.'),
  updateInvoice: (payload: UpdateInvoiceInput) => wrap<Invoice>(() => invoiceRepository.updateInvoice(payload), 'Failed to update invoice.'),
  deleteInvoice: (payload: DeleteInvoiceInput) => wrap<void>(() => invoiceRepository.deleteInvoice(payload), 'Failed to delete invoice.'),

  listInvoiceItems: (payload: InvoiceListQuery = {}) => wrap<InvoiceListPage<InvoiceItem>>(() => invoiceRepository.listInvoiceItems(payload), 'Failed to load invoice items.'),
  createInvoiceItem: (payload: CreateInvoiceItemInput) => wrap<InvoiceItem>(() => invoiceRepository.createInvoiceItem(payload), 'Failed to create invoice item.'),
  createInvoiceItemsBulk: (payload: CreateInvoiceItemInput[]) => wrap<InvoiceItem[]>(() => invoiceRepository.createInvoiceItemsBulk(payload), 'Failed to create invoice items.'),
  updateInvoiceItem: (payload: UpdateInvoiceItemInput) => wrap<InvoiceItem>(() => invoiceRepository.updateInvoiceItem(payload), 'Failed to update invoice item.'),
  deleteInvoiceItem: (payload: DeleteInvoiceItemInput) => wrap<void>(() => invoiceRepository.deleteInvoiceItem(payload), 'Failed to delete invoice item.'),

  listInventoryAccountingEntries: (payload: InvoiceListQuery = {}) => wrap<InvoiceListPage<InventoryAccountingEntry>>(() => invoiceRepository.listInventoryAccountingEntries(payload), 'Failed to load inventory accounting entries.'),
  createInventoryAccountingEntry: (payload: CreateInventoryAccountingEntryInput) => wrap<InventoryAccountingEntry>(() => invoiceRepository.createInventoryAccountingEntry(payload), 'Failed to create inventory accounting entry.'),
  createInventoryAccountingEntriesBulk: (payload: CreateInventoryAccountingEntryInput[]) => wrap<InventoryAccountingEntry[]>(() => invoiceRepository.createInventoryAccountingEntriesBulk(payload), 'Failed to create inventory accounting entries.'),
  deleteInventoryAccountingEntriesByInvoiceId: (invoiceId: number) => wrap<void>(() => invoiceRepository.deleteInventoryAccountingEntriesByInvoiceId(invoiceId), 'Failed to delete inventory accounting entries.'),
  updateInventoryAccountingEntry: (payload: UpdateInventoryAccountingEntryInput) => wrap<InventoryAccountingEntry>(() => invoiceRepository.updateInventoryAccountingEntry(payload), 'Failed to update inventory accounting entry.'),
  deleteInventoryAccountingEntry: (payload: DeleteInventoryAccountingEntryInput) => wrap<void>(() => invoiceRepository.deleteInventoryAccountingEntry(payload), 'Failed to delete inventory accounting entry.'),

  listInvoiceAccountingPayments: (payload: InvoiceListQuery = {}) => wrap<InvoiceListPage<InvoiceAccountingPayment>>(() => invoiceRepository.listInvoiceAccountingPayments(payload), 'Failed to load invoice accounting payments.'),
  createInvoiceAccountingPayment: (payload: CreateInvoiceAccountingPaymentInput) => wrap<InvoiceAccountingPayment>(() => invoiceRepository.createInvoiceAccountingPayment(payload), 'Failed to create invoice accounting payment.'),
  updateInvoiceAccountingPayment: (payload: UpdateInvoiceAccountingPaymentInput) => wrap<InvoiceAccountingPayment>(() => invoiceRepository.updateInvoiceAccountingPayment(payload), 'Failed to update invoice accounting payment.'),
  deleteInvoiceAccountingPayment: (payload: DeleteInvoiceAccountingPaymentInput) => wrap<void>(() => invoiceRepository.deleteInvoiceAccountingPayment(payload), 'Failed to delete invoice accounting payment.'),
}
