export type ThriftLedgerType = 'REVENUE' | 'EXPENSE' | 'REFUND' | 'LOSS';
export type ThriftLedgerSource = 'INVOICE' | 'SHIPMENT' | 'OPERATIONAL';

export interface ThriftLedgerEntry {
  id: number;
  tenant_id: number;
  type: ThriftLedgerType;
  source: ThriftLedgerSource;
  reference_id: number;
  amount: number;
  date: string;
  inserted_by: string;
  note?: string;
  created_at: string;
  updated_at: string;
}
