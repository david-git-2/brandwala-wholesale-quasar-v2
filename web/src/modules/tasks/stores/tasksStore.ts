import { defineStore } from 'pinia';
import { tasksRepository } from '../repositories/tasksRepository';
import type { Item, Tag, GlobalSearchResult } from '../types';

export const useTasksStore = defineStore('tasks', {
  state: () => ({
    items: [] as Item[],
    tags: [] as Tag[],
    members: [] as { email: string; role: string }[],
    loading: false,
    error: null as string | null,
    searchResults: [] as GlobalSearchResult[],
    searchLoading: false,
    totalItems: 0,
    currentPage: 1,
    pageSize: 20,
    totalPages: 1,
  }),

  getters: {
    // Builds the hierarchical tree structure of Project -> Module -> Submodule -> Task etc.
    itemsTree(state): Item[] {
      const map: Record<number, Item> = {};
      const roots: Item[] = [];

      // Create cloned structure with children array initialized
      const cloned = state.items.map((item) => ({
        ...item,
        children: [] as Item[],
      }));

      cloned.forEach((item) => {
        map[item.id] = item;
      });

      cloned.forEach((item) => {
        if (item.parent_id) {
          const parent = map[item.parent_id];
          if (parent) {
            parent.children = parent.children || [];
            parent.children.push(item);
          } else {
            roots.push(item);
          }
        } else {
          roots.push(item);
        }
      });

      return roots;
    },
  },

  actions: {
    async loadWorkspaceData(tenantId: number | null) {
      this.loading = true;
      this.error = null;
      try {
        const tagsData = await tasksRepository.fetchTags(tenantId);
        this.tags = tagsData;

        if (tenantId !== null) {
          this.members = await tasksRepository.fetchTenantMembers(tenantId);
        } else {
          this.members = [];
        }
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to load task management metadata';
      } finally {
        this.loading = false;
      }
    },

    async fetchItemsAction(
      tenantId: number | null,
      filters?: {
        search?: string;
        type?: string | null;
        status?: string | null;
        priority?: string | null;
        assignee?: string | null;
        myTasksEmail?: string | null;
        includeParents?: boolean;
      },
      page: number = 1,
      pageSize: number = 20
    ) {
      this.loading = true;
      this.error = null;
      try {
        const result = await tasksRepository.fetchItems(tenantId, filters, page, pageSize);
        this.items = result.data;
        this.totalItems = result.total;
        this.currentPage = page;
        this.pageSize = pageSize;
        this.totalPages = Math.max(1, Math.ceil(result.total / pageSize));
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to fetch items';
      } finally {
        this.loading = false;
      }
    },

    // --- Item CRUD Actions ---
    async createItem(item: Partial<Item>) {
      this.loading = true;
      try {
        const newItem = await tasksRepository.createItem(item);
        this.items.push(newItem);
        await tasksRepository.createActivityLog({
          item_id: newItem.id,
          action: 'created',
          new_value: newItem.title,
        });
        return newItem;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create item';
        throw err;
      } finally {
        this.loading = false;
      }
    },

    async updateItem(id: number, updates: Partial<Item>) {
      try {
        const oldItem = this.items.find(i => i.id === id);
        const updatedItem = await tasksRepository.updateItem(id, updates);
        
        // Update local state
        const index = this.items.findIndex(i => i.id === id);
        if (index !== -1) {
          this.items[index] = { ...this.items[index], ...updatedItem };
        }

        // Log actions for changed properties
        if (oldItem) {
          if (updates.status && oldItem.status !== updates.status) {
            await tasksRepository.createActivityLog({
              item_id: id,
              action: 'status_changed',
              old_value: oldItem.status,
              new_value: updates.status,
            });
          }
          if (updates.priority && oldItem.priority !== updates.priority) {
            await tasksRepository.createActivityLog({
              item_id: id,
              action: 'priority_changed',
              old_value: oldItem.priority,
              new_value: updates.priority,
            });
          }
        }
        return updatedItem;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update item';
        throw err;
      }
    },

    async deleteItem(id: number) {
      try {
        await tasksRepository.deleteItem(id);
        
        const getDescendantIds = (parentId: number): number[] => {
          const children = this.items.filter(i => i.parent_id === parentId);
          let ids = children.map(c => c.id);
          children.forEach(c => {
            ids = ids.concat(getDescendantIds(c.id));
          });
          return ids;
        };

        const idsToRemove = [id, ...getDescendantIds(id)];
        this.items = this.items.filter(i => !idsToRemove.includes(i.id));
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete item';
        throw err;
      }
    },

    // --- Tag Actions ---
    async createTag(tag: Partial<Tag>) {
      try {
        const newTag = await tasksRepository.createTag(tag);
        this.tags.push(newTag);
        return newTag;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to create tag';
        throw err;
      }
    },

    async deleteTag(tagId: number) {
      try {
        await tasksRepository.deleteTag(tagId);
        this.tags = this.tags.filter(t => t.id !== tagId);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete tag';
        throw err;
      }
    },

    // --- Item Tags ---
    async linkTag(itemId: number, tagId: number) {
      try {
        await tasksRepository.linkTagToItem(itemId, tagId);
        await tasksRepository.createActivityLog({
          item_id: itemId,
          action: 'tag_added',
          new_value: String(tagId),
        });
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to link tag';
        throw err;
      }
    },

    async unlinkTag(itemId: number, tagId: number) {
      try {
        await tasksRepository.unlinkTagFromItem(itemId, tagId);
        await tasksRepository.createActivityLog({
          item_id: itemId,
          action: 'tag_removed',
          new_value: String(tagId),
        });
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to unlink tag';
        throw err;
      }
    },

    // --- Assignee Actions ---
    async addAssignee(itemId: number, email: string) {
      try {
        const ass = await tasksRepository.addAssignee(itemId, email);
        await tasksRepository.createActivityLog({
          item_id: itemId,
          action: 'assigned',
          new_value: email,
        });
        return ass;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to add assignee';
        throw err;
      }
    },

    async removeAssignee(itemId: number, email: string) {
      try {
        await tasksRepository.removeAssignee(itemId, email);
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to remove assignee';
        throw err;
      }
    },

    // --- Global Search RPC ---
    async runGlobalSearch(query: string) {
      this.searchLoading = true;
      try {
        if (!query.trim()) {
          this.searchResults = [];
          return;
        }
        this.searchResults = await tasksRepository.globalSearch(query);
      } catch (err: unknown) {
        console.error('[Search Error]', err);
      } finally {
        this.searchLoading = false;
      }
    },
  },
});
