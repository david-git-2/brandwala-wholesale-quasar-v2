export const accessControlQueryKeys = {
  all: ['accessControl'] as const,

  // Modules tab
  tenantModules: (tenantId: number) => ['accessControl', 'tenantModules', { tenantId }] as const,
  catalogModules: () => ['accessControl', 'catalogModules'] as const,

  // Roles tab
  tenantRoles: (tenantId: number, scope: 'app' | 'shop') =>
    ['accessControl', 'tenantRoles', { tenantId, scope }] as const,

  // Team members tab
  tenantMembers: (tenantId: number) => ['accessControl', 'tenantMembers', { tenantId }] as const,
  memberOverrideIds: (tenantId: number) =>
    ['accessControl', 'memberOverrideIds', { tenantId }] as const,

  // Customer Groups tab
  customerGroups: (tenantId: number) => ['accessControl', 'customerGroups', { tenantId }] as const,
  customerGroupMembers: (groupId: number) =>
    ['accessControl', 'customerGroupMembers', { groupId }] as const,
  cgmOverrideIds: (groupId: number) => ['accessControl', 'cgmOverrideIds', { groupId }] as const,
  billingProfiles: (tenantId: number) =>
    ['accessControl', 'billingProfiles', { tenantId }] as const,
  investors: () => ['accessControl', 'investors'] as const,
};
