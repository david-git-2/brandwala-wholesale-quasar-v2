import { defineStore } from 'pinia'

import { membershipService } from '../services/membershipService'
import type {
  Membership,
  MembershipCreateInput,
  MembershipDeleteInput,
  MembershipStoreState,
  MembershipUpdateInput,
} from '../types'

export const useMembershipStore = defineStore('membership', {
  state: (): MembershipStoreState => ({
    items: [],
    loading: false,
    error: null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchMemberships() {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.listMemberships()

        if (!result.success) {
          this.error = result.error ?? 'Failed to load memberships.'
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },
    async fetchMembershipsByTenantId(tenantId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.fetchMembershipsByTenantId(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load memberships for tenant.'
          return result
        }

        this.items = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createMembership(membership: MembershipCreateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.createMembership(membership)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create membership.'
          return result
        }

        if (result.data) {
          this.items.push(result.data)
        }
        return result
      } finally {
        this.loading = false
      }
    },

    async updateMembership(membership: MembershipUpdateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.updateMembership(membership)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update membership.'
          return result
        }

        const updatedMembership = result.data!
        const index = this.items.findIndex((item) => item.id === updatedMembership.id)

        if (index >= 0) {
          this.items.splice(index, 1, updatedMembership)
        }

        return result
      } finally {
        this.loading = false
      }
    },

    async deleteMembership(membership: MembershipDeleteInput) {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.deleteMembership(membership)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete membership.'
          return result
        }

        this.items = this.items.filter((item: Membership) => item.id !== membership.id)
        return result
      } finally {
        this.loading = false
      }
    },
    async getTenantAdmins(tenantId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.getTenantAdmins(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load tenant admins.'
          return result
        }

        return result
      } finally {
        this.loading = false
      }
    }
  },
})
