export const customerQueryKeys = {
  root: ['customer'] as const,
  list: (tenantId: number | null, search?: string, page?: number, pageSize?: number) =>
    [
      ...customerQueryKeys.root,
      'list',
      tenantId ?? 0,
      search ?? '',
      page ?? 1,
      pageSize ?? 20,
    ] as const,
  detail: (tenantId: number | null, customerId: number) =>
    [...customerQueryKeys.root, 'detail', tenantId ?? 0, customerId] as const,
  members: (customerGroupId: number | null) =>
    [...customerQueryKeys.root, 'members', customerGroupId ?? 0] as const,
  account: (tenantId: number | null, customerGroupId: number | null) =>
    [...customerQueryKeys.root, 'account', tenantId ?? 0, customerGroupId ?? 0] as const,
};
