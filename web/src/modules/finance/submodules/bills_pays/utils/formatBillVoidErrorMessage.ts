/** User-facing text for rpc_void_bill / rpc_void_pays failures. */
export function formatBillVoidErrorMessage(error: unknown): string {
  const raw =
    error instanceof Error
      ? error.message
      : typeof error === 'object' && error !== null && 'message' in error
        ? String((error as { message: unknown }).message)
        : 'Could not cancel bill.';
  const msg = raw.trim();
  if (/multi-bill pays/i.test(msg)) {
    return 'This payment also pays other bills. Open that payment and void it there first.';
  }
  if (/insufficient_balance/i.test(msg)) {
    return 'Not enough cash in the pot to undo this payment. The money was already spent or moved.';
  }
  if (/settlements;\s*reverse_payments must be true/i.test(msg)) {
    return 'This bill has payments on it. Use Cancel bill (not void without reversal).';
  }
  return msg || 'Could not cancel bill.';
}