import { supabase } from 'src/boot/supabase';
import type {
  Item,
  ItemAssignee,
  Tag,
  Comment,
  ItemPermission,
  ActivityLog,
  GlobalSearchResult,
} from '../types';

export const tasksRepository = {
  // --- Items ---
  async fetchItems(
    tenantId: number | null,
    filters?: {
      search?: string;
      type?: string | null;
      status?: string | null;
      priority?: string | null;
      assignee?: string | null;
      myTasksEmail?: string | null;
      includeParents?: boolean;
      tagId?: number | null;
    },
    page: number = 1,
    pageSize: number = 20
  ): Promise<{ data: Item[]; total: number; statusCounts?: Record<string, number> }> {
    const { data, error } = await supabase.rpc('list_items_paginated', {
      p_tenant_id: tenantId,
      p_page: page,
      p_page_size: pageSize,
      p_search: filters?.search || null,
      p_type: filters?.type || null,
      p_status: filters?.status || null,
      p_priority: filters?.priority || null,
      p_assignee: filters?.assignee || null,
      p_my_tasks_email: filters?.myTasksEmail || null,
      p_include_parents: filters?.includeParents || false,
      p_tag_id: filters?.tagId || null,
    });

    if (error) throw error;

    const result = data as unknown as {
      data: Item[];
      meta: {
        total_count: number;
        page: number;
        page_size: number;
        total_pages: number;
        status_counts?: Record<string, number>;
      };
    };

    return {
      data: result.data || [],
      total: result.meta?.total_count || 0,
      statusCounts: result.meta?.status_counts || {
        todo: 0,
        in_progress: 0,
        review: 0,
        done: 0,
        blocked: 0,
        archived: 0,
      },
    };
  },

  async fetchItemDetails(id: number): Promise<Item> {
    const { data, error } = await supabase.from('items').select('*').eq('id', id).single();
    if (error) throw error;
    return data as Item;
  },

  async fetchFullItemDetails(itemId: number): Promise<{
    item: Item;
    assignees: ItemAssignee[];
    tags: Tag[];
    comments: Comment[];
    permissions: ItemPermission[];
    activityLogs: ActivityLog[];
  }> {
    const { data, error } = await supabase.rpc('get_item_details', {
      p_item_id: itemId,
    });
    if (error) throw error;

    const result = data as unknown as {
      item: Item;
      assignees: ItemAssignee[];
      tags: Tag[];
      comments: Comment[];
      permissions: ItemPermission[];
      activity_logs: ActivityLog[];
    };

    return {
      item: result.item,
      assignees: result.assignees || [],
      tags: result.tags || [],
      comments: result.comments || [],
      permissions: result.permissions || [],
      activityLogs: result.activity_logs || [],
    };
  },

  async createItem(item: Partial<Item>): Promise<Item> {
    const { data, error } = await supabase.from('items').insert(item).select().single();
    if (error) throw error;
    return data as Item;
  },

  async updateItem(id: number, item: Partial<Item>): Promise<Item> {
    const { data, error } = await supabase.from('items').update(item).eq('id', id).select().single();
    if (error) throw error;
    return data as Item;
  },

  async deleteItem(id: number): Promise<void> {
    const { error } = await supabase.from('items').delete().eq('id', id);
    if (error) throw error;
  },

  async deleteItemsBulk(ids: number[]): Promise<void> {
    const { error } = await supabase.from('items').delete().in('id', ids);
    if (error) throw error;
  },

  // --- Assignees ---
  async fetchItemAssignees(itemId: number): Promise<ItemAssignee[]> {
    const { data, error } = await supabase
      .from('item_assignees')
      .select('*')
      .eq('item_id', itemId);
    if (error) throw error;
    return data as ItemAssignee[];
  },

  async addAssignee(itemId: number, userEmail: string): Promise<ItemAssignee> {
    const { data, error } = await supabase
      .from('item_assignees')
      .insert({ item_id: itemId, user_email: userEmail })
      .select()
      .single();
    if (error) throw error;
    return data as ItemAssignee;
  },

  async removeAssignee(itemId: number, userEmail: string): Promise<void> {
    const { error } = await supabase
      .from('item_assignees')
      .delete()
      .eq('item_id', itemId)
      .eq('user_email', userEmail);
    if (error) throw error;
  },

  // --- Tags ---
  async fetchTags(tenantId: number | null): Promise<Tag[]> {
    let query = supabase.from('tags').select('*');
    if (tenantId !== null) {
      query = query.or(`tenant_id.eq.${tenantId},tenant_id.is.null`);
    } else {
      query = query.is('tenant_id', null);
    }
    const { data, error } = await query.order('name', { ascending: true });
    if (error) throw error;
    return data as Tag[];
  },

  async createTag(tag: Partial<Tag>): Promise<Tag> {
    const { data, error } = await supabase.from('tags').insert(tag).select().single();
    if (error) throw error;
    return data as Tag;
  },

  async updateTag(id: number, tag: Partial<Tag>): Promise<Tag> {
    const { data, error } = await supabase.from('tags').update(tag).eq('id', id).select().single();
    if (error) throw error;
    return data as Tag;
  },

  async deleteTag(id: number): Promise<void> {
    const { error } = await supabase.from('tags').delete().eq('id', id);
    if (error) throw error;
  },

  // --- Item Tags (Many-to-Many) ---
  async fetchItemTags(itemId: number): Promise<Tag[]> {
    const { data, error } = await supabase
      .from('item_tags')
      .select('tags (*)')
      .eq('item_id', itemId);
    if (error) throw error;
    const rows = (data || []) as unknown as { tags: Tag | null }[];
    return rows.map((row) => row.tags).filter((t): t is Tag => t !== null);
  },

  async linkTagToItem(itemId: number, tagId: number): Promise<void> {
    const { error } = await supabase
      .from('item_tags')
      .insert({ item_id: itemId, tag_id: tagId });
    if (error) throw error;
  },

  async unlinkTagFromItem(itemId: number, tagId: number): Promise<void> {
    const { error } = await supabase
      .from('item_tags')
      .delete()
      .eq('item_id', itemId)
      .eq('tag_id', tagId);
    if (error) throw error;
  },

  // --- Comments ---
  async fetchComments(itemId: number): Promise<Comment[]> {
    const { data, error } = await supabase
      .from('comments')
      .select('*')
      .eq('item_id', itemId)
      .order('created_at', { ascending: true });
    if (error) throw error;
    return data as Comment[];
  },

  async addComment(
    itemId: number,
    body: string,
    parentCommentId: number | null = null,
  ): Promise<Comment> {
    const { data, error } = await supabase
      .from('comments')
      .insert({
        item_id: itemId,
        body,
        parent_comment_id: parentCommentId,
      })
      .select()
      .single();
    if (error) throw error;
    return data as Comment;
  },

  async deleteComment(id: number): Promise<void> {
    const { error } = await supabase.from('comments').delete().eq('id', id);
    if (error) throw error;
  },

  // --- Permissions ---
  async fetchPermissions(itemId: number): Promise<ItemPermission[]> {
    const { data, error } = await supabase
      .from('item_permissions')
      .select('*')
      .eq('item_id', itemId);
    if (error) throw error;
    return data as ItemPermission[];
  },

  async savePermission(
    itemId: number,
    userEmail: string,
    role: string,
  ): Promise<ItemPermission> {
    const { data, error } = await supabase
      .from('item_permissions')
      .upsert({
        item_id: itemId,
        user_email: userEmail,
        role,
      })
      .select()
      .single();
    if (error) throw error;
    return data as ItemPermission;
  },

  async deletePermission(itemId: number, userEmail: string): Promise<void> {
    const { error } = await supabase
      .from('item_permissions')
      .delete()
      .eq('item_id', itemId)
      .eq('user_email', userEmail);
    if (error) throw error;
  },

  // --- Global Search RPC ---
  async globalSearch(query: string): Promise<GlobalSearchResult[]> {
    const { data, error } = await supabase.rpc('global_search_tasks', {
      p_query: query,
    });
    if (error) throw error;
    return data as GlobalSearchResult[];
  },

  // --- Activity Logs ---
  async fetchActivityLogs(itemId: number): Promise<ActivityLog[]> {
    const { data, error } = await supabase
      .from('activity_logs')
      .select('*')
      .eq('item_id', itemId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data as ActivityLog[];
  },

  async createActivityLog(log: Partial<ActivityLog>): Promise<ActivityLog> {
    const { data, error } = await supabase
      .from('activity_logs')
      .insert(log)
      .select()
      .single();
    if (error) throw error;
    return data as ActivityLog;
  },

  // --- Users/Members of Tenant helper (for assignees / permissions lists) ---
  async fetchTenantMembers(tenantId: number): Promise<{ email: string; role: string }[]> {
    const { data, error } = await supabase
      .from('memberships')
      .select('email, role')
      .eq('tenant_id', tenantId)
      .eq('is_active', true);
    if (error) throw error;
    return data || [];
  },
};
