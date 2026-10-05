export type PaymentsListSide = 'in' | 'out';

export const parsePaymentsListSide = (value: unknown): PaymentsListSide =>
  value === 'out' ? 'out' : 'in';

export const paySourceToListSide = (source: string | null | undefined): PaymentsListSide =>
  source === 'ap_payout' ? 'out' : 'in';

export const paymentsPageRoute = (
  tenantSlug: string | undefined,
  side: PaymentsListSide,
): { name: 'app-payments-page'; params?: { tenantSlug: string }; query: { side: PaymentsListSide } } => ({
  name: 'app-payments-page',
  ...(tenantSlug ? { params: { tenantSlug } } : {}),
  query: { side },
});
