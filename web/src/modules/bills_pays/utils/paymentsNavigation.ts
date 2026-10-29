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

export type PaymentsDeskView = 'profiles' | 'recent';

export type PaymentsProfileTab = 'tenant' | 'customer' | 'courier' | 'vendor';

const PAYMENTS_DESK_VIEWS = new Set<PaymentsDeskView>(['profiles', 'recent']);
const PAYMENTS_PROFILE_TABS = new Set<PaymentsProfileTab>([
  'tenant',
  'customer',
  'courier',
  'vendor',
]);

export const parsePaymentsDeskView = (value: unknown): PaymentsDeskView => {
  const raw = typeof value === 'string' ? value : '';
  return PAYMENTS_DESK_VIEWS.has(raw as PaymentsDeskView) ? (raw as PaymentsDeskView) : 'profiles';
};

export const parsePaymentsProfileTab = (value: unknown): PaymentsProfileTab => {
  const raw = typeof value === 'string' ? value : '';
  return PAYMENTS_PROFILE_TABS.has(raw as PaymentsProfileTab)
    ? (raw as PaymentsProfileTab)
    : 'customer';
};
