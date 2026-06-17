import { supabase } from 'src/boot/supabase';
import type { ThriftLedgerEntry } from '../types';

export const thriftLedgerRepository = {
  async fetchLedger(tenantId: number): Promise<ThriftLedgerEntry[]> {
    const { data, error } = await supabase
      .from('thrift_accounting_ledger')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('date', { ascending: false });
    if (error) throw error;
    return data as ThriftLedgerEntry[];
  },
};
