import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/database.types';

export type ThriftLedgerType = Database['public']['Enums']['thrift_ledger_type'];
export type ThriftLedgerSource = Database['public']['Enums']['thrift_ledger_source'];

export interface ThriftLedgerEntry {
  id: number;
  date: string;
  type: ThriftLedgerType;
  source: ThriftLedgerSource;
  amount: number;
  referenceId: number;
  note: string | null;
  createdAt: string;
}

export interface ListThriftLedgerParams {
  tenantId: number;
  dateFrom: string;
  dateTo: string;
  type?: ThriftLedgerType | null;
  page?: number;
  pageSize?: number;
}

export interface ThriftLedgerListMeta {
  total: number;
  page: number;
  pageSize: number;
}

function mapRow(row: Database['public']['Tables']['thrift_accounting_ledger']['Row']): ThriftLedgerEntry {
  return {
    id: row.id,
    date: row.date,
    type: row.type,
    source: row.source,
    amount: Number(row.amount) || 0,
    referenceId: row.reference_id,
    note: row.note,
    createdAt: row.created_at,
  };
}

export const thriftLedgerRepository = {
  async listEntries(params: ListThriftLedgerParams): Promise<{
    data: ThriftLedgerEntry[];
    meta: ThriftLedgerListMeta;
  }> {
    const page = Math.max(1, params.page ?? 1);
    const pageSize = Math.max(1, Math.min(100, params.pageSize ?? 25));
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;

    let query = supabase
      .from('thrift_accounting_ledger')
      .select(
        'id, date, type, source, amount, reference_id, note, created_at, tenant_id, inserted_by, updated_at',
        { count: 'exact' },
      )
      .eq('tenant_id', params.tenantId)
      .gte('date', params.dateFrom)
      .lte('date', params.dateTo)
      .order('date', { ascending: false })
      .order('id', { ascending: false })
      .range(from, to);

    if (params.type) {
      query = query.eq('type', params.type);
    }

    const { data, error, count } = await query;
    if (error) throw error;

    return {
      data: ((data || []) as Database['public']['Tables']['thrift_accounting_ledger']['Row'][]).map(
        mapRow,
      ),
      meta: {
        total: count ?? 0,
        page,
        pageSize,
      },
    };
  },
};
