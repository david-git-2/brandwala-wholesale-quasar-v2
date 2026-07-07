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
    pageSize: 25,
    totalPages: 1,
    statusCounts: {
      todo: 0,
      in_progress: 0,
      review: 0,
      done: 0,
      blocked: 0,
      archived: 0,
    },
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
        tagId?: number | null;
        dateField?: string | null;
        dateFrom?: string | null;
        dateTo?: string | null;
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
        this.statusCounts = {
          todo: Number(result.statusCounts?.todo ?? 0),
          in_progress: Number(result.statusCounts?.in_progress ?? 0),
          review: Number(result.statusCounts?.review ?? 0),
          done: Number(result.statusCounts?.done ?? 0),
          blocked: Number(result.statusCounts?.blocked ?? 0),
          archived: Number(result.statusCounts?.archived ?? 0),
        };
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
        newItem.tags = [];
        newItem.assignees = [];
        this.items.push(newItem);
        this.totalItems++;
        this.totalPages = Math.max(1, Math.ceil(this.totalItems / this.pageSize));
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
        this.totalItems = Math.max(0, this.totalItems - idsToRemove.length);
        this.totalPages = Math.max(1, Math.ceil(this.totalItems / this.pageSize));
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete item';
        throw err;
      }
    },

    async deleteItemsBulk(ids: number[]) {
      try {
        await tasksRepository.deleteItemsBulk(ids);

        const getDescendantIds = (parentId: number): number[] => {
          const children = this.items.filter(i => i.parent_id === parentId);
          let descendantIds = children.map(c => c.id);
          children.forEach(c => {
            descendantIds = descendantIds.concat(getDescendantIds(c.id));
          });
          return descendantIds;
        };

        const allIdsToRemove = new Set<number>();
        ids.forEach(id => {
          allIdsToRemove.add(id);
          getDescendantIds(id).forEach(dId => allIdsToRemove.add(dId));
        });

        const removedCount = this.items.filter(i => allIdsToRemove.has(i.id)).length;
        this.items = this.items.filter(i => !allIdsToRemove.has(i.id));
        this.totalItems = Math.max(0, this.totalItems - removedCount);
        this.totalPages = Math.max(1, Math.ceil(this.totalItems / this.pageSize));
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to delete items';
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

    async updateTag(id: number, updates: Partial<Tag>) {
      try {
        const updatedTag = await tasksRepository.updateTag(id, updates);
        const index = this.tags.findIndex(t => t.id === id);
        if (index !== -1) {
          this.tags[index] = { ...this.tags[index], ...updatedTag };
        }

        // Propagate tag update to items cache
        this.items.forEach(item => {
          if (item.tags) {
            const tIndex = item.tags.findIndex(t => t.id === id);
            if (tIndex !== -1) {
              item.tags[tIndex] = { ...item.tags[tIndex], ...updatedTag };
            }
          }
        });

        return updatedTag;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to update tag';
        throw err;
      }
    },

    async deleteTag(tagId: number) {
      try {
        await tasksRepository.deleteTag(tagId);
        this.tags = this.tags.filter(t => t.id !== tagId);

        // Remove tag from items cache
        this.items.forEach(item => {
          if (item.tags) {
            item.tags = item.tags.filter(t => t.id !== tagId);
          }
        });
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

        // Update local cache
        const item = this.items.find(i => i.id === itemId);
        if (item) {
          const tag = this.tags.find(t => t.id === tagId);
          if (tag) {
            item.tags = item.tags || [];
            if (!item.tags.some(t => t.id === tagId)) {
              item.tags.push(tag);
            }
          }
        }
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

        // Update local cache
        const item = this.items.find(i => i.id === itemId);
        if (item && item.tags) {
          item.tags = item.tags.filter(t => t.id !== tagId);
        }
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

        // Update local cache
        const item = this.items.find(i => i.id === itemId);
        if (item) {
          item.assignees = item.assignees || [];
          if (!item.assignees.some(a => a.user_email === email)) {
            item.assignees.push(ass);
          }
        }

        return ass;
      } catch (err: unknown) {
        this.error = (err as Error).message || 'Failed to add assignee';
        throw err;
      }
    },

    async removeAssignee(itemId: number, email: string) {
      try {
        await tasksRepository.removeAssignee(itemId, email);

        // Update local cache
        const item = this.items.find(i => i.id === itemId);
        if (item && item.assignees) {
          item.assignees = item.assignees.filter(a => a.user_email !== email);
        }
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
