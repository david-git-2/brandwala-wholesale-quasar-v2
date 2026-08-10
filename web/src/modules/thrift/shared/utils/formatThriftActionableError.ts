/** Map low-level thrift failures into a next-step message for toasts. */
export function formatThriftActionableError(err: unknown, fallback: string): string {
  const msg =
    typeof err === 'string'
      ? err
      : (err as { message?: string; details?: string; hint?: string })?.message ||
        (err as { details?: string })?.details ||
        '';
  const lower = msg.toLowerCase();

  if (
    lower.includes('permission') ||
    lower.includes('not authorized') ||
    lower.includes('row-level security') ||
    lower.includes('42501')
  ) {
    return 'Missing permission for this thrift action. Ask an admin to update your grants.';
  }

  if (
    (lower.includes('barcode') &&
      (lower.includes('duplicate') || lower.includes('unique') || lower.includes('already'))) ||
    lower.includes('thrift_stocks_barcode')
  ) {
    return 'That barcode is already used. Pick another available barcode.';
  }

  if (
    lower.includes('no available barcode') ||
    lower.includes('barcode pool') ||
    (lower.includes('barcode') && lower.includes('required') && lower.includes('generate'))
  ) {
    return 'Generate barcodes first (Thrift → Barcodes), then try again.';
  }

  if (
    lower.includes('not available') ||
    lower.includes('already sold') ||
    lower.includes('insufficient') ||
    lower.includes('oversell')
  ) {
    return msg || 'This item is no longer available to sell. Refresh and try another barcode.';
  }

  return msg || fallback;
}
