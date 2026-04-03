import { defineStore } from 'pinia'

import {
  handleApiFailure,
  showSuccessNotification,
} from 'src/utils/appFeedback'
import { customerGroupService } from '../services/customerGroupService'
import type {
  CustomerGroup,
  CustomerGroupCreateInput,
  CustomerGroupDeleteInput,
  CustomerGroupMember,
  CustomerGroupMemberCreateInput,
  CustomerGroupMemberDeleteInput,
  CustomerGroupMemberUpdateInput,
  CustomerGroupUpdateInput,
} from '../types'

export const useCustomerGroupStore = defineStore('customerGroup', {
  state: () => ({
    groups: [] as CustomerGroup[],
    members: [] as CustomerGroupMember[],
    loading: false,
    membersLoading: false,
    error: null as string | null,
  }),

  actions: {
    clearError() {
      this.error = null
    },

    async fetchCustomerGroupsByTenant(tenantId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await customerGroupService.listCustomerGroupsByTenant(tenantId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load customer groups.'
          handleApiFailure(result, this.error)
          return result
        }

        this.groups = result.data ?? []
        return result
      } finally {
        this.loading = false
      }
    },

    async createCustomerGroup(payload: CustomerGroupCreateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await customerGroupService.createCustomerGroup(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create customer group.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.groups.push(result.data)
        }

        showSuccessNotification('Customer group created successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async updateCustomerGroup(payload: CustomerGroupUpdateInput) {
      this.loading = true
      this.error = null

      try {
        const result = await customerGroupService.updateCustomerGroup(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update customer group.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedGroup = result.data

        if (updatedGroup) {
          const index = this.groups.findIndex((item) => item.id === updatedGroup.id)

          if (index >= 0) {
            this.groups.splice(index, 1, updatedGroup)
          }
        }

        showSuccessNotification('Customer group updated successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async deleteCustomerGroup(payload: CustomerGroupDeleteInput) {
      this.loading = true
      this.error = null

      try {
        const result = await customerGroupService.deleteCustomerGroup(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete customer group.'
          handleApiFailure(result, this.error)
          return result
        }

        this.groups = this.groups.filter((item) => item.id !== payload.id)
        this.members = []
        showSuccessNotification('Customer group deleted successfully.')
        return result
      } finally {
        this.loading = false
      }
    },

    async fetchCustomerGroupMembersByGroup(customerGroupId: number) {
      this.membersLoading = true
      this.error = null

      try {
        const result =
          await customerGroupService.listCustomerGroupMembersByGroup(customerGroupId)

        if (!result.success) {
          this.error = result.error ?? 'Failed to load customer group members.'
          handleApiFailure(result, this.error)
          return result
        }

        this.members = result.data ?? []
        return result
      } finally {
        this.membersLoading = false
      }
    },

    async createCustomerGroupMember(payload: CustomerGroupMemberCreateInput) {
      this.membersLoading = true
      this.error = null

      try {
        const result = await customerGroupService.createCustomerGroupMember(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to create customer group member.'
          handleApiFailure(result, this.error)
          return result
        }

        if (result.data) {
          this.members.push(result.data)
        }

        showSuccessNotification('Customer user created successfully.')
        return result
      } finally {
        this.membersLoading = false
      }
    },

    async updateCustomerGroupMember(payload: CustomerGroupMemberUpdateInput) {
      this.membersLoading = true
      this.error = null

      try {
        const result = await customerGroupService.updateCustomerGroupMember(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to update customer group member.'
          handleApiFailure(result, this.error)
          return result
        }

        const updatedMember = result.data

        if (updatedMember) {
          const index = this.members.findIndex((item) => item.id === updatedMember.id)

          if (index >= 0) {
            this.members.splice(index, 1, updatedMember)
          }
        }

        showSuccessNotification('Customer user updated successfully.')
        return result
      } finally {
        this.membersLoading = false
      }
    },

    async deleteCustomerGroupMember(payload: CustomerGroupMemberDeleteInput) {
      this.membersLoading = true
      this.error = null

      try {
        const result = await customerGroupService.deleteCustomerGroupMember(payload)

        if (!result.success) {
          this.error = result.error ?? 'Failed to delete customer group member.'
          handleApiFailure(result, this.error)
          return result
        }

        this.members = this.members.filter((item) => item.id !== payload.id)
        showSuccessNotification('Customer user deleted successfully.')
        return result
      } finally {
        this.membersLoading = false
      }
    },
  },
})
