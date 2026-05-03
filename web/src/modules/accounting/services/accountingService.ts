import { accountingRepository } from '../repositories/accountingRepository'
import type {
  AccountingListPage,
  AccountingListQuery,
  AccountingServiceResult,
  CreateInventoryAccountingEntryInput,
  CreateInvoiceAccountingPaymentInput,
  DeleteInventoryAccountingEntryInput,
  DeleteInvoiceAccountingPaymentInput,
  InventoryAccountingEntry,
  InvoiceAccountingPayment,
  UpdateInventoryAccountingEntryInput,
  UpdateInvoiceAccountingPaymentInput,
} from '../types'

const wrap = async <T>(
  fn: () => Promise<T>,
  fallback: string,
): Promise<AccountingServiceResult<T>> => {
  try {
    return { success: true, data: await fn() }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : fallback,
    }
  }
}

export const accountingService = {
  listInventoryAccountingEntries: (payload: AccountingListQuery = {}) =>
    wrap<AccountingListPage<InventoryAccountingEntry>>(
      () => accountingRepository.listInventoryAccountingEntries(payload),
      'Failed to load inventory accounting entries.',
    ),
  createInventoryAccountingEntry: (payload: CreateInventoryAccountingEntryInput) =>
    wrap<InventoryAccountingEntry>(
      () => accountingRepository.createInventoryAccountingEntry(payload),
      'Failed to create inventory accounting entry.',
    ),
  updateInventoryAccountingEntry: (payload: UpdateInventoryAccountingEntryInput) =>
    wrap<InventoryAccountingEntry>(
      () => accountingRepository.updateInventoryAccountingEntry(payload),
      'Failed to update inventory accounting entry.',
    ),
  deleteInventoryAccountingEntry: (payload: DeleteInventoryAccountingEntryInput) =>
    wrap<void>(
      () => accountingRepository.deleteInventoryAccountingEntry(payload),
      'Failed to delete inventory accounting entry.',
    ),
  listInvoiceAccountingPayments: (payload: AccountingListQuery = {}) =>
    wrap<AccountingListPage<InvoiceAccountingPayment>>(
      () => accountingRepository.listInvoiceAccountingPayments(payload),
      'Failed to load invoice accounting payments.',
    ),
  createInvoiceAccountingPayment: (payload: CreateInvoiceAccountingPaymentInput) =>
    wrap<InvoiceAccountingPayment>(
      () => accountingRepository.createInvoiceAccountingPayment(payload),
      'Failed to create invoice accounting payment.',
    ),
  updateInvoiceAccountingPayment: (payload: UpdateInvoiceAccountingPaymentInput) =>
    wrap<InvoiceAccountingPayment>(
      () => accountingRepository.updateInvoiceAccountingPayment(payload),
      'Failed to update invoice accounting payment.',
    ),
  deleteInvoiceAccountingPayment: (payload: DeleteInvoiceAccountingPaymentInput) =>
    wrap<void>(
      () => accountingRepository.deleteInvoiceAccountingPayment(payload),
      'Failed to delete invoice accounting payment.',
    ),
}
