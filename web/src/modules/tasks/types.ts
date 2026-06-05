export type ItemType =
  | 'project'
  | 'module'
  | 'submodule'
  | 'task'
  | 'note'
  | 'discussion'
  | 'bug'
  | 'feature';

export type ItemStatus =
  | 'todo'
  | 'in_progress'
  | 'review'
  | 'done'
  | 'blocked'
  | 'archived';

export type ItemPriority = 'low' | 'medium' | 'high' | 'urgent';

export type ItemAccessibility = 'public' | 'private' | 'restricted';

export type PermissionRole = 'owner' | 'manager' | 'editor' | 'viewer' | 'commenter';

export interface Item {
  id: number;
  tenant_id: number | null;
  parent_id: number | null;
  type: ItemType;
  title: string;
  content: string | null;
  status: ItemStatus;
  priority: ItemPriority;
  accessibility: ItemAccessibility;
  is_markdown: boolean;
  created_by_email: string;
  due_date: string | null;
  start_date: string | null;
  created_at: string;
  updated_at: string;
  archived_at: string | null;

  // UI derived
  assignees?: ItemAssignee[];
  tags?: Tag[];
  children?: Item[];
}

export interface ItemAssignee {
  id: number;
  item_id: number;
  user_email: string;
  assigned_by_email: string;
  created_at: string;
}

export interface Tag {
  id: number;
  tenant_id: number | null;
  name: string;
  slug: string;
  color: string;
  type: string;
  created_by_email: string;
  created_at: string;
}

export interface ItemTag {
  id: number;
  item_id: number;
  tag_id: number;
  created_at: string;
}

export interface Comment {
  id: number;
  item_id: number;
  parent_comment_id: number | null;
  user_email: string;
  body: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  replies?: Comment[];
}

export interface ItemPermission {
  id: number;
  item_id: number;
  user_email: string;
  role: PermissionRole;
  created_at: string;
}

export interface ActivityLog {
  id: number;
  item_id: number;
  user_email: string;
  action: string;
  old_value: string | null;
  new_value: string | null;
  created_at: string;
}

export interface GlobalSearchResult {
  id: number;
  tenant_id: number | null;
  tenant_name: string | null;
  parent_id: number | null;
  type: ItemType;
  title: string;
  content: string | null;
  status: ItemStatus;
  priority: ItemPriority;
  accessibility: ItemAccessibility;
  is_markdown: boolean;
  created_by_email: string;
  due_date: string | null;
  start_date: string | null;
  created_at: string;
  updated_at: string;
}
