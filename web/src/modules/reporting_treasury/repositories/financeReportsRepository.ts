import { supabase } from 'src/boot/supabase';
import type {
  CourierCodReportPayload,
  CustomerDuesReportPayload,
  InvoiceBookReportPayload,
  InvoiceProfitReportPayload,
  MonthSnapshotReportPayload,
  WalletLiabilityReportPayload,
} from '../types/financeReportTypes';

function downloadCsv(filename: string, headers: string[], rows: (string | number)[][]) {
  const escape = (val: string | number) => {
    const s = String(val ?? '');
    if (s.includes(',') || s.includes('"') || s.includes('\n')) {
      return `"${s.replace(/"/g, '""')}"`;
    }
    return s;
  };
  const lines = [headers.join(','), ...rows.map((row) => row.map(escape).join(','))];
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export const financeReportsRepository = {
  async fetchCustomerDuesReport(params: {
    tenantId: number;
    issuedByTenantId?: number | null;
    search?: string | null;
    agingBucket?: string | null;
    minDue?: number;
    overLimitOnly?: boolean;
    page?: number;
    pageSize?: number;
    skipCount?: boolean;
  }): Promise<CustomerDuesReportPayload> {
    const { data, error } = await supabase.rpc('get_customer_dues_report', {
      p_tenant_id: params.tenantId,
      p_issued_by_tenant_id: params.issuedByTenantId ?? undefined,
      p_search: params.search?.trim() || undefined,
      p_aging_bucket: params.agingBucket ?? undefined,
      p_min_due: params.minDue ?? 0,
      p_over_limit_only: params.overLimitOnly ?? false,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 50,
      p_skip_count: params.skipCount ?? true,
    });
    if (error) throw error;
    return (data as CustomerDuesReportPayload) ?? emptyCustomerDues();
  },

  async fetchInvoiceBookReport(params: {
    tenantId: number;
    startDate?: string | null;
    endDate?: string | null;
    search?: string | null;
    invoiceType?: string | null;
    paymentStatus?: string | null;
    issuedByTenantId?: number | null;
    page?: number;
    pageSize?: number;
    skipCount?: boolean;
  }): Promise<InvoiceBookReportPayload> {
    const { data, error } = await supabase.rpc('get_tenant_invoice_book_report', {
      p_tenant_id: params.tenantId,
      p_start_date: params.startDate ?? undefined,
      p_end_date: params.endDate ?? undefined,
      p_search: params.search?.trim() || undefined,
      p_invoice_type: params.invoiceType ?? undefined,
      p_payment_status: params.paymentStatus ?? undefined,
      p_issued_by_tenant_id: params.issuedByTenantId ?? undefined,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 50,
      p_skip_count: params.skipCount ?? true,
    });
    if (error) throw error;
    return (data as InvoiceBookReportPayload) ?? emptyInvoiceBook();
  },

  async fetchInvoiceProfitReport(params: {
    tenantId: number;
    startDate?: string | null;
    endDate?: string | null;
    search?: string | null;
    issuedByTenantId?: number | null;
    invoiceId?: number | null;
    page?: number;
    pageSize?: number;
    skipCount?: boolean;
  }): Promise<InvoiceProfitReportPayload> {
    const { data, error } = await supabase.rpc('get_tenant_invoice_profit_report', {
      p_tenant_id: params.tenantId,
      p_start_date: params.startDate ?? undefined,
      p_end_date: params.endDate ?? undefined,
      p_search: params.search?.trim() || undefined,
      p_issued_by_tenant_id: params.issuedByTenantId ?? undefined,
      p_invoice_id: params.invoiceId ?? undefined,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 50,
      p_skip_count: params.skipCount ?? true,
    });
    if (error) throw error;
    return (data as InvoiceProfitReportPayload) ?? emptyInvoiceProfit();
  },

  async fetchWalletLiabilityReport(params: {
    tenantId: number;
    startDate?: string | null;
    endDate?: string | null;
    search?: string | null;
    page?: number;
    pageSize?: number;
    skipCount?: boolean;
  }): Promise<WalletLiabilityReportPayload> {
    const { data, error } = await supabase.rpc('get_tenant_wallet_liability_report', {
      p_tenant_id: params.tenantId,
      p_start_date: params.startDate ?? undefined,
      p_end_date: params.endDate ?? undefined,
      p_search: params.search?.trim() || undefined,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 50,
      p_skip_count: params.skipCount ?? true,
    });
    if (error) throw error;
    return (data as WalletLiabilityReportPayload) ?? emptyWalletLiability();
  },

  async fetchCourierCodReport(params: {
    tenantId: number;
    startDate?: string | null;
    endDate?: string | null;
    courierServiceId?: string | null;
    page?: number;
    pageSize?: number;
    skipCount?: boolean;
  }): Promise<CourierCodReportPayload> {
    const { data, error } = await supabase.rpc('get_tenant_courier_cod_report', {
      p_tenant_id: params.tenantId,
      p_start_date: params.startDate ?? undefined,
      p_end_date: params.endDate ?? undefined,
      p_courier_service_id: params.courierServiceId ?? undefined,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 50,
      p_skip_count: params.skipCount ?? true,
    });
    if (error) throw error;
    return (data as CourierCodReportPayload) ?? emptyCourierCod();
  },

  async fetchMonthSnapshotReport(params: {
    tenantId: number;
    month: string;
  }): Promise<MonthSnapshotReportPayload> {
    const { data, error } = await supabase.rpc('get_tenant_month_snapshot_report', {
      p_tenant_id: params.tenantId,
      p_month: params.month,
    });
    if (error) throw error;
    return data as MonthSnapshotReportPayload;
  },

  exportCustomerDuesCsv(payload: CustomerDuesReportPayload) {
    downloadCsv(
      'customer-dues.csv',
      [
        'Customer',
        'Phone',
        'Still Due',
        'Current',
        '1-30',
        '31-60',
        '61-90',
        '90+',
        'Credit Limit',
        'Open Invoices',
      ],
      payload.rows.map((r) => [
        r.name,
        r.phone ?? '',
        r.still_due,
        r.aging.current,
        r.aging.d1_30,
        r.aging.d31_60,
        r.aging.d61_90,
        r.aging.d90_plus,
        r.credit_limit ?? '',
        r.open_invoice_count,
      ]),
    );
  },

  exportInvoiceBookCsv(payload: InvoiceBookReportPayload) {
    downloadCsv(
      'invoice-book.csv',
      [
        'Invoice',
        'Date',
        'Type',
        'Customer',
        'Payment Status',
        'Billed',
        'Returned',
        'Cash',
        'Wallet',
        'Settlement',
        'Still Due',
      ],
      payload.rows.map((r) => [
        r.invoice_no,
        r.invoice_date,
        r.invoice_type,
        r.customer_name,
        r.payment_status,
        r.billed,
        r.returned,
        r.collected_cash,
        r.wallet_applied,
        r.settlement,
        r.still_due,
      ]),
    );
  },

  exportInvoiceProfitCsv(payload: InvoiceProfitReportPayload) {
    downloadCsv(
      'invoice-profit.csv',
      ['Invoice', 'Date', 'Customer', 'Net Qty', 'Revenue', 'COGS', 'GP', 'Margin %'],
      payload.rows.map((r) => [
        r.invoice_no,
        r.invoice_date,
        r.customer_name,
        r.net_qty,
        r.net_revenue,
        r.cogs,
        r.realized_gp,
        r.gp_margin_pct,
      ]),
    );
  },

  exportWalletLiabilityCsv(payload: WalletLiabilityReportPayload) {
    downloadCsv(
      'wallet-liability.csv',
      ['Customer', 'Phone', 'Credit Issued', 'Credit Applied', 'Outstanding'],
      payload.rows.map((r) => [
        r.name,
        r.phone ?? '',
        r.credit_issued,
        r.credit_applied,
        r.outstanding,
      ]),
    );
  },

  exportCourierCodCsv(payload: CourierCodReportPayload) {
    downloadCsv(
      'courier-cod.csv',
      ['Courier', 'Delivered COD', 'Remitted', 'Unremitted', 'Short/Over', 'Orders'],
      payload.rows.map((r) => [
        r.courier_name,
        r.delivered_cod,
        r.remitted,
        r.unremitted,
        r.short_over,
        r.order_count,
      ]),
    );
  },

  exportMonthSnapshotCsv(payload: MonthSnapshotReportPayload) {
    downloadCsv(
      'month-snapshot.csv',
      ['Metric', 'Amount (BDT)'],
      [
        ['Net Sales', payload.kpis.net_sales],
        ['COGS', payload.kpis.cogs],
        ['Gross Profit', payload.kpis.gross_profit],
        ['Cash Collected', payload.kpis.cash_collected],
        ['AR Outstanding', payload.kpis.ar_outstanding],
        ['Wallet Liability', payload.kpis.wallet_liability],
        ['Unsold Stock Value', payload.kpis.unsold_stock_value],
      ],
    );
  },
};

function emptyCustomerDues(): CustomerDuesReportPayload {
  return {
    totals: {
      billed: 0,
      returned: 0,
      collected_cash: 0,
      wallet_applied: 0,
      settlement: 0,
      still_due: 0,
      customer_count: 0,
    },
    rows: [],
    page: 1,
    page_size: 50,
    total_count: null,
  };
}

function emptyInvoiceBook(): InvoiceBookReportPayload {
  return {
    totals: {
      billed: 0,
      returned: 0,
      collected_cash: 0,
      wallet_applied: 0,
      settlement: 0,
      still_due: 0,
      invoice_count: 0,
    },
    rows: [],
    page: 1,
    page_size: 50,
    total_count: null,
  };
}

function emptyInvoiceProfit(): InvoiceProfitReportPayload {
  return {
    totals: {
      net_sold_qty: 0,
      net_revenue: 0,
      cogs: 0,
      realized_gp: 0,
      gp_margin_pct: 0,
      invoice_count: 0,
    },
    rows: [],
    page: 1,
    page_size: 50,
    total_count: null,
  };
}

function emptyWalletLiability(): WalletLiabilityReportPayload {
  return {
    totals: { credit_issued: 0, credit_applied: 0, outstanding: 0, customer_count: 0 },
    rows: [],
    page: 1,
    page_size: 50,
    total_count: null,
  };
}

function emptyCourierCod(): CourierCodReportPayload {
  return {
    totals: { delivered_cod: 0, remitted: 0, unremitted: 0, short_over: 0, order_count: 0 },
    rows: [],
    page: 1,
    page_size: 50,
    total_count: null,
  };
}
