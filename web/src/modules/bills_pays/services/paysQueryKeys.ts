export const paysQueryKeys = {
  root: ['bills_pays', 'pays'] as const,
  list: (tenantId: number | null, params: Record<string, unknown>) =>
    [...paysQueryKeys.root, 'list', tenantId ?? 0, params] as const,
  detail: (payId: number | null) => [...paysQueryKeys.root, 'detail', payId ?? 0] as const,
  paymentSummary: (tenantId: number | null, search: string) =>
    [...paysQueryKeys.root, 'payment_summary', tenantId ?? 0, search] as const,
  payoutSummary: (tenantId: number | null, search: string) =>
    [...paysQueryKeys.root, 'payout_summary', tenantId ?? 0, search] as const,
  remitQueue: (tenantId: number | null) => [...paysQueryKeys.root, 'remit_queue', tenantId ?? 0] as const,
};
