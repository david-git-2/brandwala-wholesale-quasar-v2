export const customerQueryKeys = {
  root: ['customer'] as const,
  list: (tenantId: number | null, search?: string) =>
    [...customerQueryKeys.root, 'list', tenantId ?? 0, search ?? ''] as const,
  detail: (tenantId: number | null, customerId: number) =>
    [...customerQueryKeys.root, 'detail', tenantId ?? 0, customerId] as const,
  members: (customerGroupId: number | null) =>
    [...customerQueryKeys.root, 'members', customerGroupId ?? 0] as const,
};
