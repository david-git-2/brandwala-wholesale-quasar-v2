import { defineStore } from 'pinia';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { customerProfileRepository } from '../repositories/customerProfileRepository';
import type {
  CustomerProfile,
  CustomerProfileListQuery,
  CreateCustomerProfileInput,
  UpdateCustomerProfileInput,
} from '../repositories/customerProfileRepository';

const loadPromises = new Map<number, Promise<CustomerProfile[]>>();

const FULL_LIST_PAGE_SIZE = 1000;

function tenantIdsForProfile(profile: CustomerProfile): number[] {
  const ids = new Set<number>();
  if (typeof profile.parent_tenant_id === 'number') ids.add(profile.parent_tenant_id);
  if (typeof profile.operating_tenant_id === 'number') ids.add(profile.operating_tenant_id);
  return [...ids];
}

export interface CustomerProfileStoreState {
  byTenantId: Record<number, CustomerProfile[]>;
  loadedTenantIds: Record<number, true>;
  loadingTenantId: number | null;
  items: CustomerProfile[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
  loading: boolean;
  saving: boolean;
  error: string | null;
}

export const useCustomerProfileStore = defineStore('customerProfile', {
  state: (): CustomerProfileStoreState => ({
    byTenantId: {},
    loadedTenantIds: {},
    loadingTenantId: null,
    items: [],
    total: 0,
    page: 1,
    page_size: 20,
    total_pages: 1,
    loading: false,
    saving: false,
    error: null,
  }),

  actions: {
    upsertInTenantCaches(profile: CustomerProfile) {
      for (const tenantId of tenantIdsForProfile(profile)) {
        const list = this.byTenantId[tenantId] ?? [];
        const index = list.findIndex((row) => row.id === profile.id);
        if (index >= 0) {
          list.splice(index, 1, profile);
        } else {
          list.unshift(profile);
        }
        this.byTenantId[tenantId] = list;
      }
    },

    removeFromTenantCaches(profileId: number) {
      for (const tenantId of Object.keys(this.byTenantId)) {
        const id = Number(tenantId);
        this.byTenantId[id] = (this.byTenantId[id] ?? []).filter((row) => row.id !== profileId);
      }
    },

    async ensureLoaded(tenantId: number, force = false): Promise<CustomerProfile[]> {
      if (!force && this.loadedTenantIds[tenantId]) {
        return this.byTenantId[tenantId] ?? [];
      }

      const inFlight = loadPromises.get(tenantId);
      if (inFlight && !force) {
        return inFlight;
      }

      this.loadingTenantId = tenantId;
      this.error = null;

      const promise = (async () => {
        try {
          const result = await customerProfileRepository.listCustomerProfiles({
            tenant_id: tenantId,
            page: 1,
            page_size: FULL_LIST_PAGE_SIZE,
          });
          const rows = result.data ?? [];
          this.byTenantId[tenantId] = rows;
          this.loadedTenantIds[tenantId] = true;
          return rows;
        } catch (err) {
          this.error = err instanceof Error ? err.message : 'Failed to load billing profiles.';
          throw err;
        } finally {
          this.loadingTenantId = null;
          loadPromises.delete(tenantId);
        }
      })();

      loadPromises.set(tenantId, promise);
      return promise;
    },

    async fetchCustomerProfiles(payload: CustomerProfileListQuery = {}) {
      this.loading = true;
      this.error = null;

      try {
        const result = await customerProfileRepository.listCustomerProfiles(payload);
        this.items = result.data ?? [];
        this.total = result.meta.total ?? 0;
        this.page = result.meta.page ?? 1;
        this.page_size = result.meta.page_size ?? 20;
        this.total_pages = result.meta.total_pages ?? 1;

        if (typeof payload.tenant_id === 'number' && (payload.page_size ?? payload.pageSize ?? 20) >= FULL_LIST_PAGE_SIZE) {
          this.byTenantId[payload.tenant_id] = this.items;
          this.loadedTenantIds[payload.tenant_id] = true;
        }

        return { success: true, data: result };
      } catch (err: unknown) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to load billing profiles.';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.loading = false;
      }
    },

    async createCustomerProfile(payload: CreateCustomerProfileInput) {
      this.saving = true;
      this.error = null;

      try {
        const result = await customerProfileRepository.createCustomerProfile(payload);
        this.items.unshift(result);
        this.total += 1;
        this.upsertInTenantCaches(result);
        showSuccessNotification('Billing profile created successfully.');
        return { success: true, data: result };
      } catch (err: unknown) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to create billing profile.';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },

    async updateCustomerProfile(payload: UpdateCustomerProfileInput) {
      this.saving = true;
      this.error = null;

      try {
        const result = await customerProfileRepository.updateCustomerProfile(payload);
        const index = this.items.findIndex((row) => row.id === result.id);
        if (index >= 0) {
          this.items.splice(index, 1, result);
        }
        this.upsertInTenantCaches(result);
        showSuccessNotification('Billing profile updated successfully.');
        return { success: true, data: result };
      } catch (err: unknown) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to update billing profile.';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },

    async deleteCustomerProfile(id: number) {
      this.saving = true;
      this.error = null;

      try {
        await customerProfileRepository.deleteCustomerProfile({ id });
        this.items = this.items.filter((row) => row.id !== id);
        this.total = Math.max(0, this.total - 1);
        this.removeFromTenantCaches(id);
        showSuccessNotification('Billing profile deleted successfully.');
        return { success: true };
      } catch (err: unknown) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to delete billing profile.';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },
  },
});
