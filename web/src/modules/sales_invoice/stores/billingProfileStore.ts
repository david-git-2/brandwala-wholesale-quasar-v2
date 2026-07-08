import { defineStore } from 'pinia';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { billingProfileRepository } from '../repositories/billingProfileRepository';
import type {
  BillingProfile,
  BillingProfileListQuery,
  CreateBillingProfileInput,
  UpdateBillingProfileInput,
} from '../repositories/billingProfileRepository';

export interface BillingProfileStoreState {
  items: BillingProfile[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
  loading: boolean;
  saving: boolean;
  error: string | null;
}

export const useBillingProfileStore = defineStore('billingProfile', {
  state: (): BillingProfileStoreState => ({
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
    async fetchBillingProfiles(payload: BillingProfileListQuery = {}) {
      this.loading = true;
      this.error = null;

      try {
        const result = await billingProfileRepository.listBillingProfiles(payload);
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

    async createBillingProfile(payload: CreateBillingProfileInput) {
      this.saving = true;
      this.error = null;

      try {
        const result = await billingProfileRepository.createBillingProfile(payload);
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

    async updateBillingProfile(payload: UpdateBillingProfileInput) {
      this.saving = true;
      this.error = null;

      try {
        const result = await billingProfileRepository.updateBillingProfile(payload);
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

    async deleteBillingProfile(id: number) {
      this.saving = true;
      this.error = null;

      try {
        await billingProfileRepository.deleteBillingProfile({ id });
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
