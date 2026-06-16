import { defineStore } from 'pinia'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'
import { commerceBillingProfileService } from '../services/commerceBillingProfileService'
import type {
  CommerceBillingProfile,
  CommerceBillingProfileListQuery,
  CreateCommerceBillingProfileInput,
  UpdateCommerceBillingProfileInput,
} from '../repositories/commerceBillingProfileRepository'

export interface CommerceBillingProfileStoreState {
  items: CommerceBillingProfile[]
  total: number
  page: number
  page_size: number
  total_pages: number
  loading: boolean
  saving: boolean
  error: string | null
}

export const useCommerceBillingProfileStore = defineStore('commerceBillingProfile', {
  state: (): CommerceBillingProfileStoreState => ({
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
    async fetchCommerceBillingProfiles(payload: CommerceBillingProfileListQuery = {}) {
      this.loading = true
      this.error = null

      try {
        const result = await commerceBillingProfileService.listCommerceBillingProfiles(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to load commerce billing profiles.'
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

    async createCommerceBillingProfile(payload: CreateCommerceBillingProfileInput) {
      this.saving = true
      this.error = null

      try {
        const result = await commerceBillingProfileService.createCommerceBillingProfile(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to create commerce billing profile.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.items.unshift(result.data)
          this.total += 1
        }

        showSuccessNotification('Commerce billing profile created successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async updateCommerceBillingProfile(payload: UpdateCommerceBillingProfileInput) {
      this.saving = true
      this.error = null

      try {
        const result = await commerceBillingProfileService.updateCommerceBillingProfile(payload)
        if (!result.success) {
          this.error = result.error ?? 'Failed to update commerce billing profile.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          const index = this.items.findIndex((row) => row.id === result.data?.id)
          if (index >= 0) {
            this.items.splice(index, 1, result.data)
          }
        }

        showSuccessNotification('Commerce billing profile updated successfully.')
        return result
      } finally {
        this.saving = false
      }
    },

    async deleteCommerceBillingProfile(id: number) {
      this.saving = true
      this.error = null

      try {
        const result = await commerceBillingProfileService.deleteCommerceBillingProfile({ id })
        if (!result.success) {
          this.error = result.error ?? 'Failed to delete commerce billing profile.'
          handleApiFailure(result, this.error)
          return result
        }

        this.items = this.items.filter((row) => row.id !== id)
        this.total = Math.max(0, this.total - 1)
        showSuccessNotification('Commerce billing profile deleted successfully.')
        return result
      } finally {
        this.saving = false
      }
    },
  },
})
