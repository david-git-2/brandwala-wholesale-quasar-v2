/** Kernel wholesale invoices (INV-WS numbering). Adjustments: write-off only for now. */
export const isInvWsWholesaleBill = (
  bill:
    | {
        invoice_type?: string | null;
        invoice_no?: string | null;
        spine?: string | null;
      }
    | null
    | undefined,
): boolean => {
  if (!bill || bill.invoice_type === 'ap') return false;
  if (bill.invoice_type !== 'wholesale') return false;
  if (bill.spine === 'kernel') return true;
  const no = String(bill.invoice_no ?? '').trim().toUpperCase();
  return no.startsWith('INV-WS');
};