export const tenantQueryKeys = {
  root: ['tenant'] as const,
  customerGroups: (tenantId: number | null) =>
    [...tenantQueryKeys.root, 'customerGroups', tenantId ?? 0] as const,
  customerGroupMembers: (customerGroupId: number | null) =>
    [...tenantQueryKeys.root, 'customerGroupMembers', customerGroupId ?? 0] as const,
};
