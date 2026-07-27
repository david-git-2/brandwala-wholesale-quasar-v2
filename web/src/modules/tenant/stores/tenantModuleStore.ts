import { defineStore } from 'pinia';

import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { tenantService } from '../services/tenantService';
import type {
  TenantModule,
  TenantModuleCreateInput,
  TenantModuleDeleteInput,
  TenantModuleUpdateInput,
  TenantModuleSubmoduleSetInput,
} from '../types';

export const useTenantModuleStore = defineStore('tenantModule', {
  state: () => ({
    items: [] as TenantModule[],
    loading: false,
    error: null as string | null,
  }),

  actions: {
    clearError() {
      this.error = null;
    },

    async fetchTenantModules(tenantId?: number) {
      this.loading = true;
      this.error = null;

      try {
        const result = await tenantService.listTenantModules(tenantId);

        if (!result.success) {
          this.error = result.error ?? 'Failed to load modules.';
          handleApiFailure(result, this.error);
          return result;
        }

        this.items = result.data ?? [];
        return result;
      } finally {
        this.loading = false;
      }
    },

    async createTenantModule(payload: TenantModuleCreateInput) {
      this.loading = true;
      this.error = null;

      try {
        const result = await tenantService.createTenantModule(payload);

        if (!result.success) {
          this.error = result.error ?? 'Failed to create module.';
          handleApiFailure(result, this.error);
          return result;
        }

        if (result.data) {
          this.items.push(result.data);
        }

        showSuccessNotification('Feature added successfully.');
        return result;
      } finally {
        this.loading = false;
      }
    },

    async updateTenantModule(payload: TenantModuleUpdateInput) {
      this.loading = true;
      this.error = null;

      try {
        const result = await tenantService.updateTenantModule(payload);

        if (!result.success) {
          this.error = result.error ?? 'Failed to update module.';
          handleApiFailure(result, this.error);
          return result;
        }

        const updated = result.data;

        if (updated) {
          const index = this.items.findIndex((item) => item.id === updated.id);

          if (index >= 0) {
            this.items.splice(index, 1, updated);
          }
        }

        showSuccessNotification('Feature updated successfully.');
        return result;
      } finally {
        this.loading = false;
      }
    },

    async deleteTenantModule(payload: TenantModuleDeleteInput) {
      this.loading = true;
      this.error = null;

      try {
        const result = await tenantService.deleteTenantModule(payload);

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete module.';
          handleApiFailure(result, this.error);
          return result;
        }

        this.items = this.items.filter((item) => item.id !== payload.id);
        showSuccessNotification('Feature removed successfully.');
        return result;
      } finally {
        this.loading = false;
      }
    },

    async createTenantModuleWithSubmodules(
      tenantId: number,
      parentModuleKey: string,
      submoduleKeys: string[],
    ) {
      this.error = null;

      try {
        const result = await tenantService.createTenantModuleWithSubmodules(
          tenantId,
          parentModuleKey,
          submoduleKeys,
        );

        if (!result.success) {
          this.error = result.error ?? 'Failed to create feature and submodules.';
          handleApiFailure(result, this.error);
          return result;
        }

        if (result.data) {
          result.data.forEach((m) => {
            if (!this.items.some((existing) => existing.id === m.id)) {
              this.items.push(m);
            }
          });
        }

        showSuccessNotification('Feature added successfully.');
        return result;
      } catch (err) {
        console.error(err);
        this.error = 'Failed to create feature and submodules.';
        return { success: false, error: this.error };
      }
    },

    async deleteTenantModuleWithSubmodules(tenantId: number, moduleKeys: string[]) {
      this.error = null;

      // Optimistically remove from store for smooth UI transition
      const previousItems = [...this.items];
      this.items = this.items.filter((item) => !moduleKeys.includes(item.module_key));

      try {
        const result = await tenantService.deleteTenantModuleWithSubmodules(tenantId, moduleKeys);

        if (!result.success) {
          // Revert optimistic update on failure
          this.items = previousItems;
          this.error = result.error ?? 'Failed to remove feature and submodules.';
          handleApiFailure(result, this.error);
          return result;
        }

        showSuccessNotification('Feature removed successfully.');
        return result;
      } catch (err) {
        // Revert optimistic update on exception
        this.items = previousItems;
        console.error(err);
        this.error = 'Failed to remove feature and submodules.';
        return { success: false, error: this.error };
      }
    },

    async listSubmoduleOverrides(tenantId: number, parentModuleKey: string) {
      return tenantService.listTenantModuleSubmodules(tenantId, parentModuleKey);
    },

    async setSubmoduleOverride(payload: TenantModuleSubmoduleSetInput) {
      this.error = null;
      const result = await tenantService.setTenantModuleSubmodule(payload);
      if (!result.success) {
        this.error = result.error ?? 'Failed to update submodule access.';
        handleApiFailure(result, this.error);
      }
      return result;
    },
  },
});

