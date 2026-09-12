import { supabase } from 'src/boot/supabase';
import { asDashboardNumber } from 'src/modules/dashboard/utils/formatDashboardMetric';

export type SalesInvoiceOverdueCustomer = {
  name: string;
  dueAmount: number;
  invoiceCount: number;
};

export type SalesInvoiceDashboardMetrics = {
  tenantId: number;
  todayBilledAmount: number;
  unpaidCount: number;
  overdueCount: number;
  draftCount: number;
  paidAmount: number;
  dueAmount: number;
  overdueAmount: number;
  overdueCustomers: SalesInvoiceOverdueCustomer[];
};

export const salesInvoiceDashboardRepository = {
  async getMetrics(tenantId: number): Promise<SalesInvoiceDashboardMetrics> {
    const { data, error } = await supabase.rpc('get_sales_invoice_dashboard_metrics', {
      p_tenant_id: tenantId,
    });
    if (error) {
      throw error;
    }

    const raw = (data ?? {}) as Record<string, unknown>;
    const customersRaw = Array.isArray(raw.overdue_customers) ? raw.overdue_customers : [];

    return {
      tenantId: asDashboardNumber(raw.tenant_id) || tenantId,
      todayBilledAmount: asDashboardNumber(raw.today_billed_amount),
      unpaidCount: asDashboardNumber(raw.unpaid_count),
      overdueCount: asDashboardNumber(raw.overdue_count),
      draftCount: asDashboardNumber(raw.draft_count),
      paidAmount: asDashboardNumber(raw.paid_amount),
      dueAmount: asDashboardNumber(raw.due_amount),
      overdueAmount: asDashboardNumber(raw.overdue_amount),
      overdueCustomers: customersRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          name: typeof item.name === 'string' ? item.name : 'Unknown',
          dueAmount: asDashboardNumber(item.due_amount),
          invoiceCount: asDashboardNumber(item.invoice_count),
        };
      }),
    };
  },
};
