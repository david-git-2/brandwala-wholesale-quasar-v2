import { defineStore } from 'pinia'
import { membershipService } from '../services/membershipService'
import { parseMembershipPreference } from '../types/preferences'
import type { MembershipPreferenceSchema } from '../types/preferences'

export const useMembershipPreferenceStore = defineStore('membershipPreference', {
  state: () => ({
    preference: {} as MembershipPreferenceSchema,
    loadedMembershipId: null as number | null,
    loading: false,
    error: null as string | null,
  }),

  actions: {
    setPreference(membershipId: number, raw: unknown) {
      this.preference = parseMembershipPreference(raw)
      this.loadedMembershipId = membershipId
      this.error = null
    },

    patchPreference(membershipId: number, patch: Partial<MembershipPreferenceSchema>) {
      if (this.loadedMembershipId !== membershipId) {
        this.loadedMembershipId = membershipId
      }

      this.preference = {
        ...this.preference,
        ...patch,
        ui: {
          ...this.preference.ui,
          ...patch.ui,
          productBasedCosting: {
            ...this.preference.ui?.productBasedCosting,
            ...patch.ui?.productBasedCosting,
          },
          thriftShipment: {
            ...this.preference.ui?.thriftShipment,
            ...patch.ui?.thriftShipment,
          },
        },
      }
    },

    async savePreference(membershipId: number) {
      this.loading = true
      this.error = null

      try {
        const result = await membershipService.updateMembershipPreference({
          membershipId,
          preference: this.preference,
        })

        if (!result.success || !result.data) {
          this.error = result.error ?? 'Failed to save membership preferences.'
          return { success: false as const, error: this.error }
        }

        this.setPreference(membershipId, result.data.preference)
        return { success: true as const, data: result.data }
      } finally {
        this.loading = false
      }
    },

    clear() {
      this.preference = {}
      this.loadedMembershipId = null
      this.loading = false
      this.error = null
    },
  },
})
