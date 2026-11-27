/** Kernel wholesale invoices (INV-WS numbering). Adjustments: write-off only for now. */
export const isInvWsWholesaleBill = (
  bill:
    | {
        invoice_type?: string | null;
        invoice_no?: string | null;
      }
    | null
    | undefined,
): boolean => {
  if (!bill || bill.invoice_type === 'ap') return false;
  return bill.invoice_type === 'wholesale';
};