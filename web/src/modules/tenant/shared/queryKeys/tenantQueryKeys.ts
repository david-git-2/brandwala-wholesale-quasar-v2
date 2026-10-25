export const tenantQueryKeys = {
  root: ['tenant'] as const,
  customerGroups: (tenantId: number | null) =>
    [...tenantQueryKeys.root, 'customerGroups', tenantId ?? 0] as const,
  /** Groups scoped by books (parent) tenant — shop access, dropship gifts, etc. */
  booksCustomerGroups: (booksTenantId: number) =>
    [...tenantQueryKeys.root, 'booksCustomerGroups', booksTenantId] as const,
  customerGroupMembers: (customerGroupId: number | null) =>
    [...tenantQueryKeys.root, 'customerGroupMembers', customerGroupId ?? 0] as const,
};
