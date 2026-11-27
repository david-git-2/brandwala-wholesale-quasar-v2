import { defineStore } from 'pinia';
import { tagRepository } from '../repositories/tagRepository';
import type { Tag } from '../types';

export type TagsForCategoryParams = {
  categoryId?: number;
  moduleKey?: string;
  code?: string;
};

const cacheKey = (params: TagsForCategoryParams): string => {
  if (params.categoryId != null) return `id:${params.categoryId}`;
  return `mk:${params.moduleKey ?? ''}:code:${params.code ?? ''}`;
};

export const useTagStore = defineStore('tag', {
  state: () => ({
    tagsByKey: {} as Record<string, Tag[]>,
    loadedKeys: {} as Record<string, boolean>,
    loadingKeys: {} as Record<string, boolean>,
    inflight: {} as Record<string, Promise<Tag[]>>,
  }),

  actions: {
    clearCategory(params: TagsForCategoryParams) {
      const key = cacheKey(params);
      delete this.tagsByKey[key];
      delete this.loadedKeys[key];
      delete this.inflight[key];
    },

    async ensureTagsForCategory(
      params: TagsForCategoryParams,
      forceRefresh = false,
    ): Promise<Tag[]> {
      const key = cacheKey(params);

      if (!forceRefresh && (this.tagsByKey[key]?.length ?? 0) > 0) {
        return this.tagsByKey[key];
      }

      if (!forceRefresh && this.loadedKeys[key]) {
        return this.tagsByKey[key] ?? [];
      }

      const pending = this.inflight[key];
      if (pending) {
        return pending;
      }

      this.loadingKeys[key] = true;
      const request = tagRepository
        .listTagsForCategory(params)
        .then((tags) => {
          this.tagsByKey[key] = tags;
          this.loadedKeys[key] = true;
          return tags;
        })
        .finally(() => {
          delete this.inflight[key];
          this.loadingKeys[key] = false;
        });

      this.inflight[key] = request;
      return request;
    },
  },
});
