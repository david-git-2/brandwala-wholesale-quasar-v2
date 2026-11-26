import { supabase } from 'src/boot/supabase';
import type {
  AddCommentParams,
  Comment,
  ListCommentsParams,
  SoftDeleteCommentParams,
} from '../types';

function parseCommentRows(data: unknown): Comment[] {
  if (!Array.isArray(data)) return [];
  return data.filter(
    (row): row is Comment =>
      row != null
      && typeof row === 'object'
      && typeof (row as Comment).id === 'number'
      && typeof (row as Comment).body === 'string',
  );
}

function parseCommentRow(data: unknown): Comment {
  if (data == null || typeof data !== 'object') {
    throw new Error('Invalid comment response.');
  }
  const row = data as Comment;
  if (typeof row.id !== 'number' || typeof row.body !== 'string') {
    throw new Error('Invalid comment response.');
  }
  return row;
}

const listComments = async (params: ListCommentsParams): Promise<Comment[]> => {
  const { data, error } = await supabase.rpc('list_comments', {
    p_tenant_id: params.tenantId,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
  });
  if (error) throw error;
  return parseCommentRows(data);
};

const addComment = async (params: AddCommentParams): Promise<Comment> => {
  const { data, error } = await supabase.rpc('add_comment', {
    p_tenant_id: params.tenantId,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
    p_body: params.body,
  });
  if (error) throw error;
  return parseCommentRow(data);
};

const softDeleteComment = async (params: SoftDeleteCommentParams): Promise<void> => {
  const { error } = await supabase.rpc('soft_delete_comment', {
    p_tenant_id: params.tenantId,
    p_comment_id: params.commentId,
  });
  if (error) throw error;
};

export const commentsRepository = {
  listComments,
  addComment,
  softDeleteComment,
};