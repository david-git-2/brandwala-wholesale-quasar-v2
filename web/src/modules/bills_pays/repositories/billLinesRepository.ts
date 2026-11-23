import { supabase } from 'src/boot/supabase';

export type BillLineDisplayRow = {
  id: number;
  line_kind: string;
  name_snapshot: string;
  currency_code: string;
  line_total_amount: number;
  books_amount: number;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount: number;
  line_meta: Record<string, unknown> | null;
};

export async function listBillLinesForInvoices(
  invoiceIds: number[],
): Promise<Array<BillLineDisplayRow & { invoice_id: number }>> {
  const ids = invoiceIds.filter((id) => id > 0);
  if (!ids.length) return [];
  const { data, error } = await (supabase as any).rpc('get_bill_lines_for_bills', {
    p_bill_ids: ids,
  });

  if (error) throw error;

  return ((data as Array<Record<string, unknown>> | null) ?? []).map((row) => ({
    id: Number(row.id),
    invoice_id: Number(row.bill_id),
    line_kind: String(row.line_kind ?? 'stock'),
    name_snapshot: String(row.name_snapshot ?? 'Line'),
    currency_code: String(row.currency_code ?? 'BDT').toUpperCase(),
    line_total_amount: Number(row.line_total_amount ?? 0),
    books_amount: Number(row.books_amount ?? row.line_total_amount ?? 0),
    quantity: Number(row.quantity ?? 1),
    sell_price_amount: Number(row.sell_price_amount ?? 0),
    line_discount_amount: Number(row.line_discount_amount ?? 0),
    line_meta: (row.line_meta as Record<string, unknown> | null) ?? null,
  }));
}

export async function listBillLinesForInvoice(invoiceId: number): Promise<BillLineDisplayRow[]> {
  const rows = await listBillLinesForInvoices([invoiceId]);
  return rows.map(({ invoice_id: _id, ...rest }) => rest);
}
