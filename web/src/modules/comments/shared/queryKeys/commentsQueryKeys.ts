const root = ['comments'] as const;

export const commentsQueryKeys = {
  root,
  list: (tenantId: number | null, entityType: string | null, entityId: string | null) =>
    [...root, 'list', tenantId, entityType, entityId] as const,
};