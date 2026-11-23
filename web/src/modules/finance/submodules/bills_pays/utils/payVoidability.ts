export const VOIDABLE_PAY_SOURCES = new Set([
  'customer_cash',
  'bank',
  'ap_payout',
  'commission',
  'courier_remittance',
]);

export function isPayVoidable(params: {
  source: string | null | undefined;
  method: string | null | undefined;
  voidedAt: string | null | undefined;
}): boolean {
  if (params.voidedAt) return false;
  if (params.source === 'store_credit' || params.method === 'wallet_credit') return false;
  const src = params.source ?? '';
  return VOIDABLE_PAY_SOURCES.has(src);
}
