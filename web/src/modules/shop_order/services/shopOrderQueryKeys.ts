export const shopOrderQueryKeys = {
  root: ['shop_order'] as const,
  detail: (tenantSlug: string | null, orderId: number) =>
    [...shopOrderQueryKeys.root, 'detail', tenantSlug ?? 'no-tenant', orderId] as const,
  couriers: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'couriers', tenantSlug ?? 'no-tenant'] as const,
  merchants: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'merchants', tenantSlug ?? 'no-tenant'] as const,
  ledger: (
    tenantSlug: string | null,
    filters: { memberId?: number | null; from?: string | null; to?: string | null } = {},
  ) =>
    [
      ...shopOrderQueryKeys.root,
      'ledger',
      tenantSlug ?? 'no-tenant',
      {
        memberId: filters.memberId ?? null,
        from: filters.from ?? null,
        to: filters.to ?? null,
      },
    ] as const,
  ledgerPendingCod: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'ledger_pending_cod', tenantSlug ?? 'no-tenant'] as const,
  ledgerRemittanceOrders: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'ledger_remittance_orders', tenantSlug ?? 'no-tenant'] as const,
};
