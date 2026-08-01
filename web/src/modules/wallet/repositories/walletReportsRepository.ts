import { supabase } from 'src/boot/supabase';
import type { WalletStatementParams, WalletEntityStatement } from '../types';

export const walletReportsRepository = {
  /**
   * Fetch structured statement report for an entity within a date range.
   */
  async fetchEntityStatement(params: WalletStatementParams): Promise<WalletEntityStatement> {
    const { data, error } = await supabase.rpc('get_wallet_entity_statement', {
      p_tenant_id: params.tenantId,
      p_entity_type: params.entityType,
      p_entity_id: params.entityId,
      p_start_date: params.startDate ?? null,
      p_end_date: params.endDate ?? null,
    });

    if (error) {
      console.error('[walletReportsRepository.fetchEntityStatement error]:', error);
      throw error;
    }

    return (data as unknown as WalletEntityStatement) || {
      tenant_id: params.tenantId,
      entity_type: params.entityType,
      entity_id: params.entityId,
      start_date: params.startDate ?? null,
      end_date: params.endDate ?? null,
      opening_balance: 0,
      total_credits: 0,
      total_debits: 0,
      closing_balance: 0,
      entries: [],
    };
  },

  /**
   * Helper to trigger a CSV download for an entity account statement.
   */
  exportStatementToCsv(statement: WalletEntityStatement, entityLabel: string): void {
    const headers = [
      'Date & Time',
      'Transaction ID',
      'Source Type',
      'Source ID',
      'Type',
      'Amount (BDT)',
      'Running Balance (BDT)',
    ];

    const rows = (statement.entries || []).map((entry) => [
      `"${new Date(entry.created_at).toLocaleString()}"`,
      `"${entry.id}"`,
      `"${entry.source_type}"`,
      `"${entry.source_id || '-'}"`,
      `"${entry.type.toUpperCase()}"`,
      entry.type === 'debit' ? `-${Number(entry.amount).toFixed(2)}` : `+${Number(entry.amount).toFixed(2)}`,
      Number(entry.balance_after).toFixed(2),
    ]);

    const csvContent = [
      `"Account Statement - ${entityLabel}"`,
      `"Opening Balance: ${statement.opening_balance.toFixed(2)} BDT"`,
      `"Total Credits: +${statement.total_credits.toFixed(2)} BDT"`,
      `"Total Debits: -${statement.total_debits.toFixed(2)} BDT"`,
      `"Closing Balance: ${statement.closing_balance.toFixed(2)} BDT"`,
      '',
      headers.join(','),
      ...rows.map((r) => r.join(',')),
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute(
      'download',
      `statement_${statement.entity_type}_${statement.entity_id}_${new Date().toISOString().slice(0, 10)}.csv`,
    );
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  },
};
