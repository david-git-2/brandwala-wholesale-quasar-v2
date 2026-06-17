import { defineStore } from 'pinia';
import { thriftInvoiceItemRepository } from '../repositories/thriftInvoiceItemRepository';
import type { ThriftInvoiceItem } from '../types';

export const useThriftInvoiceItemStore = defineStore('thrift_invoice_item', {
  state: () => ({
    invoiceItems: [] as Array<ThriftInvoiceItem & { thrift_invoices: { invoice_number: string }; thrift_stocks: { name: string; sku: string } }>,
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadInvoiceItems(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.invoiceItems = await thriftInvoiceItemRepository.fetchInvoiceItems(tenantId) as any;
      } catch (err: any) {
        this.error = err.message || 'Failed to load invoice items';
      } finally {
        this.loading = false;
      }
    },
  },
});
