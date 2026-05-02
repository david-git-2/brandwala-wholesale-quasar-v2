import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { billingProfileService } from '../services/billingProfileService'
import type {
  BillingProfileListQuery,
  BillingProfileStoreState,
  CreateBillingProfileInput,
  UpdateBillingProfileInput,
} from '../types/billingProfile'

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
      this.loading = true
      this.error = null

      try {
        const result = await billingProfileService.listBillingProfiles(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load billing profiles.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = result.data?.data ?? []
        this.total = result.data?.meta.total ?? 0
        this.page = result.data?.meta.page ?? 1
        this.page_size = result.data?.meta.page_size ?? 20
        this.total_pages = result.data?.meta.total_pages ?? 1
        return result
      } finally {
        this.loading = false
      }
    },

    async createBillingProfile(payload: CreateBillingProfileInput) {
      this.saving = true
      this.error = null

      try {
        const result = await billingProfileService.createBillingProfile(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create billing profile.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.unshift(result.data)
          this.total += 1
        }

        showSuccessNotification('Billing profile created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateBillingProfile(payload: UpdateBillingProfileInput) {
      this.saving = true
      this.error = null

      try {
        const result = await billingProfileService.updateBillingProfile(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update billing profile.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Billing profile updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteBillingProfile(id: number) {
      this.saving = true
      this.error = null

      try {
        const result = await billingProfileService.deleteBillingProfile({ id })
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete billing profile.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((row) => row.id !== id)
        this.total = Math.max(0, this.total - 1)
        showSuccessNotification('Billing profile deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
