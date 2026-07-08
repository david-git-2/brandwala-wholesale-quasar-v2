import { defineStore } from 'pinia';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import { recipientProfileRepository } from '../repositories/recipientProfileRepository';
import type {
  RecipientProfile,
  CreateRecipientProfileInput,
  UpdateRecipientProfileInput,
} from 'src/types/recipientProfile';

export const useRecipientProfileStore = defineStore('recipientProfile', {
  state: () => ({
    items: [] as RecipientProfile[],
    loading: false,
    saving: false,
    error: null as string | null,
  }),
  actions: {
    async fetchRecipientProfiles(tenantId: number) {
      this.loading = true;
      this.error = null;
      try {
        const data = await recipientProfileRepository.list(tenantId);
        this.items = data;
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to fetch recipient profiles';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
      } finally {
        this.loading = false;
      }
    },

    async createRecipientProfile(payload: CreateRecipientProfileInput) {
      this.saving = true;
      this.error = null;
      try {
        const data = await recipientProfileRepository.create(payload);
        this.items.unshift(data);
        showSuccessNotification('Recipient profile created successfully.');
        return { success: true, data };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to create recipient profile';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },

    async updateRecipientProfile(payload: UpdateRecipientProfileInput) {
      this.saving = true;
      this.error = null;
      try {
        const data = await recipientProfileRepository.update(payload);
        const index = this.items.findIndex((row) => row.id === data.id);
        if (index >= 0) {
          this.items.splice(index, 1, data);
        }
        showSuccessNotification('Recipient profile updated successfully.');
        return { success: true, data };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to update recipient profile';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },

    async deleteRecipientProfile(id: number) {
      this.saving = true;
      this.error = null;
      try {
        await recipientProfileRepository.delete(id);
        const index = this.items.findIndex((row) => row.id === id);
        if (index >= 0) {
          this.items.splice(index, 1);
        }
        showSuccessNotification('Recipient profile deleted successfully.');
        return { success: true };
      } catch (err: any) {
        const errorMsg = err.message || 'Failed to delete recipient profile';
        this.error = errorMsg;
        handleApiFailure(err, errorMsg);
        return { success: false, error: errorMsg };
      } finally {
        this.saving = false;
      }
    },
  },
});
