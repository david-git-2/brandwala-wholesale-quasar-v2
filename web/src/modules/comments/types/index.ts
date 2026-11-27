export type Comment = {
  id: number;
  tenant_id: number;
  entity_type: string;
  entity_id: string;
  body: string;
  created_by: string;
  created_at: string;
};

export type ListCommentsParams = {
  tenantId: number;
  entityType: string;
  entityId: string;
};

export type AddCommentParams = ListCommentsParams & {
  body: string;
};

export type SoftDeleteCommentParams = {
  tenantId: number;
  commentId: number;
};