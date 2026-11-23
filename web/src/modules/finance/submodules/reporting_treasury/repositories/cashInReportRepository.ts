import { supabase } from 'src/boot/supabase';
import type { CashInReportParams, TenantCashInReport } from '../types/cashInReport';

export const cashInReportRepository = {
  /** Fetch consolidated Cash In report for tenant books. */
  async fetchCashInReport(params: CashInReportParams): Promise<TenantCashInReport> {
    const { data, error } = await supabase.rpc('get_tenant_cash_in_report', {
      p_tenant_id: params.tenantId,
      p_start_date: params.startDate ?? null,
      p_end_date: params.endDate ?? null,
    });

    if (error) {
      console.error('[cashInReportRepository.fetchCashInReport error]:', error);
      throw error;
    }

    const payload = (data as unknown as TenantCashInReport) || {};
    return {
      tenant_id: payload.tenant_id ?? params.tenantId,
      start_date: payload.start_date ?? params.startDate ?? null,
      end_date: payload.end_date ?? params.endDate ?? null,
      cash_in_total: Number(payload.cash_in_total || 0),
      entry_count: Number(payload.entry_count || 0),
      by_method: payload.by_method || [],
      entries: payload.entries || [],
    };
  },

  /** Trigger a CSV download for the Cash In report. */
  exportCashInToCsv(report: TenantCashInReport): void {
    const headers = [
      'Date & Time',
      'Transaction ID',
      'Method',
      'Amount (BDT)',
      'Label / Description',
      'Source Type',
      'Source ID',
      'Invoice ID',
    ];

    const rows = (report.entries || []).map((entry) => [
      `"${new Date(entry.created_at).toLocaleString()}"`,
      `"${entry.id}"`,
      `"${entry.method.toUpperCase()}"`,
      Number(entry.amount).toFixed(2),
      `"${(entry.label || '').replace(/"/g, '""')}"`,
      `"${entry.source_type}"`,
      `"${entry.source_id || '-'}"`,
      `"${entry.invoice_id || '-'}"`,
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `Cash_In_Report_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  },
};
