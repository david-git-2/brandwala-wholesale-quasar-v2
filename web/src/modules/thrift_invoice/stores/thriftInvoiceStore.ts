import { defineStore } from 'pinia';
import { thriftInvoiceRepository } from '../repositories/thriftInvoiceRepository';
import type { ThriftInvoice } from '../types';

export const useThriftInvoiceStore = defineStore('thrift_invoice', {
  state: () => ({
    invoices: [] as ThriftInvoice[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    async loadInvoices(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        this.invoices = await thriftInvoiceRepository.fetchInvoices(tenantId);
      } catch (err: any) {
        this.error = err.message || 'Failed to load invoices';
      } finally {
        this.loading = false;
      }
    },

    async sellThriftItems(params: {
      tenantId: number;
      invoiceNumber: string;
      recipientName: string;
      address: string;
      phone: string;
      transactionMethod: string;
      codCharge: number;
      packingCharge: number;
      invoicePrintCharge: number;
      shippingChargeCustomer: number;
      insertedBy: string;
      items: Array<{
        stock_id: number;
        quantity: number;
        sold_price: number;
        platform_fees: number;
        shipping_cost_paid_by_shop: number;
      }>;
    }) {
      this.loading = true;
      try {
        const invoiceId = await thriftInvoiceRepository.markItemsAsSold(params);
        await this.loadInvoices(params.tenantId);
        return invoiceId;
      } catch (err: any) {
        this.error = err.message || 'Failed to process sale';
        throw err;
      } finally {
        this.loading = false;
      }
    },
  },
});
