import { supabase } from 'src/boot/supabase';

export type BillLineDisplayRow = {
  id: number;
  name_snapshot: string;
  currency_code: string;
  line_total_amount: number;
  books_amount: number;
  quantity: number;
};

export async function listBillLinesForInvoices(
  invoiceIds: number[],
): Promise<Array<BillLineDisplayRow & { invoice_id: number }>> {
  const ids = invoiceIds.filter((id) => id > 0);
  if (!ids.length) return [];
  const { data, error } = await supabase
    .from('bill_lines')
    .select('id, invoice_id, name_snapshot, currency_code, line_total_amount, books_amount, quantity')
    .in('invoice_id', ids)
    .order('id');

  if (error) throw error;

  return (data ?? []).map((row) => ({
    id: Number(row.id),
    invoice_id: Number(row.invoice_id),
    name_snapshot: row.name_snapshot ?? 'Line',
    currency_code: (row.currency_code ?? 'BDT').toUpperCase(),
    line_total_amount: Number(row.line_total_amount ?? 0),
    books_amount: Number(row.books_amount ?? row.line_total_amount ?? 0),
    quantity: Number(row.quantity ?? 1),
  }));
}

export async function listBillLinesForInvoice(invoiceId: number): Promise<BillLineDisplayRow[]> {
  const rows = await listBillLinesForInvoices([invoiceId]);
  return rows.map(({ invoice_id: _id, ...rest }) => rest);
}
