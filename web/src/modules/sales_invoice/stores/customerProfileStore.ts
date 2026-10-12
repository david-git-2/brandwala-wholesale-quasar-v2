import { defineStore } from 'pinia';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { customerProfileRepository } from '../repositories/customerProfileRepository';
import type {
  CustomerProfile,
  CustomerProfileListQuery,
  CreateCustomerProfileInput,
  UpdateCustomerProfileInput,
} from '../repositories/customerProfileRepository';

export interface CustomerProfileStoreState {
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
        return { success: true, data: result };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to load billing profiles.';
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
        showSuccessNotification('Billing profile created successfully.');
        return { success: true, data: result };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to create billing profile.';
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
        showSuccessNotification('Billing profile updated successfully.');
        return { success: true, data: result };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to update billing profile.';
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
        showSuccessNotification('Billing profile deleted successfully.');
        return { success: true };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to delete billing profile.';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },
  },
});
